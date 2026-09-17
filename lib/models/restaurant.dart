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
  });
}