import 'dart:collection';
import 'ranking_models.dart';

// CACHING: LRU (Least Recently Used) memory cache of computed rankings, same as the Kotlin RankingCache.
//
// Structure: a LinkedHashMap keeps the keys in insertion order. Every get() of an existing key removes
// it and inserts it again, so the most recently used entry is always LAST and the least recently used
// is FIRST. When a put() goes over maxEntries, the FIRST key is evicted. get, put and evict are O(1).
//
// Parameters and decisions:
// - maxEntries = 10: there are 5 criteria x 2 windows = 10 rankings for the current data, so the whole
//   screen fits (switching tabs back and forth never recomputes), and memory stays small.
// - Key = criterion | window | fingerprint of the data. When a review, rating or crowding report changes,
//   the fingerprint changes, so an old ranking is never returned: it is simply not found (miss), and the
//   LRU evicts it later. This avoids having to invalidate entries by hand.
// - hits / misses are counted so the effect can be shown in the logs and in the wiki.
class RankingCache {
  RankingCache({this.maxEntries = defaultEntries}) : assert(maxEntries > 0);

  static const defaultEntries = 10;

  final int maxEntries;
  final LinkedHashMap<String, RankingResult> _entries = LinkedHashMap();
  int _hits = 0;
  int _misses = 0;

  int get hits => _hits;
  int get misses => _misses;
  int get length => _entries.length;

  RankingResult? get(RankingCriterion criterion, RankingWindow window, int fingerprint) {
    final key = _key(criterion, window, fingerprint);
    final found = _entries.remove(key);
    if (found == null) {
      _misses++;
      return null;
    }
    _entries[key] = found; // back at the end: most recently used
    _hits++;
    return found;
  }

  void put(RankingResult result, int fingerprint) {
    final key = _key(result.criterion, result.window, fingerprint);
    _entries.remove(key);
    _entries[key] = result;
    while (_entries.length > maxEntries) {
      _entries.remove(_entries.keys.first); // least recently used
    }
  }

  void putAll(Iterable<RankingResult> results, int fingerprint) {
    for (final r in results) {
      put(r, fingerprint);
    }
  }

  void clear() => _entries.clear();

  static String _key(RankingCriterion c, RankingWindow w, int fingerprint) => '${c.name}|${w.name}|$fingerprint';
}
