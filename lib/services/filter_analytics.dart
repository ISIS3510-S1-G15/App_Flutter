import 'dart:convert';
import 'package:http/http.dart' as http;

// Type 2 BQ: "Which filters (diet, budget, distance, available time) are most
// commonly used when searching for a place to eat?"
class FilterAnalytics {
  // Usa 10.0.2.2 para el emulador de Android
  static const String _baseUrl = 'http://10.0.2.2:8000';

  // Guarda que el usuario usó un filtro en una pantalla (ej. 'Open Now' en 'map')
  static Future<void> logFilterUsed(String filter, String screen) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/analytics/filter-usage'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'filter': filter, 'screen': screen}),
      );

      if (response.statusCode == 200) {
        print('✅ Logged filter usage: $filter ($screen)');
      } else {
        print('⚠️ Failed to log filter usage: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error connecting to backend: $e');
    }
  }

  // Lee el resumen de qué filtros se usan más
  static Future<List<Map<String, dynamic>>> getFilterUsage() async {
    final response = await http.get(Uri.parse('$_baseUrl/analytics/filter-usage'));
    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.cast<Map<String, dynamic>>();
    }
    return [];
  }
}
