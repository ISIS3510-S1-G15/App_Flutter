import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:app_flutter/models/restaurant.dart';
import 'package:app_flutter/services/image_disk_cache.dart';

void main() {
  const url = 'https://example.com/cosechas.jpg';
  final jpeg = [0xFF, 0xD8, 0xFF, 0xE0, 1, 2, 3];
  late Directory dir;

  setUp(() async => dir = await Directory.systemTemp.createTemp('img_cache_test'));
  tearDown(() async => dir.delete(recursive: true));

  ImageDiskCache cacheWith(MockClient client) => ImageDiskCache(directory: () async => dir, client: client);

  test('downloads once, then serves the picture from disk without network (offline)', () async {
    var calls = 0;
    final online = cacheWith(MockClient((_) async {
      calls++;
      return http.Response.bytes(jpeg, 200, headers: {'content-type': 'image/jpeg'});
    }));
    final first = await online.file(url);
    expect(first, isNotNull);
    expect(await first!.readAsBytes(), jpeg);

    // A new cache (like reopening the app) with no internet still finds the saved picture
    final offline = cacheWith(MockClient((_) async => throw const SocketException('no internet')));
    final again = await offline.file(url);
    expect(again?.path, first.path);
    expect(calls, 1);
  });

  test('several widgets asking at the same time share one download', () async {
    var calls = 0;
    final cache = cacheWith(MockClient((_) async {
      calls++;
      await Future<void>.delayed(const Duration(milliseconds: 20));
      return http.Response.bytes(jpeg, 200, headers: {'content-type': 'image/jpeg'});
    }));
    final files = await Future.wait(List.generate(8, (_) => cache.file(url)));
    expect(files.every((f) => f != null), isTrue);
    expect(calls, 1);
  });

  test('offline with no saved copy, or a non-image answer, gives null (placeholder) and saves nothing', () async {
    final offline = cacheWith(MockClient((_) async => throw const SocketException('no internet')));
    expect(await offline.file(url), isNull);

    final notAnImage = cacheWith(MockClient((_) async => http.Response('<html>', 200, headers: {'content-type': 'text/html'})));
    expect(await notAnImage.file(url), isNull);
    expect(dir.listSync(), isEmpty);
  });

  test('Restaurant reads image_url from the backend JSON', () {
    final r = Restaurant.fromJson({'id': '4', 'name': 'Cosechas', 'image_key': null, 'image_url': url});
    expect(r.imageUrl, url);
    final noUrl = Restaurant.fromJson({'id': '1', 'name': 'Starbucks', 'image_key': 'starbucks', 'image_url': null});
    expect(noUrl.imageUrl, isNull);
    expect(noUrl.image, 'web/icons/starbucks.jpeg');
  });
}
