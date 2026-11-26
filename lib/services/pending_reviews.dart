import 'package:flutter/foundation.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import '../models/review.dart';

// One review written without connection, waiting in the local queue until it can be sent
class PendingReview {
  final int userId; // who wrote it: the queue is only sent with that same session
  final String restaurantId;
  final ReviewRatings ratings;
  final List<String> dietaryOptions;
  final String comment;
  final String author; // name shown on the "Pending sync" card (the backend takes the real one from the token)
  final DateTime queuedAt;

  const PendingReview({
    required this.userId,
    required this.restaurantId,
    required this.ratings,
    this.dietaryOptions = const [],
    this.comment = '',
    required this.author,
    required this.queuedAt,
  });

  // Hive stores plain types only (ints, strings, lists of strings), so the date goes as ISO text
  Map<String, dynamic> toMap() => {
        'user_id': userId,
        'restaurant_id': restaurantId,
        ...ratings.toJson(),
        'dietary_options': dietaryOptions,
        'comment': comment,
        'author': author,
        'queued_at': queuedAt.toIso8601String(),
      };

  factory PendingReview.fromMap(Map map) => PendingReview(
        userId: (map['user_id'] as num).toInt(),
        restaurantId: map['restaurant_id'] as String,
        ratings: ReviewRatings(
          taste: map['taste'] as int,
          attention: map['attention'] as int,
          price: map['price'] as int,
          options: map['options'] as int,
        ),
        dietaryOptions: (map['dietary_options'] as List? ?? const []).cast<String>(),
        comment: map['comment'] as String? ?? '',
        author: map['author'] as String? ?? '',
        queuedAt: DateTime.parse(map['queued_at'] as String),
      );

  // Body of POST /restaurants/{id}/reviews: exactly what ReviewService.submit sends when there is internet
  Map<String, dynamic> get body => {
        ...ratings.toJson(),
        'dietary_options': dietaryOptions,
        'comment': comment,
      };

  // As a Review so the same cards can draw it, marked as pending
  Review toReview() => Review(
        id: 'pending_$restaurantId',
        restaurantId: restaurantId,
        author: author,
        date: queuedAt,
        ratings: ratings,
        dietaryOptions: dietaryOptions,
        comment: comment,
        pending: true,
      );
}

// LOCAL STORAGE (Hive, key-value): reviews written offline that the server has not received yet.
// Key = restaurantId: the backend keeps ONE review per user and restaurant, so a newer offline review
// for the same place replaces the older one instead of sending two.
// Every operation has its own try/catch: a disk error must never bring a screen down
class PendingReviews {
  static const _boxName = 'pending_reviews';
  static bool _initialized = false;

  static final ValueNotifier<int> count = ValueNotifier(0); // screens listen to show "N changes waiting to sync"

  // Same pattern as PendingEvents: Hive is initialized once, guarded by a flag
  static Future<Box> _box() async {
    if (!_initialized) {
      await Hive.initFlutter();
      _initialized = true;
    }
    return Hive.openBox(_boxName);
  }

  // Reads the box once at app start, so the banners know about the reviews queued in a previous session
  static Future<void> load() async {
    try {
      count.value = (await _box()).length;
    } catch (e) {
      debugPrint('Could not read pending reviews: $e');
    }
  }

  // Adds the review, or replaces the one already queued for the same restaurant
  static Future<void> put(PendingReview review) async {
    try {
      final box = await _box();
      await box.put(review.restaurantId, review.toMap());
      count.value = box.length;
    } catch (e) {
      debugPrint('Could not store pending review: $e');
    }
  }

  // Newest first, so the screens can put them on top in the same order as Kotlin
  static Future<List<PendingReview>> all() async {
    try {
      final box = await _box();
      final list = box.values.map((v) => PendingReview.fromMap(v as Map)).toList()
        ..sort((a, b) => b.queuedAt.compareTo(a.queuedAt));
      return list;
    } catch (e) {
      debugPrint('Could not read pending reviews: $e');
      return const [];
    }
  }

  static Future<PendingReview?> forRestaurant(String restaurantId) async {
    try {
      final value = (await _box()).get(restaurantId);
      return value == null ? null : PendingReview.fromMap(value as Map);
    } catch (e) {
      debugPrint('Could not read pending review of $restaurantId: $e');
      return null;
    }
  }

  static Future<void> remove(String restaurantId) async {
    try {
      final box = await _box();
      await box.delete(restaurantId);
      count.value = box.length;
    } catch (e) {
      debugPrint('Could not remove pending review of $restaurantId: $e');
    }
  }

  // Logout: the next account must not send (or see) this user's reviews
  static Future<void> clear() async {
    try {
      await (await _box()).clear();
      count.value = 0;
    } catch (e) {
      debugPrint('Could not clear pending reviews: $e');
    }
  }
}
