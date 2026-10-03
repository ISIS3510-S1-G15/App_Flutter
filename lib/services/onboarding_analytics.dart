import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;

// Type 2 BQ: "What percentage of users complete the food preferences survey
// during onboarding?"
class OnboardingAnalytics {
  // Usa 10.0.2.2 para el emulador de Android
  static const String _baseUrl = 'http://10.0.2.2:8000';

  // Identifica un mismo recorrido de la encuesta, para saber si quien la empezó también la terminó
  static String newSessionId() =>
      '${DateTime.now().microsecondsSinceEpoch}-${Random().nextInt(1 << 32)}';

  // event: 'started' (abrió la encuesta), 'step' (avanzó a un paso) o 'completed' (guardó sus preferencias)
  static Future<void> logEvent(String sessionId, String event, int step) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/analytics/onboarding-event'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'session_id': sessionId, 'event': event, 'step': step}),
      );

      if (response.statusCode == 200) {
        print('✅ Logged onboarding event: $event (step $step)');
      } else {
        print('⚠️ Failed to log onboarding event: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error connecting to backend: $e');
    }
  }

  // Lee el resumen: sesiones iniciadas, completadas, porcentaje y hasta qué paso llegaron
  static Future<Map<String, dynamic>?> getCompletion() async {
    final response = await http.get(Uri.parse('$_baseUrl/analytics/onboarding-completion'));
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    return null;
  }
}
