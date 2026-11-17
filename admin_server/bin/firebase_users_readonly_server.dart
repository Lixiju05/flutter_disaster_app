import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:sqlite3/sqlite3.dart';
import 'package:admin_server/database/database_service.dart';
import 'package:admin_server/services/firebase/firebase_config.dart';
import 'package:admin_server/services/firebase/firebase_connection.dart';
import 'package:admin_server/services/firebase/firebase_users_bootstrap.dart';
import 'admin_server.dart' as api;

/// Manual live-ADC acceptance harness, never started by normal tests.
/// SQLite is memory-only; only login and the two read routes are exposed.
Future<void> main() async {
  final env = Platform.environment;
  if (env['FIREBASE_USERS_READONLY_TEST_SERVER'] != 'true') {
    stderr.writeln('READONLY_TEST_SERVER_DISABLED');
    exitCode = 2;
    return;
  }
  final password = env['FIREBASE_USERS_TEST_PASSWORD'];
  final port = int.tryParse(env['FIREBASE_USERS_TEST_PORT'] ?? '8082');
  if (password == null ||
      password.length < 12 ||
      port == null ||
      port < 0 ||
      port > 65535) {
    stderr.writeln('READONLY_TEST_SERVER_CONFIGURATION');
    exitCode = 2;
    return;
  }
  Database? sql;
  HttpServer? server;
  StreamSubscription<String>? commands;
  try {
    api.firebaseUsersService =
        await createFirebaseUsersServiceFromEnvironment();
    if (api.firebaseUsersService == null ||
        !api.firebaseUsersService!.policy.adminIds.contains(1)) {
      throw const FirebaseConfigurationException(
        'READONLY_TEST_ADMIN_REQUIRED',
        'This isolated harness requires explicit permission for test admin 1',
      );
    }
    sql = sqlite3.openInMemory();
    sql.execute(
      'CREATE TABLE admins (id INTEGER PRIMARY KEY,username TEXT,password TEXT,zoneId TEXT)',
    );
    sql.execute(
      "INSERT INTO admins VALUES (1,'firebase_readonly_test',?,'OFFICE001')",
      [password],
    );
    DatabaseService.instance = DatabaseService(sql);
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
    stdout.writeln(
      'ISOLATED_FIREBASE_USERS_API: http://127.0.0.1:${server.port}',
    );
    stdout.writeln(
      'Memory-only SQLite. Type STOP to drain pending reads and close.',
    );
    final listening = server;
    commands = stdin
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
          if (line == 'STOP') unawaited(listening.close(force: true));
        });
    await api.serveRequests(
      server,
      allowedTypes: const {'login', 'getFirebaseUsers', 'getFirebaseUserById'},
    );
  } on FirebaseConfigurationException catch (error) {
    stderr.writeln(error.code);
    exitCode = 1;
  } on FirebaseConnectionException catch (error) {
    stderr.writeln(error.code);
    exitCode = 1;
  } catch (_) {
    stderr.writeln('READONLY_TEST_SERVER_UNAVAILABLE');
    exitCode = 1;
  } finally {
    await commands?.cancel();
    await api.firebaseUsersRequests.close();
    api.firebaseUsersService?.close();
    await server?.close(force: true);
    sql?.dispose();
  }
}
