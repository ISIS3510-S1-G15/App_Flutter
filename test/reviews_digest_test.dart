import 'dart:convert';
import 'dart:isolate';
import 'package:flutter_test/flutter_test.dart';
import 'package:app_flutter/services/reviews_digest.dart';

Map<String, dynamic> _review(String id, {int taste = 3, int attention = 3, int price = 3, int options = 3,
        List<String> diets = const []}) =>
    {
      'id': id,
      'restaurant_id': 'r1',
      'author': 'Ana',
      'created_at': '2026-01-01T12:00:00Z',
      'taste': taste,
      'attention': attention,
      'price': price,
      'options': options,
      'dietary_options': diets,
      'comment': '',
    };

Map<String, dynamic> _data(List<Map<String, dynamic>> reviews, {String? syncedAt}) => {
      'restaurant_id': 'r1',
      'rating': reviews.isEmpty ? null : 4.0,
      'review_count': reviews.length,
      'synced_at': ?syncedAt,
      'reviews': reviews,
    };

void main() {
  test('averages each category over all the reviews', () {
    final result = digestReviews(_data([
      _review('1', taste: 5, price: 1),
      _review('2', taste: 3, price: 2),
      _review('3', taste: 4, price: 3),
    ]));
    expect(result.averages['taste'], 4.0);
    expect(result.averages['price'], 2.0);
    expect(result.averages['attention'], 3.0);
    expect(result.reviews.length, 3);
  });

  test('an empty list gives 0 averages and no diets', () {
    final result = digestReviews(_data([]));
    expect(result.averages.values, everyElement(0));
    expect(result.averages.length, 4);
    expect(result.topDiets, isEmpty);
  });

  test('topDiets is sorted by count and limited like the screen', () {
    final result = digestReviews(_data([
      _review('1', diets: ['Vegan', 'Gluten free', 'A', 'B', 'C', 'D']),
      _review('2', diets: ['Vegan', 'Gluten free']),
      _review('3', diets: ['Vegan']),
    ]));
    expect(result.topDiets.length, topDietsLimit);
    expect(result.topDiets[0], (diet: 'Vegan', count: 3));
    expect(result.topDiets[1], (diet: 'Gluten free', count: 2));
  });

  test('a local copy keeps its synced_at as savedAt, in local time', () {
    const syncedAt = '2026-01-01T15:30:00.000Z';
    final result = digestReviews(_data([_review('1')], syncedAt: syncedAt), fromCache: true);
    expect(result.savedAt, DateTime.parse(syncedAt).toLocal());
    expect(result.fromCache, isTrue);
  });

  test('digestReviewsJson can run inside Isolate.run and gives the same result', () async {
    final body = jsonEncode(_data([
      _review('1', taste: 5, diets: ['Vegan']),
      _review('2', taste: 2, diets: ['Vegan', 'Halal']),
    ]));
    final direct = digestReviewsJson(body);
    final fromIsolate = await Isolate.run(() => digestReviewsJson(body));
    expect(fromIsolate.averages, direct.averages);
    expect(fromIsolate.topDiets, direct.topDiets);
    expect(fromIsolate.summary.count, direct.summary.count);
    expect(fromIsolate.reviews.map((r) => r.id), direct.reviews.map((r) => r.id));
  });
}
