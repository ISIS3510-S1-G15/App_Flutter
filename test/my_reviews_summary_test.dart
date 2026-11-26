import 'package:flutter_test/flutter_test.dart';
import 'package:app_flutter/models/review.dart';

// Builds a review through fromJson, the same path the backend answer of /me/reviews takes
Review _review(String id, {int taste = 3, int attention = 3, int price = 3, int options = 3}) => Review.fromJson({
      'id': id,
      'restaurant_id': 'r1',
      'author': 'Ana',
      'created_at': '2026-01-01T12:00:00Z',
      'taste': taste,
      'attention': attention,
      'price': price,
      'options': options,
      'dietary_options': const <String>[],
      'comment': '',
    });

void main() {
  test('no reviews: count 0, average "—" and plural label', () {
    final summary = MyReviewsSummary.from(const []);
    expect(summary.count, 0);
    expect(summary.averageGiven, isNull);
    expect(summary.averageLabel, '—');
    expect(summary.countLabel, 'reviews written');
  });

  test('one 5/5/5/5 review: "5.0" and singular label', () {
    final summary = MyReviewsSummary.from([_review('1', taste: 5, attention: 5, price: 5, options: 5)]);
    expect(summary.count, 1);
    expect(summary.averageGiven, 5.0);
    expect(summary.averageLabel, '5.0');
    expect(summary.countLabel, 'review written');
  });

  test('several reviews: average of the overalls, rounded to 1 decimal', () {
    final summary = MyReviewsSummary.from([
      _review('1', taste: 5, attention: 4, price: 3, options: 2), // overall 3.5
      _review('2', taste: 4, attention: 4, price: 4, options: 5), // overall 4.25
      _review('3', taste: 1, attention: 2, price: 2, options: 2), // overall 1.75
    ]);
    // By hand: (3.5 + 4.25 + 1.75) / 3 = 9.5 / 3 = 3.1666... -> "3.2"
    expect(summary.count, 3);
    expect(summary.averageGiven, closeTo(9.5 / 3, 1e-9));
    expect(summary.averageLabel, '3.2');
    expect(summary.countLabel, 'reviews written');
  });
}
