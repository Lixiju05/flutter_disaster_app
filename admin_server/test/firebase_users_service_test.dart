import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:admin_server/services/firebase/firebase_config.dart';
import 'package:admin_server/services/firebase/firebase_connection.dart';
import 'package:admin_server/services/firebase/firebase_users_bootstrap.dart';
import 'package:admin_server/services/firebase/firebase_users_service.dart';
import 'package:admin_server/services/firebase/firestore_readonly_reader.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

const usersEnvironment = {
  'FIREBASE_ENABLED': 'true',
  'FIREBASE_PROJECT_ID': 'hucares-firebase-test',
  'FIREBASE_USERS_ENABLED': 'true',
  'FIREBASE_USERS_ADMIN_IDS': '7',
  'FIREBASE_USERS_SCOPE': 'project',
};
const usersDatabase = 'projects/hucares-firebase-test/databases/(default)';
Map<String, Object?> userDocument(String uid, {Map<String, Object?>? fields}) =>
    {
      'name': '$usersDatabase/documents/users/$uid',
      'fields':
          fields ??
          {
            'id': {'stringValue': 'NOT_THE_UID'},
            'name': {'stringValue': 'MOCK ONLY'},
            'area': {'stringValue': 'MOCK AREA'},
            'registeredAt': {'timestampValue': '2026-11-17T08:00:00+08:00'},
            'email': {'stringValue': 'PRIVATE_CONTACT'},
            'phone': {'stringValue': 'PRIVATE_CONTACT'},
            'medicalInfo': {'stringValue': 'PRIVATE_MEDICAL'},
            'bloodType': {'stringValue': 'PRIVATE_MEDICAL'},
            'emergencyContactName': {'stringValue': 'PRIVATE_CONTACT'},
          },
    };
