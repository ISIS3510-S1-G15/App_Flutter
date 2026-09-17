// Widget que muestra si un lugar está lleno o vacío según reportes recientes
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class CrowdingBadge extends StatelessWidget {
// "StatelessWidget" means that it does not change on its own once it has been rendered receives data from outside and displays it; it does not manage its own internal state

  final List<int> reports;
  // List of numbers representing recent occupancy reports

  final bool small;
  // Specifies whether the badge should be displayed in small (true) or normal (false) size

  const CrowdingBadge({super.key, required this.reports, this.small = false});
  // Widget constructor: requires to pass “reports” when creating it, and 'small' is optional (it defaults to “false”)

  @override
  Widget build(BuildContext context) {
    // 'build()' is the method that renders the widget on the screen
    // Flutter calls it automatically when it needs to display this widget

    if (reports.isEmpty) return const SizedBox.shrink();
    // If there are no occupancy reports, nothing is displayed
    // (SizedBox.shrink() is a zero-sized invisible box)

    final avg = reports.reduce((a, b) => a + b) / reports.length;
    // Calculate the average of all the numbers in "reports"

    late String label;
    // Declares a text variable that will be populated later

    late Color color;
    // Declares a color variable that will be populated later

    if (avg < 0.7) {
      label = 'Not crowded';
      color = AppColors.open;
    } else if (avg < 1.4) {
      label = 'Moderate';
      color = AppColors.accent;
    } else {
      label = 'Busy';
      color = AppColors.closed;
    }

    return Container(
      // Draws a visual box/container on the screen
      padding: EdgeInsets.symmetric(horizontal: small ? 6 : 8, vertical: 2),
      // Internal spacing of the box: if “small” is true, use 6px on the sides. If it is false, use 8px. Always use 2px at the top and bottom
      decoration: BoxDecoration(
        // Defines how the box looks (background color, rounded corners, etc.)
        color: color.withOpacity(0.12),
        // 12% opacity so it looks like a soft background, not a strong solid color
        borderRadius: BorderRadius.circular(999),
        // Rounded corners 
      ),
      child: Text(
        // Display some text inside the box
        label,
        // Already defined (Not crowded / Moderate / Busy)
        style: TextStyle(
          // Estilo del texto:
          fontSize: small ? 10 : 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}