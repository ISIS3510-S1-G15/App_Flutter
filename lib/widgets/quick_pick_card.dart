import 'package:flutter/material.dart';
import '../models/quick_pick.dart';
import '../models/restaurant.dart';
import '../theme/app_theme.dart';
import '../utils/text_utils.dart';

// Created once instead of withOpacity on every build (slides 19, micro-opt #1): AppColors.accent at alpha 0.1
const _accent10 = Color(0x1AE8622C);

// BQ Type 2 answer turned into an action on Discover: the place the user (or campus) usually picks at this
// meal moment, one tap away from the route. It skips search, detail and comparing
class QuickPickCard extends StatelessWidget {
  final QuickPick pick;
  final Restaurant restaurant;
  final VoidCallback onGo; // "Get directions": straight to the route
  final VoidCallback onDismiss; // "Not today"

  const QuickPickCard({
    super.key,
    required this.pick,
    required this.restaurant,
    required this.onGo,
    required this.onDismiss,
  });

  String get _eyebrow {
    final moment = pick.mealSlot.toUpperCase();
    return pick.kind == QuickPickKind.yourUsual ? 'YOUR USUAL FOR $moment' : "STUDENTS' PICK FOR $moment";
  }

  String get _reason {
    if (pick.kind == QuickPickKind.campusFavorite) return 'Most students choose it at this time.';
    final moment = pick.mealSlot.toLowerCase();
    final mine = pick.myAvgSeconds;
    return mine == null
        ? 'Your go-to place at $moment.'
        : 'You usually take ${formatDecisionTime(mine)} to decide at $moment. Skip the search.';
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Quick pick: ${restaurant.name}. Get directions',
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderLight),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: _accent10,
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                  ),
                  child: const Icon(Icons.bolt_rounded, size: 22, color: AppColors.accent),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _eyebrow,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.accent,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        restaurant.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.cardTitle.copyWith(fontSize: 15),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _reason,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.body.copyWith(fontSize: 12, color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
                // At least 40x40 so the small X is still easy to hit
                SizedBox(
                  width: 40,
                  height: 40,
                  child: IconButton(
                    onPressed: onDismiss,
                    padding: EdgeInsets.zero,
                    tooltip: 'Not today',
                    icon: const Icon(Icons.close_rounded, size: 16, color: AppColors.mutedLight),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Same look as the app's primary button (AppPrimaryButton: accent, radius 16, button text), 40 high
            Material(
              color: AppColors.accent,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                onTap: onGo,
                borderRadius: BorderRadius.circular(16),
                child: SizedBox(
                  height: 40,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.near_me_rounded, size: 16, color: Colors.white),
                      const SizedBox(width: 8),
                      Text('Get directions', style: AppTextStyles.button.copyWith(fontSize: 13, color: Colors.white)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
