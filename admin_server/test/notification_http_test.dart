import 'support/notification_fixture.dart';
import 'dart:convert';
import 'dart:io';
import 'package:admin_server/database/database_service.dart';
import 'package:admin_server/services/notifications/notification_service.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';
import '../bin/admin_server.dart' as api;
import 'support/memory_notification_store.dart';

void main() {
  late Database sql;
  late MemoryNotificationStore store;
  late HttpClient client;
  late HttpServer server;
  late Future<void> Function() stop;
  setUp(() async {
    sql = sqlite3.openInMemory();
    sql.execute(
      'CREATE TABLE admins (id INTEGER PRIMARY KEY,username TEXT,password TEXT,zoneId TEXT)',
    );
    sql.execute(
      "INSERT INTO admins VALUES (7,'manager','test-only-password','OFFICE001'),(8,'sender','test-only-password','OFFICE001'),(9,'unprivileged','test-only-password','OFFICE001')",
    );
    DatabaseService.instance = DatabaseService(sql);
    store = MemoryNotificationStore(notificationProjectId);
    store.documents['users/uidA'] = {
      'id': 'uidA',
      'email': 'a@example.test',
      'name': '測試收件者',
      'phone': '',
      'area': '社區',
    };
    api.notificationService = NotificationService(
      store,
      NotificationPolicy(
        projectId: notificationProjectId,
        adminIds: {7, 8},
        broadcastAdminIds: {7},
      ),
      now: () => DateTime.utc(2026, 11, 10, 8),
    );
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final listener = server.listen(api.handleRequest);
    client = HttpClient();
    stop = () async {
      await listener.cancel();
      await server.close(force: true);
    };
  });
  tearDown(() async {
    client.close(force: true);
    await stop();
    api.notificationService = null;
    sql.dispose();
  });
  Future<(int, Map<String, dynamic>)> post(
    Map<String, dynamic> body, [
    String? token,
  ]) async {
    final request = await client.postUrl(
      Uri.parse('http://127.0.0.1:${server.port}'),
    );
    request.headers.contentType = ContentType.json;
    if (token != null) request.headers.set('Authorization', 'Bearer $token');
    request.write(jsonEncode(body));
    final response = await request.close();
    if (body['type'] != 'login') {
      expect(response.headers.value('Cache-Control'), 'no-store');
    }
    expect(
      response.headers.value('Access-Control-Allow-Headers'),
      contains('Authorization'),
    );
    return (
      response.statusCode,
      jsonDecode(await utf8.decoder.bind(response).join())
          as Map<String, dynamic>,
    );
  }

  Map<String, dynamic> send() => {
    'type': 'sendNotification',
    'audience': 'users',
    'recipientUids': ['uidA'],
    'title': '測試通知',
    'body': '僅在測試資料庫中使用',
    'category': 'general',
    'expiresAt': '2026-11-11T08:00:00Z',
    'clientRequestId': 'http-request-1',
  };

  test('三支 API 均要求有效 Session、存活帳號及通知權限', () async {
    for (final body in [
      {'type': 'getNotificationRecipients'},
      send(),
      {'type': 'getSentNotifications'},
    ]) {
      expect((await post(body)).$1, 401);
      expect((await post(body, 'invalid-test-value')).$1, 401);
      expect((await post(body, api.adminSessions.create(9))).$1, 403);
    }
    final token = api.adminSessions.create(7);
    sql.execute('DELETE FROM admins WHERE id=7');
    for (final body in [
      {'type': 'getNotificationRecipients'},
      send(),
      {'type': 'getSentNotifications'},
    ]) {
      expect((await post(body, token)).$1, 403);
    }
    expect(store.commits, 0);
  });
  test('實際 HTTP 登入、名單、發送、重送與發送紀錄串接', () async {
    final login = await post({
      'type': 'login',
      'username': 'manager',
      'password': 'test-only-password',
    });
    expect(login.$1, 200);
    final token = login.$2['token'] as String;
    final recipients = await post({
      'type': 'getNotificationRecipients',
      'limit': 10,
    }, token);
    expect(recipients.$1, 200);
    expect(recipients.$2['data']['recipients'][0]['uid'], 'uidA');
    final result = await post({...send(), 'createdByAdminId': 999}, token);
    expect(result.$1, 200);
    expect(result.$2['data']['deliveryStatus'], 'not_tracked');
    expect(result.$2['data']['createdAt'], '2026-11-10T08:00:00.000Z');
    final id = result.$2['data']['messageId'];
    final replay = await post(send(), token);
    expect(replay.$2['data']['replayed'], true);
    expect(store.commits, 1);
    final detail = await post({
      'type': 'getSentNotifications',
      'messageId': id,
    }, token);
    expect(detail.$2['data']['notifications'][0]['createdByAdminId'], 7);
    expect(detail.$2['data']['notifications'][0]['readStatus'], 'not_tracked');
    expect((await post({...send(), 'body': 'changed'}, token)).$1, 409);
    expect(
      (await post({
        'type': 'getSentNotifications',
        'messageId': id,
      }, api.adminSessions.create(8))).$1,
      404,
    );
  });
  test('廣播獨立權限與服務未設定時的封閉行為', () async {
    final broadcast = {...send(), 'audience': 'broadcast', 'recipientUids': []};
    expect((await post(broadcast, api.adminSessions.create(8))).$1, 403);
    expect((await post(broadcast, api.adminSessions.create(7))).$1, 200);
    api.notificationService = null;
    for (final body in [
      {'type': 'getNotificationRecipients'},
      send(),
      {'type': 'getSentNotifications'},
    ]) {
      final result = await post(body, api.adminSessions.create(7));
      expect(result.$1, 503);
      expect(result.$2['code'], 'NOTIFICATIONS_DISABLED');
      expect(result.$2['success'], false);
    }
  });
  test('HTTP 寫入失敗不回報已發布，不存在收件者整筆拒絕', () async {
    final token = api.adminSessions.create(7);
    store.failNextCommit = true;
    final result = await post(send(), token);
    expect(result.$1, 503);
    expect(result.$2['success'], false);
    expect(store.commits, 0);
    final unavailable = await post({
      ...send(),
      'recipientUids': ['uidA', 'missing-sensitive-test-uid'],
    }, token);
    expect(unavailable.$1, 422);
    expect(jsonEncode(unavailable.$2), isNot(contains('missing-sensitive-test-uid')));
    expect(
      (await post({
        ...send(),
        'recipientUids': ['uidA', 'uidA'],
      }, token)).$1,
      400,
    );
    expect(store.commits, 0);
  });
}
