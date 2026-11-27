import 'package:app_flutter/models/restaurant.dart';
import 'package:app_flutter/models/review.dart';
import 'package:app_flutter/services/recent_views_service.dart';
import 'package:app_flutter/utils/search_filter.dart';

const _names = ['Starbucks', 'Kai Sushi', 'La Puerta', 'Cosechas', 'Juan Valdez', 'Spoleto', 'La Central', 'Caffa'];
const _categories = ['Café', 'Asian', 'Burgers', 'Smoothies', 'Italian', 'Dining Hall'];
const _tags = ['Coffee', 'Vegan options', 'Halal', 'Open late', 'Quick pickup', 'Breakfast', 'Healthy', 'Noodles'];
const searchQueries = ['sushi', 'caf', 'vegan', 'burger', 'building 12', 'healthy', 'zzz', 'la', 'open late', 'pasta'];

List<Restaurant> syntheticCatalog(int size) => List.generate(
      size,
      (i) => Restaurant(
        id: '$i',
        name: '${_names[i % _names.length]} $i',
        location: 'Building ${i % 30}',
        category: _categories[i % _categories.length],
        image: '',
        isOpen: true,
        rating: 4,
        reviews: 10,
        price: r'$',
        waitTime: '5 min',
        tags: [_tags[i % _tags.length], _tags[(i + 3) % _tags.length]],
        hours: '7:00 AM – 9:00 PM',
      ),
    );

List<Map<String, dynamic>> syntheticHistory(List<Restaurant> catalog, int size) => List.generate(
      size,
      (i) => {
        'restaurant_id': catalog[(i * 7) % catalog.length].id,
        'view_count': i % 5 + 1,
        'last_viewed_at': DateTime.utc(2026, 11, 20).subtract(Duration(minutes: i)).toIso8601String(),
      },
    );

List<Restaurant> filterRestaurantsBefore(List<Restaurant> all, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return [];
  return all.where((r) {
    return r.name.toLowerCase().contains(q) ||
        r.category.toLowerCase().contains(q) ||
        r.location.toLowerCase().contains(q) ||
        r.tags.any((t) => t.toLowerCase().contains(q));
  }).toList();
}

int searchBefore(List<Restaurant> catalog, int rounds) {
  var matches = 0;
  for (var round = 0; round < rounds; round++) {
    for (final q in searchQueries) {
      matches += filterRestaurantsBefore(catalog, q).length;
    }
  }
  return matches;
}

int searchAfter(List<Restaurant> catalog, int rounds) {
  final index = buildSearchIndex(catalog);
  var matches = 0;
  for (var round = 0; round < rounds; round++) {
    for (final q in searchQueries) {
      matches += filterRestaurants(catalog, index, q).length;
    }
  }
  return matches;
}

Restaurant? _linearLookup(List<Restaurant> catalog, String id) {
  for (final r in catalog) {
    if (r.id == id) return r;
  }
  return null;
}

int historyRowsBefore(List<Restaurant> catalog, List<Map<String, dynamic>> history, int frames) {
  var rows = 0;
  for (var frame = 0; frame < frames; frame++) {
    final entries = history
        .map((e) => RecentView.fromJson(Map<String, dynamic>.from(e)))
        .where((v) => _linearLookup(catalog, v.restaurantId) != null)
        .toList();
    for (final view in entries) {
      if (_linearLookup(catalog, view.restaurantId) != null) rows++;
    }
  }
  return rows;
}

int historyRowsAfter(List<Restaurant> catalog, List<Map<String, dynamic>> history, int frames) {
  final byId = {for (final r in catalog) r.id: r};
  final prepared = <Object>[];
  for (final item in history) {
    final view = RecentView.fromJson(Map<String, dynamic>.from(item));
    final restaurant = byId[view.restaurantId];
    if (restaurant != null) prepared.add(restaurant);
  }
  var rows = 0;
  for (var frame = 0; frame < frames; frame++) {
    for (var i = 0; i < prepared.length; i++) {
      if (prepared[i] is Restaurant) rows++;
    }
  }
  return rows;
}

class BenchmarkResult {
  final String name;
  final int microseconds;
  const BenchmarkResult(this.name, this.microseconds);
  double get milliseconds => microseconds / 1000;
}

BenchmarkResult measure(String name, void Function() body) {
  final watch = Stopwatch()..start();
  body();
  watch.stop();
  return BenchmarkResult(name, watch.elapsedMicroseconds);
}

List<BenchmarkResult> runMicroOptimizationBenchmarks({int catalogSize = 2000, int historySize = 200, int searchRounds = 50, int frames = 60}) {
  final catalog = syntheticCatalog(catalogSize);
  final history = syntheticHistory(catalog, historySize);
  searchBefore(catalog, 2);
  searchAfter(catalog, 2);
  historyRowsBefore(catalog, history, 2);
  historyRowsAfter(catalog, history, 2);
  return [
    measure('Search – before', () => searchBefore(catalog, searchRounds)),
    measure('Search – after', () => searchAfter(catalog, searchRounds)),
    measure('Recently Viewed rows – before', () => historyRowsBefore(catalog, history, frames)),
    measure('Recently Viewed rows – after', () => historyRowsAfter(catalog, history, frames)),
  ];
}

const _reviewDiets = ['Vegan options', 'Vegetarian options', 'Gluten-free', 'Halal', 'Kosher'];
const _reviewComments = [
  '',
  'Good.',
  'Great arepas and fast service, I would come back.',
  'The portions are big and the price is fair. It gets crowded at noon, so better go early or late.',
  'Nice place to study with a coffee. The vegan options are limited but tasty, and the staff is always friendly '
      'even when the line is long. Wish they had more seats near the windows.',
];

// Synthetic reviews for the review-cards benchmark (Juan Felipe, issue #113): always the same data,
// so the before and after runs compare exactly the same work
List<Review> syntheticReviews(int size) => List.generate(
      size,
      (i) => Review(
        id: '$i',
        restaurantId: 'r$i',
        author: 'Ana',
        date: DateTime(2026, 11, 27).subtract(Duration(days: i)), // newest first
        ratings: ReviewRatings(
          taste: i % 5 + 1,
          attention: (i + 1) % 5 + 1,
          price: (i + 2) % 5 + 1,
          options: (i + 4) % 5 + 1,
        ),
        dietaryOptions: [for (var d = 0; d < i % 3; d++) _reviewDiets[(i + d) % _reviewDiets.length]], // 0-2 diets
        comment: _reviewComments[i % _reviewComments.length],
      ),
    );
