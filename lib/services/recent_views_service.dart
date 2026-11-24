import 'package:flutter/foundation.dart';
import 'api_client.dart';
import 'restaurant_view_analytics.dart';

class RecentView {
  final String restaurantId;
  final int viewCount;
  final DateTime lastViewedAt;

  const RecentView({required this.restaurantId, required this.viewCount, required this.lastViewedAt});

  factory RecentView.fromJson(Map<String, dynamic> json) => RecentView(
        restaurantId: json['restaurant_id'] as String,
        viewCount: json['view_count'] as int,
        lastViewedAt: DateTime.parse(json['last_viewed_at'] as String).toUtc(),
      );

  Map<String, dynamic> toJson() => {
        'restaurant_id': restaurantId,
        'view_count': viewCount,
        'last_viewed_at': lastViewedAt.toUtc().toIso8601String(),
      };
}

class RecentViewsService {
  static final ApiClient _api = ApiClient();

  static final ValueNotifier<List<RecentView>> items = ValueNotifier(const []);
  static final ValueNotifier<DateTime?> updatedAt = ValueNotifier(null);

  static Future<void> load() async {
    try {
      final data = await _api.getJson('/me/recent-views') as Map<String, dynamic>;
      _applyServerList(data);
      updatedAt.value = DateTime.now();
    } catch (e) {
      debugPrint('Could not load recent views from the backend: $e');
    }
  }

  static void _applyServerList(Map<String, dynamic> data) {
    items.value = (data['items'] as List)
        .map((e) => RecentView.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  static Future<void> recordView(String restaurantId) async {
    final now = DateTime.now().toUtc();
    final previous = items.value.where((v) => v.restaurantId == restaurantId);
    final count = previous.isEmpty ? 0 : previous.first.viewCount;
    items.value = [
      RecentView(restaurantId: restaurantId, viewCount: count + 1, lastViewedAt: now),
      ...items.value.where((v) => v.restaurantId != restaurantId),
    ];
    await RestaurantViewAnalytics.logView(restaurantId);
  }

  static Future<bool> remove(String restaurantId) async {
    items.value = items.value.where((v) => v.restaurantId != restaurantId).toList(growable: false);
    return _changeOnServer(() => _api.deleteJson('/me/recent-views/$restaurantId'));
  }

  static Future<bool> clearHistory() async {
    items.value = const [];
    return _changeOnServer(() => _api.deleteJson('/me/recent-views'));
  }

  static Future<bool> _changeOnServer(Future<dynamic> Function() request) async {
    try {
      _applyServerList(await request() as Map<String, dynamic>);
      updatedAt.value = DateTime.now();
      return true;
    } catch (e) {
      debugPrint('Could not update recent views: $e');
      await load();
      return false;
    }
  }

  static void clearLocal() {
    items.value = const [];
    updatedAt.value = null;
  }
}
