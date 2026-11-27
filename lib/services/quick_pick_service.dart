import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/quick_pick.dart';
import '../utils/meal_context.dart';
import 'api_client.dart';
import 'auth_service.dart';
import 'connectivity_service.dart';

// Repository of the Quick Pick (BQ Type 2 correction). Eventual connectivity: Network falling back to cache.
class QuickPickService {
  static final ApiClient _api = ApiClient(); // Singleton: already carries the user's session token

  // Discover listens to it: null = no card
  static final ValueNotifier<QuickPick?> current = ValueNotifier(null);

  static const _maxAge = Duration(days: 7);

  // Home and AppOpenTracker can both call load() at app start: only the newest call may set the value
  static int _request = 0;

  static Future<void> load() async {
    final request = ++_request;
    final userId = AuthService.currentUser.value?.id;
    if (userId == null) {
      current.value = null;
      return;
    }
    final now = DateTime.now();
    final slot = mealSlotFor(now); // same meal moment definition as the BQ capture
    if (await _isDismissed(userId, now, slot)) {
      if (request == _request) current.value = null;
      return;
    }

    // Same key pattern and reason as decision_time_<userId>: personal data, never shown to another account
    final cacheKey = 'quick_pick_${userId}_$slot';
    QuickPick? pick;
    try {
      // Offline: go straight to the copy instead of waiting for the request timeout
      if (!ConnectivityService.isOnline.value) throw StateError('offline');
      final json = await _api.getJson(
        '/analytics/time-to-selection/me/quick-pick?meal_slot=${Uri.encodeQueryComponent(slot)}',
      ) as Map<String, dynamic>;
      pick = QuickPick.fromJson(json, savedAt: now);
      // Saved even when kind is null: offline, "nothing to suggest" is also a valid last answer
      await _save(cacheKey, pick);
    } catch (e) {
      debugPrint('Could not load the Quick Pick, using the saved copy: $e');
      pick = await _cached(cacheKey, now);
    }

    // A newer load started, or the user logged out / changed account while this one was waiting
    if (request != _request || AuthService.currentUser.value?.id != userId) return;
    current.value = pick;
  }

  // "Not today": hides the card for this meal moment, today only (another moment can bring it back)
  static Future<void> dismissToday() async {
    _request++; // a load still running must not bring the card back
    current.value = null;
    final userId = AuthService.currentUser.value?.id;
    if (userId == null) return;
    final now = DateTime.now();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('quick_pick_dismissed_$userId', '${_day(now)}|${mealSlotFor(now)}');
    } catch (e) {
      debugPrint('Could not save the Quick Pick dismissal: $e');
    }
  }

  // Logout. The per-user keys stay: they are never shown to another account
  static Future<void> clear() async {
    _request++;
    current.value = null;
  }

  static String _day(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static Future<bool> _isDismissed(int userId, DateTime now, String slot) async {
    try {
      final value = (await SharedPreferences.getInstance()).getString('quick_pick_dismissed_$userId');
      return value == '${_day(now)}|$slot';
    } catch (e) {
      debugPrint('Could not read the Quick Pick dismissal: $e');
      return false;
    }
  }

  // Disk errors never reach the screen: the worst case is not having an offline copy
  static Future<void> _save(String key, QuickPick pick) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, jsonEncode(pick.toJson()));
    } catch (e) {
      debugPrint('Could not save the Quick Pick: $e');
    }
  }

  static Future<QuickPick?> _cached(String key, DateTime now) async {
    try {
      final raw = (await SharedPreferences.getInstance()).getString(key);
      if (raw == null) return null;
      final pick = QuickPick.fromStored(jsonDecode(raw) as Map<String, dynamic>);
      // Older than a week: the habit may have changed, better show nothing
      return now.difference(pick.savedAt) > _maxAge ? null : pick;
    } catch (e) {
      debugPrint('Could not read the saved Quick Pick: $e');
      return null;
    }
  }
}
