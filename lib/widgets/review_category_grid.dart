import 'package:flutter/material.dart';
import '../models/review.dart';
import '../theme/app_theme.dart';
import 'stars.dart';

// The 2x2 "label + small stars" grid of a review card (My Reviews and Reviews list).
// MICRO-OPTIMIZATION (slides 19, #7 flatter layouts and #1 no unnecessary objects): it used to be a
// GridView.count(shrinkWrap: true). Even without scrolling, every GridView is a full scrollable
// (Scrollable + viewport + ScrollPosition + gesture detectors), and shrinkWrap lays out all its children
// to know its size: one hidden scrollable per card inside the main list. Four fixed cells only need a
// Column of two Rows. Same look: each cell keeps the 4.6 aspect ratio and the 6 px gaps
class ReviewCategoryGrid extends StatelessWidget {
  final ReviewRatings ratings;

  const ReviewCategoryGrid({super.key, required this.ratings});

  static const _gap = 6.0; // the old mainAxisSpacing / crossAxisSpacing
  static const _cellRatio = 4.6; // the old childAspectRatio

  @override
  Widget build(BuildContext context) {
    // Indexed loop over the categories two by two ([0,1] and [2,3]): no intermediate .map().toList()
    final rows = <Widget>[];
    for (var i = 0; i < reviewCategories.length; i += 2) {
      if (i > 0) rows.add(const SizedBox(height: _gap));
      rows.add(Row(
        children: [
          Expanded(child: _cell(reviewCategories[i])),
          const SizedBox(width: _gap),
          Expanded(child: _cell(reviewCategories[i + 1])),
        ],
      ));
    }
    return Column(mainAxisSize: MainAxisSize.min, children: rows); // as tall as its rows, like shrinkWrap
  }

  // AspectRatio gives each cell exactly the height the GridView computed with childAspectRatio, for any width
  Widget _cell(({String key, String label}) c) {
    return AspectRatio(
      aspectRatio: _cellRatio,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        // const: the same decoration object for every cell of every card (no new BoxDecoration per build)
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
        child: Row(
          children: [
            Expanded(child: Text(c.label, style: const TextStyle(fontSize: 10, color: AppColors.muted))),
            StarsDisplay(value: ratings.byKey(c.key).toDouble(), size: 9),
          ],
        ),
      ),
    );
  }
}
