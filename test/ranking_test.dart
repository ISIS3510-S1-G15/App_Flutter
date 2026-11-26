import 'package:flutter_test/flutter_test.dart';
import 'package:app_flutter/models/restaurant.dart';
import 'package:app_flutter/models/review.dart';
import 'package:app_flutter/ranking/ranking_cache.dart';
import 'package:app_flutter/ranking/ranking_engine.dart';
import 'package:app_flutter/ranking/ranking_models.dart';

// Same cases as the Kotlin RankingEngineTest, so both apps are checked to rank in the same order
Restaurant restaurant(String id, {double rating = 4, int reviews = 5}) => Restaurant(
      id: id,
      name: 'R$id',
      location: '',
      category: '',
      image: '',
      isOpen: true,
      rating: rating,
      reviews: reviews,
      price: '',
      waitTime: '',
      tags: const [],
      hours: '',
    );

final restaurants = [restaurant('1'), restaurant('2'), restaurant('3')];

Review review(String id, String restaurantId, String date, int taste) => Review(
      id: id,
      restaurantId: restaurantId,
      author: 'a',
      date: DateTime.parse(date),
      ratings: ReviewRatings(taste: taste, attention: 4, price: 4, options: 4),
    );

RankingInputs inputs(List<Review> reviews, {Map<String, List<int>> crowding = const {}}) => RankingInputs(
      restaurants: restaurants,
      reviews: reviews,
      crowding: crowding,
      windowCutoff: DateTime(2026, 11, 16),
    );

List<RankedRestaurant> rank(RankingInputs i, RankingCriterion c, RankingWindow w) => RankingEngine.computeAll(i, w)[c]!;

void main() {
  group('RankingEngine (same cases as Kotlin)', () {
    test('computeAll returns every criterion', () {
      final result = RankingEngine.computeAll(inputs([review('r1', '1', '2026-11-20', 5)]), RankingWindow.allTime);
      expect(result.keys.toSet(), RankingCriterion.values.toSet());
    });

    test('higher average ranks first', () {
      final ranking = rank(
        inputs([
          review('r1', '1', '2026-11-20', 5),
          review('r2', '1', '2026-11-20', 5),
          review('r3', '2', '2026-11-20', 2),
          review('r4', '2', '2026-11-20', 2),
        ]),
        RankingCriterion.taste,
        RankingWindow.allTime,
      );
      expect(ranking.map((r) => r.restaurant.id), ['1', '2']);
      expect(ranking.map((r) => r.position), [1, 2]);
    });

    test('smoothing penalises a single review', () {
      final ranking = rank(
        inputs([
          review('r1', '1', '2026-11-20', 5),
          for (var i = 1; i <= 10; i++) review('m$i', '2', '2026-11-20', 5),
          for (var i = 1; i <= 10; i++) review('n$i', '3', '2026-11-20', 3),
        ]),
        RankingCriterion.taste,
        RankingWindow.allTime,
      );
      expect(ranking.first.restaurant.id, '2');
    });

    test('month window ranks recent reviews first and keeps the others as fallback', () {
      final ranking = rank(
        inputs([review('r1', '1', '2026-11-01', 5), review('r2', '2', '2026-11-20', 3)]),
        RankingCriterion.taste,
        RankingWindow.month,
      );
      expect(ranking.map((r) => r.restaurant.id), ['2', '1']);
      expect(ranking.map((r) => r.isFallback), [false, true]);
    });

    test('all time window never marks fallback', () {
      final ranking = rank(
        inputs([review('r1', '1', '2026-11-01', 5), review('r2', '2', '2026-11-20', 3)]),
        RankingCriterion.taste,
        RankingWindow.allTime,
      );
      expect(ranking.any((r) => r.isFallback), isFalse);
    });

    test('restaurants without any review still rank overall from their rating', () {
      final ranking = rank(inputs([]), RankingCriterion.overall, RankingWindow.month);
      expect(ranking.map((r) => r.restaurant.id).toSet(), {'1', '2', '3'});
      expect(ranking.every((r) => r.isFallback), isTrue);
    });

    test('less crowded prefers lower levels', () {
      final ranking = rank(
        inputs([], crowding: {'1': [5, 5], '2': [1, 1], '3': [3, 3]}),
        RankingCriterion.lessCrowded,
        RankingWindow.allTime,
      );
      expect(ranking.first.restaurant.id, '2');
    });

    test('the isolate gives the same ranking as the main thread', () async {
      final i = inputs([review('r1', '1', '2026-11-20', 5), review('r2', '2', '2026-11-20', 3)]);
      final background = await RankingEngine.computeAllInBackground(i, RankingWindow.allTime);
      final main = RankingEngine.computeAll(i, RankingWindow.allTime);
      for (final c in RankingCriterion.values) {
        expect(background[c]!.map((r) => r.restaurant.id), main[c]!.map((r) => r.restaurant.id));
      }
    });
  });

  group('RankingMovement and RankingFingerprint', () {
    test('movement is previous position minus new position', () {
      final ranking = rank(
        inputs([review('r1', '1', '2026-11-20', 5), review('r2', '2', '2026-11-20', 2)]),
        RankingCriterion.taste,
        RankingWindow.allTime,
      );
      final moved = RankingMovement.apply(ranking, ['2', '1']);
      expect(moved.map((r) => r.movement), [1, -1]); // "1" went up one place, "2" went down one
      expect(RankingMovement.apply(ranking, null).map((r) => r.movement), [null, null]);
    });

    test('fingerprint changes when a review changes', () {
      final a = RankingFingerprint.of(inputs([review('r1', '1', '2026-11-20', 5)]), RankingWindow.month);
      final same = RankingFingerprint.of(inputs([review('r1', '1', '2026-11-20', 5)]), RankingWindow.month);
      final b = RankingFingerprint.of(inputs([review('r1', '1', '2026-11-20', 4)]), RankingWindow.month);
      expect(a, same);
      expect(a, isNot(b));
    });
  });

  group('RankingCache (LRU)', () {
    RankingResult result(RankingCriterion c) =>
        RankingResult(criterion: c, window: RankingWindow.month, items: const [], computedAt: DateTime(2026));

    test('hit and miss are counted', () {
      final cache = RankingCache();
      expect(cache.get(RankingCriterion.overall, RankingWindow.month, 1), isNull);
      cache.put(result(RankingCriterion.overall), 1);
      expect(cache.get(RankingCriterion.overall, RankingWindow.month, 1), isNotNull);
      expect(cache.get(RankingCriterion.overall, RankingWindow.month, 2), isNull); // other data -> miss
      expect((cache.hits, cache.misses), (1, 2));
    });

    test('evicts the least recently used entry when full', () {
      final cache = RankingCache(maxEntries: 2);
      cache.put(result(RankingCriterion.overall), 1);
      cache.put(result(RankingCriterion.taste), 1);
      cache.get(RankingCriterion.overall, RankingWindow.month, 1); // overall is now the most recent
      cache.put(result(RankingCriterion.service), 1); // evicts taste, the least recently used
      expect(cache.length, 2);
      expect(cache.get(RankingCriterion.taste, RankingWindow.month, 1), isNull);
      expect(cache.get(RankingCriterion.overall, RankingWindow.month, 1), isNotNull);
      expect(cache.get(RankingCriterion.service, RankingWindow.month, 1), isNotNull);
    });
  });
}
