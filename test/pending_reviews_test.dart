import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:app_flutter/models/review.dart';
import 'package:app_flutter/services/api_client.dart';
import 'package:app_flutter/services/pending_reviews.dart';
import 'package:app_flutter/services/review_service.dart';

// Pure tests: no Hive box is opened, only the mapping and the queue/no-queue decision
final _pending = PendingReview(
  userId: 7,
  restaurantId: 'r1',
  ratings: const ReviewRatings(taste: 5, attention: 4, price: 3, options: 2),
  dietaryOptions: const ['Vegan options', 'Halal'],
  comment: 'Great arepas',
  author: 'Ana',
  queuedAt: DateTime.utc(2026, 11, 25, 14, 30),
);

void main() {
  group('shouldQueue', () {
    test('no answer from the server (timeout) -> queue', () {
      expect(shouldQueue(TimeoutException('slow')), isTrue);
    });
    test('5xx -> queue', () {
      expect(shouldQueue(ApiException(503, '')), isTrue);
    });
    test('422 -> rejected, not queued', () {
      expect(shouldQueue(ApiException(422, '')), isFalse);
    });
    test('401 -> rejected, not queued', () {
      expect(shouldQueue(ApiException(401, '')), isFalse);
    });
  });

  test('PendingReview.fromMap(toMap()) keeps every field', () {
    final copy = PendingReview.fromMap(_pending.toMap());
    expect(copy.userId, 7);
    expect(copy.restaurantId, 'r1');
    expect(copy.ratings.toJson(), _pending.ratings.toJson());
    expect(copy.dietaryOptions, ['Vegan options', 'Halal']);
    expect(copy.comment, 'Great arepas');
    expect(copy.author, 'Ana');
    expect(copy.queuedAt, _pending.queuedAt);
  });

  test('body is the same POST body the online submit sends', () {
    expect(_pending.body, {
      'taste': 5,
      'attention': 4,
      'price': 3,
      'options': 2,
      'dietary_options': ['Vegan options', 'Halal'],
      'comment': 'Great arepas',
    });
  });

  test('toReview() is marked as pending with a pending_ id', () {
    final r = _pending.toReview();
    expect(r.pending, isTrue);
    expect(r.id, 'pending_r1');
    expect(r.restaurantId, 'r1');
    expect(r.date, _pending.queuedAt);
    expect(r.ratings.overall, 3.5);
  });

  test('Review.fromJson(toJson()) keeps every field', () {
    final original = Review(
      id: '42',
      restaurantId: 'r9',
      author: 'Luis',
      date: DateTime.utc(2026, 3, 1, 8, 15).toLocal(),
      ratings: const ReviewRatings(taste: 1, attention: 2, price: 3, options: 4),
      dietaryOptions: const ['Gluten-free'],
      comment: 'ok',
    );
    final copy = Review.fromJson(original.toJson());
    expect(copy.id, '42');
    expect(copy.restaurantId, 'r9');
    expect(copy.author, 'Luis');
    expect(copy.date, original.date);
    expect(copy.ratings.toJson(), original.ratings.toJson());
    expect(copy.dietaryOptions, ['Gluten-free']);
    expect(copy.comment, 'ok');
    expect(copy.pending, isFalse);
  });
}
