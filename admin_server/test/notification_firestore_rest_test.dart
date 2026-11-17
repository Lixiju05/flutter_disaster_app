import 'support/notification_fixture.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:admin_server/services/notifications/notification_service.dart';
import 'package:admin_server/services/notifications/notification_store.dart';
import 'package:test/test.dart';

void main() {
  const prefix =
      'projects/$notificationProjectId/databases/(default)/documents/';
  late List<http.Request> requests;
  late Map<String, Map<String, Object?>> documents;
  late int commits;
  late bool abortOnce;
  late bool denyCommit;
  late bool omitAcknowledgement;
  late FirestoreNotificationStore store;
  late NotificationService service;
  late http.Client client;
  setUp(() {
    requests = [];
    commits = 0;
    abortOnce = false;
    denyCommit = false;
    omitAcknowledgement = false;
    documents = {
      'users/uidA': {
        'email': 'a@example.test',
        'name': '測試',
        'createdAt': DateTime.utc(2026),
      },
    };
    client = MockClient((request) async {
      requests.add(request);
      final path = request.url.path;
      expect(request.url.host, 'firestore.googleapis.com');
      http.Response json(Object value, [int status = 200]) => http.Response(
        jsonEncode(value),
        status,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
      if (path.endsWith(':beginTransaction')) {
        return json({
          'transaction': base64Encode(
            utf8.encode('synthetic-test-transaction'),
          ),
        });
      }
      if (path.endsWith(':rollback')) return json({});
      if (path.endsWith(':commit')) {
        commits++;
        final data = jsonDecode(request.body) as Map;
        expect(data['transaction'], isNotNull);
        if (denyCommit) {
          return json({
            'error': {
              'status': 'PERMISSION_DENIED',
              'message': 'sensitive-upstream-detail',
            },
          }, 403);
        }
        if (abortOnce) {
          abortOnce = false;
          return json({
            'error': {'status': 'ABORTED'},
          }, 409);
        }
        final writes = data['writes'] as List;
        final staged = <String, Map<String, Object?>>{};
        for (final write in writes) {
          expect(write['currentDocument']['exists'], false);
          final name = write['update']['name'] as String;
          expect(name.startsWith(prefix), true);
          staged[name.substring(prefix.length)] = decodeFirestoreFields(
            write['update']['fields'] as Map,
          );
        }
        documents.addAll(staged);
        if (omitAcknowledgement) return json({});
        return json({
          'writeResults': [
            for (final _ in writes) {'updateTime': '2026-11-10T08:00:00Z'},
          ],
          'commitTime': '2026-11-10T08:00:00Z',
        });
      }
      final relative = path.substring('/v1/$prefix'.length);
      if (relative == 'users' || relative == 'notification_sends') {
        expect(request.url.queryParameters['pageSize'], '1');
        return json({
          'documents': [
            for (final e in documents.entries.where(
              (e) => e.key.startsWith('$relative/'),
            ))
              {
                'name': '$prefix${e.key}',
                'fields': encodeFirestoreFields(e.value),
              },
          ],
          'nextPageToken': 'synthetic-page',
        });
      }
      final document = documents[relative];
      if (document == null) {
        return json({
          'error': {'status': 'NOT_FOUND'},
        }, 404);
      }
      return json({
        'name': '$prefix$relative',
        'fields': encodeFirestoreFields(document),
      });
    });
    store = FirestoreNotificationStore(notificationProjectId, client);
    service = NotificationService(
      store,
      NotificationPolicy(
        projectId: notificationProjectId,
        adminIds: {7},
        broadcastAdminIds: {7},
      ),
      now: () => DateTime.utc(2026, 11, 10, 8),
    );
  });
  tearDown(() => client.close());
  Map<String, dynamic> input() => {
    'audience': 'users',
    'recipientUids': ['uidA'],
    'title': '通知',
    'body': '內容',
    'clientRequestId': 'rest-1',
    'expiresAt': '2026-11-11T08:00:00Z',
  };

  test('REST transaction 內讀取收件者，單次 commit 同時建立紀錄及副本', () async {
    final result = await service.send(7, input());
    expect(result['status'], 'published');
    expect(commits, 1);
    final userRead = requests.singleWhere(
      (r) => r.url.path.endsWith('/users/uidA'),
    );
    expect(userRead.url.queryParameters['transaction'], isNotNull);
    final commit = requests.singleWhere((r) => r.url.path.endsWith(':commit'));
    expect((jsonDecode(commit.body)['writes'] as List), hasLength(2));
    expect(
      documents.keys.where((p) => p.contains('notification')),
      hasLength(2),
    );
    expect((await service.send(7, input()))['replayed'], true);
    expect(commits, 1);
  });
  test('Firestore ABORTED 重新讀取交易，避免盲目重複寫入', () async {
    abortOnce = true;
    final result = await service.send(7, input());
    expect(result['status'], 'published');
    expect(commits, 2);
    expect(
      requests.where((r) => r.url.path.endsWith(':beginTransaction')),
      hasLength(2),
    );
    expect(
      documents.keys.where((p) => p.contains('notification')),
      hasLength(2),
    );
  });
  test('IAM 拒絕時不回成功、不曝光上游細節且嘗試 rollback', () async {
    denyCommit = true;
    await expectLater(
      service.send(7, input()),
      throwsA(
        isA<NotificationException>()
            .having((e) => e.statusCode, 'status', 503)
            .having(
              (e) => e.message.contains('sensitive-upstream-detail'),
              'no secret leakage',
              false,
            ),
      ),
    );
    expect(
      requests.where((r) => r.url.path.endsWith(':rollback')),
      hasLength(1),
    );
    expect(documents.keys.where((p) => p.contains('notification')), isEmpty);
  });
  test('REST 分頁、opaque cursor 與 timestamp codec', () async {
    final page = await service.recipients(7, {
      'limit': 1,
      'pageToken': 'opaque',
    });
    expect(page['nextPageToken'], 'synthetic-page');
    expect(requests.single.url.queryParameters['pageToken'], 'opaque');
    final timestamp = DateTime.utc(2026, 11, 10);
    final value = {
      'time': timestamp,
      'count': 7,
      'nil': null,
      'flag': true,
      'values': ['a', 1],
      'nested': {'k': 'v'},
    };
    expect(decodeFirestoreFields(encodeFirestoreFields(value)), value);
  });
  test('HTTP 200 但提交確認不完整不可回成功，重試仍不重複建立', () async {
    omitAcknowledgement = true;
    await expectLater(
      service.send(7, input()),
      throwsA(
        isA<NotificationException>().having((e) => e.statusCode, 'status', 503),
      ),
    );
    expect((await service.send(7, input()))['replayed'], true);
    expect(commits, 1);
  });

  test('HTTP transport 未確認不可假裝成功', () async {
    final failing = FirestoreNotificationStore(
      notificationProjectId,
      MockClient((_) async => throw TimeoutException('test only')),
    );
    await expectLater(
      failing.get('users/uidA'),
      throwsA(
        isA<NotificationException>().having((e) => e.statusCode, 'status', 503),
      ),
    );
    failing.client.close();
  });
}
