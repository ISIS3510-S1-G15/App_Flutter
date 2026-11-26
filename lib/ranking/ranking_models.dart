import '../models/restaurant.dart';
import '../models/review.dart';

// Top Ranking: Flutter mirror of the Kotlin "Top Ranking" screen (App_Kotlin, data/ranking).
// Same criteria, windows, scoring and texts, so both apps rank the restaurants in the same order.

enum RankingCriterion {
  overall('Overall'),
  taste('Taste'),
  service('Service'),
  value('Value'),
  lessCrowded('Less crowded');

  const RankingCriterion(this.label);
  final String label;
}

enum RankingWindow {
  month('This month'), // reviews of the last 30 days
  allTime('All time');

  const RankingWindow(this.label);
  final String label;
}

class RankedRestaurant {
  final int position;
  final Restaurant restaurant;
  final double score; // 0-5
  final int reviewCount;
  final int? movement; // places moved since the previous ranking (+ up, - down), null = unknown
  final bool isFallback; // no reviews this month, ranked with older ones after the rest

  const RankedRestaurant({
    required this.position,
    required this.restaurant,
    required this.score,
    required this.reviewCount,
    this.movement,
    this.isFallback = false,
  });

  RankedRestaurant withMovement(int? movement) => RankedRestaurant(
        position: position,
        restaurant: restaurant,
        score: score,
        reviewCount: reviewCount,
        movement: movement,
        isFallback: isFallback,
      );
}

class RankingResult {
  final RankingCriterion criterion;
  final RankingWindow window;
  final List<RankedRestaurant> items;
  final DateTime computedAt;
  final bool fromSnapshot; // restored from the local database (shown before computing again)

  const RankingResult({
    required this.criterion,
    required this.window,
    required this.items,
    required this.computedAt,
    this.fromSnapshot = false,
  });
}

// Everything the ranking needs. Only plain data, so it can be sent to a background isolate
class RankingInputs {
  final List<Restaurant> restaurants;
  final List<Review> reviews;
  final Map<String, List<int>> crowding; // restaurant id -> crowding reports, 1 (empty) to 5 (full)
  final Map<String, ({double rating, int count})> summaries; // restaurant id -> rating summary from the backend
  final DateTime windowCutoff; // reviews from this day on count for "This month"

  const RankingInputs({
    required this.restaurants,
    required this.reviews,
    required this.crowding,
    this.summaries = const {},
    required this.windowCutoff,
  });
}

// One row of a ranking saved in the local database
class SnapshotRow {
  final String restaurantId;
  final double score;
  final int reviewCount;

  const SnapshotRow({required this.restaurantId, required this.score, required this.reviewCount});
}

class StoredRanking {
  final List<SnapshotRow> rows;
  final DateTime computedAt;

  const StoredRanking({required this.rows, required this.computedAt});

  List<String> get restaurantIds => [for (final r in rows) r.restaurantId];
}
