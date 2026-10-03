import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/restaurant.dart';
import '../models/review.dart';
import '../data/reviews_data.dart';
import '../utils/text_utils.dart';
import '../widgets/back_header.dart';
import '../widgets/app_chip.dart';
import '../widgets/progress_bar.dart';
import '../widgets/stars.dart';
import 'write_review_screen.dart';

// The 4 rating categories shown in the summary bars and in each review card: (key in ReviewRatings, short label)
const _categories = [
  (key: 'taste', label: 'Taste'),
  (key: 'attention', label: 'Service'),
  (key: 'price', label: 'Value'),
  (key: 'options', label: 'Diet Options'),
];

class ReviewsListScreen extends StatelessWidget {
  // StatelessWidget because it only displays the reviews; it redraws by listening to allReviews (see build)
  final Restaurant restaurant;

  const ReviewsListScreen({super.key, required this.restaurant});

  void _onWriteReview(BuildContext context) {
    // Opens the form. When a review is submitted, allReviews changes and this list redraws with it
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => WriteReviewScreen(restaurant: restaurant)),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Listens to all the reviews: every time one is added, the builder runs again
    return ValueListenableBuilder<List<Review>>(
      valueListenable: allReviews,
      builder: (context, _, __) => _buildContent(context, reviewsFor(restaurant.id)),
    );
  }

  Widget _buildContent(BuildContext context, List<Review> reviews) {
    // Overall average = average of the overall rating of each review (0 if there are no reviews)
    final overall = reviews.isEmpty
        ? 0.0
        : reviews.map((r) => r.ratings.overall).reduce((a, b) => a + b) / reviews.length;

    // Counts how many reviews mention each dietary option, and keeps the 5 most mentioned
    final dietCounts = <String, int>{};
    for (final r in reviews) {
      for (final d in r.dietaryOptions) {
        dietCounts[d] = (dietCounts[d] ?? 0) + 1;
      }
    }
    final topDiets = dietCounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header: back button + "REVIEWS" + restaurant name + "+ Write" button
            BackHeader(
              eyebrow: 'Reviews',
              title: restaurant.name,
              onBack: () => Navigator.of(context).pop(),
              trailing: GestureDetector(
                onTap: () => _onWriteReview(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(12)),
                  child: const Text(
                    '+ Write',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                ),
              ),
            ),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                children: [
                  // Summary card: big overall number + category bars + most noted dietary options
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(color: AppColors.dark, borderRadius: BorderRadius.circular(24)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            // Left: overall rating, stars and number of reviews
                            Column(
                              children: [
                                Text(
                                  reviews.isEmpty ? '—' : overall.toStringAsFixed(1),
                                  style: AppTextStyles.headline.copyWith(fontSize: 42, color: Colors.white, height: 1),
                                ),
                                const SizedBox(height: 4),
                                StarsDisplay(value: overall, size: 14),
                                const SizedBox(height: 4),
                                Text(
                                  '${reviews.length} review${reviews.length != 1 ? 's' : ''}',
                                  style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.5)),
                                ),
                              ],
                            ),
                            const SizedBox(width: 16),

                            // Right: one amber bar per category with its average (out of 5)
                            Expanded(
                              child: Column(
                                children: [
                                  for (final c in _categories)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 4),
                                      child: _CategoryBar(
                                        label: c.label,
                                        value: _average(reviews, c.key),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        // Commonly noted: dietary options most mentioned by the reviewers ("Vegan options · 2")
                        if (topDiets.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Divider(height: 1, color: Colors.white.withOpacity(0.1)),
                          const SizedBox(height: 12),
                          Text(
                            'COMMONLY NOTED',
                            style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.5), letterSpacing: 0.6),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: topDiets
                                .take(5)
                                .map((e) => Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(999),
                                      ),
                                      child: Text(
                                        '${e.key} · ${e.value}',
                                        style: const TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ))
                                .toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Empty state: shown when this restaurant has no reviews yet
                  if (reviews.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 48),
                      child: Column(
                        children: [
                          const Text('⭐', style: TextStyle(fontSize: 40)),
                          const SizedBox(height: 12),
                          Text('No reviews yet', style: AppTextStyles.cardTitle.copyWith(fontSize: 15)),
                          const SizedBox(height: 4),
                          Text(
                            'Be the first to review ${restaurant.name}',
                            style: AppTextStyles.body.copyWith(fontSize: 12, color: AppColors.muted),
                          ),
                          const SizedBox(height: 20),
                          GestureDetector(
                            onTap: () => _onWriteReview(context),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              decoration: BoxDecoration(
                                color: AppColors.accent,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(color: AppColors.accent.withOpacity(0.25), blurRadius: 8, offset: const Offset(0, 3)),
                                ],
                              ),
                              child: Text('Write the first review', style: AppTextStyles.button.copyWith(fontSize: 13)),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // One card per review (newest first)
                  ...reviews.map((r) => Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _ReviewCard(review: r),
                      )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Average rating of one category across all the reviews (0 if there are no reviews)
  double _average(List<Review> reviews, String key) {
    if (reviews.isEmpty) return 0;
    return reviews.map((r) => r.ratings.byKey(key)).reduce((a, b) => a + b) / reviews.length;
  }
}

// Reusable widget: one row of the summary card ("Taste  ▓▓▓▓░  4.5")
class _CategoryBar extends StatelessWidget {
  final String label;
  final double value; // Average from 0 to 5

  const _CategoryBar({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 72, // Fixed width so all the bars start at the same position
          child: Text(label, style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.6))),
        ),
        Expanded(
          child: AppProgressBar(
            progress: value / 5,
            trackColor: Colors.white.withOpacity(0.1),
            fillColor: AppColors.amber,
          ),
        ),
        SizedBox(
          width: 24,
          child: Text(
            value > 0 ? value.toStringAsFixed(1) : '—',
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white),
          ),
        ),
      ],
    );
  }
}

