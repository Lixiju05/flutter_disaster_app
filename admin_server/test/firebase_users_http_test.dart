import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:admin_server/database/database_service.dart';
import 'package:admin_server/services/firebase/firebase_config.dart';
import 'package:admin_server/services/firebase/firebase_users_service.dart';
import 'package:admin_server/services/firebase/firestore_readonly_reader.dart';
import 'package:admin_server/services/isolated_request_pool.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';
import '../bin/admin_server.dart' as api;
import 'report_location_test.dart' show createReportFixture;
import 'firebase_users_service_test.dart'
    show usersEnvironment, usersDatabase, userDocument, usersJson;

void main() {
  late Database sql;
  late HttpServer server;
  late Future<void> loop;
  late HttpClient caller;
  late FirebaseUsersService service;
  late int cloudCalls;
  late Future<http.Response> Function(http.Request) responder;
  late List<String> logs;
  setUp(() async {
    sql = sqlite3.openInMemory();
    createReportFixture(sql);
    sql.execute(
      'CREATE TABLE admins (id INTEGER PRIMARY KEY,username TEXT,password TEXT,zoneId TEXT)',
    );
    sql.execute(
      "INSERT INTO admins VALUES (7,'TEST_ADMIN','TEST_PASSWORD','OFFICE001'),(8,'TEST_OTHER','TEST_PASSWORD','OFFICE001')",
    );
    sql.execute(
      "UPDATE users SET name='SQLITE TEST',phone='TEST_ONLY',registeredAt='2026-01-01T00:00:00Z' WHERE id='U1'",
    );
    DatabaseService.instance = DatabaseService(sql);
    cloudCalls = 0;
    logs = [];
    responder = (_) async => usersJson({
      'documents': [userDocument('mock-uid')],
      'nextPageToken': 'opaque-next',
    });
    final client = MockClient((request) {
      cloudCalls++;
      return responder(request);
    });
    service = FirebaseUsersService(
      FirebaseConfig.fromEnvironment(usersEnvironment),
      FirebaseUsersPolicy({7}),
      FirestoreReadonlyReader(client, timeout: const Duration(seconds: 5)),
    );
    api.firebaseUsersService = service;
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
    service.close();
    api.firebaseUsersService = null;
    sql.dispose();
  });
  Future<(int, Map<String, dynamic>)> post(
    Map<String, dynamic> body, [
    String? token,
  ]) async {
    final request = await caller.postUrl(
      Uri.parse('http://127.0.0.1:${server.port}'),
    );
    request.headers.contentType = ContentType.json;
    if (token != null) request.headers.set('Authorization', 'Bearer $token');
    request.write(jsonEncode(body));
    final response = await request.close();
    if (body['type'] == 'getFirebaseUsers' && response.statusCode == 200) {
      expect(response.headers.value(HttpHeaders.cacheControlHeader), 'no-store');
    }
    final data =
        jsonDecode(await utf8.decoder.bind(response).join())
            as Map<String, dynamic>;
    return (response.statusCode, data);
  }

  Map<String, dynamic> sos(String id) => {
    'type': 'addEmergencyRequest',
    'emergencyId': id,
    'userId': 'U1',
    'userName': 'TEST ONLY',
    'phone': '',
    'latitude': 24.123456789,
    'longitude': 121.123456789,
    'sentAt': '2026-11-17T00:00:00Z',
  };

  test(
    'real local HTTP login/session, fixed API fields and pagination',
    () async {
      final login = await post({
        'type': 'login',
        'username': 'TEST_ADMIN',
        'password': 'TEST_PASSWORD',
      });
      expect(login.$1, 200);
      final token = login.$2['token'] as String;
      final list = await post({'type': 'getFirebaseUsers'}, token);
      expect(list.$1, 200);
      expect(list.$2['source'], 'firestore');
      expect(list.$2['data']['nextPageToken'], 'opaque-next');
      expect((list.$2['data']['users'] as List).single.keys.toSet(), {
        'uid',
        'name',
        'area',
        'registeredAt',
      });
      responder = (req) async {
        expect(req.url.queryParameters['pageToken'], 'opaque-next');
        return usersJson({});
      };
      final next = await post({
        'type': 'getFirebaseUsers',
        'pageToken': 'opaque-next',
      }, token);
      expect(next.$2['data'], {'users': [], 'nextPageToken': null});
      responder = (_) async => usersJson(userDocument('mock-uid'));
      final detail = await post({
        'type': 'getFirebaseUserById',
        'uid': 'mock-uid',
      }, token);
      expect(detail.$1, 200);
      expect(detail.$2['data']['uid'], 'mock-uid');
      expect(jsonEncode(detail.$2), isNot(contains('PRIVATE')));
      expect(logs.join(), isNot(contains(token)));
    },
  );
  test(
    'both routes reject missing/invalid Session and unapproved/deleted accounts with zero cloud reads',
    () async {
      for (final body in [
        {'type': 'getFirebaseUsers'},
        {'type': 'getFirebaseUserById', 'uid': 'PRIVATE_UID'},
      ]) {
        expect((await post(body)).$1, 401);
        expect((await post(body, 'invalid')).$1, 401);
        expect((await post(body, api.adminSessions.create(8))).$1, 403);
      }
      final token = api.adminSessions.create(7);
      sql.execute('DELETE FROM admins WHERE id=7');
      expect((await post({'type': 'getFirebaseUsers'}, token)).$1, 403);
      expect(cloudCalls, 0);
      expect(logs.join(), isNot(contains('PRIVATE_UID')));
    },
  );
  test(
    'disabled service gives 503, never falls back to SQLite users',
    () async {
      api.firebaseUsersService = null;
      final result = await post({
        'type': 'getFirebaseUsers',
      }, api.adminSessions.create(7));
      expect(result.$1, 503);
      expect(result.$2['code'], 'FIREBASE_USERS_DISABLED');
      expect(result.$2.containsKey('data'), false);
      expect(cloudCalls, 0);
    },
  );
  test(
    'invalid UID, limit, cursor and target parameters fail safely before transport',
    () async {
      final token = api.adminSessions.create(7);
      for (final body in [
        {'type': 'getFirebaseUsers', 'limit': 101},
        {'type': 'getFirebaseUsers', 'pageToken': ''},
        {'type': 'getFirebaseUsers', 'projectId': 'PRIVATE_TARGET'},
        {'type': 'getFirebaseUserById', 'uid': 'PRIVATE/UID'},
      ]) {
        expect((await post(body, token)).$1, 400);
      }
      expect(cloudCalls, 0);
      expect(logs.join(), isNot(contains('PRIVATE')));
    },
  );
  for (final status in [401, 403, 429, 500]) {
    test(
      'upstream $status is a sanitized 503, not an administrator login/permission error',
      () async {
        responder = (_) async => usersJson({
          'error': {'message': 'PRIVATE_RESPONSE'},
        }, status);
        final result = await post({
          'type': 'getFirebaseUsers',
        }, api.adminSessions.create(7));
        expect(result.$1, 503);
        expect(result.$2['source'], 'firestore');
        expect(jsonEncode(result.$2), isNot(contains('PRIVATE')));
        expect(logs.join(), isNot(contains('PRIVATE')));
      },
    );
  }
  test(
    'HTTP missing document is 404 and does not read a SQLite matching user',
    () async {
      responder = (req) async => req.url.path == '/v1/$usersDatabase'
          ? usersJson({'name': usersDatabase})
          : usersJson({}, 404);
      final result = await post({
        'type': 'getFirebaseUserById',
        'uid': 'U1',
      }, api.adminSessions.create(7));
      expect(result.$1, 404);
      expect(result.$2['code'], 'FIREBASE_USER_NOT_FOUND');
      expect(
        sql.select('SELECT * FROM users WHERE id=?', ['U1']),
        hasLength(1),
      );
    },
  );
  test(
    'production dispatcher lets SOS commit while Mock Firestore is still pending',
    () async {
      final entered = Completer<void>(), release = Completer<http.Response>();
      responder = (_) {
        entered.complete();
        return release.future;
      };
      final first = post({
        'type': 'getFirebaseUsers',
      }, api.adminSessions.create(7));
      await entered.future;
      try {
        final saved = await post(
          sos('ISOLATED_CONCURRENT'),
        ).timeout(const Duration(seconds: 2));
        expect(saved.$1, 200);
        expect(release.isCompleted, false);
        final row = sql.select('SELECT * FROM emergency_requests').single;
        expect(row['latitude'], 24.123456789);
        expect(row['sentAt'], '2026-11-17T00:00:00.000Z');
        expect(api.firebaseUsersRequests.active, 1);
      } finally {
        release.complete(usersJson({}));
        await first;
      }
    },
  );
  test('SOS statement rollback remains atomic while a read is pending', () async {
    sql.execute(
      "CREATE TRIGGER reject_sos BEFORE INSERT ON emergency_requests BEGIN UPDATE users SET area='CORRUPTED'; SELECT RAISE(ABORT,'isolated failure'); END",
    );
    final before = sql.select('SELECT area FROM users').single['area'];
    final entered = Completer<void>(), release = Completer<http.Response>();
    responder = (_) {
      entered.complete();
      return release.future;
    };
    final read = post({
      'type': 'getFirebaseUsers',
    }, api.adminSessions.create(7));
    await entered.future;
    try {
      expect((await post(sos('ISOLATED_ROLLBACK'))).$1, 400);
      expect(sql.select('SELECT * FROM emergency_requests'), isEmpty);
      expect(sql.select('SELECT area FROM users').single['area'], before);
    } finally {
      release.complete(usersJson({}));
      await read;
    }
  });
  test('account deletion during a slow read blocks data release', () async {
    final entered = Completer<void>(), release = Completer<http.Response>();
    responder = (_) {
      entered.complete();
      return release.future;
    };
    final read = post({
      'type': 'getFirebaseUsers',
    }, api.adminSessions.create(7));
    await entered.future;
    sql.execute('DELETE FROM admins WHERE id=7');
    release.complete(
      usersJson({
        'documents': [userDocument('private-read')],
      }),
    );
    final result = await read;
    expect(result.$1, 403);
    expect(result.$2.containsKey('data'), false);
  });
  test('capacity backpressure rejects excess reads but not SOS', () async {
    api.firebaseUsersRequests = IsolatedRequestPool(maxConcurrent: 1);
    final entered = Completer<void>(), release = Completer<http.Response>();
    responder = (_) {
      entered.complete();
      return release.future;
    };
    final token = api.adminSessions.create(7);
    final first = post({'type': 'getFirebaseUsers'}, token);
    await entered.future;
    try {
      final rejected = await post({'type': 'getFirebaseUsers'}, token);
      expect(rejected.$1, 429);
      expect(rejected.$2['code'], 'FIREBASE_USERS_BUSY');
      expect((await post(sos('ISOLATED_CAPACITY'))).$1, 200);
      expect(cloudCalls, 1);
    } finally {
      release.complete(usersJson({}));
      await first;
    }
  });
  test(
    'timeout returns 504 and releases slot; subsequent SOS still works',
    () async {
      api.firebaseUsersService = FirebaseUsersService(
        service.config,
        service.policy,
        FirestoreReadonlyReader(
          service.reader.client,
          timeout: const Duration(milliseconds: 20),
        ),
      );
      responder = (_) async => Completer<http.Response>().future;
      final result = await post({
        'type': 'getFirebaseUsers',
      }, api.adminSessions.create(7));
      expect(result.$1, 504);
      expect(result.$2['code'], 'FIRESTORE_NETWORK_TIMEOUT');
      await Future<void>.delayed(Duration.zero);
      expect(api.firebaseUsersRequests.active, 0);
      expect((await post(sos('ISOLATED_TIMEOUT'))).$1, 200);
    },
  );
  test(
    'old SQLite user routes retain shape, source and values; new reads do not write SQLite',
    () async {
      List<Map<String, Object?>> snapshot() => sql
          .select('SELECT * FROM users')
          .map(Map<String, Object?>.from)
          .toList();
      final before = snapshot();
      final all = await post({'type': 'getAllUsers'});
      expect(all.$1, 200);
      expect(all.$2['data'], isA<List>());
      final row = (all.$2['data'] as List).single as Map;
      expect(row['id'], 'U1');
      expect(row['name'], 'SQLITE TEST');
      expect(row.keys.toSet(), {
        'id',
        'name',
        'phone',
        'area',
        'emergencyContactName',
        'emergencyContactPhone',
        'emergencyContactRelation',
        'bloodType',
        'medicalInfo',
        'registeredAt',
      });
      final single = await post({'type': 'getUser', 'id': 'U1'});
      expect(single.$2['data'], row);
      final search = await post({'type': 'searchUsers', 'keyword': 'SQLITE'});
      expect(search.$2['data'], [row]);
      expect((await post({'type': 'getUser', 'id': 'no-match'})).$1, 404);
      expect(
        (await post({'type': 'searchUsers', 'keyword': 'no-match'})).$2['data'],
        isEmpty,
      );
      expect(
        (await post({
          'type': 'getFirebaseUsers',
        }, api.adminSessions.create(7))).$1,
        200,
      );
      expect(snapshot(), before);
      expect(sql.select('PRAGMA integrity_check').single.values.single, 'ok');
    },
  );

  test(
    'isolated acceptance allowlist exposes no SQLite or write routes',
    () async {
      final restricted = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final running = api.serveRequests(
        restricted,
        allowedTypes: const {
          'login',
          'getFirebaseUsers',
          'getFirebaseUserById',
        },
      );
      try {
        for (final type in [
          'getAllUsers',
          'addEmergencyRequest',
          'sendNotification',
        ]) {
          final request = await caller.postUrl(
            Uri.parse('http://127.0.0.1:${restricted.port}'),
          );
          request.headers.contentType = ContentType.json;
          request.write(jsonEncode({'type': type}));
          final response = await request.close();
          expect(response.statusCode, 404);
          await response.drain<void>();
        }
        expect(sql.select('SELECT * FROM emergency_requests'), isEmpty);
        expect(cloudCalls, 0);
      } finally {
        await restricted.close(force: true);
        await running;
      }
    },
  );

  test(
    'live acceptance launcher is disabled without explicit opt-in',
    () async {
      final root = Directory.current.absolute.path;
      final sdk = File(Platform.resolvedExecutable).parent.path;
      final result = await Process.run(
        '$sdk/${Platform.isWindows ? 'dart.exe' : 'dart'}',
        [
          '--packages=$root/.dart_tool/package_config.json',
          '$root/bin/firebase_users_readonly_server.dart',
        ],
        environment: {'FIREBASE_USERS_READONLY_TEST_SERVER': 'false'},
      );
      expect(result.exitCode, 2);
      expect(result.stdout, '');
      expect(result.stderr, contains('READONLY_TEST_SERVER_DISABLED'));
    },
  );
}
