import 'package:flutter/foundation.dart';
import '../models/review.dart';
import 'api_client.dart';

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

  const RestaurantReviews({required this.summary, required this.reviews, this.fromCache = false});
}

// Design pattern: REPOSITORY (slides 17 - Caching). The screens never call the backend directly:
// they ask ReviewService, and it decides where the data comes from (backend or the in-memory cache).
// Same style as SavedService: static methods + ValueNotifier so the screens redraw when the data changes
class ReviewService {
  static final ApiClient _api = ApiClient(); // Singleton: already carries the user's session token

  // Rating and number of reviews of every restaurant (Home, Map, Search, Saved and Detail read this)
  static final ValueNotifier<Map<String, RatingSummary>> summaries = ValueNotifier(const {});

  // Memory cache: the last reviews downloaded for each restaurant. Lives while the app is open
  static final Map<String, RestaurantReviews> _cache = {};

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

  // Strategy "Network falling back to cache" (slides 15): always try the backend to get the newest reviews;
  // without internet, return the last ones downloaded (fromCache = true). Null = no internet AND nothing cached
  static Future<RestaurantReviews?> fetch(String restaurantId) async {
    try {
      final data = await _api.getJson('/restaurants/$restaurantId/reviews') as Map<String, dynamic>;
      final result = RestaurantReviews(
        summary: RatingSummary.fromJson(data),
        reviews: (data['reviews'] as List).cast<Map<String, dynamic>>().map(Review.fromJson).toList(),
      );
      _cache[restaurantId] = result;
      _setSummary(restaurantId, result.summary);
      return result;
    } catch (e) {
      debugPrint('Could not load reviews of $restaurantId: $e');
      final cached = _cache[restaurantId];
      return cached == null
          ? null
          : RestaurantReviews(summary: cached.summary, reviews: cached.reviews, fromCache: true);
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
    await fetch(restaurantId); // updates the cache and the rating shown everywhere (if it fails, nothing breaks)
  }

  // A new map (instead of changing the old one) so the ValueNotifier notices the change
  static void _setSummary(String restaurantId, RatingSummary summary) {
    summaries.value = {...summaries.value, restaurantId: summary};
  }
}
