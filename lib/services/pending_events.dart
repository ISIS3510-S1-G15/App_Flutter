import 'package:flutter/foundation.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'api_client.dart';

class PendingEvents {
  static const _boxName = 'pending_events';
  static final ApiClient _api = ApiClient();
  static bool _initialized = false;
  static bool _sending = false;

  static Future<Box> _box() async {
    if (!_initialized) {
      await Hive.initFlutter();
      _initialized = true;
    }
    return Hive.openBox(_boxName);
  }

  static Future<void> add(String path, Map<String, dynamic> body) async {
    try {
      final box = await _box();
      await box.add({'path': path, 'body': body, 'created_at': DateTime.now().toIso8601String()});
    } catch (e) {
      debugPrint('Could not store pending event: $e');
    }
  }

  static Future<int> count() async => (await _box()).length;

  static Future<void> sendAll() async {
    if (_sending) return;
    _sending = true;
    try {
      final box = await _box();
      for (final key in box.keys.toList()) {
        final event = Map<String, dynamic>.from(box.get(key) as Map);
        try {
          await _api.postJson(event['path'] as String, Map<String, dynamic>.from(event['body'] as Map));
          await box.delete(key);
        } catch (e) {
          debugPrint('Pending event not sent yet: $e');
          break;
        }
      }
    } finally {
      _sending = false;
    }
  }
}
