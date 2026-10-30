import 'package:flutter_test/flutter_test.dart';
import 'package:app_flutter/services/review_service.dart';
import 'package:app_flutter/services/reviews_memory_cache.dart';

void main() {
  late DateTime now;
  late ReviewsMemoryCache cache;
  const data = RestaurantReviews(summary: RatingSummary.empty, reviews: []);

  setUp(() {
    now = DateTime(2026, 1, 1, 12);
    cache = ReviewsMemoryCache(now: () => now);
  });

  test('a network entry inside the TTL is a hit', () {
    cache.put('a', data, fromNetwork: true);
    expect(cache.fresh('a'), same(data));
  });

  test('after the TTL the entry is not fresh, but is still available as a fallback', () {
    cache.put('a', data, fromNetwork: true);
    now = now.add(const Duration(minutes: 2, seconds: 1));
    expect(cache.fresh('a'), isNull);
    expect(cache.any('a'), same(data));
  });

  test('an entry loaded from disk is never fresh', () {
    cache.put('a', data, fromNetwork: false);
    expect(cache.fresh('a'), isNull);
    expect(cache.any('a'), same(data));
  });

  test('with capacity 3 the least recently used entry is evicted', () {
    cache.put('a', data, fromNetwork: true);
    cache.put('b', data, fromNetwork: true);
    cache.put('c', data, fromNetwork: true);
    cache.fresh('a'); // a becomes the most recently used, so b is now the oldest
    cache.put('d', data, fromNetwork: true);
    expect(cache.any('b'), isNull);
    expect(cache.any('a'), same(data));
    expect(cache.length, 3);
  });

  test('clear empties the cache', () {
    cache.put('a', data, fromNetwork: true);
    cache.put('b', data, fromNetwork: true);
    cache.clear();
    expect(cache.length, 0);
  });
}
