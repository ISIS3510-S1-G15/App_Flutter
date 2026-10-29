import 'package:flutter_test/flutter_test.dart';
import 'package:app_flutter/data/restaurants_data.dart';
import 'package:app_flutter/models/survey_answers.dart';
import 'package:app_flutter/services/preference_match.dart';

void main() {
  final starbucks = restaurants.firstWhere((r) => r.name == 'Starbucks');
  final yamato = restaurants.firstWhere((r) => r.name == 'Yamato Sushi Wok');
  final cosechas = restaurants.firstWhere((r) => r.name == 'Cosechas');
  final laPuerta = restaurants.firstWhere((r) => r.name == 'La Puerta');

  test('empty profile has no preferences', () {
    expect(PreferenceMatcher.hasPreferences(const SurveyAnswers()), isFalse);
    expect(PreferenceMatcher.hasPreferences(const SurveyAnswers(dietaryRestrictions: ['None'])), isFalse);
  });

  test('vegan student on a mid budget gets Cosechas first', () {
    const profile = SurveyAnswers(
      cuisines: ['Vegan'],
      dietaryRestrictions: ['Vegan'],
      budget: '\$8.000 – \$15.000',
    );
    final ranked = PreferenceMatcher.rank([starbucks, yamato, laPuerta, cosechas], profile, (_) => 200);
    expect(ranked.first.name, 'Cosechas');

    final match = PreferenceMatcher.score(cosechas, profile, distanceMeters: 200);
    expect(match.reasons, contains('Vegan options'));
    expect(match.warnings, isEmpty);
  });

  test('Asian food lover gets Yamato with the cuisine as a reason', () {
    const profile = SurveyAnswers(cuisines: ['Asian']);
    final ranked = PreferenceMatcher.rank([starbucks, yamato, laPuerta, cosechas], profile, (_) => 200);
    expect(ranked.first.name, 'Yamato Sushi Wok');
    expect(PreferenceMatcher.score(yamato, profile).reasons.first, 'Asian');
  });

  test('budget and disliked foods add warnings and lower the score', () {
    const profile = SurveyAnswers(budget: 'Under \$8.000', dislikedFoods: 'mushrooms, pickles');
    final match = PreferenceMatcher.score(laPuerta, profile);
    expect(match.warnings, contains('Above your budget'));
    expect(match.warnings.any((w) => w.contains('which you avoid')), isTrue);

    final clean = PreferenceMatcher.score(laPuerta, const SurveyAnswers(budget: 'Under \$8.000'));
    expect(match.percent, lessThan(clean.percent));
  });

  test('Proximity priority makes the closer place win', () {
    const profile = SurveyAnswers(priorities: ['Proximity']);
    double distance(r) => r.name == 'La Puerta' ? 20 : 550;
    final ranked = PreferenceMatcher.rank([starbucks, yamato, laPuerta, cosechas], profile, distance);
    expect(ranked.first.name, 'La Puerta');
  });

  test('background isolate gives the same scores as the main thread', () async {
    const profile = SurveyAnswers(cuisines: ['Asian'], dietaryRestrictions: ['Vegetarian'], budget: '\$8.000 – \$15.000');
    final distances = {for (final r in restaurants) r.id: 150.0};
    final background = await PreferenceMatcher.scoreAllInBackground(restaurants, profile, distances);
    final main = PreferenceMatcher.scoreAll(restaurants, profile, distances);
    expect(background.keys, main.keys);
    for (final id in main.keys) {
      expect(background[id]!.percent, main[id]!.percent);
      expect(background[id]!.reasons, main[id]!.reasons);
    }
  });
}
