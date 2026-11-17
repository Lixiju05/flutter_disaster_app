import 'dart:convert';
import 'dart:io';
import 'package:admin_server/database/database_service.dart';
import '../../bin/admin_server.dart' as api;

/// Test-only worker. The parent always supplies a newly created temporary cwd.
Future<void> main() async {
  if (!Directory.current.path.contains('cares_demo_acceptance_')) {
    throw StateError(
      'This worker must run inside an isolated temporary folder',
    );
  }
  await DatabaseService.init();
  // init() starts seedAll without awaiting it; wait for its final seed here.
  var seeded = false;
  for (var attempt = 0; attempt < 200; attempt++) {
    final rows = await DatabaseService.instance.select(
      'SELECT COUNT(*) AS n FROM emergency_requests',
    );
    if ((rows.first['n'] as int) >= 4) {
      seeded = true;
      break;
    }
    await Future<void>.delayed(const Duration(milliseconds: 25));
  }
  if (!seeded) {
    throw StateError('Isolated seed initialization did not complete');
  }
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  final requests = server.listen(api.handleRequest);
  stdout.writeln('DEMO_READY:${server.port}');
  // This exits only this test worker, never an existing server process.
  await stdin.transform(utf8.decoder).transform(const LineSplitter()).first;
  await requests.cancel();
  await server.close(force: true);
  exit(0);
}
