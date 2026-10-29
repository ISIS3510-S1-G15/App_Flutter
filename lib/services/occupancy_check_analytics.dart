import 'package:flutter/foundation.dart';
import 'api_client.dart';
import 'pending_events.dart';

// BQ: "How often do users check or inquire about a restaurant's occupancy level before deciding to go?"
//   1. Capture:    DetailScreen sends "occupancy_checked" when it shows the crowding indicator
//                  and "go_decision" when the user taps "Get directions"
//   2. Storage:    POST /analytics/occupancy-event saves one row per event with the user (from the session token)
//   3. Processing: GET /analytics/occupancy-check-rate -> % of go decisions with a check in the 30 min before
class OccupancyCheckAnalytics {
  static final ApiClient _api = ApiClient(); // Singleton: already carries the user's session token

  // The user saw the crowding indicator of this restaurant (hasData = there were reports to show)
  static Future<void> logCheck(String restaurantId, {required bool hasData}) =>
      _log({'restaurant_id': restaurantId, 'event': 'occupancy_checked', 'has_data': hasData});

  // The user decided to go to this restaurant (tapped "Get directions")
  static Future<void> logGoDecision(String restaurantId) =>
      _log({'restaurant_id': restaurantId, 'event': 'go_decision'});

  // Fails silently: analytics must never block or interrupt the user
  static Future<void> _log(Map<String, dynamic> body) async {
    try {
      await _api.postJson('/analytics/occupancy-event', body);
    } catch (e) {
      debugPrint('Could not log occupancy event, saved to send later: $e');
      await PendingEvents.add('/analytics/occupancy-event', body);
    }
  }
}
