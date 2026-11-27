import 'dart:collection';
import '../models/review.dart';

// CACHING: in-memory copy of the logged-in user's own reviews (GET /me/reviews).
// Different from my Sprint 3 ReviewsMemoryCache (LRU + 2 min TTL):
//   - these reviews can only change through THIS app (the user's own actions), so the cache is kept
//     exact by EVENTS (write-through on publish/sync) instead of expiring by time
//   - HashMap keyed by restaurantId: O(1) get/put The backend keeps ONE review per user and restaurant
// Pure class (no Flutter, no Hive, no network) so it can be unit tested; MyReviewsService decides when to use it
class MyReviewsMemoryCache {
  final DateTime Function() _now; // injectable clock so loadedAt can be tested

  int? _ownerId; // whose reviews these are
  final HashMap<String, Review> _byRestaurant = HashMap();
  bool _loaded = false; // true only after a FULL list came from the network
  DateTime? _loadedAt; // shown as "saved on" if the user goes offline
  int hits = 0, misses = 0; // for the debug log / wiki evidence

  MyReviewsMemoryCache({DateTime Function()? now}) : _now = now ?? DateTime.now;

  // Full list, newest first, or null (miss) if nothing confirmed by the network for this user
  List<Review>? get(int userId) {
    if (!_loaded || _ownerId != userId) {
      misses++;
      return null;
    }
    hits++;
    return _byRestaurant.values.toList()..sort((a, b) => b.date.compareTo(a.date));
  }

  DateTime? get loadedAt => _loadedAt;

  void replaceAll(int userId, List<Review> reviews) {
    _byRestaurant
      ..clear()
      ..addAll({for (final r in reviews) r.restaurantId: r});
    _ownerId = userId;
    _loaded = true;
    _loadedAt = _now();
  }

  bool upsert(int userId, Review review) {
    if (!_loaded || _ownerId != userId) return false;
    _byRestaurant[review.restaurantId] = review; // same place -> replaces, like the backend
    return true;
  }

  void clear() {
    _byRestaurant.clear();
    _loaded = false;
    _ownerId = null;
    _loadedAt = null;
  }
}
