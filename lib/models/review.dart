// Defines what information each review has (who wrote it, when, the 4 ratings, dietary options and comment)
class Review {
  final String id;
  final String restaurantId; // Which restaurant this review belongs to (Restaurant.id)
  final String author;
  final DateTime date;
  final ReviewRatings ratings;
  final List<String> dietaryOptions; // Special diets the reviewer says the restaurant accommodates
  final String comment;              // Free text, empty string means no comment was written
  // true = written offline and still in the local queue (PendingReviews): the server has not received it yet,
  // so the cards show "Pending sync" instead of the date
  final bool pending;

  const Review({
    required this.id,
    required this.restaurantId,
    required this.author,
    required this.date,
    required this.ratings,
    this.dietaryOptions = const [],
    this.comment = '',
    this.pending = false,
  });

  // Same shape the backend sends, so Review.fromJson(review.toJson()) gives back an equivalent review.
  // Used to keep the local copy of My Reviews in Hive
  Map<String, dynamic> toJson() => {
        'id': id,
        'restaurant_id': restaurantId,
        'author': author,
        'created_at': date.toUtc().toIso8601String(),
        ...ratings.toJson(),
        'dietary_options': dietaryOptions,
        'comment': comment,
      };

  // Builds a Review from the JSON of the backend (GET/POST /restaurants/{id}/reviews).
  // created_at comes in UTC ("...Z"); toLocal() turns it into the phone's time (Colombia) before showing it
  factory Review.fromJson(Map<String, dynamic> json) {
    return Review(
      id: json['id'].toString(),
      restaurantId: json['restaurant_id'] as String,
      author: json['author'] as String,
      date: DateTime.parse(json['created_at'] as String).toLocal(),
      ratings: ReviewRatings(
        taste: json['taste'] as int,
        attention: json['attention'] as int,
        price: json['price'] as int,
        options: json['options'] as int,
      ),
      dietaryOptions: (json['dietary_options'] as List? ?? const []).cast<String>(),
      comment: json['comment'] as String? ?? '',
    );
  }
}

// The 4 star ratings (1-5) a review gives. Each one is a category of the review
class ReviewRatings {
  final int taste;     // Taste & Food Quality
  final int attention; // Service & Attention
  final int price;     // Value for Money
  final int options;   // Dietary Options

  const ReviewRatings({this.taste = 0, this.attention = 0, this.price = 0, this.options = 0});

  // Body sent to the backend with the 4 ratings (same keys the backend expects)
  Map<String, dynamic> toJson() => {'taste': taste, 'attention': attention, 'price': price, 'options': options};

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

const reviewCategories = [
  (key: 'taste', label: 'Taste'),
  (key: 'attention', label: 'Service'),
  (key: 'price', label: 'Value'),
  (key: 'options', label: 'Diet Options'),
];

class MyReviewsSummary {
  final int count;
  final double? averageGiven; // null when the user has no reviews -> the card shows "—"

  const MyReviewsSummary({required this.count, this.averageGiven});

  static const empty = MyReviewsSummary(count: 0);

  factory MyReviewsSummary.from(List<Review> reviews) {
    if (reviews.isEmpty) return empty;
    final total = reviews.fold<double>(0, (sum, r) => sum + r.ratings.overall);
    return MyReviewsSummary(count: reviews.length, averageGiven: total / reviews.length);
  }

  String get countLabel => count == 1 ? 'review written' : 'reviews written';
  String get averageLabel => averageGiven == null ? '—' : averageGiven!.toStringAsFixed(1);
}
