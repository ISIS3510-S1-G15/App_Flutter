import 'package:flutter/foundation.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import '../models/review.dart';
import 'api_client.dart';
import 'auth_service.dart';
import 'connectivity_service.dart';
import 'pending_reviews.dart';

// Design pattern: REPOSITORY. This service is the ONLY access point to "my reviews" (the reviews written by
// the logged-in user). MyReviewsScreen never calls the backend nor Hive directly: it subscribes to watch()
// and this service decides where the data comes from (local copy, queued reviews, backend).

// What the screen receives on every emission of watch()
class MyReviewsSnapshot {
  final List<Review> reviews; // pending first (newest first), then the server ones
  final int pendingCount;
  final bool fromCache; // true = what is shown is the local copy (offline or network failed)
  final DateTime? savedAt; // when the local copy was downloaded
  final bool failed; // the network failed AND there was nothing local to show

  const MyReviewsSnapshot({
    required this.reviews,
    this.pendingCount = 0,
    this.fromCache = false,
    this.savedAt,
    this.failed = false,
  });

  static const failure = MyReviewsSnapshot(reviews: [], failed: true);
}

// Same rule as Kotlin: pending reviews go on top, and a server review of the same restaurant is hidden
// because the pending one replaces it when it is sent (the backend keeps one review per user and place)
List<Review> mergeMyReviews(List<Review> server, List<Review> pending) {
  if (pending.isEmpty) return server;
  // pending already arrives newest first; sorting again is a cheap guarantee of the order on screen
  final sortedPending = [...pending]..sort((a, b) => b.date.compareTo(a.date));
  final queuedPlaces = {for (final p in pending) p.restaurantId};
  return [...sortedPending, ...server.where((r) => !queuedPlaces.contains(r.restaurantId))];
}

class MyReviewsService {
  static final ApiClient _api = ApiClient(); // Singleton: already carries the user's session token

  // LOCAL STORAGE (Hive, key-value), a different box from the queue: the last list the backend answered.
  // Keys: user_id (whose copy it is), saved_at (ISO) and items (list of review.toJson())
  static const _boxName = 'my_reviews';
  static bool _initialized = false;

  // Same pattern as PendingEvents: Hive is initialized once, guarded by a flag
  static Future<Box> _box() async {
    if (!_initialized) {
      await Hive.initFlutter();
      _initialized = true;
    }
    return Hive.openBox(_boxName);
  }

  // CACHE THEN NETWORK (slides 15, strategy #5): emits the local copy first (instant, offline too),
  // then the backend answer, which also refreshes the local copy. async* = a Stream that emits over time
  static Stream<MyReviewsSnapshot> watch() async* {
    final userId = AuthService.currentUser.value?.id;
    var pending = await _pending(userId);
    final local = await _readLocal(userId);

    // 1. Cache: what is on the phone, shown before any network request
    var emitted = false;
    if (local != null || pending.isNotEmpty) {
      yield _snapshot(local?.reviews ?? const [], pending, fromCache: true, savedAt: local?.savedAt);
      emitted = true;
    }

    // 2. Offline: do not even try (it would only wait for the timeout)
    if (!ConnectivityService.isOnline.value) {
      if (!emitted) yield MyReviewsSnapshot.failure;
      return;
    }

    // 3. Network: the fresh list replaces the cached one on screen AND on disk
    try {
      final server = await _fetchNetwork();
      await _saveLocal(userId, server);
      // Read again: the queue may have been synced while the request was running
      pending = await _pending(userId);
      yield _snapshot(server, pending, fromCache: false, savedAt: DateTime.now());
    } catch (e) {
      // 4. Network failed: keep showing the local copy if there was one, otherwise report the failure
      debugPrint('Could not load my reviews from the backend: $e');
      if (emitted) {
        yield _snapshot(local?.reviews ?? const [], pending, fromCache: true, savedAt: local?.savedAt);
      } else {
        yield MyReviewsSnapshot.failure;
      }
    }
  }

  // Logout: the next account must never see this user's copy
  static Future<void> clearLocal() async {
    try {
      await (await _box()).clear();
    } catch (e) {
      debugPrint('Could not clear the local copy of my reviews: $e');
    }
  }

  static MyReviewsSnapshot _snapshot(List<Review> server, List<Review> pending,
          {required bool fromCache, DateTime? savedAt}) =>
      MyReviewsSnapshot(
        reviews: mergeMyReviews(server, pending),
        pendingCount: pending.length,
        fromCache: fromCache,
        savedAt: savedAt,
      );

  // GET /me/reviews -> the reviews written by the logged-in user, newest first. THROWS if the request fails
  static Future<List<Review>> _fetchNetwork() async {
    // The backend answers a plain JSON list (the { items: [...] } wrapper only exists in the Kotlin client)
    final data = await _api.getJson('/me/reviews') as List;
    final reviews = data.cast<Map<String, dynamic>>().map(Review.fromJson).toList();
    // The backend already sends them newest first; sorting again is a cheap guarantee for the view
    reviews.sort((a, b) => b.date.compareTo(a.date));
    return reviews;
  }

  // Only this account's queued reviews, as Review objects marked pending
  static Future<List<Review>> _pending(int? userId) async {
    final queued = await PendingReviews.all(); // already newest first, never throws
    return [for (final p in queued) if (p.userId == userId) p.toReview()];
  }

  // null = nothing saved, OR the copy belongs to another account (it is never shown)
  static Future<({List<Review> reviews, DateTime? savedAt})?> _readLocal(int? userId) async {
    if (userId == null) return null;
    try {
      final box = await _box();
      if (box.isEmpty || box.get('user_id') != userId) return null;
      final items = (box.get('items') as List? ?? const [])
          .map((item) => Review.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList();
      final savedAt = box.get('saved_at') as String?;
      return (reviews: items, savedAt: savedAt == null ? null : DateTime.parse(savedAt));
    } catch (e) {
      debugPrint('Could not read the local copy of my reviews: $e');
      return null;
    }
  }

  // Cached on network response: the copy is refreshed with every good answer from the backend.
  // Own try/catch: a disk error must not turn a good network answer into a failure
  static Future<void> _saveLocal(int? userId, List<Review> reviews) async {
    if (userId == null) return;
    try {
      final box = await _box();
      await box.putAll({
        'user_id': userId,
        'saved_at': DateTime.now().toIso8601String(),
        'items': [for (final r in reviews) r.toJson()],
      });
    } catch (e) {
      debugPrint('Could not save the local copy of my reviews: $e');
    }
  }
}
