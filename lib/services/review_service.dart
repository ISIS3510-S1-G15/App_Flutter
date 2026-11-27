import 'dart:isolate';
import 'package:flutter/foundation.dart';
import '../models/review.dart';
import 'api_client.dart';
import 'auth_service.dart';
import 'connectivity_service.dart';
import 'my_reviews_service.dart';
import 'pending_reviews.dart';
import 'restaurant_service.dart';
import 'reviews_db.dart';
import 'reviews_digest.dart';
import 'reviews_memory_cache.dart';

// What happened with a submitted review: it reached the server, or it was saved on the phone to be sent later
enum ReviewSubmitOutcome { sent, queued }

// true = connection/server problem worth retrying later; false = the server rejected the review (4xx)
// No answer at all (timeout, socket, ClientException) or a 5xx -> retrying makes sense. A 4xx (401 included)
// means the server said no: sending it again would get the same answer
bool shouldQueue(Object error) => error is! ApiException || error.statusCode >= 500;

// Rating of one restaurant, CALCULATED by the backend from the real reviews (before it was a fixed number)
class RatingSummary {
  final double? rating; // null = no reviews yet
  final int count;

  const RatingSummary({this.rating, this.count = 0});

  static const empty = RatingSummary();

  factory RatingSummary.fromJson(Map<String, dynamic> json) => RatingSummary(
        rating: (json['rating'] as num?)?.toDouble(),
        count: json['review_count'] as int,
      );

  // Text shown next to the star: "4.5", or "New" when nobody has reviewed it
  String get label => rating == null ? 'New' : rating!.toStringAsFixed(1);
}

// What the reviews screen needs: the rating, the reviews, and whether they come from the cache (no internet)
class RestaurantReviews {
  final RatingSummary summary;
  final List<Review> reviews;
  final bool fromCache;
  final DateTime? savedAt; // when this copy came from the backend, so the offline banner can say how old it is
  // Precalculated once per load (reviews_digest.dart, in an isolate) so the screen does not redo them on every build()
  final Map<String, double> averages; // 'taste', 'attention', 'price', 'options' -> 0-5
  final List<({String diet, int count})> topDiets; // most mentioned first

  const RestaurantReviews({
    required this.summary,
    required this.reviews,
    this.fromCache = false,
    this.savedAt,
    this.averages = const {},
    this.topDiets = const [],
  });

  // A copy, so the object stored in the cache is never mutated
  RestaurantReviews get asFromCache => RestaurantReviews(
        summary: summary,
        reviews: reviews,
        fromCache: true,
        savedAt: savedAt,
        averages: averages,
        topDiets: topDiets,
      );
}

// Design pattern: REPOSITORY (slides 17 - Caching). The screens never call the backend directly:
// they ask ReviewService, and it decides where the data comes from (backend, memory or the local SQLite copy).
// Same style as SavedService: static methods + ValueNotifier so the screens redraw when the data changes
class ReviewService {
  static final ApiClient _api = ApiClient(); // Singleton: already carries the user's session token

  // Rating and number of reviews of every restaurant (Home, Map, Search, Saved and Detail read this)
  static final ValueNotifier<Map<String, RatingSummary>> summaries = ValueNotifier(const {});

  // Strategy: LRU memory cache (slides 17) with an expiration policy (slides 15), on top of SQLite
  static final ReviewsMemoryCache _memory = ReviewsMemoryCache();

  // false until /reviews/summary answers once: lets RatingText tell "no reviews" from "not loaded (offline)"
  static bool _summariesLoaded = false;
  static bool get summariesLoaded => _summariesLoaded;

  // The sync running right now (null = none). A second call gets THIS same Future instead of starting another
  // one, so the same review is never posted twice and logout can wait for it to finish
  static Future<void>? _syncing;

  // Name of the restaurant whose queued review the server rejected while syncing in the background.
  // My Reviews shows it in a SnackBar: a background process must not fail silently (anti-pattern #9)
  static final ValueNotifier<String?> syncRejected = ValueNotifier(null);

