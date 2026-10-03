// Big orange circle with a white check mark, shown on confirmation screens (survey saved, review submitted)
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class SuccessCheck extends StatelessWidget {
  const SuccessCheck({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: AppColors.accent,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: AppColors.accent.withOpacity(0.35), blurRadius: 24, offset: const Offset(0, 10))],
      ),
      child: const Icon(Icons.check_rounded, size: 40, color: Colors.white),
    );
  }
}
