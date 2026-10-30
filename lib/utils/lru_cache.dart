import 'dart:collection';

class LruCache<K, V> {
  final int maxSize;
  final LinkedHashMap<K, V> _entries = LinkedHashMap<K, V>();

  LruCache(this.maxSize) : assert(maxSize > 0);

  V? get(K key) {
    if (!_entries.containsKey(key)) return null;
    final value = _entries.remove(key) as V;
    _entries[key] = value;
    return value;
  }

  void put(K key, V value) {
    _entries.remove(key);
    _entries[key] = value;
    if (_entries.length > maxSize) {
      _entries.remove(_entries.keys.first);
    }
  }

  int get length => _entries.length;

  void clear() => _entries.clear();
}
