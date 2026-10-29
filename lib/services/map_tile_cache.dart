import 'package:flutter_map/flutter_map.dart';

class MapTileCache {
  static const maxSizeBytes = 50 * 1024 * 1024;
  static const freshFor = Duration(days: 7);

  static final MapCachingProvider provider = BuiltInMapCachingProvider.getOrCreateInstance(
    maxCacheSize: maxSizeBytes,
    overrideFreshAge: freshFor,
  );

  static TileProvider tileProvider() => NetworkTileProvider(cachingProvider: provider);
}
