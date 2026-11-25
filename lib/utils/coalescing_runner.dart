// MULTITHREADING helper: runs at most ONE background job at a time.
//
// Requests that arrive while a job is running are not discarded and do not start new jobs:
// they collapse into a single re-run that reads the newest data when the current job ends.
// This fixes the old "run counter" approach, where every new request invalidated the previous
// result, so with frequent GPS updates no result ever reached the screen.
//
// Every finished job delivers its result (onResult), so the UI always gets an answer, and an
// error in one run is reported (onError) without stopping later runs.
class CoalescingRunner<T> {
  CoalescingRunner(this._job, {required this.onResult, this.onError});

  final Future<T> Function() _job;
  final void Function(T result) onResult;
  final void Function(Object error, StackTrace stack)? onError;

  bool _running = false;
  bool _pending = false;

  bool get isRunning => _running;

  Future<void> request() async {
    if (_running) {
      _pending = true; // the running job will start one more run with the latest data
      return;
    }
    _running = true;
    try {
      do {
        _pending = false;
        try {
          onResult(await _job());
        } catch (e, s) {
          onError?.call(e, s);
        }
      } while (_pending);
    } finally {
      _running = false;
    }
  }
}
