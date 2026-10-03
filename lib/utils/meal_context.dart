// Context-aware helpers (Juan Felipe Ochoa)
// The app reads the phone's current time (context) and adapts without the user doing anything:
//  - which meal moment it is (same six moments the user picks in the survey)
//  - the greeting on Discover
//  - which restaurants are open right now, according to their opening hours
import '../models/restaurant.dart';

// Same labels and order as the survey question "When do you eat on campus?"
const mealSlots = ['Breakfast', 'Mid-morning snack', 'Lunch', 'Afternoon snack', 'Dinner', 'Late night'];

// Meal moment for a time of day. Ranges follow a typical Uniandes class day
String mealSlotFor(DateTime time) {
  final h = time.hour;
  if (h >= 5 && h < 9) return 'Breakfast';
  if (h >= 9 && h < 11) return 'Mid-morning snack';
  if (h >= 11 && h < 15) return 'Lunch';
  if (h >= 15 && h < 18) return 'Afternoon snack';
  if (h >= 18 && h < 22) return 'Dinner';
  return 'Late night';
}

String greetingFor(DateTime time) {
  if (time.hour >= 5 && time.hour < 12) return 'Good morning';
  if (time.hour >= 12 && time.hour < 18) return 'Good afternoon';
  return 'Good evening';
}

// True if the restaurant is open at that time according to its "hours" text (e.g. "6:30am - 8:00pm").
// If the text cannot be read, falls back to the fixed isOpen value so a restaurant is never hidden by a typo
bool isOpenAt(Restaurant r, DateTime time) {
  final matches = RegExp(r'(\d{1,2})(?::(\d{2}))?\s*(am|pm)', caseSensitive: false).allMatches(r.hours).toList();
  if (matches.length < 2) return r.isOpen;

  final opens = _minutesOfDay(matches[0]);
  final closes = _minutesOfDay(matches[1]);
  final now = time.hour * 60 + time.minute;

  // Normal schedule (7am - 9pm) vs. one that goes past midnight (6pm - 2am)
  return closes > opens ? (now >= opens && now < closes) : (now >= opens || now < closes);
}

int _minutesOfDay(RegExpMatch m) {
  var hour = int.parse(m.group(1)!) % 12; // 12am -> 0, 12pm -> 12 after adding 12 below
  final minutes = int.tryParse(m.group(2) ?? '') ?? 0;
  if (m.group(3)!.toLowerCase() == 'pm') hour += 12;
  return hour * 60 + minutes;
}

// "Today's Pick" chosen by context: only restaurants open right now, best rated first.
// Returns null if everything is closed at this time
Restaurant? contextualPick(List<Restaurant> restaurants, DateTime time) {
  final openNow = restaurants.where((r) => isOpenAt(r, time)).toList()
    ..sort((a, b) => b.rating.compareTo(a.rating));
  return openNow.isEmpty ? null : openNow.first;
}
