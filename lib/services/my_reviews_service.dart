import '../models/review.dart';
import 'api_client.dart';

// Design pattern: REPOSITORY. This service is the ONLY access point to "my reviews" (the reviews written by
// the logged-in user). MyReviewsScreen never calls the backend directly, so the local copy, the memory cache
// and the stream planned for the next sprint can be added here later without touching the screen.

class MyReviewsService {
  static final ApiClient _api = ApiClient(); // Singleton: already carries the user's session token

  // GET /me/reviews -> the reviews written by the logged-in user, newest first.
  // THROWS if the request fails, so the screen can tell "error" apart from "no reviews"
  static Future<List<Review>> fetch() async {
    final data = await _api.getJson('/me/reviews') as List;
    final reviews = data.cast<Map<String, dynamic>>().map(Review.fromJson).toList();
    // The backend already sends them newest first; sorting again is a cheap guarantee for the view
    reviews.sort((a, b) => b.date.compareTo(a.date));
    return reviews;
  }
}
