// Group of toggle chips where several options can be selected at once (survey questions, review dietary options)
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class AppMultiSelect extends StatelessWidget {
  final List<String> options;
  final List<String> selected;
  final ValueChanged<String> onToggle;
  final Color activeColor;      // Background of the selected chips (orange, green or amber depending on the question)
  final Color activeTextColor;  // Text color of the selected chips
  final Color inactiveColor;    // Background of the chips that are not selected
  final String? maxLabel;       // Optional warning shown above the chips (e.g. "Max 3 selected")

  const AppMultiSelect({
    super.key,
    required this.options,
    required this.selected,
    required this.onToggle,
    required this.activeColor,
    this.activeTextColor = Colors.white,
    this.inactiveColor = AppColors.card,
    this.maxLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (maxLabel != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                Text(
                  maxLabel!,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.accent),
                ),
              ],
            ),
          ),
        Wrap(
          // Wrap lets the chips flow to a new line automatically if there are many
          spacing: 8,
          runSpacing: 8,
          children: options.map((opt) {
            final isSelected = selected.contains(opt);
            return GestureDetector(
              onTap: () => onToggle(opt),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? activeColor : inactiveColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isSelected ? activeColor : AppColors.border),
                ),
                child: Text(
                  // Selected chips show a check mark before the text
                  isSelected ? '✓  $opt' : opt,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? activeTextColor : AppColors.dark,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
