// The user's profile, created by the answers of the food preferences survey
// Shared by SurveyScreen (writes it), HomeScreen (greeting + avatar initials) and ProfileScreen (full profile)
import 'package:flutter/foundation.dart';
import '../models/survey_answers.dart';

// ValueNotifier holds one value and notifies whoever is listening every time it changes.
// The screens wrap their content in a ValueListenableBuilder, so when the survey saves new answers
// Home and Profile redraw automatically. It starts empty until the user completes the survey
final ValueNotifier<SurveyAnswers> userProfile = ValueNotifier(const SurveyAnswers());
