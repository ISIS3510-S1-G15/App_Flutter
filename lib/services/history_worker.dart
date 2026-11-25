import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'package:flutter/foundation.dart';
import '../utils/history_grouping.dart';

class HistoryWorker {
  static SendPort? _workerPort;
  static Future<void>? _starting;
  static final Map<int, Completer<Object?>> _replies = {};
  static int _nextId = 0;

  static Future<void> _start() {
    return _starting ??= () async {
      final fromWorker = ReceivePort();
      final ready = Completer<SendPort>();
      fromWorker.listen((message) {
        if (message is SendPort) {
          ready.complete(message);
          return;
        }
        final reply = message as List;
        _replies.remove(reply[0] as int)?.complete(reply[1]);
      });
      await Isolate.spawn(_workerMain, fromWorker.sendPort, debugName: 'history_worker');
      _workerPort = await ready.future;
      debugPrint('History worker isolate started');
    }();
  }

  static Future<Object?> _run(String task, Object? data) async {
    await _start();
    final id = _nextId++;
    final completer = Completer<Object?>();
    _replies[id] = completer;
    _workerPort!.send([id, task, data]);
    return completer.future;
  }

  static Future<Map<String, dynamic>> decode(String raw) async {
    final result = await _run('decode', raw);
    return Map<String, dynamic>.from(result as Map);
  }

  static Future<String> encode(Map<String, dynamic> data) async => await _run('encode', data) as String;

  static Future<List<Map<String, dynamic>>> group(List<Map<String, dynamic>> items, DateTime now) async {
    final result = await _run('group', [items, now.millisecondsSinceEpoch]);
    return (result as List).map((s) => Map<String, dynamic>.from(s as Map)).toList();
  }

  static void _workerMain(SendPort toMain) {
    final inbox = ReceivePort();
    toMain.send(inbox.sendPort);
    inbox.listen((message) {
      final request = message as List;
      final id = request[0] as int;
      final task = request[1] as String;
      final data = request[2];
      Object? result;
      switch (task) {
        case 'decode':
          result = jsonDecode(data as String);
          break;
        case 'encode':
          result = jsonEncode(data);
          break;
        case 'group':
          final args = data as List;
          result = groupByDay(
            (args[0] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList(),
            DateTime.fromMillisecondsSinceEpoch(args[1] as int),
          );
          break;
      }
      toMain.send([id, result]);
    });
  }
}
