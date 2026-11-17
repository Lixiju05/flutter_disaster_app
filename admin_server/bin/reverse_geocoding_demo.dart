import 'dart:io';
import 'package:sqlite3/sqlite3.dart';
import 'package:admin_server/database/database_service.dart';
import 'package:admin_server/services/reverse_geocoding_service.dart';
import 'admin_server.dart' as api;

/// Explicit isolated DEMO launcher. Never invokes DatabaseService.init(),
/// seedAll(), Firebase initialization or opens the project's admin.db.
Future<void> main() async {
  final directory = await Directory.systemTemp.createTemp(
    'hucares_geocoding_demo_records_',
  );
  final sql = sqlite3.open('${directory.path}/demo.sqlite');
  sql.execute('''CREATE TABLE admins (id INTEGER PRIMARY KEY,
    username TEXT,password TEXT,zoneId TEXT)''');
  sql.execute(
    "INSERT INTO admins VALUES (1,'demo_admin','DemoOnly123!','OFFICE001')",
  );
  sql.execute(
    '''CREATE TABLE emergency_requests (emergencyId TEXT PRIMARY KEY,
    userId TEXT,userName TEXT,phone TEXT,latitude REAL,longitude REAL,
    address TEXT,status TEXT,receiverAdminId TEXT,hopCount INTEGER,sentAt TEXT,receivedAt TEXT)''',
  );
  // Synthetic report at a public landmark, with NO stored address. Lookup
  // must return a real provider result or an honest error; never a fake address.
  final time = DateTime.now().toUtc().toIso8601String();
  sql.execute(
    "INSERT INTO emergency_requests VALUES ('DEMO_SOS_001','DEMO_USER','DEMO ONLY','',25.033964,121.564468,NULL,'active','demo_admin',0,?,?)",
    [time, time],
  );
  DatabaseService.instance = DatabaseService(sql);
  try {
    api.reverseGeocodingService = createReverseGeocodingService();
  } catch (_) {
    stderr.writeln(
      'Invalid reverse geocoding DEMO configuration. No external lookup enabled.',
    );
  }
  final port =
      int.tryParse(Platform.environment['DEMO_PORT'] ?? '8081') ?? 8081;
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
  stdout.writeln('Isolated DEMO: http://127.0.0.1:${server.port}');
  stdout.writeln('Records: ${directory.path}/demo.sqlite');
  stdout.writeln(
    'DEMO login: demo_admin / DemoOnly123! (isolated loopback server only)',
  );
  stdout.writeln(
    'Reverse geocoding: ${api.reverseGeocodingService == null ? 'DISABLED' : 'PUBLIC DEMO SITES ONLY'}',
  );
  await for (final request in server) {
    // Parallel HTTP handling is necessary for in-flight lookup coalescing.
    api.handleRequest(request);
  }
}
