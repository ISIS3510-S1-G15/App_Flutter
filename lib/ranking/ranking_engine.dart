import 'dart:developer';
import 'dart:isolate';
import '../models/restaurant.dart';
import '../models/review.dart';
import 'ranking_models.dart';

// Computes the Top Ranking. Same formula as the Kotlin RankingEngine:
// - Each restaurant gets the average of its reviews for the criterion ("Less crowded" uses the
//   crowding reports instead).
// - Bayesian smoothing: the average is pulled toward the global mean with a weight of 3 reviews, so a
//   place with one 5-star review does not beat a place with forty 4.6 reviews.
// - "This month" only counts the last 30 days. A place with no reviews this month is ranked with
//   its older reviews, after the others (fallback, "none this month").
class RankingEngine {
  static const priorWeight = 3.0;
  static const crowdingScaleTop = 6.0; // crowding 1 (empty) -> 5 points, 5 (full) -> 1 point
  static const neutralCrowding = 3.0; // no crowding reports: middle score

  // MULTITHREADING: the 5 rankings (one per criterion) are computed in ONE background isolate, so
  // sorting and averaging every review never blocks the UI thread. RankingInputs only has plain data,
  // so it is copied to the isolate. The TimelineTask shows each run as "RankingEngine.computeAll" in DevTools
  static Future<Map<RankingCriterion, List<RankedRestaurant>>> computeAllInBackground(
    RankingInputs inputs,
    RankingWindow window,
  ) async {
    final task = TimelineTask()..start('RankingEngine.computeAll', arguments: {'reviews': inputs.reviews.length});
    try {
      return await Isolate.run(() => computeAll(inputs, window));
    } finally {
      task.finish();
    }
  }

  static Map<RankingCriterion, List<RankedRestaurant>> computeAll(RankingInputs inputs, RankingWindow window) {
    final all = <String, List<Review>>{};
    final inWindow = <String, List<Review>>{};
    for (final r in inputs.reviews) {
      all.putIfAbsent(r.restaurantId, () => []).add(r);
      if (window == RankingWindow.allTime || !r.date.isBefore(inputs.windowCutoff)) {
        inWindow.putIfAbsent(r.restaurantId, () => []).add(r);
      }
    }
    return {
      for (final c in RankingCriterion.values) c: _rank(inputs, window, c, inWindow, all),
    };
  }

  static List<RankedRestaurant> _rank(
    RankingInputs inputs,
    RankingWindow window,
    RankingCriterion criterion,
    Map<String, List<Review>> inWindow,
    Map<String, List<Review>> all,
  ) {
    final samples = <_Sample>[];
    for (final restaurant in inputs.restaurants) {
      final s = _sampleFor(
        restaurant,
        inWindow[restaurant.id] ?? const [],
        all[restaurant.id] ?? const [],
        inputs.crowding[restaurant.id] ?? const [],
        inputs.summaries[restaurant.id],
        criterion,
        window,
      );
      if (s != null) samples.add(s);
    }
    if (samples.isEmpty) return const [];

    final totalCount = samples.fold<int>(0, (sum, s) => sum + s.count);
    final weighted = samples.fold<double>(0, (sum, s) => sum + s.average * s.count);
    final globalMean = weighted / (totalCount < 1 ? 1 : totalCount);

    final scored = [for (final s in samples) (sample: s, score: smooth(s.average, s.count, globalMean))];
    // Order: places with reviews in the window first, then higher score, more reviews, and name
    scored.sort((a, b) {
      if (a.sample.fallback != b.sample.fallback) return a.sample.fallback ? 1 : -1;
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) return byScore;
      final byCount = b.sample.count.compareTo(a.sample.count);
      if (byCount != 0) return byCount;
      return a.sample.restaurant.name.compareTo(b.sample.restaurant.name);
    });

