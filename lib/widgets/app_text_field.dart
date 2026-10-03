// Rounded text field with an orange border when focused (survey name/foods to avoid, review comment)
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class AppTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;
  final int maxLines;
  final int? maxLength;   // If set, limits the characters and shows a "0/300" counter below the field
  final Color fillColor;  // Background of the field (white by default)

  const AppTextField({
    super.key,
    required this.controller,
    required this.hint,
    required this.onChanged,
    this.maxLines = 1,
    this.maxLength,
    this.fillColor = AppColors.card,
  });

  @override
  Widget build(BuildContext context) {
    // Same rounded shape for both states; only the border color changes
    OutlineInputBorder border(Color color) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: color),
        );

    return TextField(
      controller: controller,
      onChanged: onChanged,
      maxLines: maxLines,
      maxLength: maxLength,
      textCapitalization: maxLines == 1 ? TextCapitalization.words : TextCapitalization.sentences,
      style: AppTextStyles.body.copyWith(fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.mutedLight, fontSize: 14),
        filled: true,
        fillColor: fillColor,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        enabledBorder: border(AppColors.border),
        focusedBorder: border(AppColors.accent),
        counterStyle: const TextStyle(fontSize: 10, color: AppColors.mutedLight), // Style of the "0/300" counter
      ),
    );
  }
}
