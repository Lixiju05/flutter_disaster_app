import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:admin_server/database/database_service.dart';
import 'package:admin_server/services/integration_database.dart';
import 'package:admin_server/services/firebase/firebase_config.dart';
import 'package:admin_server/services/firebase/firestore_health_report_reader.dart';
import 'package:admin_server/services/firebase/firestore_readonly_reader.dart';
import 'package:admin_server/services/isolated_request_pool.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import '../bin/admin_server.dart' as api;
import 'firebase_reports_reader_test.dart'
    show reportEnvironment, reportDocument, reportJson;

void main() {
  late Directory root;
  late HttpServer server;
  late Future<void> serving;
  late HttpClient caller;
  late String token;
  late int cloudCalls;
  late Future<http.Response> Function(http.Request) cloudResponse;
  Future<(int, Map<String, dynamic>)> post(
    String type, {
    Map<String, dynamic> body = const {},
    String? bearer,
  }) async {
    final request = await caller.postUrl(
      Uri.parse('http://127.0.0.1:${server.port}'),
    );
    request.headers.contentType = ContentType.json;
    request.headers.set('Authorization', 'Bearer ${bearer ?? token}');
    request.write(jsonEncode({'type': type, ...body}));
    final response = await request.close();
    return (
      response.statusCode,
      jsonDecode(await utf8.decoder.bind(response).join())
          as Map<String, dynamic>,
    );
  }

  setUp(() async {
    root = Directory.systemTemp.createTempSync(IntegrationDatabase.marker);
    await IntegrationDatabase.initialize(root.path, 'SYNTHETIC-TEST-PASSWORD');
    await DatabaseService.instance.execute(
      "INSERT INTO admins VALUES(2,'unapproved','SYNTHETIC-TEST-PASSWORD','OFFICE001')",
    );
    cloudCalls = 0;
    cloudResponse = (_) async => reportJson({
      'documents': [reportDocument('SYNTHETIC-UID')],
    });
    api.firebaseReportsReader = FirestoreHealthReportReader(
      FirebaseConfig.fromEnvironment(reportEnvironment),
      {1},
      FirestoreReadonlyReader(
        MockClient((request) {
          expect(request.method, 'GET');
          cloudCalls++;
          return cloudResponse(request);
        }),
        timeout: const Duration(milliseconds: 100),
      ),
    );
    api.firebaseReportsRequests = IsolatedRequestPool(maxConcurrent: 4);
    api.firebaseUsersRequests = IsolatedRequestPool();
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    serving = api.serveRequests(server);
    caller = HttpClient()..maxConnectionsPerHost = 10;
    token = '';
    final login = await post(
      'login',
      body: {
        'username': 'integration_test',
        'password': 'SYNTHETIC-TEST-PASSWORD',
      },
    );
    expect(login.$1, 200);
    token = login.$2['token'] as String;
  });
  tearDown(() async {
    caller.close(force: true);
    await server.close(force: true);
    await serving;
    api.firebaseReportsReader?.close();
    api.firebaseReportsReader = null;
    DatabaseService.instance.close();
    // Only the verified freshly-created test directory is removed.
    expect(p.basename(root.path), startsWith(IntegrationDatabase.marker));
    root.deleteSync(recursive: true);
  });

  test(
    'same login accesses SQLite dashboard routes and both Firestore routes',
    () async {
      for (final type in [
        'getAllUsers',
        'getInventory',
        'getSupplyRequestDetails',
        'getEmergencyRequestsByAdmin',
        'getFirebaseHealthReports',
        'getFirebaseSosReports',
      ]) {
        final response = await post(
          type,
          body: type == 'getEmergencyRequestsByAdmin'
              ? {'receiverAdminId': 'integration_test'}
              : {},
        );
        expect(response.$1, 200, reason: type);
        expect(response.$2['success'], true, reason: type);
      }
      expect(cloudCalls, 2);
      final status = await post('getServiceStatus');
      expect(status.$2['data'], containsPair('sqlite', true));
      expect(status.$2['data'], containsPair('firestoreReports', true));
      expect(jsonEncode(status.$2), isNot(contains(root.path)));
    },
  );
  test('inventory HTTP writes persist only in validated file', () async {
    final result = await post('updateStock', body: {'itemId': 1, 'qty': 3});
    expect(result.$1, 200);
    final rows = await DatabaseService.instance.select(
      "SELECT stockQty FROM station_inventory WHERE stationId='OFFICE001' AND itemId=1",
    );
    expect(rows.single['stockQty'], 23);
    final databases = await DatabaseService.instance.select(
      'PRAGMA database_list',
    );
    expect(databases.single['file'], p.join(root.path, 'integration.sqlite'));
    expect(File(p.join(root.path, 'integration.sqlite')).existsSync(), true);
  });
  test(
    'SQLite demand and SOS inserts are visible through the same local dashboard routes',
    () async {
      final demand = await post(
        'addSupplyRequest',
        body: {
          'requestId': 'INTEGRATION_REQ',
          'userId': 'INTEGRATION_USER',
          'itemId': 1,
          'qty': 2,
          'receiverAdminId': 'integration_test',
        },
      );
      expect(demand.$1, 200);
      final requests = await post('getSupplyRequestDetails');
      expect((requests.$2['data'] as List).single['stationId'], 'OFFICE001');
      final sos = await post(
        'addEmergencyRequest',
        body: {
          'emergencyId': 'INTEGRATION_SOS',
          'userId': 'INTEGRATION_USER',
          'userName': 'SYNTHETIC TEST USER',
          'phone': '',
          'sentAt': '2026-01-01T00:00:00Z',
          'receiverAdminId': 'integration_test',
        },
      );
      expect(sos.$1, 200);
      final events = await post(
        'getEmergencyRequestsByAdmin',
        body: {'receiverAdminId': 'integration_test'},
      );
      expect((events.$2['data'] as List), hasLength(1));
      expect(cloudCalls, 0);
    },
  );
  test(
    'Firestore 403, upstream error, timeout and disabled do not break SQLite',
    () async {
      for (final status in [403, 500]) {
        cloudResponse = (_) async => http.Response('{}', status);
        expect((await post('getFirebaseSosReports')).$1, isNot(200));
        expect((await post('getInventory')).$1, 200);
      }
      cloudResponse = (_) async {
        await Future<void>.delayed(const Duration(milliseconds: 150));
        return reportJson({});
      };
      expect((await post('getFirebaseSosReports')).$1, isNot(200));
      api.firebaseReportsReader?.close();
      api.firebaseReportsReader = null;
      expect((await post('getFirebaseSosReports')).$1, 503);
      expect((await post('getAllUsers')).$1, 200);
    },
  );
  test(
    'unapproved admin and foreign session rejected before cloud access',
    () async {
      expect(
        (await post(
          'getFirebaseSosReports',
          bearer: api.adminSessions.create(2),
        )).$1,
        403,
      );
      expect(
        (await post('getFirebaseSosReports', bearer: 'foreign-session')).$1,
        401,
      );
      expect(cloudCalls, 0);
    },
  );
  test('slow cloud request does not block local SOS route', () async {
    final entered = Completer<void>();
    final release = Completer<http.Response>();
    cloudResponse = (_) {
      entered.complete();
      return release.future;
    };
    final slow = post('getFirebaseSosReports');
    await entered.future;
    final local = await post(
      'getEmergencyRequestsByAdmin',
      body: {'receiverAdminId': 'integration_test'},
    );
    expect(local.$1, 200);
    release.complete(reportJson({'documents': []}));
    await slow;
  });
  test(
    'path guard rejects relative, traversal, outside, unowned and linked paths',
    () {
      for (final path in [
        'data',
        p.join(root.path, '..', 'data'),
        Directory.current.path,
        p.join(root.path, 'nested'),
      ]) {
        expect(() => IntegrationDatabase.validate(path), throwsStateError);
      }
      final other = Directory.systemTemp.createTempSync(
        IntegrationDatabase.marker,
      );
      try {
        File(
          p.join(other.path, 'integration.sqlite'),
        ).writeAsStringSync('unowned');
        expect(
          () => IntegrationDatabase.validate(other.path),
          throwsStateError,
        );
      } finally {
        other.deleteSync(recursive: true);
      }
      final alias = '${root.path}-alias';
      if (Platform.isWindows) {
        final made = Process.runSync('cmd', [
          '/c',
          'mklink',
          '/J',
          alias,
          root.path,
        ]);
        expect(made.exitCode, 0);
        try {
          expect(() => IntegrationDatabase.validate(alias), throwsStateError);
        } finally {
          Link(alias).deleteSync();
        }
      } else {
        Link(alias).createSync(root.path);
        try {
          expect(() => IntegrationDatabase.validate(alias), throwsStateError);
        } finally {
          Link(alias).deleteSync();
        }
      }
    },
  );
  test(
    'hard linked database is rejected even with copied ownership marker',
    () {
      final other = Directory.systemTemp.createTempSync(
        IntegrationDatabase.marker,
      );
      final alias = p.join(other.path, 'integration.sqlite');
      try {
        if (Platform.isWindows) {
          expect(
            Process.runSync('fsutil', [
              'hardlink',
              'create',
              alias,
              p.join(root.path, 'integration.sqlite'),
            ]).exitCode,
            0,
          );
        } else {
          expect(
            Process.runSync('ln', [
              p.join(root.path, 'integration.sqlite'),
              alias,
            ]).exitCode,
            0,
          );
        }
        File(
          p.join(other.path, '.hucares-test-database'),
        ).writeAsStringSync(alias);
        expect(
          () => IntegrationDatabase.validate(other.path),
          throwsStateError,
        );
      } finally {
        other.deleteSync(recursive: true);
      }
    },
  );
  test(
    'restricted host capability probe never claims SQLite routes are available',
    () async {
      await server.close(force: true);
      await serving;
      api.firebaseReportsRequests = IsolatedRequestPool();
      api.firebaseUsersRequests = IsolatedRequestPool();
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      serving = api.serveRequests(
        server,
        allowedTypes: {'login', 'getFirebaseSosReports'},
      );
      final response = await post('getServiceStatus');
      expect(response.$2['data']['http'], true);
      expect(response.$2['data']['sqlite'], false);
      expect(
        response.$2['data']['firestoreReportsState'],
        'configured_not_verified',
      );
      expect((await post('getInventory')).$1, 404);
      expect((await post('getFirebaseSosReports')).$1, 200);
    },
  );

  test(
    'real subprocess restart preserves file inventory and invalidates previous session',
    () async {
      final isolated = Directory.systemTemp.createTempSync(
        IntegrationDatabase.marker,
      );
      Process? worker;
      final httpClient = HttpClient();
      Future<int> start() async {
        worker = await Process.start(Platform.resolvedExecutable, [
          'run',
          'test/support/integration_worker.dart',
          isolated.path,
        ]);
        // Drain diagnostics without exposing request data or credentials.
        worker!.stderr.drain<void>();
        final ready = Completer<String>();
        worker!.stdout
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .listen((line) {
              if (line.startsWith('WORKER_READY:') && !ready.isCompleted) {
                ready.complete(line);
              }
            });
        final line = await ready.future.timeout(const Duration(seconds: 30));
        return int.parse(line.split(':').last);
      }

      Future<Map<String, dynamic>> call(
        int port,
        Map<String, dynamic> body, [
        String? bearer,
      ]) async {
        final request = await httpClient.postUrl(
          Uri.parse('http://127.0.0.1:$port'),
        );
        request.headers.contentType = ContentType.json;
        if (bearer != null) {
          request.headers.set('Authorization', 'Bearer $bearer');
        }
        request.write(jsonEncode(body));
        final response = await request.close();
        return jsonDecode(await utf8.decoder.bind(response).join())
            as Map<String, dynamic>;
      }

      Future<void> stop() async {
        worker!.stdin.writeln('STOP');
        expect(await worker!.exitCode, 0);
      }

      try {
        var port = await start();
        final login = await call(port, {
          'type': 'login',
          'username': 'integration_test',
          'password': 'SYNTHETIC-TEST-PASSWORD',
        });
        final previous = login['token'] as String;
        expect(
          (await call(port, {
            'type': 'updateStock',
            'itemId': 1,
            'qty': 3,
          }))['success'],
          true,
        );
        await stop();
        port = await start();
        final rejected = await call(port, {
          'type': 'getFirebaseSosReports',
        }, previous);
        expect(rejected['success'], false);
        expect(rejected['code'], 'ADMIN_SESSION_REQUIRED');
        final inventory = await call(port, {'type': 'getInventory'});
        expect((inventory['data'] as List).single['stockQty'], 23);
        await stop();
        worker = null;
      } finally {
        if (worker != null) {
          worker!.stdin.writeln('STOP');
          await worker!.exitCode;
        }
        httpClient.close(force: true);
        isolated.deleteSync(recursive: true);
      }
    },
    timeout: const Timeout(Duration(seconds: 80)),
  );
}
