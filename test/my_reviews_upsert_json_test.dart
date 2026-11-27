import 'package:flutter_test/flutter_test.dart';
import 'package:app_flutter/services/my_reviews_service.dart';

Map<String, dynamic> _json(String id, String restaurantId) => {
      'id': id,
      'restaurant_id': restaurantId,
      'author': 'Ana',
      'created_at': '2026-11-27T12:00:00Z',
      'taste': 4,
      'attention': 4,
      'price': 4,
      'options': 4,
      'dietary_options': <String>[],
      'comment': '',
    };

void main() {
  final items = [_json('1', 'r_a'), _json('2', 'r_b')];

  test('replaces by restaurant_id without duplicating', () {
    final result = upsertReviewJson(items, _json('9', 'r_b'));
    expect(result.length, 2);
    expect(result.map((r) => r['id']), ['1', '9']);
  });

  test('adds it when that restaurant had no review', () {
    final result = upsertReviewJson(items, _json('9', 'r_c'));
    expect(result.map((r) => r['id']), ['1', '2', '9']);
  });

  test('returns a new list and leaves the original untouched', () {
    final result = upsertReviewJson(items, _json('9', 'r_a'));
    expect(identical(result, items), isFalse);
    expect(items.map((r) => r['id']), ['1', '2']);
  });
}
