// Defines what information each restaurant has (name, category, rating, etc.)
class Restaurant {
  final String id;
  final String name;
  final String location;
  final String category;
  final String image;
  final bool isOpen;
  final double rating;
  final int reviews;
  final String price;
  final String waitTime;
  final List<String> tags;
  final bool saved;
  final String hours;
  final String description;
  final List<MenuSection> menu;

  // Position of the restaurant pin on the campus map, as a percentage (0-100) of the map's width/height
  final double mapX;
  final double mapY;

  // Recent crowding reports (same 0-2 scale used by CrowdingBadge: 0 = not crowded, 2 = busy)
  final List<int> crowdingReports;

  const Restaurant({
    required this.id,
    required this.name,
    required this.location,
    required this.category,
    required this.image,
    required this.isOpen,
    required this.rating,
    required this.reviews,
    required this.price,
    required this.waitTime,
    required this.tags,
    this.saved = false,
    required this.hours,
    this.description = '',
    this.menu = const [],
    this.mapX = 50,
    this.mapY = 50,
    this.crowdingReports = const [],
  });
}

class MenuSection {
  final String category;
  final List<MenuItem> items;

  const MenuSection({required this.category, required this.items});
}

class MenuItem {
  final String name;
  final String price;
  final String desc;

  const MenuItem({required this.name, required this.price, required this.desc});
}