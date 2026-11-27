import 'package:flutter/material.dart';
import 'package:app_flutter/models/review.dart';
import 'package:app_flutter/theme/app_theme.dart';
import 'package:app_flutter/widgets/stars.dart';

// BEFORE version of the 2x2 category grid, kept ONLY for the profiling app and the parity tests.
// The app no longer uses it (see lib/widgets/review_category_grid.dart).
// Exact copy of the GridView.count that MyReviewCard and the Reviews list _ReviewCard used to build
class LegacyCategoryGrid extends StatelessWidget {
  final ReviewRatings ratings;

  const LegacyCategoryGrid({super.key, required this.ratings});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true, // Takes only the height it needs (it is inside a scrolling list)
      physics: const NeverScrollableScrollPhysics(), // The outer list handles scrolling
      mainAxisSpacing: 6,
      crossAxisSpacing: 6,
      childAspectRatio: 4.6,
      children: [
        for (final c in reviewCategories)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(8)),
            child: Row(
              children: [
                Expanded(child: Text(c.label, style: const TextStyle(fontSize: 10, color: AppColors.muted))),
                StarsDisplay(value: ratings.byKey(c.key).toDouble(), size: 9),
              ],
            ),
          ),
      ],
    );
  }
}
