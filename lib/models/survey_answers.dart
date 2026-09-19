// Defines the answers a user gives in the food preferences survey
// ProfileScreen reads this to display the profile; in the future SurveyScreen will produce it
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
}
