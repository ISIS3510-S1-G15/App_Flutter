// Star widgets used by the reviews: a read-only row of stars and a tappable 1-5 star selector
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

// Read-only row of 5 stars filled according to a rating (review list summary and review cards)
class StarsDisplay extends StatelessWidget {
  final double value; // Rating from 0 to 5 (can have decimals, e.g. 4.3)
  final double size;

  const StarsDisplay({super.key, required this.value, this.size = 12});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int s = 1; s <= 5; s++)
          Padding(
            padding: const EdgeInsets.only(right: 2),
            // A star is filled if the rating reaches it or is at most half a star below (4.5 shows 5 stars)
            child: Icon(Icons.star_rounded, size: size, color: value >= s - 0.5 ? AppColors.amber : AppColors.border),
          ),
      ],
    );
  }
}

// Row of 5 big tappable stars to choose a rating from 1 to 5 (Write a Review)
class StarRatingInput extends StatelessWidget {
  final int value;                 // Current rating (0 = not rated yet)
  final ValueChanged<int> onChanged;

  const StarRatingInput({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (int star = 1; star <= 5; star++)
          GestureDetector(
            onTap: () => onChanged(star), // Tapping the 3rd star sets the rating to 3
            child: Padding(
              padding: const EdgeInsets.only(right: 6),
              child: AnimatedSwitcher(
                // Small fade when a star changes from empty to filled
                duration: const Duration(milliseconds: 150),
                child: Icon(
                  Icons.star_rounded,
                  key: ValueKey(value >= star),
                  size: 32,
                  color: value >= star ? AppColors.amber : AppColors.border,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