// Reusable widget: one review (author, date, overall, category stars, dietary options and comment)
class _ReviewCard extends StatelessWidget {
  final Review review;

  const _ReviewCard({required this.review});

  @override
  Widget build(BuildContext context) {
    final r = review;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Author row: avatar with initials + name + date on the left, overall rating on the right
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: const BoxDecoration(color: AppColors.dark, shape: BoxShape.circle),
                child: Text(
                  initialsOf(r.author),
                  style: AppTextStyles.headline.copyWith(fontSize: 11, color: Colors.white),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r.author, style: AppTextStyles.cardTitle.copyWith(fontSize: 13)),
                    Text(formatDate(r.date), style: const TextStyle(fontSize: 10, color: AppColors.mutedLight)),
                  ],
                ),
              ),
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

          // Category breakdown: 2 x 2 grid of "label + small stars"
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true, // Takes only the height it needs (it is inside a scrolling list)
            physics: const NeverScrollableScrollPhysics(), // The outer list handles scrolling
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
            childAspectRatio: 4.6,
            children: [
              for (final c in _categories)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(8)),
                  child: Row(
                    children: [
                      Expanded(child: Text(c.label, style: const TextStyle(fontSize: 10, color: AppColors.muted))),
                      StarsDisplay(value: r.ratings.byKey(c.key).toDouble(), size: 9),
                    ],
                  ),
                ),
            ],
          ),

          // Dietary options the reviewer marked (small green chips)
          if (r.dietaryOptions.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: r.dietaryOptions.map((d) => AppChip.diet(diet: d, small: true)).toList(),
            ),
          ],

          // Comment (only if the reviewer wrote one)
          if (r.comment.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(r.comment, style: AppTextStyles.body.copyWith(fontSize: 13, height: 1.5)),
          ],
        ],
      ),
    );
  }
}
