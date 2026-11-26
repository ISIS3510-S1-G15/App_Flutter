import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/restaurant.dart';
import 'api_client.dart';
import 'connectivity_service.dart';

// Design pattern: REPOSITORY. The restaurant list used to be hardcoded in the app (restaurants_data.dart);
// now it comes from the backend (GET /restaurants). The screens never call the backend directly:
// they read RestaurantService.restaurants and redraw when it changes.
class RestaurantService {
  static final ApiClient _api = ApiClient();
  static const _cacheKey = 'restaurants_cache_v1';
  static const _savedAtKey = 'restaurants_cache_saved_at_v1';

  // Every restaurant of the app. Starts empty and is filled from the cache and then from the backend
  static final ValueNotifier<List<Restaurant>> restaurants = ValueNotifier(const []);

  // EVENTUAL CONNECTIVITY: when the list shown was downloaded from the backend. Screens use it to say
  // "places from 2 h ago" while offline. Null until the first list is available (cache or network)
  static final ValueNotifier<DateTime?> updatedAt = ValueNotifier(null);

  static bool _loading = false;
  static bool _listening = false;

  // Strategy "Cache then network": shows the last list saved on the phone right away (works offline),
  // then asks the backend for the newest one and saves it for next time
  static Future<void> load() async {
    _listenForReconnection();
    if (_loading) return;
    _loading = true;
    try {
      await _loadCache();
      await _loadNetwork();
    } finally {
      _loading = false;
    }
  }

  // EVENTUAL CONNECTIVITY: if the app was opened without internet, the list stays the cached one.
  // As soon as the connection comes back, the newest list is downloaded without restarting the app.
  // It listens to the app-wide connectivity notifier instead of being called from it, so the
  // connectivity service doesn't need to know about restaurants
  static void _listenForReconnection() {
    if (_listening) return;
    _listening = true;
    var wasOnline = ConnectivityService.isOnline.value;
    ConnectivityService.isOnline.addListener(() {
      final online = ConnectivityService.isOnline.value;
      if (online && !wasOnline) load();
      wasOnline = online;
    });
  }

  static Future<void> _loadCache() async {
    if (restaurants.value.isNotEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(_cacheKey);
      if (cached == null) return;
      restaurants.value = _parse(jsonDecode(cached));
      final savedAt = prefs.getInt(_savedAtKey);
      updatedAt.value = savedAt == null ? null : DateTime.fromMillisecondsSinceEpoch(savedAt);
    } catch (e) {
      debugPrint('Could not read cached restaurants: $e');
    }
  }

  static Future<void> _loadNetwork() async {
    try {
      final data = await _api.getJson('/restaurants');
      restaurants.value = _parse(data);
      final now = DateTime.now();
      updatedAt.value = now;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, jsonEncode(data));
      await prefs.setInt(_savedAtKey, now.millisecondsSinceEpoch);
    } catch (e) {
      debugPrint('Could not load restaurants from the backend, keeping the saved list: $e');
    }
  }

  static List<Restaurant> _parse(dynamic data) => ((data as Map<String, dynamic>)['restaurants'] as List)
      .cast<Map<String, dynamic>>()
      .map(Restaurant.fromJson)
      .toList(growable: false);

  // "just now", "15 min ago", "3 h ago", "2 days ago"
  static String ago(DateTime time, {DateTime? now}) {
    final d = (now ?? DateTime.now()).difference(time);
    if (d.inMinutes < 1) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes} min ago';
    if (d.inHours < 24) return '${d.inHours} h ago';
    return d.inDays == 1 ? '1 day ago' : '${d.inDays} days ago';
  }
}
