import '../utils/lru_cache.dart';
import 'review_service.dart' show RestaurantReviews;

// Strategy: LRU memory cache (slides 17) with an expiration policy (slides 15), on top of the SQLite copy.
// I reuse Sofía's LruCache (LinkedHashMap, O(1) get/put) and only add what is specific to reviews: the TTL.
//   - capacity 3: each entry holds up to 50 reviews (heavier than a Search result list), with a 2 min TTL the
//     memory only helps while comparing the 2-3 places the user is deciding between, and SQLite already keeps
//     the persistent copy. With 4 restaurants in the catalog the eviction can also be shown live
//   - TTL 2 min: reviews change slowly, so within 2 min a request is wasted; longer would hide new reviews
class ReviewsMemoryCache {
  final int capacity;
  final Duration ttl;
  final DateTime Function() _now; // injectable clock so the TTL can be tested without waiting
  final LruCache<String, _Entry> _lru;

  ReviewsMemoryCache({this.capacity = 3, this.ttl = const Duration(minutes: 2), DateTime Function()? now})
      : _now = now ?? DateTime.now,
        _lru = LruCache(capacity);

  // Only a NETWORK answer younger than the TTL counts as fresh; a copy loaded from disk must still try the network
  RestaurantReviews? fresh(String restaurantId) {
    final entry = _lru.get(restaurantId);
    if (entry == null || !entry.fromNetwork) return null;
    return _now().difference(entry.storedAt) < ttl ? entry.data : null;
  }

  // Any entry, even expired or loaded from disk: only used when the network failed
  RestaurantReviews? any(String restaurantId) => _lru.get(restaurantId)?.data;

  void put(String restaurantId, RestaurantReviews data, {required bool fromNetwork}) {
    _lru.put(restaurantId, _Entry(data, _now(), fromNetwork));
  }

  int get length => _lru.length;

  void clear() => _lru.clear();
}

class _Entry {
  final RestaurantReviews data;
  final DateTime storedAt;
  final bool fromNetwork;

  const _Entry(this.data, this.storedAt, this.fromNetwork);
}
