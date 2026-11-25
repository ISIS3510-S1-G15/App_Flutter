import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:app_flutter/utils/coalescing_runner.dart';

void main() {
  test('a burst of requests (like GPS updates) still delivers the newest result', () async {
    var data = 0; // what the job reads when it starts, like the current GPS position
    var jobs = 0;
    final results = <int>[];
    final runner = CoalescingRunner<int>(
      () async {
        jobs++;
        final snapshot = data;
        await Future<void>.delayed(const Duration(milliseconds: 20)); // slow isolate
        return snapshot;
      },
      onResult: results.add,
    );

    // 20 updates arrive while the first job is still running.
    // The old run counter discarded every result in this situation
    final first = runner.request();
    for (var i = 1; i <= 20; i++) {
      data = i;
      unawaited(runner.request());
    }
    await first;

    expect(results, isNotEmpty);
    expect(results.last, 20); // the screen ends with the newest data
    expect(jobs, 2); // 1 running + 1 coalesced re-run, not 21 isolates
    expect(runner.isRunning, isFalse);
  });

  test('an error is reported and the next request still runs', () async {
    var fail = true;
    final errors = <Object>[];
    final results = <String>[];
    final runner = CoalescingRunner<String>(
      () async => fail ? throw StateError('isolate crashed') : 'ok',
      onResult: results.add,
      onError: (e, _) => errors.add(e),
    );

    await runner.request();
    fail = false;
    await runner.request();

    expect(errors, hasLength(1));
    expect(results, ['ok']);
  });
}
