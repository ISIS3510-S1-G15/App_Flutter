import '../utils/meal_context.dart';
import '../utils/text_utils.dart';
import 'restaurant.dart';

enum QuickPickKind { yourUsual, campusFavorite }

// Answer of the BQ Type 2 turned into an action: the place to suggest at this meal moment and why
class QuickPick {
  final String mealSlot;
  final QuickPickKind? kind;          // null = nothing to suggest (the card is hidden)
  final List<String> candidates;      // restaurant ids, best first
  final int timesChosen;
  final double? myAvgSeconds;         // decision time WITHOUT the shortcut, this meal moment
  final double? campusAvgSeconds;
  final int mySelections;
  final DateTime savedAt;             // when the backend answered (for the offline copy)
  final bool fromCache;

  const QuickPick({
    required this.mealSlot,
    required this.kind,
    this.candidates = const [],
    this.timesChosen = 0,
    this.myAvgSeconds,
    this.campusAvgSeconds,
    this.mySelections = 0,
    required this.savedAt,
    this.fromCache = false,
  });

  // GET /analytics/time-to-selection/me/quick-pick. An unknown kind is treated as "nothing to suggest"
  factory QuickPick.fromJson(Map<String, dynamic> json, {required DateTime savedAt, bool fromCache = false}) =>
      QuickPick(
        mealSlot: json['meal_slot'] as String? ?? '',
        kind: switch (json['kind']) {
          'your_usual' => QuickPickKind.yourUsual,
          'campus_favorite' => QuickPickKind.campusFavorite,
          _ => null,
        },
        candidates: [for (final id in json['candidates'] as List? ?? const []) id.toString()],
        timesChosen: (json['times_chosen'] as num?)?.toInt() ?? 0,
        myAvgSeconds: (json['my_avg_seconds'] as num?)?.toDouble(),
        campusAvgSeconds: (json['campus_avg_seconds'] as num?)?.toDouble(),
        mySelections: (json['my_selections'] as num?)?.toInt() ?? 0,
        savedAt: savedAt,
        fromCache: fromCache,
      );

  // Offline copy: the same shape the backend sends, plus when it was received
  Map<String, dynamic> toJson() => {
        'meal_slot': mealSlot,
        'kind': switch (kind) {
          QuickPickKind.yourUsual => 'your_usual',
          QuickPickKind.campusFavorite => 'campus_favorite',
          null => null,
        },
        'candidates': candidates,
        'times_chosen': timesChosen,
        'my_avg_seconds': myAvgSeconds,
        'campus_avg_seconds': campusAvgSeconds,
        'my_selections': mySelections,
        'saved_at': savedAt.toIso8601String(),
      };

  factory QuickPick.fromStored(Map<String, dynamic> stored) =>
      QuickPick.fromJson(stored, savedAt: DateTime.parse(stored['saved_at'] as String), fromCache: true);
}

// First candidate that exists in the catalog AND is open right now (the backend does not know the hours)
Restaurant? resolveQuickPick(QuickPick? pick, List<Restaurant> catalog, DateTime now) {
  if (pick == null || pick.kind == null) return null;
  final byId = {for (final r in catalog) r.id: r};
  for (final id in pick.candidates) {
    final r = byId[id];
    if (r != null && isOpenAt(r, now)) return r;
  }
  return null;
}

// Feedback after using the shortcut, only when this decision was faster than usual:
// "⚡ Picked in 12 s · you usually take about 3 min at lunch". null = say nothing
String? quickPickFeedback(Duration elapsed, QuickPick pick) {
  // Own average first (the habit this shortcut replaces); without it, the campus one
  final mine = pick.myAvgSeconds;
  final reference = mine ?? pick.campusAvgSeconds;
  if (reference == null) return null;
  final seconds = elapsed.inMilliseconds / 1000;
  // Not faster than usual: claiming an improvement that did not happen would be misleading
  if (seconds >= reference) return null;

  final moment = pick.mealSlot.toLowerCase(); // "lunch", "mid-morning snack"...
  final who = mine != null ? 'you usually take' : 'students usually take';
  return '⚡ Picked in ${formatDecisionTime(seconds, exactSeconds: true)} · '
      '$who ${formatDecisionTime(reference, exactSeconds: true)} at $moment';
}
