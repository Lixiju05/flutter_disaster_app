import 'dart:async';
import 'package:admin_server/services/isolated_request_pool.dart';
import 'package:test/test.dart';

void main() {
  test('detached exceptions are observed; capacity is released', () async {
    final pool = IsolatedRequestPool(maxConcurrent: 1);
    var handled = 0;
    await pool.dispatch(
      () async => throw StateError('test-only'),
      onUnavailable: (_) async => fail('unexpected'),
      onFailure: () async {
        handled++;
      },
    );
    await pool.close();
    expect(handled, 1);
    expect(pool.active, 0);
  });
  test('shutdown rejects new work and waits for the active request', () async {
    final pool = IsolatedRequestPool();
    final release = Completer<void>();
    var finished = false;
    await pool.dispatch(
      () => release.future,
      onUnavailable: (_) async {},
      onFailure: () async {},
    );
    final closing = pool.close().then((_) => finished = true);
    var rejected = false;
    await pool.dispatch(
      () async => fail('must not start'),
      onUnavailable: (isClosing) async {
        rejected = isClosing;
      },
      onFailure: () async {},
    );
    expect(rejected, true);
    expect(finished, false);
    release.complete();
    await closing;
    expect(pool.active, 0);
  });
  test('client failure during rejection does not escape unhandled', () async {
    final pool = IsolatedRequestPool();
    await pool.close();
    await pool.dispatch(
      () async {},
      onUnavailable: (_) async => throw StateError('disconnected'),
      onFailure: () async => throw StateError('already closed'),
    );
  });
}
