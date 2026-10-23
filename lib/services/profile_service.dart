import 'package:flutter/foundation.dart';
import '../data/profile_data.dart';
import '../models/survey_answers.dart';
import 'api_client.dart';

// Saves the food preferences survey in the backend, per user, so it is kept after closing the app
// or logging in from another phone. The screens keep reading userProfile like before
class ProfileService {
  static final ApiClient _api = ApiClient(); // Singleton: already carries the user's session token

  // Reads the saved profile into userProfile. Called when the main app opens (after login or a restored session)
  static Future<void> load() async {
    try {
      final data = await _api.getJson('/me/profile') as Map<String, dynamic>;
      if (data['completed'] != true) return; // never answered the survey: keep what is there (the account name)
      final saved = SurveyAnswers.fromJson(data);
      // An empty name in the survey keeps the account name for the greeting
      userProfile.value = saved.name.isEmpty ? saved.copyWith(name: userProfile.value.name) : saved;
    } catch (e) {
      debugPrint('Could not load the profile: $e');
    }
  }

  // Sends the survey answers (first time and every "Retake survey"). Fails silently: the answers stay in the app
  static Future<void> save(SurveyAnswers answers) async {
    try {
      await _api.putJson('/me/profile', body: answers.toJson());
    } catch (e) {
      debugPrint('Could not save the profile: $e');
    }
  }
}
