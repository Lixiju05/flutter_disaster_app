import 'dart:convert';
import 'package:admin_server/services/firebase/firebase_config.dart';
import 'package:admin_server/services/firebase/firebase_connection.dart';
import 'package:admin_server/services/firebase/firebase_reports_bootstrap.dart';
import 'package:admin_server/services/firebase/firestore_health_report_reader.dart';
import 'package:admin_server/services/firebase/firestore_readonly_reader.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

const reportEnvironment = {
  'FIREBASE_ENABLED': 'true',
  'FIREBASE_PROJECT_ID': 'hucares-reports-test',
  'FIREBASE_READ_ONLY': 'true',
  'NOTIFICATIONS_ENABLED': 'false',
  'FIREBASE_REPORTS_ENABLED': 'true',
  'FIREBASE_REPORTS_ADMIN_IDS': '7',
  'FIREBASE_REPORTS_SCOPE': 'project',
};
const reportDatabase = 'projects/hucares-reports-test/databases/(default)';
Map<String, Object?> reportDocument(
  String uid, {
  Map<String, Object?>? fields,
}) => {
  'name': '$reportDatabase/documents/health_reports/$uid',
  'fields':
      fields ??
      {
        'id': {'stringValue': '00000000-0000-4000-8000-000000000001'},
        'reporterId': {'stringValue': uid},
        'name': {'stringValue': 'SYNTHETIC'},
        'status': {'stringValue': '未宣告'},
        'sos': {'booleanValue': true},
        'lat': {'doubleValue': 24.123456789},
        'lng': {'doubleValue': 121.987654321},
        'reportTime': {'stringValue': '2026-11-17T08:00:00+08:00'},
        'description': {'nullValue': null},
        'medicalInfo': {'stringValue': 'PRIVATE_MEDICAL'},
        'phone': {'stringValue': 'PRIVATE_CONTACT'},
        'survey': {'stringValue': 'PRIVATE_SURVEY'},
      },
};
http.Response reportJson(Object value, [int status = 200]) => http.Response(
  jsonEncode(value),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);
Matcher reportsError(int status, [String? code]) =>
    isA<FirebaseReportsException>()
        .having((e) => e.statusCode, 'status', status)
        .having((e) => code == null || code == e.code, 'code matches', true);

