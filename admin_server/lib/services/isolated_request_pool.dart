import 'dart:async';

/// Detaches only explicitly selected read-only routes. Existing SQLite business
/// handlers retain their sequential dispatch. All detached errors are observed.
class IsolatedRequestPool {
  final int maxConcurrent;
  final Set<Future<void>> _pending = {};
  bool _closing = false;
  IsolatedRequestPool({this.maxConcurrent = 8}) {
    if (maxConcurrent < 1) throw ArgumentError('Positive capacity required');
  }
  int get active => _pending.length;

  Future<void> dispatch(
    Future<void> Function() action, {
    required Future<void> Function(bool closing) onUnavailable,
    required Future<void> Function() onFailure,
  }) async {
    if (_closing || _pending.length >= maxConcurrent) {
      try {
        await onUnavailable(_closing);
      } catch (_) {
        try {
          await onFailure();
        } catch (_) {
          /* Disconnected caller. */
        }
      }
      return;
    }
    late Future<void> tracked;
    tracked = Future<void>.sync(action)
        .catchError((Object _, StackTrace _) async {
          try {
            await onFailure();
          } catch (_) {
            /* Client may have disconnected. */
          }
        })
        .whenComplete(() => _pending.remove(tracked));
    _pending.add(tracked);
  }

  Future<void> close() async {
    _closing = true;
    while (_pending.isNotEmpty) {
      await Future.wait(_pending.toList());
    }
  }
}
