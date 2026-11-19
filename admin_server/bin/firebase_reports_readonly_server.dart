import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:sqlite3/sqlite3.dart';
import 'package:admin_server/database/database_service.dart';
import 'package:admin_server/services/firebase/firebase_config.dart';
import 'package:admin_server/services/firebase/firebase_connection.dart';
import 'package:admin_server/services/firebase/firebase_reports_bootstrap.dart';
import 'admin_server.dart' as api;

/// Explicit manual read-only acceptance host, never calls production main/init.
Future<void> main() async {
  final env = Platform.environment;
  if (env['FIREBASE_REPORTS_READONLY_TEST_SERVER'] != 'true') {
    stderr.writeln('REPORTS_READONLY_TEST_SERVER_DISABLED');
    exitCode = 2;
    return;
  }
  final password = env['FIREBASE_REPORTS_TEST_PASSWORD'];
  final port = int.tryParse(env['FIREBASE_REPORTS_TEST_PORT'] ?? '8084');
  if (password == null ||
      password.length < 16 ||
      port == null ||
      port < 0 ||
      port > 65535) {
    stderr.writeln('REPORTS_READONLY_TEST_CONFIGURATION');
    exitCode = 2;
    return;
  }
  Database? sql;
  HttpServer? server;
  StreamSubscription<String>? commands;
  try {
    api.firebaseReportsReader =
        await createFirebaseReportsReaderFromEnvironment();
    if (api.firebaseReportsReader == null ||
        !api.firebaseReportsReader!.adminIds.contains(1)) {
      throw const FirebaseConfigurationException(
        'REPORTS_TEST_ADMIN_REQUIRED',
        'Test admin 1 must be explicitly approved',
      );
    }
    sql = sqlite3.openInMemory();
    sql.execute(
      'CREATE TABLE admins (id INTEGER PRIMARY KEY,username TEXT,password TEXT,zoneId TEXT)',
    );
    sql.execute(
      "INSERT INTO admins VALUES (1,'firebase_reports_test',?,'OFFICE001')",
      [password],
    );
    DatabaseService.instance = DatabaseService(sql);
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
    final listening = server;
    final boundPort = server.port;
    stdout.writeln('ISOLATED_FIREBASE_REPORTS_API http://127.0.0.1:$boundPort');
    final project = api.firebaseReportsReader!.config.projectId;
    final database = api.firebaseReportsReader!.config.databaseId;
    stdout.writeln(
      'Backend target: $project / $database (does not verify the APK target)',
    );
    stdout.writeln(
      'GET-only live ADC. Memory-only admin fixture. Type STOP to drain and close.',
    );
    commands = stdin
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
          if (line == 'STOP') unawaited(listening.close(force: true));
        });
    await api.serveRequests(
      server,
      allowedTypes: const {
        'login',
        'getFirebaseHealthReports',
        'getFirebaseSosReports',
      },
    );
  } on FirebaseConfigurationException catch (error) {
    stderr.writeln(error.code);
    exitCode = 1;
  } on FirebaseConnectionException catch (error) {
    stderr.writeln(error.code);
    exitCode = 1;
  } catch (_) {
    stderr.writeln('REPORTS_READONLY_TEST_SERVER_UNAVAILABLE');
    exitCode = 1;
  } finally {
    await commands?.cancel();
    await api.firebaseReportsRequests.close();
    api.firebaseReportsReader?.close();
    await server?.close(force: true);
    sql?.dispose();
  }
}
