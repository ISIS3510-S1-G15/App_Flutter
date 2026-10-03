// Time-of-day context for the Map screen: which meal students are probably looking for right now,
// and which restaurant categories fit that meal best
class MealMoment {
  final String label;            // 'Breakfast', 'Lunch', ...
  final List<String> categories; // Restaurant categories that fit this meal

  const MealMoment(this.label, this.categories);

  static const breakfast = MealMoment('Breakfast', ['Café', 'Smoothies', 'Dining Hall']);
  static const lunch = MealMoment('Lunch', ['Dining Hall', 'Asian', 'Burgers', 'Indian']);
  static const snack = MealMoment('Snack', ['Café', 'Smoothies']);
  static const dinner = MealMoment('Dinner', ['Asian', 'Burgers', 'Indian', 'Dining Hall']);

  // Meal that matches the given time, or null late at night / very early (no specific meal)
  static MealMoment? at(DateTime time) {
    final h = time.hour;
    if (h >= 6 && h < 11) return breakfast;
    if (h >= 11 && h < 15) return lunch;
    if (h >= 15 && h < 18) return snack;
    if (h >= 18 && h < 22) return dinner;
    return null;
  }

  bool fits(String category) => categories.contains(category);
}
