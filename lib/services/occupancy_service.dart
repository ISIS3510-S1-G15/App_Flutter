import 'package:flutter/foundation.dart';
import 'api_client.dart';
import 'occupancy_propagation_analytics.dart';

// How crowded a restaurant is right now, according to the reports of the last hour (backend)
class OccupancyStatus {
  final double? level;          // average 0-2 (0 not crowded, 2 busy); null = no recent reports
  final List<int> reports;      // the reports used for the average, newest first
  final DateTime? lastReportAt; // in the phone's time
  final int? lastReportId;      // id of the newest report used (BQ Type 1: tells me when a NEW report arrived)

  const OccupancyStatus({this.level, this.reports = const [], this.lastReportAt, this.lastReportId});

  static const empty = OccupancyStatus();

  bool get hasData => level != null;

  factory OccupancyStatus.fromJson(Map<String, dynamic> json) => OccupancyStatus(
        level: (json['level'] as num?)?.toDouble(),
        reports: (json['reports'] as List).cast<int>(),
        lastReportAt: json['last_report_at'] == null ? null : DateTime.parse(json['last_report_at'] as String).toLocal(),
        lastReportId: json['last_report_id'] as int?,
      );
}

// Why I asked for the crowding data. The screens say WHY they refresh; the service sees the data arrive
// and decides if a new report showed up. wireName is the value the backend expects
enum OccupancyRefreshSource {
  appOpen('app_open'),       // first load of the session: only a starting point, never measured
  tabChange('tab_change'),
  detailOpen('detail_open'),
  detailPoll('detail_poll'), // the detail's 30 s timer
  ownReport('own_report');   // answer to the user's own report (may bring other people's reports too)

  const OccupancyRefreshSource(this.wireName);
  final String wireName;
}

// Design pattern: REPOSITORY. Before, Home/Map used a fixed list inside each restaurant and the Detail used
// SharedPreferences (only this phone's reports), so the same place could show 3 different levels.
// Now EVERY screen reads the same ValueNotifier, filled from the backend
class OccupancyService {
  static final ApiClient _api = ApiClient(); // Singleton: already carries the user's session token

  // Same window the backend uses: a report older than this no longer says how the place is NOW
  static const Duration recentWindow = Duration(hours: 1);

  static final ValueNotifier<Map<String, OccupancyStatus>> statuses = ValueNotifier(const {});

  // BQ Type 1: newest report id this phone already has per restaurant (null = it knew there were none)
  static final Map<String, int?> _shownReportId = {};
  // Last refresh per restaurant, and last full load (after it I also know the missing ones have no reports)
  static final Map<String, DateTime> _refreshedAt = {};
  static DateTime? _fullLoadAt;

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
  static Future<void> loadAll({required OccupancyRefreshSource source}) async {
    // A new session (app opened or another user logged in) starts the comparison from zero
    if (source == OccupancyRefreshSource.appOpen) _resetTracking();
    try {
      final data = await _api.getJson('/occupancy') as List;
      final fresh = {
        for (final item in data.cast<Map<String, dynamic>>())
          item['restaurant_id'] as String: OccupancyStatus.fromJson(item),
      };
      // Also the ones I knew before: if they are missing now, their reports expired
      for (final id in {...fresh.keys, ..._shownReportId.keys}) {
        _track(id, fresh[id] ?? OccupancyStatus.empty, source);
      }
      _fullLoadAt = DateTime.now();
      statuses.value = fresh;
    } catch (e) {
      debugPrint('Could not load occupancy: $e'); // keeps the last known values (network falling back to cache)
    }
  }

  // Status of one restaurant (Detail card, refreshed every few seconds while it is open)
  static Future<OccupancyStatus> refresh(String restaurantId, {required OccupancyRefreshSource source}) async {
    try {
      final data = await _api.getJson('/occupancy/$restaurantId') as Map<String, dynamic>;
      final fresh = OccupancyStatus.fromJson(data);
      _track(restaurantId, fresh, source);
      _put(restaurantId, fresh);
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
      final fresh = OccupancyStatus.fromJson(data as Map<String, dynamic>);
      // The answer may include other people's reports I had not seen; the backend ignores the user's own
      _track(restaurantId, fresh, OccupancyRefreshSource.ownReport);
      _put(restaurantId, fresh);
      return true;
    } catch (e) {
      debugPrint('Could not send occupancy report: $e');
      return false;
    }
  }

  static void _put(String restaurantId, OccupancyStatus status) {
    statuses.value = {...statuses.value, restaurantId: status};
  }

  // If what arrived has a NEWER report than the one I had, sends the BQ event (fire-and-forget)
  static void _track(String restaurantId, OccupancyStatus fresh, OccupancyRefreshSource source) {
    final now = DateTime.now();
    final previousRefresh = _latest(_refreshedAt[restaurantId], _fullLoadAt);
    final previousId = _shownReportId[restaurantId];
    final newId = fresh.lastReportId;
    _shownReportId[restaurantId] = newId;
    _refreshedAt[restaurantId] = now;

    // Not measured: the session's first load, the first time I see this restaurant, no reports, or the same report
    if (source == OccupancyRefreshSource.appOpen || previousRefresh == null) return;
    if (newId == null || newId == previousId) return;

    OccupancyPropagationAnalytics.logUpdate(
      restaurantId: restaurantId,
      reportId: newId,
      previousReportId: previousId,
      source: source.wireName,
      // Both times come from the same phone clock, so a wrong clock does not matter
      msSincePreviousRefresh: now.difference(previousRefresh).inMilliseconds,
    );
  }

  static void _resetTracking() {
    _shownReportId.clear();
    _refreshedAt.clear();
    _fullLoadAt = null;
  }

  static DateTime? _latest(DateTime? a, DateTime? b) {
    if (a == null) return b;
    if (b == null) return a;
    return a.isAfter(b) ? a : b;
  }
}
