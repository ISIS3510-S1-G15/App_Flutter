import '../models/restaurant.dart';
import '../models/survey_answers.dart';

class PreferenceMatch {
  final int percent;
  final List<String> reasons;
  final List<String> warnings;

  const PreferenceMatch({required this.percent, required this.reasons, required this.warnings});

  String get summary => reasons.take(2).join(', ');
}

class PreferenceMatcher {
  static const _categoryCuisines = {
    'Asian': ['Asian'],
    'Burgers': ['American'],
    'Indian': ['Indian'],
    'Dining Hall': ['Colombian'],
    'Smoothies': ['Vegetarian', 'Vegan'],
    'Café': <String>[],
  };

  static const _dietaryKeywords = {
    'Vegetarian': ['vegetarian', 'veggie', 'vegan', 'tofu'],
    'Vegan': ['vegan'],
    'Gluten-free': ['gluten-free', 'gluten free'],
    'Lactose-free': ['lactose-free', 'oat milk', 'almond milk', 'coconut'],
    'Halal': ['halal'],
    'Kosher': ['kosher'],
    'Nut-free': ['nut-free'],
  };

  static const _budgetLimits = {
    'Under \$8.000': 8000,
    '\$8.000 – \$15.000': 15000,
    '\$15.000 – \$25.000': 25000,
  };

  static const _maxWalkMeters = 600.0;
  static const _maxWaitMinutes = 20.0;

  static bool hasPreferences(SurveyAnswers p) =>
      p.cuisines.isNotEmpty || _restrictions(p).isNotEmpty || p.budget.isNotEmpty || p.priorities.isNotEmpty;

  static PreferenceMatch score(Restaurant r, SurveyAnswers p, {double? distanceMeters}) {
    final reasons = <String>[];
    final warnings = <String>[];
    final text = _searchableText(r);
    final weights = <String, double>{};
    final values = <String, double>{};

    void add(String key, double weight, double value) {
      final boosted = p.priorities.contains(_priorityFor(key)) ? weight * 2 : weight;
      weights[key] = boosted;
      values[key] = value.clamp(0.0, 1.0);
    }

    if (p.cuisines.isNotEmpty) {
      final cuisines = _categoryCuisines[r.category] ?? [r.category];
      final matched = p.cuisines.where((c) => cuisines.contains(c) || text.contains(c.toLowerCase())).toList();
      add('cuisine', 3, matched.isEmpty ? 0 : 1);
      if (matched.isNotEmpty) reasons.add(matched.first);
    }

    final restrictions = _restrictions(p);
    if (restrictions.isNotEmpty) {
      final met = restrictions.where((d) => (_dietaryKeywords[d] ?? [d.toLowerCase()]).any(text.contains)).toList();
      add('dietary', 3, met.length / restrictions.length);
      reasons.addAll(met.map((d) => '$d options'));
      warnings.addAll(restrictions.where((d) => !met.contains(d)).map((d) => 'May not have $d options'));
    }

    final cheapest = _cheapestItem(r);
    final limit = _budgetLimits[p.budget];
    if (p.budget.isNotEmpty && cheapest != null) {
      final fits = limit == null || cheapest <= limit;
      add('budget', 2, fits ? 1 : 0);
      if (fits) {
        reasons.add('Fits your budget');
      } else {
        warnings.add('Above your budget');
      }
    }

    if (distanceMeters != null) {
      add('distance', 2, 1 - distanceMeters / _maxWalkMeters);
    }

    add('rating', 1, r.rating / 5);

    final wait = _waitMinutes(r);
    if (wait != null) add('speed', 1, 1 - wait / _maxWaitMinutes);

    final disliked = _dislikedWords(p).where(text.contains).toList();
    if (disliked.isNotEmpty) warnings.add('Has ${disliked.first}, which you avoid');

    final totalWeight = weights.values.fold(0.0, (a, b) => a + b);
    var result = weights.keys.fold(0.0, (sum, k) => sum + weights[k]! * values[k]!) / totalWeight;
    if (disliked.isNotEmpty) result *= 0.5;

    return PreferenceMatch(percent: (result * 100).round(), reasons: reasons, warnings: warnings);
  }

  static List<Restaurant> rank(List<Restaurant> list, SurveyAnswers p, double? Function(Restaurant) distance) {
    final scores = {for (final r in list) r.id: score(r, p, distanceMeters: distance(r)).percent};
    return [...list]..sort((a, b) => scores[b.id]!.compareTo(scores[a.id]!));
  }

  static String? _priorityFor(String key) => switch (key) {
        'budget' => 'Price',
        'distance' => 'Proximity',
        'rating' => 'Taste',
        'speed' => 'Speed',
        'cuisine' => 'Variety',
        'dietary' => 'Nutrition',
        _ => null,
      };

  static List<String> _restrictions(SurveyAnswers p) => p.dietaryRestrictions.where((d) => d != 'None').toList();

  static String _searchableText(Restaurant r) => [
        r.name,
        r.category,
        ...r.tags,
        for (final section in r.menu) ...[section.category, for (final item in section.items) '${item.name} ${item.desc}'],
      ].join(' ').toLowerCase();

  static int? _cheapestItem(Restaurant r) {
    final prices = [
      for (final section in r.menu)
        for (final item in section.items) int.tryParse(item.price.replaceAll(RegExp(r'[^0-9]'), '')),
    ].whereType<int>().toList();
    if (prices.isEmpty) return null;
    prices.sort();
    return prices.first;
  }

  static double? _waitMinutes(Restaurant r) {
    final match = RegExp(r'\d+').firstMatch(r.waitTime);
    return match == null ? null : double.parse(match.group(0)!);
  }

  static List<String> _dislikedWords(SurveyAnswers p) => p.dislikedFoods
      .toLowerCase()
      .split(RegExp(r'[,;/\n]|\band\b|\by\b'))
      .map((w) => w.trim())
      .where((w) => w.length >= 3)
      .toList();
}
