import 'support/notification_fixture.dart';
import 'package:admin_server/services/notifications/notification_bootstrap.dart';
import 'package:admin_server/services/notifications/notification_service.dart';
import 'package:admin_server/services/notifications/notification_store.dart';
import 'package:test/test.dart';
import 'support/memory_notification_store.dart';

void main() {
  late MemoryNotificationStore store;
  late NotificationService service;
  var now = DateTime.utc(2026, 11, 10, 8);
  setUp(() {
    now = DateTime.utc(2026, 11, 10, 8);
    store = MemoryNotificationStore(notificationProjectId);
    for (final uid in ['uidA', 'uidB']) {
      store.documents['users/$uid'] = {
        'id': 'profile-$uid',
        'email': '$uid@example.test',
        'name': uid,
        'phone': 'test-phone',
        'area': '社區',
        'medicalInfo': 'must-not-leak',
      };
    }
    service = NotificationService(
      store,
      NotificationPolicy(
        projectId: notificationProjectId,
        adminIds: {7, 8},
        broadcastAdminIds: {7},
      ),
      now: () => now,
    );
  });
  Map<String, dynamic> input({
    String key = 'request-1',
    List<String>? uids,
    String audience = 'users',
  }) => {
    'audience': audience,
    'recipientUids': uids ?? (audience == 'broadcast' ? [] : ['uidA']),
    'title': '物資通知',
    'body': '請至管理中心領取',
    'category': 'supply',
    'expiresAt': '2026-11-11T08:00:00Z',
    'clientRequestId': key,
  };
  Matcher error(int status, [String? code]) => isA<NotificationException>()
      .having((e) => e.statusCode, 'status', status)
      .having((e) => code == null || e.code == code, 'code', true);

  test('無設定不探索 ADC，不會自動選用假資料', () async {
    expect(
      await createNotificationServiceFromEnvironment(environment: {}),
      isNull,
    );
    await expectLater(
      createNotificationServiceFromEnvironment(
        environment: {'NOTIFICATIONS_ENABLED': 'true'},
      ),
      throwsA(error(503)),
    );
  });
  test('Firebase UID 為路徑來源，名單不洩漏完整使用者資料且可分頁', () async {
    final page = await service.recipients(7, {'limit': 1});
    final first = (page['recipients'] as List).single as Map;
    expect(first['uid'], 'uidA');
    expect(first['id'], 'profile-uidA');
    expect(first.containsKey('medicalInfo'), false);
    expect(page['nextPageToken'], isNotNull);
    final next = await service.recipients(7, {
      'limit': 1,
      'pageToken': page['nextPageToken'],
    });
    expect((next['recipients'] as List).single['uid'], 'uidB');
    store.documents['users/bad'] = {'name': 'missing email'};
    expect((await service.recipients(7, {}))['skippedInvalidProfiles'], 1);
  });
  test('預設拒絕未知管理員，廣播另需授權', () async {
    await expectLater(service.recipients(9, {}), throwsA(error(403)));
    await expectLater(service.sent(9, {}), throwsA(error(403)));
    await expectLater(
      service.send(8, input(audience: 'broadcast')),
      throwsA(error(403)),
    );
    expect(store.commits, 0);
    expect(
      () => NotificationPolicy(
        projectId: notificationProjectId,
        adminIds: {7},
        broadcastAdminIds: {9},
      ),
      throwsArgumentError,
    );
  });
  test('單人、多人的投遞副本與稽核紀錄原子寫入，不複製個資', () async {
    final one = await service.send(7, input());
    expect(one['status'], 'published');
    expect(one['deliveryStatus'], 'not_tracked');
    expect(one['readStatus'], 'not_tracked');
    final id = one['messageId'];
    expect(store.documents.containsKey('users/uidA/notifications/$id'), true);
    expect(store.documents.containsKey('users/uidB/notifications/$id'), false);
    final copy = store.documents['users/uidA/notifications/$id']!;
    expect(copy.containsKey('recipientUids'), false);
    expect(copy.containsKey('email'), false);
    expect(copy['createdByAdminId'], 7);
    final many = await service.send(
      7,
      input(key: 'request-2', uids: ['uidA', 'uidB']),
    );
    expect(many['recipientCount'], 2);
    expect(store.commits, 2);
    final detail = await service.sent(7, {'messageId': many['messageId']});
    expect((detail['notifications'] as List).single['recipientUids'], [
      'uidA',
      'uidB',
    ]);
    await expectLater(service.sent(8, {'messageId': id}), throwsA(error(404)));
    final page = await service.sent(7, {'limit': 1});
    expect(page['notifications'] as List, hasLength(1));
    expect(page['nextPageToken'], isNotNull);
    await service.send(8, input(key: 'other-admin'));
    final own = (await service.sent(7, {}))['notifications'] as List;
    expect(own, hasLength(2));
    expect(own.every((r) => r['createdByAdminId'] == 7), true);
  });
  test('廣播一份主檔與一份公告，不寫入全部使用者收件匣', () async {
    final result = await service.send(7, input(audience: 'broadcast'));
    expect(
      store.documents.containsKey('broadcasts/${result['messageId']}'),
      true,
    );
    expect(
      store.documents.keys.where((p) => p.contains('/notifications/')),
      isEmpty,
    );
    expect(result['recipientCount'], isNull);
  });
  test('相同內容重送或並行只發布一次，重用 key 改內容拒絕', () async {
    final results = await Future.wait(
      List.generate(8, (_) => service.send(7, input(uids: ['uidB', 'uidA']))),
    );
    expect(results.map((r) => r['messageId']).toSet(), hasLength(1));
    expect(results.where((r) => r['replayed'] == false), hasLength(1));
    expect(store.commits, 1);
    expect(
      (await service.send(7, input(uids: ['uidA', 'uidB'])))['replayed'],
      true,
    );
    await expectLater(
      service.send(7, {
        ...input(uids: ['uidA', 'uidB']),
        'body': 'different',
      }),
      throwsA(error(409, 'IDEMPOTENCY_CONFLICT')),
    );
    expect(store.commits, 1);
  });
  test('寫入失敗無部分發布，提交回應遺失不能回成功且可安全重試', () async {
    store.failNextCommit = true;
    await expectLater(
      service.send(7, input(uids: ['uidA', 'uidB'])),
      throwsA(error(503)),
    );
    expect(
      store.documents.keys.where((p) => p.contains('notification')),
      isEmpty,
    );
    store.loseNextAcknowledgement = true;
    await expectLater(service.send(7, input()), throwsA(error(503)));
    final retried = await service.send(7, input());
    expect(retried['replayed'], true);
    expect(store.commits, 1);
  });
  test('不存在或格式不符收件者整筆拒絕，不能只發布給部分人', () async {
    await expectLater(
      service.send(7, input(uids: ['uidA', 'missing'])),
      throwsA(error(422)),
    );
    store.documents['users/bad'] = {'name': 'no email'};
    await expectLater(
      service.send(7, input(uids: ['uidA', 'bad'])),
      throwsA(error(422)),
    );
    expect(store.commits, 0);
  });
  test('內容、UID、上限、時區與有效期限檢查', () async {
    for (final change in [
      {'title': ''},
      {'body': 'x' * 4001},
      {'category': 1},
      {'clientRequestId': 'bad/key'},
      {'audience': 'all'},
      {'recipientUids': []},
      {
        'recipientUids': ['uidA', 'uidA'],
      },
      {
        'recipientUids': ['../bad'],
      },
      {
        'recipientUids': [r'bad\uid'],
      },
      {'recipientUids': List.generate(101, (i) => 'uid$i')},
      {'expiresAt': '2026-11-11T08:00:00'},
      {'expiresAt': '2026-11-09T08:00:00Z'},
      {'expiresAt': '2027-11-11T08:00:00Z'},
    ]) {
      await expectLater(
        service.send(7, {...input(), ...change}),
        throwsA(error(400)),
      );
    }
    expect(store.commits, 0);
    await service.send(7, input());
    now = now.add(const Duration(days: 2));
    expect((await service.send(7, input()))['replayed'], true);
  });
  test('忽略偽造的操作人、時間與送達狀態；最多 100 人', () async {
    for (var i = 0; i < 100; i++) {
      store.documents['users/u$i'] = {'email': 'u$i@example.test'};
    }
    final result = await service.send(7, {
      ...input(uids: List.generate(100, (i) => 'u$i')),
      'createdByAdminId': 999,
      'status': 'read',
      'createdAt': 'forged',
      'deliveryStatus': 'delivered',
    });
    final log = store.documents['notification_sends/${result['messageId']}']!;
    expect(log['createdByAdminId'], 7);
    expect(log['createdAt'], now);
    expect(log['status'], 'published');
    expect(
      store.documents.keys.where((p) => p.contains('/notifications/')),
      hasLength(100),
    );
  });
}
