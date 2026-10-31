import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/meal_context.dart';
import 'api_client.dart';
import 'auth_service.dart';
import 'pending_events.dart';

// The Type 2 BQ answer shown to the user: their average time to choose a place vs. every student's
class DecisionTime {
  final double? mySeconds; // null = this user has not chosen any place yet
  final int mySelections;
  final double campusSeconds;
  final int campusSelections;
  final DateTime updatedAt;
  final bool fromCache;

  const DecisionTime({
    required this.mySeconds,
    required this.mySelections,
    required this.campusSeconds,
    required this.campusSelections,
    required this.updatedAt,
    this.fromCache = false,
  });

  factory DecisionTime.fromJson(Map<String, dynamic> json, {required DateTime updatedAt, bool fromCache = false}) =>
      DecisionTime(
        mySeconds: (json['my_avg_seconds'] as num?)?.toDouble(),
        mySelections: json['my_selections'] as int? ?? 0,
        campusSeconds: (json['campus_avg_seconds'] as num? ?? 0).toDouble(),
        campusSelections: json['campus_selections'] as int? ?? 0,
        updatedAt: updatedAt,
        fromCache: fromCache,
      );
}

// Analytics pipeline for the Type 2 BQ (Juan Felipe Ochoa):
// "How long does it take, on average, for a user to go from opening the app to selecting a place to eat?"
//
//   1. Capture:    AppOpenTracker calls markAppOpen() with the same "open" definition as the Type 1 BQ,
//                  and DetailScreen calls logSelection() when the user taps "Get directions"
//   2. Storage:    POST /analytics/place-selection saves the user (from the token), the restaurant,
//                  the milliseconds since the open and the meal moment of the open
//   3. Processing: GET /analytics/time-to-selection -> average, median, p90 and % within 1 and 5 minutes
//   4. Report:     GET /analytics/time-to-selection/export (CSV)
class PlaceSelectionAnalytics {
  static final ApiClient _api = ApiClient();

  // measure a duration with Stopwatch instead of subtracting two DateTime.now(): its clock is monotonic,
  // so it does not jump if the phone's time is adjusted in the middle
  static final Stopwatch _sinceOpen = Stopwatch();
  static String? _openMealSlot;
  static bool _alreadySelected = true; // nothing to measure until the first open is marked

  // The backend rejects more than a day (422), and PendingEvents stops at the first failure, so a rejected
  // event would block the other BQs' queued events behind it. I drop it here instead
  static const _maxDuration = Duration(hours: 24);

  static void markAppOpen() {
    _sinceOpen
      ..reset()
      ..start();
    _openMealSlot = mealSlotFor(DateTime.now());
    _alreadySelected = false;
  }

  // Only the FIRST "Get directions" after each open counts: later taps are no longer "time until choosing"
  static Future<void> logSelection(String restaurantId) async {
    if (_alreadySelected || !_sinceOpen.isRunning) return;
    _alreadySelected = true; // set before the await so a fast double tap cannot send a duplicate
    final elapsed = _sinceOpen.elapsed;
    if (elapsed > _maxDuration) return;

    final body = <String, dynamic>{
      'restaurant_id': restaurantId,
      'ms_since_app_open': elapsed.inMilliseconds,
      'meal_slot': _openMealSlot,
    };
    // The duration is already measured at the tap, so it stays correct even if the event is sent hours later
    try {
      await _api.postJson('/analytics/place-selection', body);
    } catch (e) {
      debugPrint('Could not log place selection, saved to send later: $e');
      await PendingEvents.add('/analytics/place-selection', body);
    }
  }

  // Type 2: the answer goes back to the user. Strategy "Network falling back to cache" (slides 15):
  // always ask the backend; without internet, show the last value saved on this phone for THIS user
  static Future<DecisionTime?> mySummary() async {
    final userId = AuthService.currentUser.value?.id;
    // The key includes the user: "your average" is personal, another account on this phone must not see it
    final cacheKey = userId == null ? null : 'decision_time_$userId';

    Map<String, dynamic> json;
    try {
      json = await _api.getJson('/analytics/time-to-selection/me') as Map<String, dynamic>;
    } catch (e) {
      debugPrint('Could not load decision time, using the saved copy: $e');
      return cacheKey == null ? null : _cached(cacheKey);
    }

    // No selections on campus yet: nothing true to show, so the card stays hidden
    if ((json['campus_selections'] as int? ?? 0) == 0) return null;
    final now = DateTime.now();
    if (cacheKey != null) await _save(cacheKey, json, now);
    return DecisionTime.fromJson(json, updatedAt: now);
  }

  // Disk errors never reach the Profile: the worst case is not having an offline copy
  static Future<void> _save(String key, Map<String, dynamic> json, DateTime at) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, jsonEncode({'data': json, 'saved_at': at.toIso8601String()}));
    } catch (e) {
      debugPrint('Could not save decision time: $e');
    }
  }

  static Future<DecisionTime?> _cached(String key) async {
    try {
      final raw = (await SharedPreferences.getInstance()).getString(key);
      if (raw == null) return null;
      final stored = jsonDecode(raw) as Map<String, dynamic>;
      return DecisionTime.fromJson(
        stored['data'] as Map<String, dynamic>,
        updatedAt: DateTime.parse(stored['saved_at'] as String),
        fromCache: true,
      );
    } catch (e) {
      debugPrint('Could not read saved decision time: $e');
      return null;
    }
  }
}
