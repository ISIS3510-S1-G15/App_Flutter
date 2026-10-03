import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'main_navigation.dart';
import 'screens/survey_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: appTheme,
      // The first screen of the app is the onboarding survey. Its answers create the user's profile
      home: Builder(
        // Builder gives a context that is inside the MaterialApp's Navigator, so the survey can navigate from it
        builder: (context) => SurveyScreen(
          isOnboarding: true,
          // When the survey is saved, replaces it with the main app (pushReplacement: the user can't go back to it)
          onComplete: () => Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const MainNavigation()),
          ),
        ),
      ),
    );
  }
}
