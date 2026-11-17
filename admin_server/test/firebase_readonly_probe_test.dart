import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:admin_server/services/firebase/firebase_config.dart';
import 'package:admin_server/services/firebase/firebase_connection.dart';
import 'package:admin_server/services/firebase/firestore_readonly_probe.dart';
import 'package:googleapis_auth/auth_io.dart' as auth;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

void main() {
  final config = FirebaseConfig.fromEnvironment({
    'FIREBASE_ENABLED': 'true',
    'FIREBASE_PROJECT_ID': 'hucares-firebase-test',
  });
  const path = 'projects/hucares-firebase-test/databases/(default)';
  http.Response json(Object value, [int status = 200]) => http.Response(
    jsonEncode(value),
    status,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
  Matcher failure(String code) => isA<FirebaseConnectionException>().having(
    (error) => error.code,
    'code',
    code,
  );

  group('MOCK UNIT TESTS - not live Firebase verification', () {
    test(
      'GET-only, one document, masks fields and redacts all values/UIDs',
      () async {
        final requests = <http.Request>[];
        final client = MockClient((req) async {
          requests.add(req);
          expect(req.method, 'GET');
          expect(req.followRedirects, false);
          expect(req.url.host, 'firestore.googleapis.com');
          expect(req.url.path, '/v1/$path/documents/users');
          expect(req.url.queryParameters['pageSize'], '1');
          expect(
            req.url.queryParametersAll['mask.fieldPaths'],
            FirestoreReadonlyProbe.fields,
          );
          return json({
            'documents': [
              {
                'name': '$path/documents/users/PRIVATE_UID',
                'fields': {
                  'id': {'stringValue': 'PRIVATE_UID'},
                  'name': {'stringValue': 'PRIVATE_NAME'},
                  'email': {'stringValue': 'PRIVATE_EMAIL'},
                  'phone': {'stringValue': 'PRIVATE_PHONE'},
                  'area': {'stringValue': 'PRIVATE_ADDRESS'},
                  'registeredAt': {'timestampValue': '2026-11-15T00:00:00Z'},
                  'PRIVATE_FIELD_NAME': {'stringValue': 'MUST_NOT_PRINT'},
                },
              },
            ],
          });
        });
        final result = await FirestoreReadonlyProbe(config, client).run();
        expect(result['documentsRead'], 1);
        expect(result['fieldTypes'], {
          'id': 'string',
          'name': 'string',
          'email': 'string',
          'phone': 'string',
          'area': 'string',
          'registeredAt': 'timestamp',
        });
        expect(jsonEncode(result), isNot(contains('PRIVATE')));
        expect(requests, hasLength(1));
        client.close();
      },
    );
    test(
      'optional metadata is also GET-only and validates target database',
      () async {
        var calls = 0;
        final client = MockClient((req) async {
          calls++;
          expect(req.method, 'GET');
          return req.url.path == '/v1/$path' ? json({'name': path}) : json({});
        });
        final result = await FirestoreReadonlyProbe(
          config,
          client,
        ).run(includeMetadata: true);
        expect(calls, 2);
        expect(result['documentsRead'], 0);
        expect(result['status'], 'read_ok_empty');
        client.close();
      },
    );
    test('wrong metadata target fails before listing users', () async {
      var calls = 0;
      final client = MockClient((_) async {
        calls++;
        return json({'name': 'different-target'});
      });
      await expectLater(
        FirestoreReadonlyProbe(config, client).run(includeMetadata: true),
        throwsA(failure('DATABASE_TARGET_MISMATCH')),
      );
      expect(calls, 1);
      client.close();
    });
    for (final entry in {
      401: 'ADC_REJECTED',
      403: 'PERMISSION_DENIED',
      404: 'DATABASE_NOT_FOUND_OR_INACCESSIBLE',
      429: 'QUOTA_EXCEEDED',
      500: 'FIRESTORE_HTTP_ERROR',
      302: 'FIRESTORE_HTTP_ERROR',
    }.entries) {
      test(
        'HTTP ${entry.key} maps to ${entry.value}, without leaking upstream details',
        () async {
          final client = MockClient(
            (_) async => json({
              'error': {'message': 'PRIVATE_UID PRIVATE_TOKEN'},
            }, entry.key),
          );
          await expectLater(
            FirestoreReadonlyProbe(config, client).run(),
            throwsA(failure(entry.value)),
          );
          client.close();
        },
      );
    }
    test('API-not-enabled is distinct from generic IAM denial', () async {
      final client = MockClient(
        (_) async => json({
          'error': {
            'message': 'PRIVATE_DATA',
            'details': [
              {'reason': 'SERVICE_DISABLED'},
            ],
          },
        }, 403),
      );
      await expectLater(
        FirestoreReadonlyProbe(config, client).run(),
        throwsA(failure('API_NOT_ENABLED')),
      );
      client.close();
    });
    test('network unavailable and timeout are distinct', () async {
      final offline = MockClient(
        (_) async => throw const SocketException('PRIVATE_ADDRESS'),
      );
      await expectLater(
        FirestoreReadonlyProbe(config, offline).run(),
        throwsA(failure('NETWORK_ERROR')),
      );
      offline.close();
      final slow = MockClient((_) => Completer<http.Response>().future);
      await expectLater(
        FirestoreReadonlyProbe(
          config,
          slow,
          timeout: const Duration(milliseconds: 10),
        ).run(),
        throwsA(failure('NETWORK_TIMEOUT')),
      );
      slow.close();
    });
    test(
      'ADC failures are sanitized and distinguished from transport errors',
      () {
        for (final error in [
          auth.CredentialsFileException('PRIVATE_TOKEN'),
          auth.AccessDeniedException('PRIVATE_TOKEN'),
          auth.ServerRequestFailedException(
            'PRIVATE_TOKEN',
            statusCode: 403,
            responseContent: 'PRIVATE_TOKEN',
          ),
        ]) {
          final mapped = firebaseConnectionFailure(error, 'adc');
          expect(mapped.code, startsWith('ADC_'));
          expect('$mapped', isNot(contains('PRIVATE')));
        }
      },
    );
    for (final value in [
      {'documents': 'PRIVATE'},
      {
        'documents': [{}, {}],
      },
      {
        'documents': [
          {'name': 'projects/wrong/documents/users/PRIVATE'},
        ],
      },
      {
        'error': {'message': 'PRIVATE'},
      },
    ]) {
      test(
        'malformed or oversized page is never treated as a successful read',
        () async {
          final client = MockClient((_) async => json(value));
          await expectLater(
            FirestoreReadonlyProbe(config, client).run(),
            throwsA(failure('INVALID_FIRESTORE_RESPONSE')),
          );
          client.close();
        },
      );
    }
    test(
      'named database routes to the explicit target, without project fallback',
      () async {
        final named = FirebaseConfig.fromEnvironment({
          'FIREBASE_ENABLED': 'true',
          'FIREBASE_PROJECT_ID': 'hucares-firebase-test',
          'FIREBASE_DATABASE_ID': 'test-db',
        });
        final client = MockClient((req) async {
          expect(
            req.url.path,
            '/v1/projects/hucares-firebase-test/databases/test-db/documents/users',
          );
          return json({});
        });
        await FirestoreReadonlyProbe(named, client).run();
        client.close();
      },
    );
  });

  test(
    'real CLI disabled path: no SQLite, no credential access, no Mock mode',
    () async {
      final root = Directory.current.absolute.path;
      final sdk = File(Platform.resolvedExecutable).parent.path;
      final dir = await Directory.systemTemp.createTemp(
        'hucares_firebase_disabled_',
      );
      try {
        for (final args in [
          <String>[],
          ['--mock'],
        ]) {
          final result = await Process.run(
            '$sdk/${Platform.isWindows ? 'dart.exe' : 'dart'}',
            [
              '--packages=$root/.dart_tool/package_config.json',
              '$root/bin/firebase_readonly_probe.dart',
              ...args,
            ],
            workingDirectory: dir.path,
            environment: {
              'FIREBASE_ENABLED': 'false',
              'FIREBASE_READ_ONLY': 'true',
              'NOTIFICATIONS_ENABLED': 'false',
              'GOOGLE_APPLICATION_CREDENTIALS': 'DO_NOT_READ',
            },
          );
          expect(result.exitCode, 2);
          expect(result.stderr, '');
          final output = jsonDecode(result.stdout as String) as Map;
          expect(
            output['code'],
            args.isEmpty ? 'FIREBASE_DISABLED' : 'INVALID_PROBE_ARGUMENTS',
          );
          expect(dir.listSync(), isEmpty);
        }
      } finally {
        await dir.delete();
      }
    },
    timeout: const Timeout(Duration(seconds: 60)),
  );
}
