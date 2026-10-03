import 'package:flutter/foundation.dart';
import '../utils/meal_context.dart';
import 'api_client.dart';

// Analytics pipeline for the Type 1 BQ (Juan Felipe Ochoa):
// "On average, how many times does a user open the app during a typical academic week?"
//
//   1. Capture:    AppOpenTracker calls logAppOpen() when a logged-in user enters or comes back to the app
//   2. Storage:    POST /analytics/app-open saves one row with the user (from the session token),
//                  the time, and the meal moment of that time (context)
//   3. Processing: GET /analytics/app-opens/weekly averages the opens per user per week
//   4. Report:     GET /analytics/app-opens/export (CSV) for the team
class AppUsageAnalytics {
  static final ApiClient _api = ApiClient(); // Singleton: already carries the user's session token

  // Fails silently: analytics must never block or interrupt the user
  static Future<void> logAppOpen() async {
    try {
      await _api.postJson('/analytics/app-open', {'meal_slot': mealSlotFor(DateTime.now())});
    } catch (e) {
      debugPrint('Could not log app open: $e');
    }
  }
}
