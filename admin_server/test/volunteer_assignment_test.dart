import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'package:admin_server/database/database_service.dart';
import 'package:admin_server/services/admin_session_store.dart';
import 'package:admin_server/services/supply/supply_request_service.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';
import '../bin/admin_server.dart' as api;
import 'office_inventory_test.dart' show createFixture;

Future<bool> raceAssignment(String path, bool assigned) => Isolate.run(() async {
  final sql = sqlite3.open(path);
  sql.execute('PRAGMA busy_timeout = 5000');
  final service = SupplyRequestService(DatabaseService(sql));
  try {
    if (assigned) {
      await service.assignSupplyRequestVolunteer(
        requestId: 'R1', volunteerId: 'V002', adminId: 7,
      );
    } else {
      await service.claimSupplyRequest(
        requestId: 'R1', volunteerId: 'V001', stationId: 'OFFICE001',
      );
    }
    return true;
  } on Exception {
    return false;
  } finally {
    sql.dispose();
  }
});

void main() {
  late Database sql;
  late DatabaseService db;
  late SupplyRequestService service;

  setUp(() {
    sql = sqlite3.openInMemory();
    createFixture(sql);
    sql.execute("UPDATE station_inventory SET stockQty=10,reservedQty=3 WHERE stationId='OFFICE001' AND itemId=1");
    sql.execute('CREATE TABLE admins (id INTEGER PRIMARY KEY, username TEXT, password TEXT, zoneId TEXT)');
    sql.execute("INSERT INTO admins VALUES (7,'manager','test-secret','OFFICE001')");
    sql.execute('''CREATE TABLE supply_requests (
      requestId TEXT PRIMARY KEY, userId TEXT, itemId INTEGER, qty INTEGER,
      stationId TEXT, lat REAL, lng REAL, address TEXT, status TEXT,
      createdAt TEXT, receiverAdminId TEXT, hopCount INTEGER, receivedAt TEXT,
      volunteerId TEXT, claimedAt TEXT, completedAt TEXT
    )''');
    sql.execute("INSERT INTO supply_requests (requestId,userId,itemId,qty,stationId,status,receiverAdminId) VALUES ('R1','U001',1,3,'OFFICE001','reserved','7')");
    DatabaseService.ensureSupplyRequestSchema(sql);
    db = DatabaseService(sql);
    DatabaseService.instance = db;
    service = SupplyRequestService(db);
  });
  tearDown(() => sql.dispose());

  Map<String, Object?> row() => Map<String, Object?>.from(sql.select("SELECT * FROM supply_requests WHERE requestId='R1'").single);
  List<Object?> stock() => sql.select("SELECT stockQty,reservedQty FROM station_inventory WHERE stationId='OFFICE001' AND itemId=1").single.values.toList();
  Future<void> claim() => service.claimSupplyRequest(requestId: 'R1', volunteerId: 'V001', stationId: 'OFFICE001');
  Future<Map<String, Object?>> assign() => service.assignSupplyRequestVolunteer(requestId: 'R1', volunteerId: 'V002', adminId: 7);

  test('安全 Token 綁定管理員、到期拒絕、重啟失效', () {
    var now = DateTime.utc(2026, 10, 20);
    final sessions = AdminSessionStore(now: () => now);
    final token = sessions.create(7);
    expect(token, matches(RegExp(r'^[0-9a-f]{64}$')));
    expect(sessions.create(7), isNot(token));
    expect(sessions.authenticate('Bearer $token')!.adminId, 7);
    expect(sessions.authenticate(null), isNull);
    expect(sessions.authenticate('Basic $token'), isNull);
    expect(sessions.authenticate('Bearer ${'0' * 64}'), isNull);
    expect(AdminSessionStore().authenticate('Bearer $token'), isNull);
    now = now.add(const Duration(hours: 8));
    expect(sessions.authenticate('Bearer $token'), isNull);
  });

  test('Migration 可重跑且舊資料保持 NULL 與原值', () {
    final before = row();
    DatabaseService.ensureSupplyRequestSchema(sql);
    expect(row(), before);
    expect(row()['assignmentType'], isNull);
    expect(row()['assignedBy'], isNull);
    expect(() => sql.execute("UPDATE supply_requests SET assignmentType='unknown'"), throwsA(isA<SqliteException>()));
  });

  test('自主認領阻擋指派與重複認領，不扣庫存', () async {
    await claim();
    expect(row()['assignmentType'], 'self_claimed');
    expect(row()['assignedBy'], isNull);
    expect(row()['claimedAt'], isNotNull);
    await expectLater(assign(), throwsException);
    await expectLater(claim(), throwsException);
    expect(row()['volunteerId'], 'V001');
    expect(stock(), [10, 3]);
  });

  test('人工指派出現在我的任務，僅取貨扣一次，完成不扣', () async {
    final result = await assign();
    expect(result['assignmentType'], 'admin_assigned');
    expect(result['assignedBy'], 7);
    await expectLater(claim(), throwsException);
    await expectLater(assign(), throwsException);
    expect(stock(), [10, 3]);
    final tasks = await service.getVolunteerClaims(volunteerId: 'V002', stationId: 'OFFICE001');
    expect(tasks.single['volunteerId'], 'V002');
    expect(tasks.single['assignmentType'], 'admin_assigned');
    Future<dynamic> pickup() => service.dispatchSupplyRequest(requestId: 'R1', volunteerId: 'V002', stationId: 'OFFICE001');
    Future<dynamic> complete() => service.completeSupplyRequest(requestId: 'R1', volunteerId: 'V002', stationId: 'OFFICE001');
    await expectLater(complete(), throwsException);
    await pickup();
    expect(stock(), [7, 0]);
    await expectLater(pickup(), throwsException);
    await complete();
    await expectLater(complete(), throwsException);
    expect(stock(), [7, 0]);
    final details = (await db.getSupplyRequestDetails()).single;
    expect(details['completedAt'], isNotNull);
    expect(details['volunteerId'], 'V002');
    expect(details['assignmentType'], 'admin_assigned');
    expect((await db.getRequestsByAdmin('7')).single['completedAt'], details['completedAt']);
    expect((await service.getVolunteerHistory(volunteerId: 'V002', stationId: 'OFFICE001')).single['volunteerId'], 'V002');
  });

  test('取消後清除方式與管理員，允許自主認領', () async {
    await assign();
    await service.cancelClaim(requestId: 'R1', volunteerId: 'V002', stationId: 'OFFICE001');
    expect(row()['assignmentType'], isNull);
    expect(row()['assignedBy'], isNull);
    expect(stock(), [10, 3]);
    await claim();
    expect(row()['assignmentType'], 'self_claimed');
  });

  test('未預留、其他據點、既有認領者、不存在管理員與空 ID 拒絕', () async {
    for (final update in ["status='pending'", "status='reserved',stationId='S001'", "stationId='OFFICE001',volunteerId='VOLD'"]) {
      sql.execute('UPDATE supply_requests SET $update');
      await expectLater(assign(), throwsException);
    }
    sql.execute("UPDATE supply_requests SET volunteerId=NULL");
    await expectLater(service.assignSupplyRequestVolunteer(requestId: 'R1', volunteerId: 'V002', adminId: 999), throwsException);
    await expectLater(service.assignSupplyRequestVolunteer(requestId: 'R1', volunteerId: ' ', adminId: 7), throwsException);
    expect(stock(), [10, 3]);
  });

  test('指派後庫存不足拒絕取貨，回滾狀態與庫存', () async {
    await assign();
    sql.execute("UPDATE station_inventory SET stockQty=2 WHERE stationId='OFFICE001' AND itemId=1");
    await expectLater(service.dispatchSupplyRequest(requestId: 'R1', volunteerId: 'V002', stationId: 'OFFICE001'), throwsException);
    expect(row()['status'], 'claimed');
    expect(stock(), [2, 3]);
  });

  test('獨立連線競爭自主認領與人工指派只有一方成功，重新開啟保留', () async {
    final directory = await Directory.systemTemp.createTemp('cares_assignment_');
    final path = '${directory.path}/test.db';
    sql.execute('VACUUM INTO ?', [path]);
    try {
      final results = await Future.wait([raceAssignment(path, false), raceAssignment(path, true)]);
      expect(results.where((value) => value), hasLength(1));
      final reopened = sqlite3.open(path);
      try {
        final saved = reopened.select('SELECT * FROM supply_requests').single;
        expect(saved['status'], 'claimed');
        expect(saved['assignmentType'], results.first ? 'self_claimed' : 'admin_assigned');
        expect(reopened.select("SELECT stockQty FROM station_inventory WHERE stationId='OFFICE001' AND itemId=1").single['stockQty'], 10);
      } finally {
        reopened.dispose();
      }
    } finally {
      await directory.delete(recursive: true);
    }
  });

  test('HTTP 登入格式、Token 權限、偽造 adminId、指派與既有認領相容', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final listener = server.listen(api.handleRequest);
    final client = HttpClient();
    Future<(int, Map<String, dynamic>)> post(Map<String, dynamic> body, [String? auth]) async {
      final request = await client.postUrl(Uri.parse('http://127.0.0.1:${server.port}'));
      request.headers.contentType = ContentType.json;
      if (auth != null) request.headers.set('Authorization', auth);
      request.write(jsonEncode(body));
      final response = await request.close();
      expect(response.headers.value('Access-Control-Allow-Headers'), contains('Authorization'));
      return (response.statusCode, jsonDecode(await utf8.decoder.bind(response).join()) as Map<String, dynamic>);
    }
    final body = {'type': 'assignSupplyRequestVolunteer', 'requestId': 'R1', 'volunteerId': 'V002', 'adminId': 999};
    try {
      expect((await post(body)).$1, 401);
      expect((await post(body, 'Bearer ${'0' * 64}')).$1, 401);
      expect((await post({'type': 'login', 'username': 'manager', 'password': 'wrong'})).$1, 403);
      final login = await post({'type': 'login', 'username': 'manager', 'password': 'test-secret'});
      expect(login.$1, 200);
      expect(login.$2.keys, containsAll(['success', 'token', 'username', 'zoneId']));
      final auth = 'Bearer ${login.$2['token']}';
      expect((await post({...body, 'stationId': 'S001'}, auth)).$1, 400);
      expect((await post({...body, 'volunteerId': ''}, auth)).$1, 400);
      final assigned = await post(body, auth);
      expect(assigned.$1, 200);
      expect((assigned.$2['data'] as Map)['assignedBy'], 7);
      expect((await post(body, auth)).$1, 409);
      final claims = await post({'type': 'getVolunteerClaims', 'volunteerId': 'V002', 'stationId': 'OFFICE001'});
      expect((claims.$2['data'] as List).single['assignmentType'], 'admin_assigned');
      final self = {'type': 'claimSupplyRequest', 'requestId': 'R1', 'volunteerId': 'V001', 'stationId': 'OFFICE001'};
      expect((await post(self)).$2['success'], false);
      await service.cancelClaim(requestId: 'R1', volunteerId: 'V002', stationId: 'OFFICE001');
      final claimed = await post(self);
      expect(claimed.$1, 200);
      expect(claimed.$2['requestId'], 'R1');
      expect(claimed.$2['volunteerId'], 'V001');
      expect(row()['assignmentType'], 'self_claimed');
      sql.execute('DELETE FROM admins WHERE id=7');
      expect((await post(body, auth)).$1, 403);
    } finally {
      client.close(force: true);
      await listener.cancel();
      await server.close(force: true);
    }
  });
}
