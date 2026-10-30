import 'dart:isolate';
import 'package:flutter/foundation.dart';
import '../models/review.dart';
import 'api_client.dart';
import 'reviews_db.dart';
import 'reviews_digest.dart';
import 'reviews_memory_cache.dart';

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

  static RatingSummary summaryOf(String restaurantId) => summaries.value[restaurantId] ?? RatingSummary.empty;

  // Called when the main app opens. If it fails, the ratings show "New" until the next successful load
  static Future<void> loadSummaries() async {
    try {
      final data = await _api.getJson('/reviews/summary') as List;
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
    try {
      await ReviewsDb.clear();
    } catch (e) {
      debugPrint('Could not clear local reviews: $e');
    }
  }

  // Sends the review. The author is NOT sent: the backend takes it from the session token.
  // It THROWS if it fails (instead of failing silently) so the form can stay open with the user's answers
  static Future<void> submit({
    required String restaurantId,
    required ReviewRatings ratings,
    required List<String> dietaryOptions,
    required String comment,
  }) async {
    await _api.postJson('/restaurants/$restaurantId/reviews', {
      ...ratings.toJson(),
      'dietary_options': dietaryOptions,
      'comment': comment,
    });
    // Invalidates the cached entry so the user's new review shows up immediately (if it fails, nothing breaks)
    await fetch(restaurantId, forceRefresh: true);
  }

  // A new map (instead of changing the old one) so the ValueNotifier notices the change
  static void _setSummary(String restaurantId, RatingSummary summary) {
    summaries.value = {...summaries.value, restaurantId: summary};
  }
}