    return [
      for (var i = 0; i < scored.length; i++)
        RankedRestaurant(
          position: i + 1,
          restaurant: scored[i].sample.restaurant,
          score: scored[i].score,
          reviewCount: scored[i].sample.count,
          isFallback: scored[i].sample.fallback,
        ),
    ];
  }

  static _Sample? _sampleFor(
    Restaurant restaurant,
    List<Review> reviews,
    List<Review> allReviews,
    List<int> crowdingReports,
    ({double rating, int count})? summary,
    RankingCriterion criterion,
    RankingWindow window,
  ) {
    if (criterion == RankingCriterion.lessCrowded) {
      final average = crowdingReports.isEmpty
          ? neutralCrowding
          : crowdingScaleTop - crowdingReports.reduce((a, b) => a + b) / crowdingReports.length;
      return _Sample(restaurant, average, crowdingReports.length);
    }
    final outsideWindow = window == RankingWindow.month;
    if (reviews.isNotEmpty) return _Sample(restaurant, _average(reviews, criterion), reviews.length);
    if (allReviews.isNotEmpty) {
      return _Sample(restaurant, _average(allReviews, criterion), allReviews.length, fallback: outsideWindow);
    }
    // No reviews downloaded: use the rating summary (same as Kotlin applyRatingSummaries)
    final rating = summary?.rating ?? restaurant.rating;
    final count = summary?.count ?? restaurant.reviews;
    if (criterion == RankingCriterion.overall && count > 0) {
      return _Sample(restaurant, rating, count, fallback: outsideWindow);
    }
    return null;
  }

  static double _average(List<Review> reviews, RankingCriterion c) =>
      reviews.fold<double>(0, (sum, r) => sum + _valueOf(r, c)) / reviews.length;

  static double _valueOf(Review r, RankingCriterion c) => switch (c) {
        RankingCriterion.overall => r.ratings.overall,
        RankingCriterion.taste => r.ratings.taste.toDouble(),
        RankingCriterion.service => r.ratings.attention.toDouble(),
        RankingCriterion.value => r.ratings.price.toDouble(),
        RankingCriterion.lessCrowded => 0,
      };

  static double smooth(double average, int count, double globalMean) =>
      (count / (count + priorWeight)) * average + (priorWeight / (count + priorWeight)) * globalMean;
}

class _Sample {
  final Restaurant restaurant;
  final double average;
  final int count;
  final bool fallback;

  const _Sample(this.restaurant, this.average, this.count, {this.fallback = false});
}

// Places moved since the previous ranking: previous position - new position (+ means it went up)
class RankingMovement {
  static List<RankedRestaurant> apply(List<RankedRestaurant> items, List<String>? baselineIds) {
    if (baselineIds == null) return items;
    final before = {for (var i = 0; i < baselineIds.length; i++) baselineIds[i]: i + 1};
    return [
      for (final item in items)
        item.withMovement(before[item.restaurant.id] == null ? null : before[item.restaurant.id]! - item.position),
    ];
  }
}

// A number that changes when any data used by the ranking changes (restaurants, ratings, reviews,
// crowding or the window). It is part of the cache key, so a cached ranking is never shown for old data
class RankingFingerprint {
  static int of(RankingInputs inputs, RankingWindow window) {
    var h = 0x811c9dc5 ^ window.index;
    void mix(Object? v) => h = ((h ^ v.hashCode) * 0x01000193) & 0x7fffffff;
    if (window == RankingWindow.month) mix(inputs.windowCutoff.millisecondsSinceEpoch);
    for (final id in (inputs.summaries.keys.toList()..sort())) {
      mix(id);
      mix(inputs.summaries[id]!.rating);
      mix(inputs.summaries[id]!.count);
    }
    for (final r in inputs.restaurants) {
      mix(r.id);
      mix(r.rating);
      mix(r.reviews);
    }
    for (final r in inputs.reviews) {
      mix(r.id);
      mix(r.restaurantId);
      mix(r.date.millisecondsSinceEpoch);
      mix(r.ratings.overall);
      mix(r.ratings.taste);
      mix(r.ratings.attention);
      mix(r.ratings.price);
    }
    for (final id in (inputs.crowding.keys.toList()..sort())) {
      mix(id);
      for (final level in inputs.crowding[id]!) {
        mix(level);
      }
    }
    return h;
  }
}
