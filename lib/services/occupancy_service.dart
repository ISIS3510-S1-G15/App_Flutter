import 'package:flutter/foundation.dart';
import 'api_client.dart';

// How crowded a restaurant is right now, according to the reports of the last hour (backend)
class OccupancyStatus {
  final double? level;          // average 0-2 (0 not crowded, 2 busy); null = no recent reports
  final List<int> reports;      // the reports used for the average, newest first
  final DateTime? lastReportAt; // in the phone's time

  const OccupancyStatus({this.level, this.reports = const [], this.lastReportAt});

  static const empty = OccupancyStatus();

  bool get hasData => level != null;

  factory OccupancyStatus.fromJson(Map<String, dynamic> json) => OccupancyStatus(
        level: (json['level'] as num?)?.toDouble(),
        reports: (json['reports'] as List).cast<int>(),
        lastReportAt: json['last_report_at'] == null ? null : DateTime.parse(json['last_report_at'] as String).toLocal(),
      );
}

// Design pattern: REPOSITORY. Before, Home/Map used a fixed list inside each restaurant and the Detail used
// SharedPreferences (only this phone's reports), so the same place could show 3 different levels.
// Now EVERY screen reads the same ValueNotifier, filled from the backend
class OccupancyService {
  static final ApiClient _api = ApiClient(); // Singleton: already carries the user's session token

  // Same window the backend uses: a report older than this no longer says how the place is NOW
  static const Duration recentWindow = Duration(hours: 1);

  static final ValueNotifier<Map<String, OccupancyStatus>> statuses = ValueNotifier(const {});

  // Status to show. A cached value older than 1 hour is treated as "no data" so the app never shows an
  // old "Busy" as if it were current (this can happen when there is no internet to refresh it)
  static OccupancyStatus statusOf(String restaurantId) {
    final status = statuses.value[restaurantId];
    if (status == null || status.lastReportAt == null) return OccupancyStatus.empty;
    final age = DateTime.now().difference(status.lastReportAt!);
    return age > recentWindow ? OccupancyStatus.empty : status;
  }

  // Status of every restaurant in ONE request (badges of Home, Map, Search and Saved).
  // Replaces the whole map: places that are not in the answer have no recent reports anymore
  static Future<void> loadAll() async {
    try {
      final data = await _api.getJson('/occupancy') as List;
      statuses.value = {
        for (final item in data.cast<Map<String, dynamic>>())
          item['restaurant_id'] as String: OccupancyStatus.fromJson(item),
      };
    } catch (e) {
      debugPrint('Could not load occupancy: $e'); // keeps the last known values (network falling back to cache)
    }
  }

  // Status of one restaurant (Detail card, refreshed every few seconds while it is open)
  static Future<OccupancyStatus> refresh(String restaurantId) async {
    try {
      final data = await _api.getJson('/occupancy/$restaurantId') as Map<String, dynamic>;
      _put(restaurantId, OccupancyStatus.fromJson(data));
    } catch (e) {
      debugPrint('Could not refresh occupancy of $restaurantId: $e');
    }
    return statusOf(restaurantId);
  }

  // Sends a report (0, 1 or 2). The backend answers with the updated status, so no extra request is needed.
  // Returns false when it could not be sent, so the screen does not say "Thanks" for something that was lost
  static Future<bool> submitReport(String restaurantId, int level) async {
    try {
      final data = await _api.postJson('/occupancy/reports', {'restaurant_id': restaurantId, 'level': level});
      _put(restaurantId, OccupancyStatus.fromJson(data as Map<String, dynamic>));
      return true;
    } catch (e) {
      debugPrint('Could not send occupancy report: $e');
      return false;
    }
  }

  static void _put(String restaurantId, OccupancyStatus status) {
    statuses.value = {...statuses.value, restaurantId: status};
  }
}
