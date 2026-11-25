import 'package:app_flutter/services/history_worker.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('groups the history by day in the worker isolate, newest first', () async {
    final now = DateTime(2026, 11, 20, 15);
    String at(DateTime t) => t.toUtc().toIso8601String();
    final sections = await HistoryWorker.group([
      {'restaurant_id': '1', 'view_count': 2, 'last_viewed_at': at(DateTime(2026, 11, 20, 9))},
      {'restaurant_id': '2', 'view_count': 1, 'last_viewed_at': at(DateTime(2026, 11, 19, 20))},
      {'restaurant_id': '3', 'view_count': 4, 'last_viewed_at': at(DateTime(2026, 11, 20, 12))},
      {'restaurant_id': '4', 'view_count': 1, 'last_viewed_at': at(DateTime(2026, 11, 2, 8))},
    ], now);

    expect(sections.map((s) => s['title']), ['Today', 'Yesterday', 'Earlier']);
    expect((sections[0]['items'] as List).map((e) => (e as Map)['restaurant_id']), ['3', '1']);
  });

  test('decodes and encodes JSON in the worker isolate', () async {
    final raw = await HistoryWorker.encode({'items': [], 'pending': [], 'updated_at': null});
    final data = await HistoryWorker.decode(raw);
    expect(data['items'], isEmpty);
  });
}
