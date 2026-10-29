import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/onboarding_analytics.dart';

class SurveyCompletionBanner extends StatefulWidget {
  final String callToAction;

  const SurveyCompletionBanner({super.key, required this.callToAction});

  @override
  State<SurveyCompletionBanner> createState() => _SurveyCompletionBannerState();
}

class _SurveyCompletionBannerState extends State<SurveyCompletionBanner> {
  late final Future<double?> _rate = OnboardingAnalytics.completionRate();

  String _format(double rate) => rate == rate.roundToDouble() ? rate.toStringAsFixed(0) : rate.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<double?>(
      future: _rate,
      builder: (context, snapshot) {
        final rate = snapshot.data;
        if (rate == null) return const SizedBox.shrink();

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
              const Icon(Icons.insights, size: 18, color: AppColors.accent),
              const SizedBox(width: 10),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    style: AppTextStyles.body.copyWith(fontSize: 12, color: AppColors.dark),
                    children: [
                      TextSpan(
                        text: '${_format(rate)}% of students',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      TextSpan(text: ' complete this survey. ${widget.callToAction}'),
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
