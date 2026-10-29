import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_client.dart';
import 'pending_events.dart';

class CompletionRate {
  final double rate;
  final DateTime updatedAt;
  final bool fromCache;

  const CompletionRate({required this.rate, required this.updatedAt, required this.fromCache});
}

class OnboardingAnalytics {
  static final ApiClient _api = ApiClient();
  static const _eventPath = '/analytics/onboarding-event';
  static const _rateKey = 'onboarding_completion_rate';
  static const _rateAtKey = 'onboarding_completion_rate_at';

  static String newSessionId() =>
      '${DateTime.now().microsecondsSinceEpoch}-${Random().nextInt(1 << 32)}';

  static Future<void> logEvent(String sessionId, String event, int step) async {
    final body = {'session_id': sessionId, 'event': event, 'step': step};
    try {
      await _api.postJson(_eventPath, body);
    } on ApiException catch (e) {
      debugPrint('Onboarding event rejected (${e.statusCode}): $event');
    } catch (_) {
      await PendingEvents.add(_eventPath, body);
    }
  }

  static Future<Map<String, dynamic>?> getCompletion() async {
    try {
      return await _api.getJson('/analytics/onboarding-completion') as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  static Future<CompletionRate?> completionRate() async {
    final summary = await getCompletion();
    if (summary != null && (summary['started'] as num? ?? 0) > 0) {
      final rate = (summary['completion_rate'] as num).toDouble();
      final now = DateTime.now();
      await _saveRate(rate, now);
      return CompletionRate(rate: rate, updatedAt: now, fromCache: false);
    }
    return _cachedRate();
  }

  static Future<void> _saveRate(double rate, DateTime at) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_rateKey, rate);
      await prefs.setString(_rateAtKey, at.toIso8601String());
    } catch (_) {}
  }

  static Future<CompletionRate?> _cachedRate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rate = prefs.getDouble(_rateKey);
      final at = DateTime.tryParse(prefs.getString(_rateAtKey) ?? '');
      if (rate == null || at == null) return null;
      return CompletionRate(rate: rate, updatedAt: at, fromCache: true);
    } catch (_) {
      return null;
    }
  }
}
