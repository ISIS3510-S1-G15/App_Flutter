import 'package:flutter/foundation.dart';
import 'api_client.dart';

// Restaurants the logged-in user saved (bookmark on the detail screen), stored in the backend per user.
// savedIds is a ValueNotifier, so the Saved tab and the detail's bookmark redraw as soon as it changes
class SavedService {
  static final ApiClient _api = ApiClient(); // Singleton: already carries the user's session token

  static final ValueNotifier<Set<String>> savedIds = ValueNotifier(<String>{});

  static bool isSaved(String restaurantId) => savedIds.value.contains(restaurantId);

  // Reads the user's saved restaurants. Called when the main app opens (after login or a restored session)
  static Future<void> load() async {
    try {
      final data = await _api.getJson('/me/saved') as Map<String, dynamic>;
      savedIds.value = (data['restaurant_ids'] as List).cast<String>().toSet();
    } catch (e) {
      debugPrint('Could not load saved restaurants: $e'); // keeps what was there (empty at first)
    }
  }

  // Saves or unsaves a restaurant. The icon changes right away and goes back if the server can't be reached.
  // Returns false when it failed, so the screen can tell the user
  static Future<bool> toggle(String restaurantId) async {
    final wasSaved = isSaved(restaurantId);
    final before = savedIds.value;
    savedIds.value = wasSaved ? ({...before}..remove(restaurantId)) : {...before, restaurantId};
    try {
      final data = wasSaved
          ? await _api.deleteJson('/me/saved/$restaurantId')
          : await _api.putJson('/me/saved/$restaurantId');
      savedIds.value = ((data as Map<String, dynamic>)['restaurant_ids'] as List).cast<String>().toSet();
      return true;
    } catch (e) {
      debugPrint('Could not update saved restaurant: $e');
      savedIds.value = before;
      return false;
    }
  }

  // Forgets the previous user's list when logging out
  static void clear() => savedIds.value = <String>{};
}
