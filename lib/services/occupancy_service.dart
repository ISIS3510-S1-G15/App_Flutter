import 'package:shared_preferences/shared_preferences.dart';

class OccupancyService {
  // Builds a unique storage key per restaurant, so each place has its own list of reports
  static String _keyFor(String restaurantId) => 'occupancy_$restaurantId';

  // Saves a new report locally on this device
  static Future<void> submitReport(String restaurantId, int level) async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getStringList(_keyFor(restaurantId)) ?? [];
    current.add(level.toString());
    // Keep only the last 10 reports so old data doesn't pile up forever
    final trimmed = current.length > 10 ? current.sublist(current.length - 10) : current;
    await prefs.setStringList(_keyFor(restaurantId), trimmed);
  }

  // Reads the reports saved locally for a given restaurant
  static Future<List<int>> getReports(String restaurantId) async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList(_keyFor(restaurantId)) ?? [];
    return saved.map(int.parse).toList();
  }
}