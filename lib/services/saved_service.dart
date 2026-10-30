import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_client.dart';
import 'connectivity_service.dart';
import 'local_db.dart';

class SavedService {
  static final ApiClient _api = ApiClient();
  static const _lastSyncKey = 'saved_last_synced_at';

  static final ValueNotifier<Set<String>> savedIds = ValueNotifier(<String>{});
  static final ValueNotifier<DateTime?> lastSyncedAt = ValueNotifier(null);
  static final ValueNotifier<int> pendingChanges = ValueNotifier(0);

  static bool isSaved(String restaurantId) => savedIds.value.contains(restaurantId);

  static Future<void> load() async {
    try {
      savedIds.value = await LocalDb.getSavedIds();
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString(_lastSyncKey);
      lastSyncedAt.value = stored == null ? null : DateTime.tryParse(stored);
      pendingChanges.value = (await LocalDb.getPendingChanges()).length;
    } catch (e) {
      debugPrint('Could not read local saved restaurants: $e');
    }
    if (!await _sendPendingChanges()) return;
    try {
      final data = await _api.getJson('/me/saved') as Map<String, dynamic>;
      final ids = (data['restaurant_ids'] as List).cast<String>().toSet();
      savedIds.value = ids;
      await LocalDb.replaceSavedIds(ids);
      await _markSynced();
    } catch (e) {
      debugPrint('Could not load saved restaurants from the backend: $e');
    }
  }

  static Future<bool> _sendPendingChanges() async {
    try {
      final changes = await LocalDb.getPendingChanges();
      for (final change in changes) {
        final restaurantId = change['restaurant_id'] as String;
        try {
          change['action'] == 'save'
              ? await _api.putJson('/me/saved/$restaurantId')
              : await _api.deleteJson('/me/saved/$restaurantId');
        } on ApiException catch (e) {
          if (e.statusCode == 401 || e.statusCode >= 500) rethrow;
        }
        await LocalDb.removePendingChange(change['id'] as int);
        pendingChanges.value = pendingChanges.value > 0 ? pendingChanges.value - 1 : 0;
      }
      return true;
    } catch (e) {
      debugPrint('Pending saved changes not sent yet: $e');
      return false;
    }
  }

  static Future<bool> toggle(String restaurantId) async {
    final wasSaved = isSaved(restaurantId);
    final before = savedIds.value;
    savedIds.value = wasSaved ? ({...before}..remove(restaurantId)) : {...before, restaurantId};
    if (ConnectivityService.isOnline.value && pendingChanges.value == 0) {
      try {
        final data = wasSaved
            ? await _api.deleteJson('/me/saved/$restaurantId')
            : await _api.putJson('/me/saved/$restaurantId');
        savedIds.value = ((data as Map<String, dynamic>)['restaurant_ids'] as List).cast<String>().toSet();
        wasSaved ? await LocalDb.removeSaved(restaurantId) : await LocalDb.addSaved(restaurantId);
        await _markSynced();
        return true;
      } catch (e) {
        debugPrint('Could not update saved restaurant, keeping it on this phone: $e');
      }
    }
    try {
      wasSaved ? await LocalDb.removeSaved(restaurantId) : await LocalDb.addSaved(restaurantId);
      await LocalDb.addPendingChange(restaurantId, wasSaved ? 'unsave' : 'save');
      pendingChanges.value = pendingChanges.value + 1;
      if (ConnectivityService.isOnline.value) load();
    } catch (e) {
      debugPrint('Could not store saved change on this phone: $e');
      savedIds.value = before;
    }
    return false;
  }

  static Future<void> _markSynced() async {
    final now = DateTime.now();
    lastSyncedAt.value = now;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastSyncKey, now.toIso8601String());
  }

  static Future<void> clear() async {
    savedIds.value = <String>{};
    lastSyncedAt.value = null;
    pendingChanges.value = 0;
    try {
      await LocalDb.clearSaved();
      await LocalDb.clearPendingChanges();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_lastSyncKey);
    } catch (e) {
      debugPrint('Could not clear local saved restaurants: $e');
    }
  }
}
