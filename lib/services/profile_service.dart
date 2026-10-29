import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/profile_data.dart';
import '../models/survey_answers.dart';
import 'api_client.dart';
import 'auth_service.dart';

// Saves the food preferences survey in the backend, per user, so it is kept after closing the app
// or logging in from another phone. The screens keep reading userProfile like before
class ProfileService {
  static final ApiClient _api = ApiClient(); // Singleton: already carries the user's session token
  static bool _syncing = false;

  static String? get _userKey {
    final id = AuthService.currentUser.value?.id;
    return id == null ? null : 'profile_cache_$id';
  }

  static String? get _pendingKey {
    final id = AuthService.currentUser.value?.id;
    return id == null ? null : 'profile_pending_$id';
  }

  static Future<void> load() async {
    await _loadCached();
    await syncPending();
    try {
      final data = await _api.getJson('/me/profile') as Map<String, dynamic>;
      if (data['completed'] != true) return;
      if (await _hasPending()) return;
      final saved = SurveyAnswers.fromJson(data);
      _apply(saved);
      await _cache(saved);
    } catch (e) {
      debugPrint('Could not load the profile, using the saved copy: $e');
    }
  }

  static Future<void> save(SurveyAnswers answers) async {
    await _cache(answers);
    try {
      await _api.putJson('/me/profile', body: answers.toJson());
      await _setPending(false);
    } on ApiException catch (e) {
      debugPrint('Profile rejected by the server (${e.statusCode})');
    } catch (e) {
      debugPrint('Could not save the profile, it will be sent when the connection comes back: $e');
      await _setPending(true);
    }
  }

  static Future<void> syncPending() async {
    if (_syncing || !await _hasPending()) return;
    _syncing = true;
    try {
      final cached = await _readCache();
      if (cached == null) return;
      await _api.putJson('/me/profile', body: cached.toJson());
      await _setPending(false);
    } catch (e) {
      debugPrint('Profile still pending: $e');
    } finally {
      _syncing = false;
    }
  }

  static void _apply(SurveyAnswers saved) {
    userProfile.value = saved.name.isEmpty ? saved.copyWith(name: userProfile.value.name) : saved;
  }

  static Future<void> _loadCached() async {
    final cached = await _readCache();
    if (cached != null) _apply(cached);
  }

  static Future<SurveyAnswers?> _readCache() async {
    final key = _userKey;
    if (key == null) return null;
    try {
      final raw = (await SharedPreferences.getInstance()).getString(key);
      return raw == null ? null : SurveyAnswers.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  static Future<void> _cache(SurveyAnswers answers) async {
    final key = _userKey;
    if (key == null) return;
    try {
      await (await SharedPreferences.getInstance()).setString(key, jsonEncode(answers.toJson()));
    } catch (_) {}
  }

  static Future<bool> _hasPending() async {
    final key = _pendingKey;
    if (key == null) return false;
    try {
      return (await SharedPreferences.getInstance()).getBool(key) ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> _setPending(bool pending) async {
    final key = _pendingKey;
    if (key == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      pending ? await prefs.setBool(key, true) : await prefs.remove(key);
    } catch (_) {}
  }
}
