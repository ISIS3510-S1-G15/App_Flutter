import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/occupancy_service.dart';

class OccupancySurvey extends StatelessWidget {
  final String restaurantId;
  final String restaurantName;

  const OccupancySurvey({
    super.key,
    required this.restaurantId,
    required this.restaurantName,
  });

  // Call this from anywhere to pop up the survey
  // Call this from anywhere to open the survey as a popup dialog.
  // Returns a Future that completes when the dialog closes, so callers
  // can "await" it and run code right after (e.g. refresh the data shown).
  static Future<void> show(BuildContext context, String restaurantId, String restaurantName) {
    return showDialog<void>(
      context: context,
      builder: (_) => OccupancySurvey(
        restaurantId: restaurantId,
        restaurantName: restaurantName,
      ),
    );
  }

  Future<void> _submit(BuildContext context, int level, String label) async {
    await OccupancyService.submitReport(restaurantId, level);
    if (context.mounted) {
      Navigator.of(context).pop(); // close the dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Thanks! Marked as "$label"')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Are you at $restaurantName?', style: AppTextStyles.cardTitle.copyWith(fontSize: 16)),
      content: Text(
        'Help other students by reporting how busy it is right now.',
        style: AppTextStyles.body.copyWith(fontSize: 13, color: AppColors.closed),
      ),
      actions: [
        _optionButton(context, 0, 'Not crowded', AppColors.open),
        _optionButton(context, 1, 'Moderate', AppColors.accent),
        _optionButton(context, 2, 'Busy', AppColors.closed),
      ],
    );
  }

  Widget _optionButton(BuildContext context, int level, String label, Color color) {
    return TextButton(
      onPressed: () => _submit(context, level, label),
      child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
    );
  }
}