// Rounded pill chip with a border (profile cuisines/dietary restrictions, dietary options in review cards)
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class AppChip extends StatelessWidget {
  final String label;
  final Color background;
  final Color textColor;
  final Color borderColor;
  final bool small; // true = smaller padding and text (review cards); false = normal size (profile)

  const AppChip({
    super.key,
    required this.label,
    required this.background,
    required this.textColor,
    required this.borderColor,
    this.small = false,
  });

  // Ready-made green chip with a check mark, used for dietary restrictions/options
  const AppChip.diet({super.key, required String diet, this.small = false})
      : label = '✓ $diet',
        background = AppColors.greenLight,
        textColor = AppColors.green,
        borderColor = AppColors.greenBorder;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: small ? 8 : 12, vertical: small ? 2 : 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: borderColor),
      ),
      child: Text(
        label,
        style: AppTextStyles.body.copyWith(
          fontSize: small ? 10 : 12,
          fontWeight: small ? FontWeight.w500 : FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }
}
