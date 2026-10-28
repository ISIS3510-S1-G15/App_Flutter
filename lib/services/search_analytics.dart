import 'dart:convert';
import 'package:http/http.dart' as http;

class SearchAnalytics {
  // Usa 10.0.2.2 para el emulador de Android
  static const String _baseUrl = 'http://10.0.2.2:8000';

  // Guarda un término que no arrojó resultados.
  // async/await: espera la respuesta del backend sin bloquear la pantalla.
  // Si el backend responde con error, lanza una excepción para que quien la llame la maneje con .catchError
  static Future<void> logZeroResultSearch(String term) async {
    final response = await http
        .post(
          Uri.parse('$_baseUrl/analytics/zero-result-search'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'query': term}),
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw Exception('Backend answered ${response.statusCode}');
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
