import 'package:flutter/foundation.dart';
import '../utils/meal_context.dart';
import 'api_client.dart';
import 'pending_events.dart';

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
}
