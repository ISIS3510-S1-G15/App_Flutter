import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'pending_events.dart';
import 'saved_service.dart';
import 'profile_service.dart';

class ConnectivityService {
  static final ValueNotifier<bool> isOnline = ValueNotifier(true);
  static StreamSubscription<List<ConnectivityResult>>? _sub;

  static Future<void> start() async {
    if (_sub != null) return;
    _sub = Connectivity().onConnectivityChanged.listen(_update);
    try {
      _update(await Connectivity().checkConnectivity());
    } catch (e) {
      debugPrint('Could not read connectivity: $e');
    }
  }

  static void _update(List<ConnectivityResult> results) {
    final online = results.isNotEmpty && !results.contains(ConnectivityResult.none);
    final cameBack = online && !isOnline.value;
    isOnline.value = online;
    if (cameBack) {
            Future.delayed(const Duration(seconds: 3), () {
        PendingEvents.sendAll();
        SavedService.load();
        ProfileService.syncPending();
      });
    }
  }
}
