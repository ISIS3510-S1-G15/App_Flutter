// Defines what information each restaurant has (name, category, rating, etc.)
import '../utils/meal_context.dart';
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

  // Real GPS coordinates, used to compute the distance from the user (defaults to the campus center)
  final double latitude;
  final double longitude;

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
    this.latitude = 4.6018,
    this.longitude = -74.0661,
  });

  // Builds a Restaurant from the JSON of the backend (GET /restaurants)
  factory Restaurant.fromJson(Map<String, dynamic> json) => Restaurant(
        id: json['id'] as String,
        name: json['name'] as String,
        location: json['location'] as String? ?? '',
        category: json['category'] as String? ?? '',
        image: _imageAsset(json['image_key'] as String?),
        isOpen: true, // the real open/closed state comes from "hours" (see isOpenAt)
        rating: (json['rating'] as num?)?.toDouble() ?? 0,
        reviews: json['review_count'] as int? ?? 0,
        price: json['price'] as String? ?? '',
        waitTime: json['wait_time'] as String? ?? '',
        tags: (json['tags'] as List? ?? const []).cast<String>(),
        hours: json['hours'] as String? ?? '',
        description: json['description'] as String? ?? '',
        menu: (json['menu'] as List? ?? const [])
            .cast<Map<String, dynamic>>()
            .map(MenuSection.fromJson)
            .toList(growable: false),
        mapX: (json['map_x'] as num?)?.toDouble() ?? 50,
        mapY: (json['map_y'] as num?)?.toDouble() ?? 50,
        latitude: (json['latitude'] as num?)?.toDouble() ?? 4.6018,
        longitude: (json['longitude'] as num?)?.toDouble() ?? -74.0661,
      );

  // The backend sends an image key (e.g. "starbucks"); the pictures are bundled in web/icons.
  // An unknown or missing key falls back to the placeholder each screen draws in errorBuilder
  static const _imageFiles = {
    'starbucks': 'starbucks.jpeg',
    'sushi': 'sushi.png',
    'la_puerta': 'la_puerta.png',
  };

  static String _imageAsset(String? key) {
    if (key == null || key.isEmpty) return 'web/icons/placeholder.png';
    return 'web/icons/${_imageFiles[key] ?? '$key.png'}';
  }

  bool get isOpenNow => isOpenAt(this, DateTime.now());
}

class MenuSection {
  final String category;
  final List<MenuItem> items;

  const MenuSection({required this.category, required this.items});

  factory MenuSection.fromJson(Map<String, dynamic> json) => MenuSection(
        category: json['category'] as String? ?? '',
        items: (json['items'] as List? ?? const [])
            .cast<Map<String, dynamic>>()
            .map(MenuItem.fromJson)
            .toList(growable: false),
      );
}

class MenuItem {
  final String name;
  final String price;
  final String desc;

  const MenuItem({required this.name, required this.price, required this.desc});

  factory MenuItem.fromJson(Map<String, dynamic> json) => MenuItem(
        name: json['name'] as String? ?? '',
        price: json['price'] as String? ?? '',
        desc: json['description'] as String? ?? '',
      );
}