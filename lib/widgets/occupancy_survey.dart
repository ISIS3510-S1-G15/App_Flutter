import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/occupancy_service.dart';
import '../services/connectivity_service.dart';

class OccupancySurvey extends StatelessWidget {
  final String restaurantId;
  final String restaurantName;

  const OccupancySurvey({
    super.key,
    required this.restaurantId,
    required this.restaurantName,
  });

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
    // The report goes to the backend so ALL users see it. It is not queued offline on purpose:
    // a "Busy" sent 40 minutes later would describe a moment that already passed
    final sent = await OccupancyService.submitReport(restaurantId, level);
    if (context.mounted) {
      final messenger = ScaffoldMessenger.of(context); // taken before pop: the dialog's context goes away
      Navigator.of(context).pop(); // close the dialog
      messenger.showSnackBar(
        SnackBar(
          content: Text(sent
              ? 'Thanks! Marked as "$label"'
              : 'Could not send your report. Check your connection and try again.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Offline the dialog explains why it cannot report instead of "accepting" a report that fails 5 s later
    // (anti-patterns #5/#8). Not queued for the same reason as in _submit: the report describes "right now".
    // If the connection comes back with the dialog open, the 3 options appear by themselves (anti-pattern #7)
    return ValueListenableBuilder<bool>(
      valueListenable: ConnectivityService.isOnline,
      builder: (context, online, _) => AlertDialog(
        title: Text('Are you at $restaurantName?', style: AppTextStyles.cardTitle.copyWith(fontSize: 16)),
        content: Text(
          online
              ? 'Help other students by reporting how busy it is right now.'
              : "You're offline. Crowding reports need internet because they describe how busy it is right now"
                  ' — a report sent later would be wrong for everyone.',
          style: AppTextStyles.body.copyWith(fontSize: 13, color: AppColors.closed),
        ),
        actions: online
            ? [
                _optionButton(context, 0, 'Not crowded', AppColors.open),
                _optionButton(context, 1, 'Moderate', AppColors.accent),
                _optionButton(context, 2, 'Busy', AppColors.closed),
              ]
            : [
                TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK')),
              ],
      ),
    );
  }

  Widget _optionButton(BuildContext context, int level, String label, Color color) {
    return TextButton(
      onPressed: () => _submit(context, level, label),
      child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
    );
  }
}