  static RatingSummary summaryOf(String restaurantId) => summaries.value[restaurantId] ?? RatingSummary.empty;

  // Called when the main app opens. If it fails, the ratings show "New" until the next successful load
  static Future<void> loadSummaries() async {
    try {
      final data = await _api.getJson('/reviews/summary') as List;
      _summariesLoaded = true; // before the assignment, so RatingText already sees it when it redraws
      summaries.value = {
        for (final item in data.cast<Map<String, dynamic>>())
          item['restaurant_id'] as String: RatingSummary.fromJson(item),
      };
    } catch (e) {
      debugPrint('Could not load ratings: $e');
    }
  }

  // Memory (if fresh) -> backend -> "Network falling back to cache" (slides 15): without internet, return the
  // last ones downloaded (fromCache = true). Null = no internet AND nothing cached.
  // forceRefresh skips the memory: the user asked for new data (Retry) or just wrote a review
  static Future<RestaurantReviews?> fetch(String restaurantId, {bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final hit = _memory.fresh(restaurantId);
      if (hit != null) {
        debugPrint('Reviews cache hit: $restaurantId (${_memory.length}/${_memory.capacity})');
        return hit;
      }
    }
    debugPrint('Reviews cache miss: $restaurantId, asking the backend');
    try {
      // I/O: a Future. While waiting for the network the UI thread is free, so no isolate is needed here
      final body = await _api.getRawJson('/restaurants/$restaurantId/reviews');
      // CPU: decode + build the reviews + averages + diet counts in a background isolate, ONCE per load
      // instead of on every build() of the screen (slides 19). The closure only captures the local body
      final result = await Isolate.run(() => digestReviewsJson(body));
      _memory.put(restaurantId, result, fromNetwork: true);
      _setSummary(restaurantId, result.summary);
      await _saveLocally(restaurantId, result); // "Cached on network response" (slides 15)
      return result;
    } catch (e) {
      debugPrint('Could not load reviews of $restaurantId: $e');
      return _fromLocal(restaurantId);
    }
  }

  // Own try/catch: a disk error must not fall into the network catch, the network answer was fine
  static Future<void> _saveLocally(String restaurantId, RestaurantReviews result) async {
    try {
      await ReviewsDb.save(restaurantId, result.summary, result.reviews);
    } catch (e) {
      debugPrint('Could not save reviews of $restaurantId locally: $e');
    }
  }

  // Memory first, even if expired (fastest), then the SQLite copy, which survives closing the app
  static Future<RestaurantReviews?> _fromLocal(String restaurantId) async {
    final cached = _memory.any(restaurantId);
    if (cached != null) return cached.asFromCache;
    try {
      final stored = await ReviewsDb.read(restaurantId);
      if (stored == null) return null;
      final result = await Isolate.run(() => digestReviews(stored, fromCache: true));
      // fromNetwork: false so the next fetch still tries the backend instead of treating it as a hit
      _memory.put(restaurantId, result, fromNetwork: false);
      _setSummary(restaurantId, result.summary);
      return result;
    } catch (e) {
      debugPrint('Could not read local reviews of $restaurantId: $e');
      return null;
    }
  }

  // Called on logout: the local copy holds other people's names
  static Future<void> clearLocal() async {
    _memory.clear();
    // The next user must not see the ratings loaded in this session
    _summariesLoaded = false;
    summaries.value = const {};
    try {
      await ReviewsDb.clear();
    } catch (e) {
      debugPrint('Could not clear local reviews: $e');
    }
    await PendingReviews.clear(); // the queue belongs to this account: the next one must not send it
  }

