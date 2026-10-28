import 'package:flutter/foundation.dart';
import 'api_client.dart';

// BQ Type 1: how long does the occupancy indicator take to update after a place reports its status?
// capture it when a refresh brings a newer report than the one this phone had, and send it to the backend,
// which stores it with its own database clock (so a wrong phone clock does not change the result)
class OccupancyPropagationAnalytics {
  static final ApiClient _api = ApiClient();

  // Fire-and-forget: a failure never interrupts the user
  static Future<void> logUpdate({
    required String restaurantId,
    required int reportId,
    required int? previousReportId,
    required String source,
    required int? msSincePreviousRefresh,
  }) async {
    try {
      await _api.postJson('/analytics/occupancy-propagation', {
        'restaurant_id': restaurantId,
        'report_id': reportId,
        'previous_report_id': previousReportId,
        'source': source,
        'ms_since_previous_refresh': msSincePreviousRefresh,
      });
    } catch (e) {
      debugPrint('Could not log occupancy propagation: $e');
    }
  }
}
