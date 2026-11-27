import 'review.dart';

// What the user has filled in the review form but not submitted yet. Saved on the phone (Hive) so it
// survives leaving the screen or closing the app.
class ReviewDraft {
  final int userId;              // whose draft it is: never restored for another account
  final String restaurantId;
  final ReviewRatings ratings;   // 0 = category not rated yet
  final List<String> dietaryOptions;
  final String comment;          // exactly as typed (not trimmed), so it comes back the same
  final DateTime savedAt;

  const ReviewDraft({
    required this.userId,
    required this.restaurantId,
    required this.ratings,
    this.dietaryOptions = const [],
    this.comment = '',
    required this.savedAt,
  });

  bool get hasContent =>
      ratings.taste > 0 ||
      ratings.attention > 0 ||
      ratings.price > 0 ||
      ratings.options > 0 ||
      dietaryOptions.isNotEmpty ||
      comment.trim().isNotEmpty;
}
