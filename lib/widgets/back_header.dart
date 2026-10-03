// Header with a back button + small uppercase label + title, and an optional widget on the right
// Used by the Reviews and Write a Review screens ("REVIEWS / Starbucks", "WRITE A REVIEW / Starbucks")
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'circle_button.dart';

class BackHeader extends StatelessWidget {
  final String eyebrow;   // Small grey uppercase text above the title
  final String title;
  final VoidCallback onBack;
  final Widget? trailing; // Optional widget on the right (e.g. the "+ Write" button)

  const BackHeader({super.key, required this.eyebrow, required this.title, required this.onBack, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      child: Row(
        children: [
          AppCircleButton(icon: Icons.arrow_back_ios_new, onTap: onBack),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  eyebrow.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.muted,
                    letterSpacing: 0.6,
                  ),
                ),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis, // Cuts long restaurant names with "..."
                  style: AppTextStyles.headline.copyWith(fontSize: 18, height: 1.2),
                ),
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 12), trailing!],
        ],
      ),
    );
  }
}
