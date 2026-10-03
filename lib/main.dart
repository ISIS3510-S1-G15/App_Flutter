import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'screens/auth_gate.dart';

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
      // First screen: AuthGate checks if there is a saved session.
      // No session -> Login / Create account. New account -> onboarding survey -> main app.
      // Saved session or existing account -> main app directly
      home: const AuthGate(),
    );
  }
}
