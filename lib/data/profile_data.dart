// The person's survey answers for testing (in the future, these will come from the onboarding survey)
// Shared by HomeScreen (greeting + avatar initials) and ProfileScreen (full profile)
import '../models/survey_answers.dart';

const SurveyAnswers mockProfile = SurveyAnswers(
  cuisines: ['Mexican', 'Vegetarian'],
  dietaryRestrictions: ['Lactose-free', 'Halal'],
  mealFrequency: 'Daily',
  mealTimes: ['Dinner'],
  budget: '\$8.000 – \$15.000',
  priorities: ['Sustainability', 'Proximity', 'Variety'],
);
