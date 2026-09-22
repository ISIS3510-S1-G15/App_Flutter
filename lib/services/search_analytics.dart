import 'dart:convert';
import 'package:http/http.dart' as http;

class SearchAnalytics {
  // Usa 10.0.2.2 para el emulador de Android
  static const String _baseUrl = 'http://10.0.2.2:8000';

  // Guarda un término que no arrojó resultados
  static Future<void> logZeroResultSearch(String term) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/analytics/zero-result-search'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'query': term}),
      );

      if (response.statusCode == 200) {
        print('✅ Logged zero-result search: $term');
      } else {
        print('⚠️ Failed to log search: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error connecting to backend: $e');
    }
  }

  // Lee el resumen de búsquedas sin resultados
  static Future<List<Map<String, dynamic>>> getSearchGaps() async {
    final response = await http.get(Uri.parse('$_baseUrl/analytics/search-gaps'));
    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.cast<Map<String, dynamic>>();
    }
    return [];
  }
}