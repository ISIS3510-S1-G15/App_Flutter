import 'package:flutter_test/flutter_test.dart';
import 'package:app_flutter/utils/lru_cache.dart';

void main() {
  test('evicts the least recently used entry', () {
    final cache = LruCache<String, int>(2);
    cache.put('a', 1);
    cache.put('b', 2);
    expect(cache.get('a'), 1);
    cache.put('c', 3);
    expect(cache.get('b'), isNull);
    expect(cache.get('a'), 1);
    expect(cache.get('c'), 3);
    expect(cache.length, 2);
  });

  test('updating a key keeps a single entry', () {
    final cache = LruCache<String, int>(2);
    cache.put('a', 1);
    cache.put('a', 5);
    expect(cache.length, 1);
    expect(cache.get('a'), 5);
  });
}
