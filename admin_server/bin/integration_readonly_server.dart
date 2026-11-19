import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:admin_server/database/database_service.dart';
import 'package:admin_server/services/integration_database.dart';
import 'package:admin_server/services/firebase/firebase_reports_bootstrap.dart';
import 'package:admin_server/services/firebase/firebase_config.dart';
import 'package:admin_server/services/firebase/firebase_connection.dart';
import 'admin_server.dart' as api;

/// Manual acceptance host. Never invokes production main or notification bootstrap.
Future<void> main() async {
  final env = Platform.environment;
  if (env['INTEGRATION_TEST_SERVER'] != 'true' ||
      env['FIREBASE_READ_ONLY'] != 'true' ||
      env['NOTIFICATIONS_ENABLED'] != 'false') {
    stderr.writeln('INTEGRATION_EXPLICIT_SAFE_FLAGS_REQUIRED');
    exitCode = 2;
    return;
  }
  HttpServer? server;
  StreamSubscription<String>? commands;
  bool opened = false;
  try {
    final root = env['INTEGRATION_TEST_DIRECTORY'] ?? '';
    final path = IntegrationDatabase.validate(root);
    stdout.writeln('ISOLATED_SQLITE: $path');
    await IntegrationDatabase.initialize(
      root,
      env['INTEGRATION_TEST_PASSWORD'] ?? '',
    );
    opened = true;
    api.firebaseReportsReader =
        await createFirebaseReportsReaderFromEnvironment();
    if (env['FIREBASE_REPORTS_ENABLED'] == 'true' &&
        api.firebaseReportsReader?.adminIds.contains(1) != true) {
      throw StateError('INTEGRATION_TEST_ADMIN_1_MUST_BE_APPROVED');
    }
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 8085);
    final listening = server;
    stdout.writeln(
      'READY http://127.0.0.1:8085 — synthetic SQLite + GET-only Firestore',
    );
    stdout.writeln('Login: integration_test (admin ID 1). Type STOP to drain.');
    commands = stdin
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
          if (line == 'STOP') unawaited(listening.close());
        });
    await api.serveRequests(server);
  } on FirebaseConfigurationException catch (error) {
    stderr.writeln(error.code);
    exitCode = 1;
  } on FirebaseConnectionException catch (error) {
    stderr.writeln(error.code);
    exitCode = 1;
  } on SocketException {
    stderr.writeln('INTEGRATION_PORT_UNAVAILABLE');
    exitCode = 1;
  } on StateError catch (error) {
    final message = error.message.toString();
    stderr.writeln(
      RegExp(r'^INTEGRATION_[A-Z0-9_]+$').hasMatch(message)
          ? message
          : 'INTEGRATION_START_OR_RUN_FAILED',
    );
    exitCode = 1;
  } catch (_) {
    stderr.writeln(
      'INTEGRATION_START_OR_RUN_FAILED (check safe flags, path, password, ADC and port)',
    );
    exitCode = 1;
  } finally {
    await commands?.cancel();
    await api.firebaseReportsRequests.close();
    await api.firebaseUsersRequests.close();
    api.firebaseReportsReader?.close();
    await server?.close(force: true);
    if (opened) DatabaseService.instance.close();
  }
}