http.Response usersJson(Object data, [int status = 200]) => http.Response(
  jsonEncode(data),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

void main() {
  late int calls;
  late MockClient client;
  late FirebaseUsersService service;
  late Future<http.Response> Function(http.Request) responder;
  Matcher userError(int status, [String? code]) => isA<FirebaseUsersException>()
      .having((e) => e.statusCode, 'status', status)
      .having((e) => code == null || e.code == code, 'code matches', true);
  setUp(() {
    calls = 0;
    responder = (_) async => usersJson({
      'documents': [userDocument('mock-uid')],
    });
    client = MockClient((request) {
      calls++;
      return responder(request);
    });
    service = FirebaseUsersService(
      FirebaseConfig.fromEnvironment(usersEnvironment),
      FirebaseUsersPolicy({7}),
      FirestoreReadonlyReader(client),
    );
  });
  tearDown(() => service.close());

  test(
    'Mock list GET uses fixed target, mask, ordering and one upstream page',
    () async {
      responder = (req) async {
        expect(req.method, 'GET');
        expect(req.followRedirects, false);
        expect(req.url.host, 'firestore.googleapis.com');
        expect(req.url.path, '/v1/$usersDatabase/documents/users');
        expect(req.url.queryParameters['pageSize'], '25');
        expect(req.url.queryParameters['orderBy'], '__name__ asc');
        expect(
          req.url.queryParametersAll['mask.fieldPaths'],
          FirebaseUsersService.fields,
        );
        return usersJson({
          'documents': [userDocument('mock-uid')],
          'nextPageToken': 'opaque-next',
        });
      };
      final result = await service.list(7, {});
      expect(calls, 1);
      expect(result['nextPageToken'], 'opaque-next');
      final row = (result['users'] as List).single as Map;
      expect(row.keys.toSet(), {'uid', 'name', 'area', 'registeredAt'});
      expect(row['uid'], 'mock-uid');
      expect(row['registeredAt'], '2026-11-17T00:00:00.000Z');
      expect(jsonEncode(result), isNot(contains('PRIVATE')));
      expect(jsonEncode(result), isNot(contains('NOT_THE_UID')));
    },
  );
  test('page cursor is forwarded, not scanned or used as an ID', () async {
    responder = (req) async {
      expect(req.url.queryParameters['pageToken'], 'opaque-next');
      expect(req.url.queryParameters['pageSize'], '100');
      return usersJson({});
    };
    expect(await service.list(7, {'limit': 100, 'pageToken': 'opaque-next'}), {
      'users': [],
      'nextPageToken': null,
    });
    expect(calls, 1);
  });
  test('no email requirement; missing and invalid fields stay null', () async {
    responder = (_) async => usersJson({
      'documents': [
        userDocument('missing', fields: {}),
        userDocument(
          'invalid',
          fields: {
            'name': {'integerValue': '123'},
            'area': {'mapValue': {}},
            'registeredAt': {'timestampValue': '2026-02-30T00:00:00Z'},
          },
        ),
      ],
    });
    final rows = (await service.list(7, {}))['users'] as List;
    expect(rows.length, 2);
    for (final row in rows) {
      expect(row['name'], isNull);
      expect(row['area'], isNull);
      expect(row['registeredAt'], isNull);
    }
  });
  test(
    'detail UID comes from exact document path and returns no contact fields',
    () async {
      responder = (req) async {
        expect(req.url.path, '/v1/$usersDatabase/documents/users/mock-uid');
        expect(
          req.url.queryParametersAll['mask.fieldPaths'],
          FirebaseUsersService.fields,
        );
        return usersJson(userDocument('mock-uid'));
      };
      final row = await service.get(7, {'uid': 'mock-uid'});
      expect(row.keys.toSet(), {'uid', 'name', 'area', 'registeredAt'});
      expect(row['uid'], 'mock-uid');
    },
  );
  test(
    'percent signs and URL punctuation in valid UID remain one encoded path segment',
    () async {
      const uid = 'literal%2Fvalue?#';
      responder = (req) async {
        expect(req.url.pathSegments.last, uid);
        expect(req.url.queryParameters.keys.toSet(), {'mask.fieldPaths'});
        return usersJson(userDocument(uid));
      };
      expect((await service.get(7, {'uid': uid}))['uid'], uid);
    },
  );
  test(
    'invalid UID is rejected before transport, without echoing it',
    () async {
      for (final uid in [
        null,
        '',
        ' ',
        '/',
        'a/b',
        r'a\b',
        '.',
        '..',
        'a\n',
        true,
        12,
        'a' * 129,
      ]) {
        await expectLater(
          service.get(7, {'uid': uid}),
          throwsA(userError(400, 'INVALID_UID')),
        );
      }
      expect(calls, 0);
    },
  );
  test(
    'invalid limits, cursors and request target overrides fail before network',
    () async {
      for (final body in [
        {'limit': 0},
        {'limit': 101},
        {'limit': null},
        {'limit': '25'},
        {'pageToken': null},
        {'pageToken': ''},
        {'pageToken': 'x' * 8193},
        {'pageToken': 'a\n'},
        {'projectId': 'different-project'},
        {'databaseId': 'other'},
        {'collection': 'other'},
        {'orderBy': 'name'},
        {'keyword': 'PRIVATE_SEARCH'},
      ]) {
        await expectLater(service.list(7, body), throwsA(userError(400)));
      }
      await expectLater(
        service.get(7, {'uid': 'mock-uid', 'includeContact': true}),
        throwsA(userError(400)),
      );
      expect(calls, 0);
    },
  );
  test('non-allowlisted admin is rejected before transport', () async {
    await expectLater(service.list(8, {}), throwsA(userError(403)));
    await expectLater(
      service.get(8, {'uid': 'mock-uid'}),
      throwsA(userError(403)),
    );
    expect(calls, 0);
  });
  test(
    'missing document returns 404 only after a successful database metadata GET',
    () async {
      responder = (req) async => req.url.path == '/v1/$usersDatabase'
          ? usersJson({'name': usersDatabase})
          : usersJson({'error': {}}, 404);
      await expectLater(
        service.get(7, {'uid': 'missing'}),
        throwsA(userError(404, 'FIREBASE_USER_NOT_FOUND')),
      );
      expect(calls, 2);
    },
  );
  test('missing database is never misreported as a missing user', () async {
    responder = (_) async => usersJson({'error': {}}, 404);
    await expectLater(
      service.get(7, {'uid': 'missing'}),
      throwsA(isA<FirebaseConnectionException>()),
    );
    expect(calls, 2);
  });
  test('invalid upstream page token receives safe client error', () async {
    responder = (_) async => usersJson({
      'error': {'message': 'PRIVATE_CURSOR'},
    }, 400);
    await expectLater(
      service.list(7, {'pageToken': 'opaque'}),
      throwsA(userError(400, 'INVALID_PAGE_TOKEN')),
    );
  });
  for (final body in [
    {
      'documents': [userDocument('same'), userDocument('same')],
    },
    {'documents': 'invalid'},
    {
      'documents': [
        {'name': 'projects/other/documents/users/private'},
      ],
    },
    {
      'documents': [userDocument('a/b')],
    },
    {'documents': [], 'nextPageToken': 42},
  ]) {
    test(
      'invalid upstream structure is rejected without partial success',
      () async {
        responder = (_) async => usersJson(body);
        await expectLater(
          service.list(7, {}),
          throwsA(isA<FirebaseConnectionException>()),
        );
      },
    );
  }
  test(
    'service timeout aborts request and close releases owned client',
    () async {
      final aborted = Completer<void>();
      var closed = false;
      final transport = _TrackedClient(
        MockClient((req) async => Completer<http.Response>().future),
        () => closed = true,
      );
      final reader = FirestoreReadonlyReader(
        transport,
        timeout: const Duration(milliseconds: 10),
      );
      transport.onRequest = (request) {
      expect(request, isA<http.AbortableRequest>());
        (request as http.AbortableRequest).abortTrigger!.then(
          (_) => aborted.complete(),
        );
      };
      await expectLater(
        reader.get('mock', 'users'),
        throwsA(
          isA<FirebaseConnectionException>().having(
            (e) => e.code,
            'code',
            'NETWORK_TIMEOUT',
          ),
        ),
      );
      await aborted.future;
      transport.close();
      expect(closed, true);
    },
  );
  test('disabled or invalid bootstrap performs zero ADC calls', () async {
    var adc = 0;
    Future<http.Client> factory() async {
      adc++;
      return client;
    }

    for (final env in [
      <String, String>{},
      {'FIREBASE_ENABLED': 'true'},
      {...usersEnvironment, 'FIREBASE_USERS_ENABLED': 'false'},
    ]) {
      expect(
        await createFirebaseUsersServiceFromEnvironment(
          environment: env,
          authenticatedClientFactory: factory,
        ),
        isNull,
      );
    }
    for (final env in [
      {...usersEnvironment, 'FIREBASE_ENABLED': 'false'},
      {...usersEnvironment, 'FIREBASE_READ_ONLY': 'false'},
      {...usersEnvironment, 'NOTIFICATIONS_ENABLED': 'true'},
      {...usersEnvironment, 'FIREBASE_USERS_SCOPE': 'area'},
      {...usersEnvironment, 'FIREBASE_USERS_ADMIN_IDS': ''},
      {...usersEnvironment, 'FIREBASE_USERS_ADMIN_IDS': '0'},
      {...usersEnvironment, 'FIREBASE_USERS_ENABLED': 'yes'},
      {...usersEnvironment, 'FIREBASE_PROJECT_ID': ''},
    ]) {
      await expectLater(
        createFirebaseUsersServiceFromEnvironment(
          environment: env,
          authenticatedClientFactory: factory,
        ),
        throwsA(isA<FirebaseConfigurationException>()),
      );
    }
    expect(adc, 0);
    expect(calls, 0);
  });
  test(
    'enabled bootstrap uses configured named database and explicit policy',
    () async {
      final created = await createFirebaseUsersServiceFromEnvironment(
        environment: {...usersEnvironment, 'FIREBASE_DATABASE_ID': 'test-db'},
        authenticatedClientFactory: () async => client,
      );
      expect(created!.config.databaseId, 'test-db');
      expect(created.policy.adminIds, {7});
    },
  );
  test('network failure is sanitized without fallback', () async {
    responder = (_) async => throw const SocketException('PRIVATE_UID');
    await expectLater(
      service.list(7, {}),
      throwsA(
        isA<FirebaseConnectionException>().having(
          (e) => e.code,
          'code',
          'NETWORK_ERROR',
        ),
      ),
    );
    expect(calls, 1);
  });
}

class _TrackedClient extends http.BaseClient {
  final http.Client inner;
  final void Function() onClose;
  void Function(http.BaseRequest)? onRequest;
  _TrackedClient(this.inner, this.onClose);
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    onRequest?.call(request);
    return inner.send(request);
  }

  @override
  void close() {
    onClose();
    inner.close();
  }
}
