import 'package:flutter_test/flutter_test.dart';
import 'package:app_flutter/models/review.dart';
import 'package:app_flutter/services/my_reviews_memory_cache.dart';

Review _review(String id, String restaurantId, DateTime date) => Review(
      id: id,
      restaurantId: restaurantId,
      author: 'Ana',
      date: date,
      ratings: const ReviewRatings(taste: 4, attention: 4, price: 4, options: 4),
    );

void main() {
  late DateTime now;
  late MyReviewsMemoryCache cache;
  final monday = DateTime(2026, 11, 23);
  final tuesday = DateTime(2026, 11, 24);
  final a = _review('1', 'r_a', monday);
  final b = _review('2', 'r_b', tuesday);

  setUp(() {
    now = DateTime(2026, 11, 27, 10, 30);
    cache = MyReviewsMemoryCache(now: () => now);
  });

  test('a new cache is a miss', () {
    expect(cache.get(1), isNull);
    expect(cache.misses, 1);
    expect(cache.hits, 0);
  });

  test('after replaceAll it is a hit, newest first', () {
    cache.replaceAll(1, [a, b]);
    expect(cache.get(1), [b, a]);
    expect(cache.hits, 1);
  });

  test("another account never gets this user's reviews", () {
    cache.replaceAll(1, [a, b]);
    expect(cache.get(2), isNull);
    expect(cache.misses, 1);
  });

  test('upsert without a full list does nothing (no partial list)', () {
    expect(cache.upsert(1, a), isFalse);
    expect(cache.get(1), isNull);
  });

  test('upsert of the same restaurant replaces it', () {
    cache.replaceAll(1, [a, b]);
    final newA = _review('3', 'r_a', DateTime(2026, 11, 26));
    expect(cache.upsert(1, newA), isTrue);
    final list = cache.get(1)!;
    expect(list.length, 2);
    expect(list.first.id, '3'); // the newer review of r_a, which is also the newest overall
    expect(list.where((r) => r.restaurantId == 'r_a').single.id, '3');
  });

  test('upsert of another restaurant adds it, first if it is the newest', () {
    cache.replaceAll(1, [a, b]);
    final c = _review('4', 'r_c', DateTime(2026, 11, 26));
    expect(cache.upsert(1, c), isTrue);
    expect(cache.get(1)!.map((r) => r.id), ['4', '2', '1']);
  });

  test('upsert for another account does not touch the cache', () {
    cache.replaceAll(1, [a]);
    expect(cache.upsert(2, b), isFalse);
    expect(cache.get(1), [a]);
  });

  test('clear -> miss again', () {
    cache.replaceAll(1, [a, b]);
    cache.clear();
    expect(cache.get(1), isNull);
  });

  test('loadedAt is the injected clock at replaceAll time', () {
    expect(cache.loadedAt, isNull);
    cache.replaceAll(1, [a]);
    final loadedAt = now;
    now = now.add(const Duration(minutes: 5)); // later reads do not move it
    cache.get(1);
    expect(cache.loadedAt, loadedAt);
  });
}
