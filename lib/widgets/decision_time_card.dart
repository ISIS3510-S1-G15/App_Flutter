import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/place_selection_analytics.dart';

// Type 2 BQ answered to the user in Profile. Same look and offline behavior as SurveyCompletionBanner,
// so both BQ answers next to each other read as one consistent block
class DecisionTimeCard extends StatefulWidget {
  const DecisionTimeCard({super.key});

  @override
  State<DecisionTimeCard> createState() => _DecisionTimeCardState();
}

class _DecisionTimeCardState extends State<DecisionTimeCard> {
  late final Future<DecisionTime?> _summary = PlaceSelectionAnalytics.mySummary();

  String _age(DateTime at) {
    final diff = DateTime.now().difference(at);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes} min ago';
    if (diff.inDays < 1) return '${diff.inHours} h ago';
    return '${diff.inDays} d ago';
  }

  // < 60 s -> "less than a minute"; otherwise rounded minutes ("about 3 min")
  String _duration(double seconds) => seconds < 60 ? 'less than a minute' : 'about ${(seconds / 60).round()} min';

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DecisionTime?>(
      future: _summary,
      builder: (context, snapshot) {
        final data = snapshot.data;
        if (data == null) return const SizedBox.shrink();
        final mine = data.mySelections > 0 ? data.mySeconds : null;
        final campus = _duration(data.campusSeconds);

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.accent.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.timer_outlined, size: 18, color: AppColors.accent),
              const SizedBox(width: 10),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    style: AppTextStyles.body.copyWith(fontSize: 12, color: AppColors.dark),
                    children: [
                      if (mine != null) ...[
                        TextSpan(
                          text: 'You usually pick a place in ${_duration(mine)}.',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        TextSpan(text: ' Students take $campus on average.'),
                      ] else ...[
                        TextSpan(
                          text: 'Students usually pick a place in $campus',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const TextSpan(text: ' after opening the app.'),
                      ],
                      if (data.fromCache)
                        TextSpan(
                          text: '\nOffline · last updated ${_age(data.updatedAt)}',
                          style: const TextStyle(fontSize: 11, color: AppColors.muted),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
