// Thin rounded progress bar (survey steps, profile completeness)
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class AppProgressBar extends StatelessWidget {
  final double progress;  // How full the bar is, from 0.0 (empty) to 1.0 (full)
  final Color trackColor; // Color of the empty part of the bar
  final Color fillColor;  // Color of the filled part of the bar
  final double height;

  const AppProgressBar({
    super.key,
    required this.progress,
    required this.trackColor,
    this.fillColor = AppColors.accent,
    this.height = 6,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      // Clips the track and the fill to rounded ends
      borderRadius: BorderRadius.circular(999),
      child: Container(
        height: height,
        color: trackColor,
        child: AnimatedFractionallySizedBox(
          // Width of the fill = progress % of the track; animates smoothly when progress changes
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOut,
          alignment: Alignment.centerLeft,
          widthFactor: progress.clamp(0.0, 1.0),
          child: Container(color: fillColor),
        ),
      ),
    );
  }
}
