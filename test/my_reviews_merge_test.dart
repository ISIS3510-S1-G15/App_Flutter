import 'package:flutter_test/flutter_test.dart';
import 'package:app_flutter/models/review.dart';
import 'package:app_flutter/services/my_reviews_service.dart';
import 'package:app_flutter/services/pending_reviews.dart';

// A review as the backend sends it (newest first in the lists below)
Review _server(String restaurantId, DateTime date, {int stars = 4}) => Review(
      id: 'srv_$restaurantId',
      restaurantId: restaurantId,
      author: 'Ana',
      date: date,
      ratings: ReviewRatings(taste: stars, attention: stars, price: stars, options: stars),
    );

// A review written offline, through the same path the app uses (PendingReview.toReview)
Review _pending(String restaurantId, DateTime queuedAt, {int stars = 2}) => PendingReview(
      userId: 1,
      restaurantId: restaurantId,
      ratings: ReviewRatings(taste: stars, attention: stars, price: stars, options: stars),
      author: 'Ana',
      queuedAt: queuedAt,
    ).toReview();

final _server3 = [
  _server('a', DateTime(2026, 11, 20)),
  _server('b', DateTime(2026, 11, 10)),
  _server('c', DateTime(2026, 11, 1)),
];

void main() {
  test('no pending -> the server list as it is', () {
    expect(mergeMyReviews(_server3, const []), _server3);
  });

  test('pending of a restaurant with no server review -> first, the others follow', () {
    final merged = mergeMyReviews(_server3, [_pending('z', DateTime(2026, 11, 25))]);
    expect(merged.map((r) => r.id), ['pending_z', 'srv_a', 'srv_b', 'srv_c']);
    expect(merged.first.pending, isTrue);
  });

  test('pending of a restaurant WITH a server review -> the pending shows, the server one is hidden', () {
    final merged = mergeMyReviews(_server3, [_pending('b', DateTime(2026, 11, 25))]);
    expect(merged.map((r) => r.id), ['pending_b', 'srv_a', 'srv_c']);
  });

  test('two pending -> newest queuedAt first, both before the server ones', () {
    // Passed oldest first on purpose: the merge must still put the newest on top
    final merged = mergeMyReviews(_server3, [
      _pending('x', DateTime(2026, 11, 24)),
      _pending('y', DateTime(2026, 11, 26)),
    ]);
    expect(merged.map((r) => r.id), ['pending_y', 'pending_x', 'srv_a', 'srv_b', 'srv_c']);
  });

  test('MyReviewsSummary of the merge counts the pending review', () {
    // Server a=4, b=4 (hidden by its pending), c=4; pending b=2 -> (2 + 4 + 4) / 3 = 3.33 -> "3.3"
    final merged = mergeMyReviews(_server3, [_pending('b', DateTime(2026, 11, 25), stars: 2)]);
    final summary = MyReviewsSummary.from(merged);
    expect(summary.count, 3);
    expect(summary.averageLabel, '3.3');

    // A pending review of a new place adds one more: (2 + 4 + 4 + 4) / 4 = 3.5
    final withNew = MyReviewsSummary.from(mergeMyReviews(_server3, [_pending('z', DateTime(2026, 11, 25), stars: 2)]));
    expect(withNew.count, 4);
    expect(withNew.averageLabel, '3.5');
  });
}
