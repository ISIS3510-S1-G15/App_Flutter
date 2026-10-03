// Round white button with an icon, used for "back" in the headers (Profile, Reviews, Write a Review)
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class AppCircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const AppCircleButton({super.key, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(), // The ripple effect follows the round shape
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppColors.card,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.border),
        ),
        child: Icon(icon, size: 16, color: AppColors.dark),
      ),
    );
  }
}
