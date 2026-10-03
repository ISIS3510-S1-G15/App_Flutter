import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../main_navigation.dart';
import '../data/profile_data.dart';
import '../models/survey_answers.dart';
import '../services/auth_service.dart';
import '../widgets/app_open_tracker.dart';
import 'login_screen.dart';
import 'survey_screen.dart';

// First screen of the app. Decides where the user goes:
//  - saved, valid session  -> main app
//  - no session            -> login / register
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  // Opens the app after a successful login or register, replacing everything behind it (no going back to login).
  // A new account goes through the onboarding survey first; an existing one goes straight to the app
  static void enterApp(BuildContext context, AuthUser user, {required bool isNewUser}) {
    final navigator = Navigator.of(context);
    // The account name pre-fills the survey ("What should we call you?") and the greeting on Discover
    if (userProfile.value.name.isEmpty) {
      userProfile.value = userProfile.value.copyWith(name: user.name);
    }

    final Widget next = isNewUser
        ? SurveyScreen(
            isOnboarding: true,
            onComplete: () => navigator.pushAndRemoveUntil(_mainApp(), (_) => false),
          )
        : const AppOpenTracker(child: MainNavigation());
    navigator.pushAndRemoveUntil(MaterialPageRoute(builder: (_) => next), (_) => false);
  }

  // Closes the session and goes back to the login screen, removing every screen behind it
  static Future<void> logout(BuildContext context) async {
    final navigator = Navigator.of(context, rootNavigator: true);
    await AuthService.logout();
    userProfile.value = const SurveyAnswers(); // the next person must not see this user's preferences
    navigator.pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
  }

  static MaterialPageRoute<void> _mainApp() =>
      MaterialPageRoute(builder: (_) => const AppOpenTracker(child: MainNavigation()));

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  // Checks the saved session once. If it is valid, the account name is used for the greeting on Discover
  late final Future<AuthUser?> _session = AuthService.restoreSession().then((user) {
    if (user != null && userProfile.value.name.isEmpty) {
      userProfile.value = userProfile.value.copyWith(name: user.name);
    }
    return user;
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AuthUser?>(
      future: _session,
      builder: (context, snapshot) {
        // While the saved session is being checked, show a simple loading screen
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            backgroundColor: AppColors.background,
            body: Center(child: CircularProgressIndicator(color: AppColors.accent)),
          );
        }
        if (snapshot.data == null) return const LoginScreen();
        return const AppOpenTracker(child: MainNavigation());
      },
    );
  }
}
