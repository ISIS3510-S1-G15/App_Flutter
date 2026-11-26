import '../models/restaurant.dart';

// Search matching used by SearchScreen. It is a top-level function (not inside a class or widget)
// so it can run inside a separate isolate: it only receives plain data and returns plain data,
// it never touches the screen or any shared state
List<String> buildSearchIndex(List<Restaurant> all) {
  final index = List<String>.filled(all.length, '');
  for (var i = 0; i < all.length; i++) {
    final r = all[i];
    index[i] = [r.name, r.category, r.location, ...r.tags].join('\u0000').toLowerCase();
  }
  return index;
}

List<Restaurant> filterRestaurants(List<Restaurant> all, List<String> index, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return [];
  final found = <Restaurant>[];
  for (var i = 0; i < all.length; i++) {
    if (index[i].contains(q)) found.add(all[i]);
  }
  return found;
}
