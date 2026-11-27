// withOpacity is used ON PURPOSE: it is the old code the constants must match
// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app_flutter/models/review.dart';
import 'package:app_flutter/screens/reviews_list_screen.dart';
import 'package:app_flutter/theme/app_theme.dart';
import 'package:app_flutter/widgets/review_category_grid.dart';
import 'package:app_flutter/widgets/stars.dart';
import '../profiling/benchmarks.dart';
import '../profiling/legacy_category_grid.dart';
import '../profiling/review_cards_benchmark.dart';

const _ratings = ReviewRatings(taste: 5, attention: 4, price: 2, options: 3);

// Same parent for both versions, so any difference comes from the grid itself
Future<void> _pumpAt(WidgetTester tester, double width, Widget grid) => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(width: width, child: grid),
          ),
        ),
      ),
    );

void main() {
  testWidgets('the new grid creates no scrollable at all', (tester) async {
    await _pumpAt(tester, 335, const ReviewCategoryGrid(ratings: _ratings));
    expect(find.byType(Scrollable), findsNothing);
  });

  testWidgets('it shows the 4 categories, each with its stars', (tester) async {
    await _pumpAt(tester, 335, const ReviewCategoryGrid(ratings: _ratings));
    for (final label in ['Taste', 'Service', 'Value', 'Diet Options']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.byType(StarsDisplay), findsNWidgets(4));
  });

  // Visual parity (mirror app of Kotlin): same size and same cell positions as the old GridView
  for (final width in [335.0, 280.0]) {
    testWidgets('same size and positions as the legacy GridView at $width px', (tester) async {
      await _pumpAt(tester, width, const LegacyCategoryGrid(ratings: _ratings));
      final legacySize = tester.getSize(find.byType(LegacyCategoryGrid));
      final legacyValue = tester.getTopLeft(find.text('Value'));
      final legacyDiet = tester.getTopLeft(find.text('Diet Options'));

      await _pumpAt(tester, width, const ReviewCategoryGrid(ratings: _ratings));
      final newSize = tester.getSize(find.byType(ReviewCategoryGrid));
      expect(newSize.width, legacySize.width);
      expect(newSize.height, closeTo(legacySize.height, 0.5));
      final newValue = tester.getTopLeft(find.text('Value'));
      expect(newValue.dx, closeTo(legacyValue.dx, 0.5));
      expect(newValue.dy, closeTo(legacyValue.dy, 0.5));
      final newDiet = tester.getTopLeft(find.text('Diet Options'));
      expect(newDiet.dx, closeTo(legacyDiet.dx, 0.5));
      expect(newDiet.dy, closeTo(legacyDiet.dy, 0.5));
    });
  }

  testWidgets('the legacy grid DOES mount a scrollable (the problem being fixed)', (tester) async {
    await _pumpAt(tester, 335, const LegacyCategoryGrid(ratings: _ratings));
    expect(find.byType(Scrollable), findsOneWidget);
  });

  test('the constant colors are exactly the old withOpacity values', () {
    final expected = {
      'white10': Colors.white.withOpacity(0.1),
      'white50': Colors.white.withOpacity(0.5),
      'white60': Colors.white.withOpacity(0.6),
      'accent10': AppColors.accent.withOpacity(0.1),
      'accent25': AppColors.accent.withOpacity(0.25),
    };
    expect(reviewsListOpacityColors.keys, expected.keys);
    for (final entry in expected.entries) {
      expect(reviewsListOpacityColors[entry.key], entry.value, reason: entry.key);
      expect(reviewsListOpacityColors[entry.key]!.toARGB32(), entry.value.toARGB32(), reason: entry.key);
    }
  });

  // The same count the profiling app shows: one hidden scrollable per card before, only the list after
  for (final (variant, expected) in [(GridVariant.before, 5 + 1), (GridVariant.after, 1)]) {
    testWidgets('5 benchmark cards in ${variant.name} mode mount $expected scrollables', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: ReviewCardsList(variant: variant, reviews: syntheticReviews(5))),
      ));
      expect(find.byType(Scrollable), findsNWidgets(expected));
    });
  }
}
