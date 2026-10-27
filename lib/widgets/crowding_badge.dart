// Widget que muestra si un lugar está lleno o vacío según los reportes recientes (backend)
import 'package:flutter/material.dart';
import '../services/occupancy_service.dart';
import '../theme/app_theme.dart';

// ONE rule to turn the 0-2 average into a label and a color. Before, these thresholds were copied in this
// badge and in the Detail card; if someone changed one, the two could disagree for the same place
({String label, Color color}) crowdingStyle(double avg) {
  if (avg < 0.7) return (label: 'Not crowded', color: AppColors.open);
  if (avg < 1.4) return (label: 'Moderate', color: AppColors.accent);
  return (label: 'Busy', color: AppColors.closed);
}

class CrowdingBadge extends StatelessWidget {
  // Receives only the restaurant id: the badge itself reads the current status from OccupancyService,
  // so every screen (Home, Map, Search, Saved, Detail) shows exactly the same level
  final String restaurantId;

  // Specifies whether the badge should be displayed in small (true) or normal (false) size
  final bool small;

  const CrowdingBadge({super.key, required this.restaurantId, this.small = false});

  @override
  Widget build(BuildContext context) {
    // ValueListenableBuilder redraws ONLY this badge when the occupancy data changes (data binding, as in MVVM)
    return ValueListenableBuilder<Map<String, OccupancyStatus>>(
      valueListenable: OccupancyService.statuses,
      builder: (context, _, __) {
        final status = OccupancyService.statusOf(restaurantId);
        if (!status.hasData) return const SizedBox.shrink(); // No recent reports: nothing is displayed

        final style = crowdingStyle(status.level!);
        return Container(
          padding: EdgeInsets.symmetric(horizontal: small ? 6 : 8, vertical: 2),
          decoration: BoxDecoration(
            color: style.color.withOpacity(0.12), // soft background, not a strong solid color
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            style.label,
            style: TextStyle(fontSize: small ? 10 : 11, fontWeight: FontWeight.w700, color: style.color),
          ),
        );
      },
    );
  }
}
