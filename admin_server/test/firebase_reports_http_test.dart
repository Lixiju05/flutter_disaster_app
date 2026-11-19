import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:admin_server/database/database_service.dart';
import 'package:admin_server/services/admin_session_store.dart';
import 'package:admin_server/services/firebase/firebase_config.dart';
import 'package:admin_server/services/firebase/firestore_health_report_reader.dart';
import 'package:admin_server/services/firebase/firestore_readonly_reader.dart';
import 'package:admin_server/services/isolated_request_pool.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';
import '../bin/admin_server.dart' as api;
import 'firebase_reports_reader_test.dart'
    show reportEnvironment, reportDocument, reportJson;
import 'report_location_test.dart' show createReportFixture;

void main() {
  late Database sql;
  late FirestoreHealthReportReader reader;
  late HttpServer server;
  late Future<void> loop;
  late HttpClient caller;
  late http.Client cloud;
  late int calls;
  late List<String> logs;
  late Future<http.Response> Function(http.Request) responder;
  setUp(() async {
    sql = sqlite3.openInMemory();
    createReportFixture(sql);
    sql.execute(
      'CREATE TABLE admins (id INTEGER PRIMARY KEY, username TEXT, password TEXT, zoneId TEXT)',
    );
    sql.execute(
      "INSERT INTO admins VALUES (7,'TEST_ADMIN','TEST_PASSWORD','OFFICE001'),(8,'OTHER','TEST_PASSWORD','OFFICE001')",
    );
    DatabaseService.instance = DatabaseService(sql);
    calls = 0;
    logs = [];
    responder = (_) async => reportJson({
      'documents': [reportDocument('synthetic-cloud-uid')],
    });
    cloud = MockClient((request) {
      calls++;
      return responder(request);
    });
    reader = FirestoreHealthReportReader(
      FirebaseConfig.fromEnvironment(reportEnvironment),
      {7},
      FirestoreReadonlyReader(cloud, timeout: const Duration(seconds: 5)),
    );
    api.firebaseReportsReader = reader;
    api.firebaseReportsRequests = IsolatedRequestPool(maxConcurrent: 4);
    api.firebaseUsersRequests = IsolatedRequestPool();
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    loop = runZoned(
      () => api.serveRequests(server),
      zoneSpecification: ZoneSpecification(
        print: (self, parent, zone, line) => logs.add(line),
      ),
    );
    caller = HttpClient()..maxConnectionsPerHost = 10;
  });
  tearDown(() async {
    caller.close(force: true);
    await server.close(force: true);
    await loop;
    reader.close();
    api.firebaseReportsReader = null;
    sql.dispose();
  });
  Future<(int, Map<String, dynamic>)> post(
    Map<String, dynamic> input, [
    String? token,
  ]) async {
    final request = await caller.postUrl(
      Uri.parse('http://127.0.0.1:${server.port}'),
    );
    request.headers.contentType = ContentType.json;
    if (token != null) request.headers.set('Authorization', 'Bearer $token');
    request.write(jsonEncode(input));
    final response = await request.close();
    if (const [
      'getFirebaseHealthReports',
      'getFirebaseSosReports',
    ].contains(input['type'])) {
      expect(response.headers.value('Cache-Control'), 'no-store');
    }
    return (
      response.statusCode,
      jsonDecode(await utf8.decoder.bind(response).join())
          as Map<String, dynamic>,
    );
  }

  Map<String, dynamic> sos(String id) => {
    'type': 'addEmergencyRequest',
    'emergencyId': id,
    'userId': 'U1',
    'userName': 'SYNTHETIC',
    'phone': '',
    'latitude': 24.123456789,
    'longitude': 121.987654321,
    'sentAt': '2026-11-17T00:00:00Z',
    'receiverAdminId': 'TEST_ADMIN',
  };

  test('HTTP login and both read-only APIs use expected envelope', () async {
    final login = await post({
      'type': 'login',
      'username': 'TEST_ADMIN',
      'password': 'TEST_PASSWORD',
    });
    final token = login.$2['token'] as String;
    for (final type in ['getFirebaseHealthReports', 'getFirebaseSosReports']) {
      final response = await post({'type': type}, token);
      expect(response.$1, 200);
      expect(response.$2['success'], true);
      expect(response.$2['source'], 'firestore');
      expect(response.$2['collection'], 'health_reports');
      expect(response.$2['data']['reports'], hasLength(1));
      expect(response.$2['data']['semantics'], 'latest_per_uid');
    }
  });
  test(
    'missing/invalid session and unapproved/deleted admins are refused before GET',
    () async {
      for (final type in [
        'getFirebaseHealthReports',
        'getFirebaseSosReports',
      ]) {
        expect((await post({'type': type})).$1, 401);
        expect((await post({'type': type}, 'invalid')).$1, 401);
        expect(
          (await post({'type': type}, api.adminSessions.create(8))).$1,
          403,
        );
      }
      final token = api.adminSessions.create(7);
      sql.execute('DELETE FROM admins WHERE id=7');
      expect((await post({'type': 'getFirebaseHealthReports'}, token)).$1, 403);
      expect(calls, 0);
    },
  );
  test('shared session store rejects expired tokens at boundary', () {
    var now = DateTime.utc(2026, 11, 17);
    final sessions = AdminSessionStore(
      now: () => now,
      lifetime: const Duration(seconds: 1),
    );
    final token = sessions.create(7);
    expect(sessions.authenticate('Bearer $token'), isNotNull);
    now = now.add(const Duration(seconds: 1));
    expect(sessions.authenticate('Bearer $token'), isNull);
  });
  test('disabled reader fails closed with zero cloud access', () async {
    api.firebaseReportsReader = null;
    for (final type in ['getFirebaseHealthReports', 'getFirebaseSosReports']) {
      final response = await post({'type': type}, api.adminSessions.create(7));
      expect(response.$1, 503);
      expect(response.$2['code'], 'FIREBASE_REPORTS_DISABLED');
    }
    expect(calls, 0);
  });
  test(
    'pagination, refresh and cleared SOS retain current-state semantics',
    () async {
      final token = api.adminSessions.create(7);
      responder = (request) async {
        expect(request.url.queryParameters['pageSize'], '1');
        return reportJson({
          'documents': [reportDocument('synthetic-cloud-uid')],
          'nextPageToken': 'cursor',
        });
      };
      expect(
        (await post({
          'type': 'getFirebaseSosReports',
          'limit': 1,
        }, token)).$2['data']['nextPageToken'],
        'cursor',
      );
      responder = (request) async {
        expect(request.url.queryParameters['pageToken'], 'cursor');
        return reportJson({
          'documents': [
            reportDocument(
              'synthetic-cloud-uid',
              fields: {
                'status': {'stringValue': '安全'},
                'sos': {'booleanValue': false},
              },
            ),
          ],
        });
      };
      final cleared = await post({
        'type': 'getFirebaseSosReports',
        'pageToken': 'cursor',
      }, token);
      expect(cleared.$2['data']['reports'], isEmpty);
      expect(cleared.$2['data']['nextPageToken'], isNull);
    },
  );
  test(
    'upstream permission failure does not leak response or fall back to SQLite',
    () async {
      responder = (_) async => reportJson({
        'error': {'message': 'PRIVATE_UPSTREAM_DETAIL'},
      }, 403);
      final response = await post({
        'type': 'getFirebaseHealthReports',
      }, api.adminSessions.create(7));
      expect(response.$1, 503);
      expect(response.$2['code'], 'FIRESTORE_PERMISSION_DENIED');
      expect(response.$2.containsKey('data'), false);
      expect(
        jsonEncode(response.$2),
        isNot(contains('PRIVATE_UPSTREAM_DETAIL')),
      );
    },
  );
  test('slow Firestore read leaves actual SOS SQLite write unqueued', () async {
    final entered = Completer<void>(), release = Completer<http.Response>();
    responder = (_) {
      entered.complete();
      return release.future;
    };
    final read = post({
      'type': 'getFirebaseHealthReports',
    }, api.adminSessions.create(7));
    await entered.future;
    try {
      expect(
        (await post(
          sos('TEST_CONCURRENT'),
        ).timeout(const Duration(seconds: 2))).$1,
        200,
      );
      expect(sql.select('SELECT * FROM emergency_requests'), hasLength(1));
      expect(release.isCompleted, false);
      expect(api.firebaseReportsRequests.active, 1);
    } finally {
      release.complete(reportJson({}));
      await read;
    }
  });
  test('account deletion during slow cloud read prevents disclosure', () async {
    final entered = Completer<void>(), release = Completer<http.Response>();
    responder = (_) {
      entered.complete();
      return release.future;
    };
    final read = post({
      'type': 'getFirebaseSosReports',
    }, api.adminSessions.create(7));
    await entered.future;
    sql.execute('DELETE FROM admins WHERE id=7');
    release.complete(
      reportJson({
        'documents': [reportDocument('synthetic-cloud-uid')],
      }),
    );
    final response = await read;
    expect(response.$1, 403);
    expect(response.$2.containsKey('data'), false);
  });
  test('bounded pool refuses excess cloud requests but accepts SOS', () async {
    api.firebaseReportsRequests = IsolatedRequestPool(maxConcurrent: 1);
    final entered = Completer<void>(), release = Completer<http.Response>();
    responder = (_) {
      entered.complete();
      return release.future;
    };
    final token = api.adminSessions.create(7);
    final first = post({'type': 'getFirebaseHealthReports'}, token);
    await entered.future;
    try {
      expect((await post({'type': 'getFirebaseSosReports'}, token)).$1, 429);
      expect((await post(sos('TEST_CAPACITY'))).$1, 200);
      expect(calls, 1);
    } finally {
      release.complete(reportJson({}));
      await first;
    }
  });
  test('timeout returns 504 and releases query capacity', () async {
    api.firebaseReportsReader = FirestoreHealthReportReader(
      reader.config,
      {7},
      FirestoreReadonlyReader(cloud, timeout: const Duration(milliseconds: 25)),
    );
    responder = (_) async => Completer<http.Response>().future;
    final response = await post({
      'type': 'getFirebaseSosReports',
    }, api.adminSessions.create(7));
    expect(response.$1, 504);
    expect(response.$2['code'], 'FIRESTORE_NETWORK_TIMEOUT');
    await Future<void>.delayed(Duration.zero);
    expect(api.firebaseReportsRequests.active, 0);
    expect((await post(sos('TEST_TIMEOUT'))).$1, 200);
  });
  test(
    'legacy SQLite routes keep their data and new cloud reads never modify local tables',
    () async {
      sql.execute(
        "INSERT INTO health_reports (uuid,reporterId,name,phone,status,reportTime) VALUES ('legacy-health','U1','LOCAL ONLY','','安全','2026-11-17T00:00:00Z')",
      );
      expect((await post(sos('LEGACY_SOS'))).$1, 200);
      final before = sql.select('SELECT total_changes() AS n').single['n'];
      final all = await post({'type': 'getAllReports'});
      expect(all.$2['data'], isA<List>());
      expect(all.$2['data'][0]['uuid'], 'legacy-health');
      final legacySos = await post({
        'type': 'getEmergencyRequestsByAdmin',
        'receiverAdminId': 'TEST_ADMIN',
      });
      expect(legacySos.$2['data'][0]['emergencyId'], 'LEGACY_SOS');
      final counts = [
        sql.select('SELECT * FROM users').length,
        sql.select('SELECT * FROM health_reports').length,
        sql.select('SELECT * FROM emergency_requests').length,
      ];
      final cloudResult = await post({
        'type': 'getFirebaseHealthReports',
      }, api.adminSessions.create(7));
      expect(
        cloudResult.$2['data']['reports'][0]['uid'],
        'synthetic-cloud-uid',
      );
      expect([
        sql.select('SELECT * FROM users').length,
        sql.select('SELECT * FROM health_reports').length,
        sql.select('SELECT * FROM emergency_requests').length,
      ], counts);
      expect(sql.select('SELECT total_changes() AS n').single['n'], before);
    },
  );
  test(
    'shutdown drains pending read before resources close and keeps SOS available',
    () async {
      final entered = Completer<void>(), release = Completer<http.Response>();
      responder = (_) {
        entered.complete();
        return release.future;
      };
      final token = api.adminSessions.create(7);
      final pending = post({'type': 'getFirebaseHealthReports'}, token);
      await entered.future;
      var drained = false;
      final drain = api.firebaseReportsRequests.close().then(
        (_) => drained = true,
      );
      await Future<void>.delayed(Duration.zero);
      try {
        expect(drained, false);
        final rejected = await post({'type': 'getFirebaseSosReports'}, token);
        expect(rejected.$1, 503);
        expect(rejected.$2['code'], 'FIREBASE_REPORTS_SHUTTING_DOWN');
        expect((await post(sos('TEST_DRAIN'))).$1, 200);
        expect(calls, 1);
      } finally {
        release.complete(reportJson({}));
        expect((await pending).$1, 200);
        await drain;
      }
      expect(drained, true);
    },
  );
  test(
    'application logs contain no UID, token, cursor, medical or report details',
    () async {
      final token = api.adminSessions.create(7);
      await post({
        'type': 'getFirebaseHealthReports',
        'pageToken': 'PRIVATE_CURSOR',
      }, token);
      final output = logs.join('\n');
      for (final private in [
        token,
        'PRIVATE_CURSOR',
        'synthetic-cloud-uid',
        'SYNTHETIC',
        'PRIVATE_MEDICAL',
        'PRIVATE_CONTACT',
      ]) {
        expect(output, isNot(contains(private)));
      }
    },
  );
}
