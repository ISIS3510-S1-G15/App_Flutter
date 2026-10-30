import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/restaurant.dart';
import 'api_client.dart';

// Design pattern: REPOSITORY. The restaurant list used to be hardcoded in the app (restaurants_data.dart);
// now it comes from the backend (GET /restaurants). The screens never call the backend directly:
// they read RestaurantService.restaurants and redraw when it changes.
class RestaurantService {
  static final ApiClient _api = ApiClient();
  static const _cacheKey = 'restaurants_cache_v1';

  // Every restaurant of the app. Starts empty and is filled from the cache and then from the backend
  static final ValueNotifier<List<Restaurant>> restaurants = ValueNotifier(const []);

  // Strategy "Cache then network": shows the last list saved on the phone right away (works offline),
  // then asks the backend for the newest one and saves it for next time
  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(_cacheKey);
      if (cached != null && restaurants.value.isEmpty) restaurants.value = _parse(jsonDecode(cached));
    } catch (e) {
      debugPrint('Could not read cached restaurants: $e');
    }
    try {
      final data = await _api.getJson('/restaurants');
      restaurants.value = _parse(data);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, jsonEncode(data));
    } catch (e) {
      debugPrint('Could not load restaurants from the backend: $e');
    }
  }

  static List<Restaurant> _parse(dynamic data) => ((data as Map<String, dynamic>)['restaurants'] as List)
      .cast<Map<String, dynamic>>()
      .map(Restaurant.fromJson)
      .toList(growable: false);
}
