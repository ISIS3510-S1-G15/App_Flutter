import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'api_client.dart';
import 'history_worker.dart';
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
  static const _fileName = 'recent_views.json';

  static final ValueNotifier<List<RecentView>> items = ValueNotifier(const []);
  static final ValueNotifier<DateTime?> updatedAt = ValueNotifier(null);

  static Future<void>? _loadingFile;

  static const freshFor = Duration(minutes: 2);
  static DateTime? _lastFetch;
  static Future<void>? _fetching;

  static Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File(join(dir.path, _fileName));
  }

  static Future<void> _ensureFileLoaded() => _loadingFile ??= _readFile();

  static Future<void> _readFile() async {
    try {
      final file = await _file();
      if (!await file.exists()) return;
      final data = await HistoryWorker.decode(await file.readAsString());
      items.value = (data['items'] as List)
          .map((e) => RecentView.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(growable: false);
      final stored = data['updated_at'] as String?;
      updatedAt.value = stored == null ? null : DateTime.tryParse(stored)?.toLocal();
    } catch (e) {
      debugPrint('Could not read the recent views file: $e');
    }
  }

  static Future<void> _writeFile() async {
    try {
      final file = await _file();
      final raw = await HistoryWorker.encode({
        'updated_at': updatedAt.value?.toUtc().toIso8601String(),
        'items': items.value.map((v) => v.toJson()).toList(),
      });
      final temp = File('${file.path}.tmp');
      await temp.writeAsString(raw, flush: true);
      await temp.rename(file.path);
    } catch (e) {
      debugPrint('Could not write the recent views file: $e');
    }
  }

  static bool get _isFresh {
    final last = _lastFetch;
    return last != null && DateTime.now().difference(last) < freshFor;
  }

  static Future<void> load({bool force = false}) async {
    await _ensureFileLoaded();
    if (!force && _isFresh) {
      debugPrint('Recent views cache hit: fetched ${DateTime.now().difference(_lastFetch!).inSeconds}s ago, no request sent');
      return;
    }
    await (_fetching ??= _fetch().whenComplete(() => _fetching = null));
  }

  static Future<void> _fetch() async {
    debugPrint('Recent views cache miss: asking the backend');
    try {
      final data = await _api.getJson('/me/recent-views') as Map<String, dynamic>;
      _applyServerList(data);
      updatedAt.value = DateTime.now();
      _lastFetch = DateTime.now();
      await _writeFile();
    } catch (e) {
      debugPrint('Could not load recent views from the backend, using the saved file: $e');
    }
  }

  static void _applyServerList(Map<String, dynamic> data) {
    items.value = (data['items'] as List)
        .map((e) => RecentView.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  static Future<void> recordView(String restaurantId) async {
    await _ensureFileLoaded();
    final now = DateTime.now().toUtc();
    final previous = items.value.where((v) => v.restaurantId == restaurantId);
    final count = previous.isEmpty ? 0 : previous.first.viewCount;
    items.value = [
      RecentView(restaurantId: restaurantId, viewCount: count + 1, lastViewedAt: now),
      ...items.value.where((v) => v.restaurantId != restaurantId),
    ];
    await _writeFile();
    await RestaurantViewAnalytics.logView(restaurantId);
  }

  static Future<bool> remove(String restaurantId) async {
    await _ensureFileLoaded();
    items.value = items.value.where((v) => v.restaurantId != restaurantId).toList(growable: false);
    return _changeOnServer(() => _api.deleteJson('/me/recent-views/$restaurantId'));
  }

  static Future<bool> clearHistory() async {
    await _ensureFileLoaded();
    items.value = const [];
    return _changeOnServer(() => _api.deleteJson('/me/recent-views'));
  }

  static Future<bool> _changeOnServer(Future<dynamic> Function() request) async {
    try {
      _applyServerList(await request() as Map<String, dynamic>);
      updatedAt.value = DateTime.now();
      _lastFetch = DateTime.now();
      await _writeFile();
      return true;
    } catch (e) {
      debugPrint('Could not update recent views: $e');
      await load(force: true);
      return false;
    }
  }

  static Future<void> clearLocal() async {
    items.value = const [];
    updatedAt.value = null;
    _lastFetch = null;
    _loadingFile = Future.value();
    try {
      final file = await _file();
      if (await file.exists()) await file.delete();
    } catch (e) {
      debugPrint('Could not delete the recent views file: $e');
    }
  }
}
