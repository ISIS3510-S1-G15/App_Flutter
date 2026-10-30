import 'package:flutter/material.dart';
import '../services/connectivity_service.dart';
import '../theme/app_theme.dart';

class OfflineBanner extends StatelessWidget {
  final String message;
  final EdgeInsetsGeometry margin;

  const OfflineBanner({super.key, required this.message, this.margin = EdgeInsets.zero});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: ConnectivityService.isOnline,
      builder: (context, online, _) {
        if (online) return const SizedBox.shrink();
        return Container(
          margin: margin,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.dark,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(Icons.wifi_off, color: AppColors.card, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: AppTextStyles.body.copyWith(fontSize: 12, color: AppColors.card),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
