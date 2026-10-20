import 'package:flutter/foundation.dart';
import 'api_client.dart';

class SurveyAnalytics {
  static final ApiClient _api = ApiClient();

  static Future<void> log(String event, {int? step}) async {
    try {
      await _api.postJson('/analytics/survey-event', {
        'event': event,
        if (step != null) 'step': step,
      });
    } catch (e) {
      debugPrint('Could not log survey event: $e');
    }
  }
}