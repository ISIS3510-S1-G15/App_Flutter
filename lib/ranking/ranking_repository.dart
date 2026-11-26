import 'package:flutter/foundation.dart';
import '../models/review.dart';
import '../services/occupancy_service.dart';
import '../services/restaurant_service.dart';
import '../services/review_service.dart';
import 'ranking_cache.dart';
import 'ranking_db.dart';
import 'ranking_engine.dart';
import 'ranking_models.dart';

// Design pattern: REPOSITORY. The Top Ranking screen never talks to the backend, the database or the
// isolate directly: it asks this class, which decides where each ranking comes from.
// Mirror of the Kotlin RankingRepository:
//   1. snapshot(): the last ranking saved in SQLite (shown instantly, also offline)
//   2. load(): memory LRU cache (hit) -> or compute in an isolate (miss), save it and cache it
//   3. refresh: download restaurants, ratings and reviews again (all at the same time)
class RankingRepository {
  RankingRepository._();
  static final RankingRepository instance = RankingRepository._();

  // CACHING (TTL): after 30 min the ranking is considered stale and is refreshed when there is internet
  static const ttl = Duration(minutes: 30);
  static const windowDays = 30;

  final RankingCache cache = RankingCache();

  Future<RankingResult?> snapshot(RankingCriterion c, RankingWindow w) async {
    try {
      final stored = await RankingDb.load(c, w, RankingDb.current);
      if (stored == null) return null;
      final previous = await RankingDb.load(c, w, RankingDb.previous);
      final byId = {for (final r in RestaurantService.restaurants.value) r.id: r};
      final items = <RankedRestaurant>[];
      for (final row in stored.rows) {
        final restaurant = byId[row.restaurantId];
        if (restaurant == null) continue;
        items.add(RankedRestaurant(
          position: items.length + 1,
          restaurant: restaurant,
          score: row.score,
          reviewCount: row.reviewCount,
        ));
      }
      if (items.isEmpty) return null;
      return RankingResult(
        criterion: c,
        window: w,
        items: RankingMovement.apply(items, previous?.restaurantIds),
        computedAt: stored.computedAt,
        fromSnapshot: true,
      );
    } catch (e) {
      debugPrint('Ranking: could not read the saved ranking: $e');
      return null;
    }
  }

  Future<DateTime?> lastRefreshAt() async {
    try {
      return await RankingDb.lastRefresh();
    } catch (_) {
      return null;
    }
  }

  Future<bool> isStale() async {
    final last = await lastRefreshAt();
    return last == null || DateTime.now().difference(last) > ttl;
  }

  Future<RankingResult> load(RankingCriterion c, RankingWindow w, {required bool refresh}) async {
    final watch = Stopwatch()..start();
    if (refresh) await refreshSources();
    final refreshMs = watch.elapsedMilliseconds;
    final inputs = await _gatherInputs(refresh: false);
    final fingerprint = RankingFingerprint.of(inputs, w);

    final cached = cache.get(c, w, fingerprint);
    if (cached != null) {
      debugPrint('Ranking: cache=HIT hits=${cache.hits} misses=${cache.misses} entries=${cache.length}');
      return cached;
    }

    final gatheredMs = watch.elapsedMilliseconds;
    final results = await _computeAndStore(inputs, w, fingerprint);
    debugPrint('Ranking: cache=MISS refresh=${refreshMs}ms inputs=${gatheredMs - refreshMs}ms '
        'compute=${watch.elapsedMilliseconds - gatheredMs}ms hits=${cache.hits} misses=${cache.misses} '
        'restaurants=${inputs.restaurants.length} reviews=${inputs.reviews.length}');
    return results.firstWhere((r) => r.criterion == c);
  }