void main() {
  late FirestoreHealthReportReader reader;
  late http.Client client;
  late int calls;
  late Future<http.Response> Function(http.Request) responder;
  setUp(() {
    calls = 0;
    responder = (_) async => reportJson({
      'documents': [reportDocument('test-uid')],
    });
    client = MockClient((request) {
      calls++;
      return responder(request);
    });
    reader = FirestoreHealthReportReader(
      FirebaseConfig.fromEnvironment(reportEnvironment),
      {7},
      FirestoreReadonlyReader(client),
    );
  });
  tearDown(() => client.close());

  test(
    'disabled bootstrap performs zero ADC calls regardless of unrelated flags',
    () async {
      for (final env in [
        <String, String>{},
        {...reportEnvironment, 'FIREBASE_REPORTS_ENABLED': 'false'},
      ]) {
        expect(
          await createFirebaseReportsReaderFromEnvironment(
            environment: env,
            authenticatedClientFactory: () async =>
                throw StateError('No ADC allowed'),
          ),
          isNull,
        );
      }
    },
  );
  test(
    'enabled bootstrap validates readonly project scope and explicit admin IDs before ADC',
    () async {
      for (final change in [
        {'FIREBASE_REPORTS_ENABLED': 'yes'},
        {'FIREBASE_ENABLED': 'false'},
        {'FIREBASE_PROJECT_ID': ''},
        {'FIREBASE_REPORTS_SCOPE': ''},
        {'FIREBASE_REPORTS_ADMIN_IDS': ''},
        {'FIREBASE_REPORTS_ADMIN_IDS': '0'},
        {'FIREBASE_READ_ONLY': 'false'},
        {'NOTIFICATIONS_ENABLED': 'true'},
        {'NOTIFICATION_FIREBASE_PROJECT': 'different-project'},
      ]) {
        await expectLater(
          createFirebaseReportsReaderFromEnvironment(
            environment: {...reportEnvironment, ...change},
            authenticatedClientFactory: () async =>
                throw StateError('No ADC allowed'),
          ),
          throwsA(isA<FirebaseConfigurationException>()),
        );
      }
    },
  );
  test(
    'enabled bootstrap uses injected Mock and does not write or query during startup',
    () async {
      final actual = await createFirebaseReportsReaderFromEnvironment(
        environment: reportEnvironment,
        authenticatedClientFactory: () async => client,
      );
      expect(actual!.adminIds, {7});
      expect(calls, 0);
      expect(actual.config.readOnly, true);
    },
  );
  test(
    'GET uses fixed target, mask, ordering and exactly one source page',
    () async {
      responder = (request) async {
        expect(request.method, 'GET');
        expect(request.followRedirects, false);
        expect(request.url.host, 'firestore.googleapis.com');
        expect(
          request.url.path,
          '/v1/$reportDatabase/documents/health_reports',
        );
        expect(request.url.queryParameters['pageSize'], '25');
        expect(request.url.queryParameters['orderBy'], '__name__ asc');
        expect(
          request.url.queryParametersAll['mask.fieldPaths'],
          FirestoreHealthReportReader.fields,
        );
        return reportJson({
          'documents': [reportDocument('test-uid')],
          'nextPageToken': 'opaque-next',
        });
      };
      final page = await reader.list(7, {}, sosOnly: false);
      expect(calls, 1);
      expect(page['nextPageToken'], 'opaque-next');
      final report = (page['reports'] as List).single as Map;
      expect(report['uid'], 'test-uid');
      expect(report['reporterIdMatchesUid'], true);
      expect(report['eventIdIsUuid'], true);
      expect(report['status'], '未宣告');
      expect(report['sos'], true);
      expect(report['reportTime'], '2026-11-17T00:00:00.000Z');
      expect(report['latitude'], 24.123456789);
      expect(report['longitude'], 121.987654321);
      expect(report['location'], {
        'source': 'app_reported',
        'precision': 'unspecified',
        'freshness': 'unknown',
        'capturedAt': null,
        'isRealtime': false,
      });
      expect(jsonEncode(page), isNot(contains('PRIVATE_')));
      expect(report.keys.toSet(), {
        'uid',
        'eventId',
        'eventIdIsUuid',
        'reporterIdMatchesUid',
        'name',
        'status',
        'description',
        'sos',
        'latitude',
        'longitude',
        'reportTime',
        'location',
        'dataQuality',
      });
    },
  );
  test(
    'unapproved admins and unsupported client targets never reach Firestore',
    () async {
      await expectLater(
        reader.list(8, {}, sosOnly: false),
        throwsA(reportsError(403)),
      );
      for (final key in [
        'projectId',
        'databaseId',
        'collection',
        'uid',
        'adminId',
        'sos',
      ]) {
        await expectLater(
          reader.list(7, {key: 'injected'}, sosOnly: true),
          throwsA(reportsError(400)),
        );
      }
      expect(calls, 0);
    },
  );
  test('limits and cursors are strictly bounded', () async {
    for (final input in [
      {'limit': null},
      {'limit': 0},
      {'limit': 101},
      {'limit': '25'},
      {'pageToken': null},
      {'pageToken': ''},
      {'pageToken': 'x' * 8193},
      {'pageToken': 'a\nb'},
    ]) {
      await expectLater(
        reader.list(7, input, sosOnly: false),
        throwsA(reportsError(400)),
      );
    }
    expect(calls, 0);
  });
  test(
    'SOS filtering is strict bool true and empty page retains upstream cursor',
    () async {
      responder = (_) async => reportJson({
        'documents': [
          reportDocument(
            'test-uid',
            fields: {
              'status': {'stringValue': '未宣告'},
              'sos': {'stringValue': 'true'},
            },
          ),
        ],
        'nextPageToken': 'next',
      });
      final page = await reader.list(7, {}, sosOnly: true);
      expect(page['reports'], isEmpty);
      expect(page['nextPageToken'], 'next');
      expect(page['scannedCount'], 1);
      responder = (request) async {
        expect(request.url.queryParameters['pageToken'], 'next');
        return reportJson({
          'documents': [reportDocument('test-uid')],
        });
      };
      expect(
        (await reader.list(7, {'pageToken': 'next'}, sosOnly: true))['reports'],
        hasLength(1),
      );
    },
  );
  test(
    'missing fields remain null and unknown SOS is not safe or active',
    () async {
      responder = (_) async => reportJson({
        'documents': [reportDocument('test-uid', fields: {})],
      });
      final report =
          ((await reader.list(7, {}, sosOnly: false))['reports'] as List).single
              as Map;
      for (final key in [
        'eventId',
        'eventIdIsUuid',
        'reporterIdMatchesUid',
        'name',
        'status',
        'description',
        'sos',
        'latitude',
        'longitude',
        'reportTime',
      ]) {
        expect(report[key], isNull);
      }
      expect((await reader.list(7, {}, sosOnly: true))['reports'], isEmpty);
    },
  );
  test(
    'identity comes only from path; mismatched reporter is flagged, not matched to SQLite',
    () async {
      responder = (_) async => reportJson({
        'documents': [
          reportDocument(
            'test-uid',
            fields: {
              'id': {'stringValue': 'legacy-event-id'},
              'reporterId': {'stringValue': 'other-uid'},
              'status': {'stringValue': '未宣告'},
              'sos': {'booleanValue': true},
            },
          ),
        ],
      });
      final report =
          ((await reader.list(7, {}, sosOnly: true))['reports'] as List).single
              as Map;
      expect(report['uid'], 'test-uid');
      expect(report['eventIdIsUuid'], false);
      expect(report['reporterIdMatchesUid'], false);
      expect(jsonEncode(report), isNot(contains('other-uid')));
    },
  );
  test(
    'timestamps accept explicit offsets/timestamps and reject invalid or timezone-less dates',
    () async {
      for (final value in [
        '2026-02-31T00:00:00Z',
        'not-a-time',
        '2026-11-17T08:00:00',
      ]) {
        responder = (_) async => reportJson({
          'documents': [
            reportDocument(
              'test-uid',
              fields: {
                'reportTime': {'stringValue': value},
              },
            ),
          ],
        });
        final report =
            ((await reader.list(7, {}, sosOnly: false))['reports'] as List)
                    .single
                as Map;
        expect(report['reportTime'], isNull);
      }
      responder = (_) async => reportJson({
        'documents': [
          reportDocument(
            'test-uid',
            fields: {
              'reportTime': {'timestampValue': '2026-11-17T00:00:00Z'},
            },
          ),
        ],
      });
      expect(
        ((await reader.list(7, {}, sosOnly: false))['reports'] as List)
            .single['reportTime'],
        '2026-11-17T00:00:00.000Z',
      );
    },
  );
  test(
    'invalid, partial, nonfinite and zero-pair GPS never becomes a fake position',
    () async {
      for (final fields in <Map<String, Object?>>[
        {
          'lat': {'doubleValue': 91},
          'lng': {'doubleValue': 121},
        },
        {
          'lat': {'doubleValue': 24},
        },
        {
          'lat': {'doubleValue': 'NaN'},
          'lng': {'doubleValue': 121},
        },
        {
          'lat': {'integerValue': '0'},
          'lng': {'integerValue': '0'},
        },
      ]) {
        responder = (_) async => reportJson({
          'documents': [reportDocument('test-uid', fields: fields)],
        });
        final report =
            ((await reader.list(7, {}, sosOnly: false))['reports'] as List)
                    .single
                as Map;
        expect(report['latitude'], isNull);
        expect(report['longitude'], isNull);
      }
    },
  );
  test(
    'same UID updates in place, repeated reads do not append; SOS clear removes active result',
    () async {
      expect(
        (await reader.list(7, {}, sosOnly: true))['reports'],
        hasLength(1),
      );
      expect(
        (await reader.list(7, {}, sosOnly: true))['reports'],
        hasLength(1),
      );
      responder = (_) async => reportJson({
        'documents': [
          reportDocument(
            'test-uid',
            fields: {
              'status': {'stringValue': '安全'},
              'sos': {'booleanValue': false},
              'id': {'stringValue': '00000000-0000-4000-8000-000000000002'},
            },
          ),
        ],
      });
      expect((await reader.list(7, {}, sosOnly: true))['reports'], isEmpty);
      final report =
          ((await reader.list(7, {}, sosOnly: false))['reports'] as List).single
              as Map;
      expect(report['uid'], 'test-uid');
      expect(report['sos'], false);
      expect(report['status'], '安全');
    },
  );
  test(
    'duplicate UID, wrong collection/project and malformed upstream page reject safely',
    () async {
      for (final page in [
        {
          'documents': [reportDocument('test-uid'), reportDocument('test-uid')],
        },
        {
          'documents': [
            {'name': '$reportDatabase/documents/users/test-uid'},
          ],
        },
        {
          'documents': [
            {
              'name':
                  'projects/other/databases/(default)/documents/health_reports/test-uid',
            },
          ],
        },
        {
          'documents': [reportDocument('bad/uid')],
        },
        {'documents': 'invalid'},
        {
          'documents': [
            reportDocument('test-uid', fields: null)..['fields'] = 'invalid',
          ],
        },
        {'nextPageToken': 'bad\ncursor'},
      ]) {
        responder = (_) async => reportJson(page);
        await expectLater(
          reader.list(7, {}, sosOnly: false),
          throwsA(isA<FirebaseConnectionException>()),
        );
      }
    },
  );
  test('invalid upstream cursor maps to safe client error', () async {
    responder = (_) async => reportJson({
      'error': {'message': 'PRIVATE_UPSTREAM'},
    }, 400);
    await expectLater(
      reader.list(7, {'pageToken': 'expired'}, sosOnly: false),
      throwsA(reportsError(400, 'INVALID_PAGE_TOKEN')),
    );
  });
}
