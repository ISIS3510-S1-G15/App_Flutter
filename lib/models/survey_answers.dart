// Defines the answers a user gives in the food preferences survey
// SurveyScreen produces it, and ProfileScreen / HomeScreen read it to show the user's profile
class SurveyAnswers {
  final String name;
  final List<String> cuisines;
  final List<String> dietaryRestrictions;
  final String mealFrequency;
  final List<String> mealTimes;
  final String budget;
  final List<String> priorities;
  final String dislikedFoods; // Free text, empty string means nothing was written

  const SurveyAnswers({
    this.name = '',
    this.cuisines = const [],
    this.dietaryRestrictions = const [],
    this.mealFrequency = '',
    this.mealTimes = const [],
    this.budget = '',
    this.priorities = const [],
    this.dislikedFoods = '',
  });

  // Returns a copy of these answers changing only the fields that are passed
  // (the fields are final, so the survey creates a new object every time the user answers something)
  SurveyAnswers copyWith({
    String? name,
    List<String>? cuisines,
    List<String>? dietaryRestrictions,
    String? mealFrequency,
    List<String>? mealTimes,
    String? budget,
    List<String>? priorities,
    String? dislikedFoods,
  }) {
    return SurveyAnswers(
      name: name ?? this.name,
      cuisines: cuisines ?? this.cuisines,
      dietaryRestrictions: dietaryRestrictions ?? this.dietaryRestrictions,
      mealFrequency: mealFrequency ?? this.mealFrequency,
      mealTimes: mealTimes ?? this.mealTimes,
      budget: budget ?? this.budget,
      priorities: priorities ?? this.priorities,
      dislikedFoods: dislikedFoods ?? this.dislikedFoods,
    );
  }
}
