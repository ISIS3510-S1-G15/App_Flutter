import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

// CACHING + EVENTUAL CONNECTIVITY for restaurant pictures that come from the backend (image_url).
//
// Flutter's Image.network only keeps pictures in memory: after closing the app, or without
// internet, the photo is gone. This cache keeps every downloaded picture as a file on the phone:
//   1. Memory: the file of each URL already resolved in this session (no disk check again).
//   2. Disk: <app support>/restaurant_images/<hash of the URL>. If it exists, it is used without
//      any network call, so the photo also shows offline.
//   3. Network: only when the picture is not on disk. It is written to a temporary file and
//      renamed at the end, so a cut connection never leaves a half-written picture.
// Several widgets asking for the same URL at the same time share ONE download.
// The URL works as the version: if the backend changes a picture, it sends a new URL.
class ImageDiskCache {
  ImageDiskCache({Future<Directory> Function()? directory, http.Client? client, this.timeout = const Duration(seconds: 10)})
      : _directory = directory ?? _defaultDirectory,
        _client = client ?? http.Client();

  static final ImageDiskCache instance = ImageDiskCache();

  final Future<Directory> Function() _directory;
  final http.Client _client;
  final Duration timeout;

  final Map<String, File> _memory = {};
  final Map<String, Future<File?>> _inFlight = {};

  static Future<Directory> _defaultDirectory() async =>
      Directory(p.join((await getApplicationSupportDirectory()).path, 'restaurant_images'));

  // File already in memory for this URL (lets the widget draw it in the first frame, no flicker)
  File? peek(String url) => _memory[url];

  // Returns the picture file, or null if it is not cached and cannot be downloaded (e.g. offline)
  Future<File?> file(String url) {
    final known = _memory[url];
    if (known != null) return Future.value(known);
    // Block body on purpose: "=> _inFlight.remove(url)" would return this same future to
    // whenComplete, which would then wait for itself forever
    return _inFlight[url] ??= _resolve(url).whenComplete(() {
      _inFlight.remove(url);
    });
  }

  Future<File?> _resolve(String url) async {
    try {
      final dir = await _directory();
      final file = File(p.join(dir.path, _fileName(url)));
      if (await file.exists() && await file.length() > 0) return _memory[url] = file;

      final response = await _client.get(Uri.parse(url)).timeout(timeout);
      final type = response.headers['content-type'] ?? '';
      if (response.statusCode != 200 || !type.startsWith('image/') || response.bodyBytes.isEmpty) {
        debugPrint('Picture not available (${response.statusCode}, $type): $url');
        return null;
      }
      await dir.create(recursive: true);
      final tmp = File('${file.path}.tmp');
      await tmp.writeAsBytes(response.bodyBytes, flush: true);
      await tmp.rename(file.path);
      return _memory[url] = file;
    } catch (e) {
      debugPrint('Could not get picture (offline?): $e');
      return null;
    }
  }

  // Stable file name for a URL (FNV-1a 32-bit hash), the same in every app run
  static String _fileName(String url) {
    var hash = 0x811c9dc5;
    for (final byte in utf8.encode(url)) {
      hash = ((hash ^ byte) * 0x01000193) & 0xffffffff;
    }
    return '${hash.toRadixString(16).padLeft(8, '0')}.img';
  }
}