  // Sends the review, or QUEUES it on the phone when it cannot reach the server (outbox: the write is kept in
  // Hive and sent on reconnect, Sprint 3 correction of JF-2, which used to be network only).
  // The author is NOT sent: the backend takes it from the session token.
  // It still THROWS when the server rejects the review (4xx), so the form stays open with the user's answers
  static Future<ReviewSubmitOutcome> submit({
    required String restaurantId,
    required ReviewRatings ratings,
    required List<String> dietaryOptions,
    required String comment,
  }) async {
    final pending = _pendingReview(restaurantId, ratings, dietaryOptions, comment);
    // Offline: queue it at once, without waiting the 5 s of the request timeout
    if (!ConnectivityService.isOnline.value) {
      await PendingReviews.put(pending);
      return ReviewSubmitOutcome.queued;
    }
    final dynamic published; // the server answers the created review (ReviewOut, same shape as Review.fromJson)
    try {
      published = await _api.postJson('/restaurants/$restaurantId/reviews', pending.body);
    } catch (e) {
      if (!shouldQueue(e)) rethrow;
      debugPrint('Review of $restaurantId queued, the server could not be reached: $e');
      await PendingReviews.put(pending);
      return ReviewSubmitOutcome.queued;
    }
    // Already on the server: write it through into My Reviews' cache instead of asking the list again
    await _writeThroughMyReviews(published);
    // An older queued review of the same place was just replaced on the server by this one
    await PendingReviews.remove(restaurantId);
    // Invalidates the cached entry so the user's new review shows up immediately (if it fails, nothing breaks)
    await fetch(restaurantId, forceRefresh: true);
    return ReviewSubmitOutcome.sent;
  }

  // The queued review keeps who wrote it, so it is only sent with that same session
  static PendingReview _pendingReview(
      String restaurantId, ReviewRatings ratings, List<String> dietaryOptions, String comment) {
    final user = AuthService.currentUser.value;
    if (user == null) throw StateError('No session: a review needs a logged-in user');
    return PendingReview(
      userId: user.id,
      restaurantId: restaurantId,
      ratings: ratings,
      dietaryOptions: dietaryOptions,
      comment: comment,
      author: user.name,
      queuedAt: DateTime.now(),
    );
  }

  // Sends the queued reviews. Called when the connection comes back (ConnectivityService), when the app opens
  // with internet (MainNavigation) and before logout (AuthGate)
  static Future<void> syncPending() => _syncing ??= _sync().whenComplete(() => _syncing = null);

  static Future<void> _sync() async {
    final user = AuthService.currentUser.value;
    if (!ConnectivityService.isOnline.value || user == null) return;
    var sent = 0;
    for (final p in await PendingReviews.all()) {
      if (p.userId != user.id) continue; // never post a review with another account's token
      try {
        final published = await _api.postJson('/restaurants/${p.restaurantId}/reviews', p.body);
        await _writeThroughMyReviews(published);
        await PendingReviews.remove(p.restaurantId);
        sent++;
        // Refreshes the summary, the memory entry and the SQLite copy of that restaurant
        await fetch(p.restaurantId, forceRefresh: true);
      } catch (e) {
        if (shouldQueue(e)) {
          debugPrint('Pending reviews not sent yet: $e');
          break; // still no connection / server down: the next reconnection retries
        }
        if ((e as ApiException).statusCode == 401) {
          debugPrint('Session expired while syncing reviews; they stay queued for the next login');
          break;
        }
        // Rejected by the server: retrying would fail forever, so it leaves the queue and the user is told
        debugPrint('Pending review of ${p.restaurantId} rejected: $e');
        await PendingReviews.remove(p.restaurantId);
        syncRejected.value = _restaurantName(p.restaurantId);
      }
    }
    if (sent > 0) await loadSummaries(); // the ratings of Home, Map, Search... now include the sent reviews
  }

  static Future<void> _writeThroughMyReviews(dynamic json) async {
    try {
      await MyReviewsService.onReviewPublished(Review.fromJson(Map<String, dynamic>.from(json as Map)));
    } catch (e) {
      debugPrint('Could not write the published review into My Reviews: $e');
    }
  }

  static String _restaurantName(String restaurantId) {
    for (final r in RestaurantService.restaurants.value) {
      if (r.id == restaurantId) return r.name;
    }
    return 'a restaurant';
  }

  // A new map (instead of changing the old one) so the ValueNotifier notices the change
  static void _setSummary(String restaurantId, RatingSummary summary) {
    summaries.value = {...summaries.value, restaurantId: summary};
  }
}
