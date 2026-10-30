import 'package:flutter/foundation.dart';
import 'api_client.dart';
import 'pending_events.dart';

class RecommendationAnalytics {
  static final ApiClient _api = ApiClient();
  static const _path = '/analytics/recommendation-shown';

  static Future<void> logShown({required String recommendedId, double? recommendedLevel, String? alternativeId}) async {
    final body = {
      'recommended_id': recommendedId,
      'recommended_level': recommendedLevel,
      'alternative_id': alternativeId,
    };
    try {
      await _api.postJson(_path, body);
    } on ApiException catch (e) {
      debugPrint('Recommendation event rejected (${e.statusCode})');
    } catch (e) {
      debugPrint('Could not log recommendation, saved to send later: $e');
      await PendingEvents.add(_path, body);
    }
  }
}
