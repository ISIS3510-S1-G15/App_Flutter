import 'dart:convert';
import '../models/review.dart';
import 'review_service.dart' show RatingSummary, RestaurantReviews;

// Same limit the reviews screen always showed under "Commonly noted"
const int topDietsLimit = 5;

const _categoryKeys = ['taste', 'attention', 'price', 'options'];

// Entry point for the NETWORK answer: decoding is also CPU work, so it runs inside the isolate too.
// Top-level on purpose: an isolate shares no memory with the UI isolate, so it can only run
// top-level/static functions and only receives/returns copied, plain data
RestaurantReviews digestReviewsJson(String body) => digestReviews(jsonDecode(body) as Map<String, dynamic>);

// Entry point for an already-decoded map (the local SQLite copy from ReviewsDb.read)
RestaurantReviews digestReviews(Map<String, dynamic> data, {bool fromCache = false}) {
  final reviews = (data['reviews'] as List).cast<Map<String, dynamic>>().map(Review.fromJson).toList();

  // ONE pass for the 4 category sums and the diet counts, instead of the 5 loops the screen did on every build()
  final sums = {for (final key in _categoryKeys) key: 0};
  final dietCounts = <String, int>{};
  for (final r in reviews) {
    for (final key in _categoryKeys) {
      sums[key] = sums[key]! + r.ratings.byKey(key);
    }
    for (final d in r.dietaryOptions) {
      dietCounts[d] = (dietCounts[d] ?? 0) + 1;
    }
  }

  // Same sort the screen used, so ties keep the same order on screen
  final sortedDiets = dietCounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  final syncedAt = data['synced_at'] as String?;

  return RestaurantReviews(
    summary: RatingSummary.fromJson(data),
    reviews: reviews,
    fromCache: fromCache,
    // Local copy: when it was synced. Network: it just arrived
    savedAt: syncedAt != null ? DateTime.parse(syncedAt).toLocal() : DateTime.now(),
    averages: {for (final key in _categoryKeys) key: reviews.isEmpty ? 0 : sums[key]! / reviews.length},
    topDiets: [for (final e in sortedDiets.take(topDietsLimit)) (diet: e.key, count: e.value)],
  );
}
