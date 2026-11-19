import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:admin_server/database/database_service.dart';
import 'package:admin_server/services/integration_database.dart';
import '../../bin/admin_server.dart' as api;

/// Automated subprocess fixture: ephemeral loopback port, no ADC or cloud setup.
Future<void> main(List<String> args) async {
  await IntegrationDatabase.initialize(args.single, 'SYNTHETIC-TEST-PASSWORD');
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  stdout.writeln('WORKER_READY:${server.port}');
  final commands = stdin
      .transform(utf8.decoder)
      .transform(const LineSplitter())
      .listen((line) {
        if (line == 'STOP') unawaited(server.close());
      });
  try {
    await api.serveRequests(server);
  } finally {
    await commands.cancel();
    DatabaseService.instance.close();
  }
}
