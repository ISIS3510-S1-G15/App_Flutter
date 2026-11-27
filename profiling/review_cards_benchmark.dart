import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:app_flutter/models/review.dart';
import 'package:app_flutter/theme/app_theme.dart';
import 'package:app_flutter/utils/text_utils.dart';
import 'package:app_flutter/widgets/app_chip.dart';
import 'package:app_flutter/widgets/review_category_grid.dart';
import 'benchmarks.dart';
import 'legacy_category_grid.dart';

// Review cards benchmark (Juan Felipe, issue #113; slides 19 micro-opt #7 flatter layouts).
// Scenario: 200 review cards MOUNTED at once, the worst case of the Reviews list, which creates every card
// when it opens. Both variants paint the same card (name, date, overall pill, grid, chips, comment, with
// MyReviewCard's styles); the ONLY difference is the 2x2 category grid:
//   - before: LegacyCategoryGrid (a GridView.count with shrinkWrap = one hidden scrollable per card)
//   - after:  ReviewCategoryGrid (a Column of two Rows)
// A layout is not a pure function, so the time is one real frame: setState -> build + layout + paint ->
// endOfFrame. Rounds alternate before/after so neither variant is favoured by running first or last
// (warm caches, GC, CPU frequency). Results use Sofía's BenchmarkResult, so they print the same way.

enum GridVariant { before, after }

const benchmarkCardCount = 200;

// The same 200 synthetic reviews in every round (benchmarks.dart: derived from the index, no Random)
final List<Review> _reviews = syntheticReviews(benchmarkCardCount);

// The list of cards of one variant. SingleChildScrollView + Column instead of ListView(children: [...]):
// a ListView only mounts the cards inside its viewport (+ cache extent) even when it receives all the
// widgets, and the scenario needs the 200 cards really mounted (built, laid out and painted)
class ReviewCardsList extends StatelessWidget {
  final GridVariant variant;
  final List<Review> reviews;

  const ReviewCardsList({super.key, required this.variant, required this.reviews});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          for (var i = 0; i < reviews.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: BenchmarkReviewCard(review: reviews[i], restaurantName: 'Restaurant ${i + 1}', variant: variant),
            ),
        ],
      ),
    );
  }
}

// Same structure and styles as MyReviewCard; only the grid depends on the variant
class BenchmarkReviewCard extends StatelessWidget {
  final Review review;
  final String restaurantName;
  final GridVariant variant;

  const BenchmarkReviewCard({super.key, required this.review, required this.restaurantName, required this.variant});

  @override
  Widget build(BuildContext context) {
    final r = review;
    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () {},
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
              if (variant == GridVariant.before)
                LegacyCategoryGrid(ratings: r.ratings)
              else
                ReviewCategoryGrid(ratings: r.ratings),
              if (r.dietaryOptions.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: r.dietaryOptions.map((d) => AppChip.diet(diet: d, small: true)).toList(),
                ),
              ],
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

// Fixed-height area where the active variant is mounted. Shows nothing when no variant is active
class ReviewCardsBenchmarkArea extends StatefulWidget {
  const ReviewCardsBenchmarkArea({super.key});

  @override
  State<ReviewCardsBenchmarkArea> createState() => ReviewCardsBenchmarkAreaState();
}

// Public so the profiling app can drive it through a GlobalKey
class ReviewCardsBenchmarkAreaState extends State<ReviewCardsBenchmarkArea> {
  GridVariant? _variant;

  // Mounts the variant and times that ONE frame (build + layout + paint). Leaves it mounted
  Future<int> mountAndTime(GridVariant v) async {
    final watch = Stopwatch()..start();
    setState(() => _variant = v);
    await SchedulerBinding.instance.endOfFrame;
    watch.stop();
    return watch.elapsedMicroseconds;
  }

  // Scrollable widgets mounted inside the area (the list itself counts 1)
  int countScrollables() {
    var count = 0;
    void visit(Element e) {
      if (e.widget is Scrollable) count++;
      e.visitChildElements(visit);
    }

    (context as Element).visitChildElements(visit);
    return count;
  }

  Future<void> unmount() async {
    setState(() => _variant = null);
    await SchedulerBinding.instance.endOfFrame;
  }

  // Mounts a variant and leaves it there, to inspect the instances in DevTools Memory
  Future<void> show(GridVariant v) async {
    setState(() => _variant = v);
    await SchedulerBinding.instance.endOfFrame;
  }

  @override
  Widget build(BuildContext context) {
    final variant = _variant;
    return SizedBox(
      height: 320,
      // Key per variant: switching variant disposes the other one's cards, nothing is reused between them
      child: variant == null
          ? const SizedBox.shrink()
          : ReviewCardsList(key: ValueKey(variant), variant: variant, reviews: _reviews),
    );
  }
}

Future<({List<BenchmarkResult> results, int scrollablesBefore, int scrollablesAfter})> runReviewCardsBenchmark(
  ReviewCardsBenchmarkAreaState state, {
  int rounds = 10,
}) async {
  // Warm-up, not measured (same idea as searchBefore(catalog, 2) in Sofía's benchmark): first-time costs
  // such as font loading, shader compilation and JIT/AOT caches must not count for only one variant
  for (var i = 0; i < 2; i++) {
    for (final v in GridVariant.values) {
      await state.mountAndTime(v);
      await state.unmount();
    }
  }

  var totalBefore = 0, totalAfter = 0;
  var scrollablesBefore = 0, scrollablesAfter = 0;
  for (var round = 0; round < rounds; round++) {
    // Alternating before -> after in every round
    totalBefore += await state.mountAndTime(GridVariant.before);
    if (round == 0) scrollablesBefore = state.countScrollables();
    await state.unmount();

    totalAfter += await state.mountAndTime(GridVariant.after);
    if (round == 0) scrollablesAfter = state.countScrollables();
    await state.unmount();
  }

  final label = 'Review cards ($benchmarkCardCount mounted × $rounds)';
  return (
    results: [
      BenchmarkResult('$label – before', totalBefore),
      BenchmarkResult('$label – after', totalAfter),
    ],
    scrollablesBefore: scrollablesBefore,
    scrollablesAfter: scrollablesAfter,
  );
}
