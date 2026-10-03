// Defines what information each review has (who wrote it, when, the 4 ratings, dietary options and comment)
class Review {
  final String id;
  final String restaurantId; // Which restaurant this review belongs to (Restaurant.id)
  final String author;
  final DateTime date;
  final ReviewRatings ratings;
  final List<String> dietaryOptions; // Special diets the reviewer says the restaurant accommodates
  final String comment;              // Free text, empty string means no comment was written

  const Review({
    required this.id,
    required this.restaurantId,
    required this.author,
    required this.date,
    required this.ratings,
    this.dietaryOptions = const [],
    this.comment = '',
  });
}

// The 4 star ratings (1-5) a review gives. Each one is a category of the review
class ReviewRatings {
  final int taste;     // Taste & Food Quality
  final int attention; // Service & Attention
  final int price;     // Value for Money
  final int options;   // Dietary Options

  const ReviewRatings({this.taste = 0, this.attention = 0, this.price = 0, this.options = 0});

  // Overall rating of the review = average of the 4 categories
  double get overall => (taste + attention + price + options) / 4;

  // Returns the rating of one category by its key ('taste', 'attention', 'price' or 'options')
  int byKey(String key) {
    switch (key) {
      case 'taste':
        return taste;
      case 'attention':
        return attention;
      case 'price':
        return price;
      default:
        return options;
    }
  }

  // Returns a copy changing only the category that is passed (used while the user taps the stars)
  ReviewRatings copyWithKey(String key, int value) {
    return ReviewRatings(
      taste: key == 'taste' ? value : taste,
      attention: key == 'attention' ? value : attention,
      price: key == 'price' ? value : price,
      options: key == 'options' ? value : options,
    );
  }
}
