// Reviews for testing + the reviews written by the user while the app is open
// Shared by ReviewsListScreen (reads them) and WriteReviewScreen (adds new ones)
import 'package:flutter/foundation.dart';
import '../models/review.dart';

// ValueNotifier holds the list and notifies whoever is listening every time it changes,
// so when a new review is submitted the reviews list redraws automatically (same pattern as userProfile)
final ValueNotifier<List<Review>> allReviews = ValueNotifier([
  Review(
    id: 'r1',
    restaurantId: '1',
    author: 'Valentina',
    date: DateTime(2026, 9, 12),
    ratings: const ReviewRatings(taste: 5, attention: 4, price: 3, options: 4),
    dietaryOptions: const ['Vegan options', 'Lactose-free'],
    comment: 'Great oat latte and the almond croissant is a must. Gets really busy between classes, so order ahead.',
  ),
  Review(
    id: 'r2',
    restaurantId: '1',
    author: 'Santiago',
    date: DateTime(2026, 8, 28),
    ratings: const ReviewRatings(taste: 4, attention: 5, price: 3, options: 3),
    dietaryOptions: const ['Lactose-free'],
    comment: 'Perfect spot to study for a couple of hours. Staff is always friendly.',
  ),
  Review(
    id: 'r3',
    restaurantId: '2',
    author: 'Camila',
    date: DateTime(2026, 9, 5),
    ratings: const ReviewRatings(taste: 5, attention: 4, price: 4, options: 5),
    dietaryOptions: const ['Vegetarian options', 'Gluten-free'],
    comment: 'The veggie pho is amazing and they clearly mark which dishes are gluten-free.',
  ),
  Review(
    id: 'r4',
    restaurantId: '3',
    author: 'Mateo',
    date: DateTime(2026, 9, 15),
    ratings: const ReviewRatings(taste: 4, attention: 3, price: 5, options: 5),
    dietaryOptions: const ['Vegan options', 'Vegetarian options', 'Nut-free'],
  ),
]);

// Returns only the reviews of one restaurant, newest first
List<Review> reviewsFor(String restaurantId) {
  final list = allReviews.value.where((r) => r.restaurantId == restaurantId).toList();
  list.sort((a, b) => b.date.compareTo(a.date));
  return list;
}

// Adds a new review. A new list is created (instead of .add) so the ValueNotifier detects the change
void addReview(Review review) {
  allReviews.value = [...allReviews.value, review];
}
