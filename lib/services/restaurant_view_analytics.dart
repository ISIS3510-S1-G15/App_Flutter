import 'package:flutter/foundation.dart';
import 'api_client.dart';

// BQ Type 3: "What places are saved as favorites but rarely viewed in detail again?"
//   1. Capture:    DetailScreen calls logView() every time it opens (the saved places are already in the backend)
//   2. Storage:    POST /analytics/restaurant-view saves one row with the user (from the session token)
//   3. Processing: GET /analytics/saved-rarely-viewed -> for each saved place, how many times it was opened after saving
class RestaurantViewAnalytics {
  static final ApiClient _api = ApiClient(); // Singleton: already carries the user's session token

  // Fails silently: analytics must never block or interrupt the user
  static Future<void> logView(String restaurantId) async {
    try {
      await _api.postJson('/analytics/restaurant-view', {'restaurant_id': restaurantId});
    } catch (e) {
      debugPrint('Could not log restaurant view: $e');
    }
  }
}
