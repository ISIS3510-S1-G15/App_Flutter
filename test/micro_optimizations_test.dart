import 'package:app_flutter/utils/search_filter.dart';
import 'package:flutter_test/flutter_test.dart';
import '../profiling/benchmarks.dart';

void main() {
  test('the indexed search returns exactly the same restaurants as before', () {
    final catalog = syntheticCatalog(500);
    final index = buildSearchIndex(catalog);
    for (final q in [...searchQueries, '', '  SUSHI ', 'Building 1']) {
      final before = filterRestaurantsBefore(catalog, q).map((r) => r.id).toList();
      final after = filterRestaurants(catalog, index, q).map((r) => r.id).toList();
      expect(after, before, reason: 'query "$q"');
    }
  });

  test('the history rows find the same restaurants as before', () {
    final catalog = syntheticCatalog(500);
    final history = syntheticHistory(catalog, 100);
    expect(historyRowsAfter(catalog, history, 3), historyRowsBefore(catalog, history, 3));
  });

  test('benchmark', () {
    for (final r in runMicroOptimizationBenchmarks()) {
      // ignore: avoid_print
      print('${r.name}: ${r.milliseconds.toStringAsFixed(2)} ms');
    }
  });
}
