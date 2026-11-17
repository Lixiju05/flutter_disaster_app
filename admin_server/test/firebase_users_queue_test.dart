import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:admin_server/database/database_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';
import '../bin/admin_server.dart' as api;
import 'report_location_test.dart' show createReportFixture;

void main() {
  test(
    'baseline: sequential server queues SOS behind a slow Mock Firestore GET',
    () async {
      final sql = sqlite3.openInMemory();
      createReportFixture(sql);
      DatabaseService.instance = DatabaseService(sql);
      final entered = Completer<void>();
      final release = Completer<http.Response>();
      final firestore = MockClient((_) {
        entered.complete();
        return release.future;
      });
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final loop = () async {
        await for (final request in server) {
          if (request.headers.value('x-isolated-test') == 'slow') {
            await firestore.get(
              Uri.https('firestore.googleapis.com', '/mock-users'),
            );
            await api.sendJson(request, 200, {'success': true});
          } else {
            await api.handleRequest(request);
          }
        }
      }();
      final caller = HttpClient()..maxConnectionsPerHost = 4;
      Future<void> post(Map<String, Object?> body, {bool slow = false}) async {
        final request = await caller.postUrl(
          Uri.parse('http://127.0.0.1:${server.port}'),
        );
        request.headers.contentType = ContentType.json;
        if (slow) request.headers.set('x-isolated-test', 'slow');
        request.write(jsonEncode(body));
        final response = await request.close();
        await response.drain<void>();
        expect(response.statusCode, 200);
      }

      try {
        final first = post({'type': 'getFirebaseUsers'}, slow: true);
        await entered.future;
        var sosFinished = false;
        final sos = post({
          'type': 'addEmergencyRequest',
          'emergencyId': 'ISOLATED_BASELINE',
          'userId': 'U1',
          'userName': 'TEST ONLY',
          'phone': '',
          'sentAt': '2026-11-17T00:00:00Z',
        }).then((_) => sosFinished = true);
        await Future<void>.delayed(const Duration(milliseconds: 100));
        expect(sosFinished, false);
        expect(sql.select('SELECT * FROM emergency_requests'), isEmpty);
        release.complete(http.Response('{}', 200));
        await first;
        await sos;
        expect(sql.select('SELECT * FROM emergency_requests'), hasLength(1));
      } finally {
        if (!release.isCompleted) release.complete(http.Response('{}', 200));
        caller.close(force: true);
        firestore.close();
        await server.close(force: true);
        await loop;
        sql.dispose();
      }
    },
  );
}
