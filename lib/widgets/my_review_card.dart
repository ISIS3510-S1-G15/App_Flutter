import 'package:flutter/material.dart';
import '../models/review.dart';
import '../theme/app_theme.dart';
import '../utils/text_utils.dart';
import 'app_chip.dart';
import 'review_category_grid.dart';

// One review written by the user, in My Reviews. Same card as the one in the Reviews list, except the header:
// the author is always the user, so it shows WHICH restaurant was reviewed instead of the avatar + author
class MyReviewCard extends StatelessWidget {
  final Review review;
  final String restaurantName;
  final VoidCallback? onTap; // Opens the restaurant's detail

  const MyReviewCard({super.key, required this.review, required this.restaurantName, this.onTap});

  @override
  Widget build(BuildContext context) {
    final r = review;

    // Material + InkWell so the ripple is drawn on the card's own background and clipped to its corners
    return Material(
      color: r.pending ? AppColors.background : AppColors.card, // cream = written offline, not posted yet
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.borderLight),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: restaurant name + date on the left, overall rating on the right
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          restaurantName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.cardTitle.copyWith(fontSize: 15),
                        ),
                        // A queued review has no publication date yet: it says it is waiting to be sent instead
                        if (r.pending)
                          const Row(
                            children: [
                              Icon(Icons.cloud_upload_outlined, size: 12, color: AppColors.accent),
                              SizedBox(width: 4),
                              Text(
                                'Pending sync',
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.accent),
                              ),
                            ],
                          )
                        else
                          Text(formatDate(r.date), style: const TextStyle(fontSize: 10, color: AppColors.mutedLight)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(8)),
                    child: Row(
                      children: [
                        const Icon(Icons.star_rounded, size: 12, color: AppColors.amber),
                        const SizedBox(width: 4),
                        Text(r.ratings.overall.toStringAsFixed(1), style: AppTextStyles.headline.copyWith(fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Category breakdown: 2 x 2 grid of "label + small stars" (same as the Reviews list card)
              ReviewCategoryGrid(ratings: r.ratings), // flat 2x2 grid, no nested scrollable

              // Dietary options the user marked (small green chips)
              if (r.dietaryOptions.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: r.dietaryOptions.map((d) => AppChip.diet(diet: d, small: true)).toList(),
                ),
              ],

              // Comment (only if the user wrote one)
              if (r.comment.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(r.comment, style: AppTextStyles.body.copyWith(fontSize: 13, height: 1.5)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
