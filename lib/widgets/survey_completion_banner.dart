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
  late final Future<CompletionRate?> _rate = OnboardingAnalytics.completionRate();

  String _age(DateTime at) {
    final diff = DateTime.now().difference(at);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes} min ago';
    if (diff.inDays < 1) return '${diff.inHours} h ago';
    return '${diff.inDays} d ago';
  }

  String _format(double rate) => rate == rate.roundToDouble() ? rate.toStringAsFixed(0) : rate.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<CompletionRate?>(
      future: _rate,
      builder: (context, snapshot) {
        final data = snapshot.data;
        if (data == null) return const SizedBox.shrink();
        final rate = data.rate;

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
