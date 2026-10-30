import 'package:flutter/material.dart';
import '../services/app_usage_analytics.dart';
import '../services/place_selection_analytics.dart';

// Wraps the main app (only shown to logged-in users) and records every time the user opens it.
// "Open" = entering the app after logging in / restoring the session, or coming back from the
// background after at least 30 seconds (so a quick look at a notification does not count twice)
class AppOpenTracker extends StatefulWidget {
  final Widget child;

  const AppOpenTracker({super.key, required this.child});

  @override
  State<AppOpenTracker> createState() => _AppOpenTrackerState();
}

// WidgetsBindingObserver lets this widget hear the app lifecycle (resumed, paused, ...) from the OS
class _AppOpenTrackerState extends State<AppOpenTracker> with WidgetsBindingObserver {
  static const _minimumAway = Duration(seconds: 30);
  DateTime? _wentToBackgroundAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _registerOpen(); // first open of this session
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _wentToBackgroundAt = DateTime.now(); // the user left the app (home button, another app, screen off)
    } else if (state == AppLifecycleState.resumed && _wentToBackgroundAt != null) {
      final away = DateTime.now().difference(_wentToBackgroundAt!);
      _wentToBackgroundAt = null;
      if (away >= _minimumAway) _registerOpen();
    }
  }

  // I notify both BQs from here (the widget that detects the open) instead of chaining them inside
  // AppUsageAnalytics, so the two BQs share the same "open" definition without depending on each other
  void _registerOpen() {
    AppUsageAnalytics.logAppOpen();
    PlaceSelectionAnalytics.markAppOpen();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
