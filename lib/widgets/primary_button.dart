// Full-width 48px rounded button (survey "Continue", "Submit Review", "Back to Restaurant")
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class AppPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;    // If null, the button is shown disabled (grey) and does nothing when tapped
  final Color color;            // Background when enabled (orange by default, dark for secondary actions)
  final IconData? trailingIcon; // Optional icon after the text (e.g. the ">" in "Continue")
  final bool shadow;            // Soft glow under the button, used for the main action of the screen

  const AppPrimaryButton({
    super.key,
    required this.label,
    required this.onTap,
    this.color = AppColors.accent,
    this.trailingIcon,
    this.shadow = true,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final textColor = enabled ? Colors.white : AppColors.mutedLight;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 48,
        decoration: BoxDecoration(
          color: enabled ? color : AppColors.border,
          borderRadius: BorderRadius.circular(16),
          boxShadow: enabled && shadow
              ? [BoxShadow(color: color.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 6))]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label, style: AppTextStyles.button.copyWith(fontSize: 14, color: textColor)),
            if (trailingIcon != null) ...[
              const SizedBox(width: 8),
              Icon(trailingIcon, size: 14, color: textColor),
            ],
          ],
        ),
      ),
    );
  }
}