  // MULTITHREADING (Futures with handlers + async/await): restaurants, rating summaries and the reviews
  // of every restaurant are requested AT THE SAME TIME with Future.wait, instead of one after another.
  // Each review request has its own handlers: .then counts the restaurants that answered from the
  // network, and .catchError keeps one failing restaurant from cancelling the others.
  // Returns true if the backend was reachable.
  Future<bool> refreshSources() async {
    var reachable = 0;
    final ids = [for (final r in RestaurantService.restaurants.value) r.id];
    await Future.wait<void>([
      RestaurantService.load(),
      ReviewService.loadSummaries(),
      for (final id in ids)
        ReviewService.fetch(id, forceRefresh: true).then((result) {
          if (result != null && !result.fromCache) reachable++;
        }).catchError((Object e) {
          debugPrint('Ranking: reviews of $id not refreshed: $e');
        }),
    ]);
    if (reachable > 0) {
      try {
        await RankingDb.setLastRefresh(DateTime.now());
      } catch (_) {}
    }
    debugPrint('Ranking: refresh done, $reachable/${ids.length} restaurants answered');
    return reachable > 0;
  }

  // Collects the data already on the phone (reviews come from memory, the backend, or their local SQLite
  // copy when offline). Crowding reports use the same 1-5 scale as the Kotlin app
  Future<RankingInputs> _gatherInputs({required bool refresh}) async {
    final restaurants = RestaurantService.restaurants.value;
    final reviewLists = await Future.wait([
      for (final r in restaurants)
        ReviewService.fetch(r.id, forceRefresh: refresh).then((res) => res?.reviews ?? const <Review>[]).catchError(
              (Object _) => const <Review>[],
            ),
    ]);
    final crowding = <String, List<int>>{
      for (final entry in OccupancyService.statuses.value.entries)
        if (entry.value.reports.isNotEmpty) entry.key: [for (final level in entry.value.reports) _appLevel(level)],
    };
    final summaries = <String, ({double rating, int count})>{
      for (final entry in ReviewService.summaries.value.entries)
        if (entry.value.rating != null) entry.key: (rating: entry.value.rating!, count: entry.value.count),
    };
    return RankingInputs(
      restaurants: restaurants,
      reviews: [for (final list in reviewLists) ...list],
      crowding: crowding,
      summaries: summaries,
      windowCutoff: _windowCutoff(),
    );
  }

  Future<List<RankingResult>> _computeAndStore(RankingInputs inputs, RankingWindow w, int fingerprint) async {
    final all = await RankingEngine.computeAllInBackground(inputs, w);
    final now = DateTime.now();
    final results = <RankingResult>[];
    for (final entry in all.entries) {
      final items = await _withMovement(entry.key, w, entry.value, now);
      results.add(RankingResult(criterion: entry.key, window: w, items: items, computedAt: now));
    }
    cache.putAll(results, fingerprint);
    return results;
  }

  // Saves the ranking only when the order changed, and computes ▲/▼ against the ranking before it
  Future<List<RankedRestaurant>> _withMovement(
    RankingCriterion c,
    RankingWindow w,
    List<RankedRestaurant> items,
    DateTime computedAt,
  ) async {
    if (items.isEmpty) return items;
    try {
      final ids = [for (final i in items) i.restaurant.id];
      final current = await RankingDb.load(c, w, RankingDb.current);
      final changed = !listEquals(current?.restaurantIds, ids);
      final baseline = changed ? current : await RankingDb.load(c, w, RankingDb.previous);
      if (changed) {
        await RankingDb.save(
          c,
          w,
          [for (final i in items) SnapshotRow(restaurantId: i.restaurant.id, score: i.score, reviewCount: i.reviewCount)],
          computedAt,
        );
      }
      return RankingMovement.apply(items, baseline?.restaurantIds);
    } catch (e) {
      debugPrint('Ranking: could not save the ranking: $e');
      return items;
    }
  }

  // Backend crowding levels 0 / 1 / 2 -> 1 / 3 / 5, same mapping as the Kotlin appLevelFromRemote
  static int _appLevel(int remote) => switch (remote) {
        0 => 1,
        1 => 3,
        _ => 5,
      };

  static DateTime _windowCutoff() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day).subtract(const Duration(days: windowDays));
  }
}
