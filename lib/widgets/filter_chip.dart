// Pill-shaped toggle chip used to filter lists (map "All Spots / Open Now", home categories, etc.)
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class AppFilterChip extends StatelessWidget {
  // Named AppFilterChip to avoid clashing with Flutter's built-in FilterChip widget

  final String label;       // Text shown inside the pill
  final bool active;        // Whether this chip is the currently selected one
  final Color activeColor;  // Background color when active (defaults to dark)
  final VoidCallback onTap; // What to do when the user taps the chip

  const AppFilterChip({
    super.key,
    required this.label,
    required this.active,
    required this.onTap,
    this.activeColor = AppColors.dark,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          // Active: solid colored pill with white text. Inactive: white pill with a light border and grey text
          color: active ? activeColor : AppColors.card,
          borderRadius: BorderRadius.circular(999),
          border: active ? null : Border.all(color: AppColors.closed.withOpacity(0.25)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: active ? Colors.white : AppColors.closed,
          ),
        ),
      ),
    );
  }
}
