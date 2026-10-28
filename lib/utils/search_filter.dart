import '../models/restaurant.dart';

// Search matching used by SearchScreen. It is a top-level function (not inside a class or widget)
// so it can run inside a separate isolate: it only receives plain data and returns plain data,
// it never touches the screen or any shared state
List<Restaurant> filterRestaurants(List<Restaurant> all, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return [];
  // Keeps the restaurants that match by name, category, location, or any of their tags
  return all.where((r) {
    return r.name.toLowerCase().contains(q) ||
        r.category.toLowerCase().contains(q) ||
        r.location.toLowerCase().contains(q) ||
        r.tags.any((t) => t.toLowerCase().contains(q));
  }).toList();
}
