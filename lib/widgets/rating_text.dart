import 'package:flutter/material.dart';
import '../services/review_service.dart';

// Rating of a restaurant calculated by the backend ("4.5" or "New"), or its number of reviews ("(12)").
// It redraws by itself when ReviewService.summaries changes (e.g. right after the user writes a review),
// so the screens only swap '${r.rating}' for RatingText(r.id) and keep their own text style
class RatingText extends StatelessWidget {
  final String restaurantId;
  final TextStyle? style;
  final bool showCount; // false: "4.5"   true: "(12)"

  const RatingText(this.restaurantId, {super.key, this.style}) : showCount = false;

  const RatingText.count(this.restaurantId, {super.key, this.style}) : showCount = true;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Map<String, RatingSummary>>(
      valueListenable: ReviewService.summaries,
      builder: (context, _, __) {
        final summary = ReviewService.summaryOf(restaurantId);
        return Text(showCount ? '(${summary.count})' : summary.label, style: style);
      },
    );
  }
}
