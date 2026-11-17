import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'package:admin_server/core/models/supply_request.dart';
import 'package:admin_server/database/database_service.dart';
import 'package:admin_server/services/supply/supply_request_service.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';
import '../bin/admin_server.dart' as api;
import 'office_inventory_test.dart' show createFixture;

Future<bool> offlineWorker(String path, String action) => Isolate.run(() async {
  final sql = sqlite3.open(path);
  sql.execute('PRAGMA busy_timeout=5000');
  final service = SupplyRequestService(DatabaseService(sql));
  try {
    if (action == 'claim') {
      await service.claimSupplyRequest(
        requestId: 'R1', volunteerId: 'V001', stationId: 'OFFICE001',
      );
    } else if (action == 'dispatch') {
      await service.adminDispatchSupplyRequest(requestId: 'R1', adminId: 7);
    } else {
      await service.adminCompleteSupplyRequest(requestId: 'R1', adminId: 7);
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
    sql.execute("UPDATE station_inventory SET stockQty=10,reservedQty=0 WHERE stationId='OFFICE001' AND itemId=1");
    sql.execute('CREATE TABLE admins (id INTEGER PRIMARY KEY, username TEXT, password TEXT, zoneId TEXT)');
    sql.execute("INSERT INTO admins VALUES (7,'manager','test-secret','OFFICE001'),(8,'other','test-secret','OFFICE001')");
    sql.execute('''CREATE TABLE supply_requests (
      requestId TEXT PRIMARY KEY, userId TEXT, itemId INTEGER, qty INTEGER,
      stationId TEXT, lat REAL, lng REAL, address TEXT, status TEXT,
      createdAt TEXT, receiverAdminId TEXT, hopCount INTEGER, receivedAt TEXT,
      volunteerId TEXT, claimedAt TEXT, completedAt TEXT
    )''');
    DatabaseService.ensureSupplyRequestSchema(sql);
    db = DatabaseService(sql);
    DatabaseService.instance = db;
    service = SupplyRequestService(db);
  });
  tearDown(() => sql.dispose());

  Future<void> create() => db.insertSupplyRequest(SupplyRequest(
    requestId: 'R1', userId: 'U001', itemId: 1, qty: 3,
    createdAt: DateTime.utc(2026, 11, 8),
  ));
  Future<void> reserve() => service.reserveSupplyRequest(requestId: 'R1');
  Future<Map<String, Object?>> dispatch() => service.adminDispatchSupplyRequest(requestId: 'R1', adminId: 7);
  Future<Map<String, Object?>> complete() => service.adminCompleteSupplyRequest(requestId: 'R1', adminId: 8);
  Map<String, Object?> row() => Map<String, Object?>.from(sql.select("SELECT * FROM supply_requests WHERE requestId='R1'").single);
  List<Object?> stock() => sql.select("SELECT stockQty,reservedQty FROM station_inventory WHERE stationId='OFFICE001' AND itemId=1").single.values.toList();

  test('完整新流程：預留不扣實際、出庫只扣一次、完成不扣，時間與管理員保留', () async {
    await create();
    expect(row()['stationId'], 'OFFICE001');
    await expectLater(dispatch(), throwsException);
    await reserve();
    final reservedAt = row()['reservedAt'];
    expect(reservedAt, isNotNull);
    expect(stock(), [10, 3]);
    await expectLater(reserve(), throwsException);
    await expectLater(complete(), throwsException);
    final result = await dispatch();
    expect(result['status'], 'dispatched');
    expect(stock(), [7, 0]);
    expect(row()['volunteerId'], isNull);
    expect(row()['claimedAt'], isNull);
    expect(row()['assignmentType'], isNull);
    await expectLater(dispatch(), throwsException);
    final dispatchedAt = row()['dispatchedAt'];
    await complete();
    final finalRow = row();
    expect(finalRow['status'], 'completed');
    expect(finalRow['reservedAt'], reservedAt);
    expect(finalRow['dispatchedAt'], dispatchedAt);
    expect(finalRow['dispatchedBy'], 7);
    expect(finalRow['completedBy'], 8);
    expect(finalRow['completedAt'], isNotNull);
    await expectLater(complete(), throwsException);
    expect(stock(), [7, 0]);
    final details = (await db.getSupplyRequestDetails()).single;
    expect(details['dispatchedAt'], dispatchedAt);
    expect(details['completedBy'], 8);
  });

  test('出庫與結案狀態寫入失敗會回滾全部變更', () async {
    await create();
    await reserve();
    sql.execute("CREATE TRIGGER fail_dispatch BEFORE UPDATE OF status ON supply_requests WHEN NEW.status='dispatched' BEGIN SELECT RAISE(ABORT,'test rollback'); END");
    final before = row();
    await expectLater(dispatch(), throwsException);
    expect(stock(), [10, 3]);
    expect(row(), before);
    sql.execute('DROP TRIGGER fail_dispatch');
    await dispatch();
    sql.execute("CREATE TRIGGER fail_complete BEFORE UPDATE OF status ON supply_requests WHEN NEW.status='completed' BEGIN SELECT RAISE(ABORT,'test rollback'); END");
    final dispatched = row();
    await expectLater(complete(), throwsException);
    expect(row(), dispatched);
    expect(stock(), [7, 0]);
  });

  test('庫存不足、預留不足、異常數字、錯誤數量與其他據點拒絕', () async {
    await create();
    await reserve();
    for (final change in ['stockQty=2,reservedQty=3', 'stockQty=10,reservedQty=2', 'stockQty=10,reservedQty=-1', 'stockQty=10.5,reservedQty=3']) {
      sql.execute("UPDATE station_inventory SET $change WHERE stationId='OFFICE001' AND itemId=1");
      final before = stock();
      await expectLater(dispatch(), throwsException);
      expect(stock(), before);
      expect(row()['status'], 'reserved');
    }
    sql.execute("UPDATE station_inventory SET stockQty=10,reservedQty=3 WHERE stationId='OFFICE001' AND itemId=1");
    for (final qty in [0, -1, 1.5]) {
      sql.execute('UPDATE supply_requests SET qty=?', [qty]);
      await expectLater(dispatch(), throwsException);
      expect(stock(), [10, 3]);
    }
    sql.execute("UPDATE supply_requests SET qty=3,stationId='S001'");
    await expectLater(dispatch(), throwsException);
  });

  test('歷史義工認領／配送／完成及未標記的舊配送不得由新 API 改寫', () async {
    await create();
    for (final status in ['claimed', 'dispatched', 'completed']) {
      sql.execute("UPDATE supply_requests SET status=?,volunteerId='VOLD',claimedAt='old',assignmentType='self_claimed',completedAt=?", [status, status == 'completed' ? 'old-completed' : null]);
      final before = row();
      await expectLater(dispatch(), throwsException);
      await expectLater(complete(), throwsException);
      expect(row(), before);
      expect(stock(), [10, 0]);
    }
    sql.execute("UPDATE supply_requests SET status='dispatched',volunteerId=NULL,claimedAt=NULL,assignmentType=NULL,completedAt=NULL");
    final unmarked = row();
    await expectLater(complete(), throwsException);
    expect(row(), unmarked);
    DatabaseService.ensureSupplyRequestSchema(sql);
    expect(row(), unmarked);
  });

  test('異常殘留認領資料或出庫紀錄拒絕覆寫', () async {
    await create();
    await reserve();
    for (final change in ["volunteerId='VOLD'", "claimedAt='old'", "assignmentType='admin_assigned'", 'assignedBy=7', "dispatchedAt='old'", 'dispatchedBy=7', "completedAt='old'", 'completedBy=7']) {
      sql.execute('UPDATE supply_requests SET volunteerId=NULL,claimedAt=NULL,assignmentType=NULL,assignedBy=NULL,dispatchedAt=NULL,dispatchedBy=NULL,completedAt=NULL,completedBy=NULL');
      sql.execute('UPDATE supply_requests SET $change');
      final before = row();
      await expectLater(dispatch(), throwsException);
      expect(row(), before);
      expect(stock(), [10, 3]);
    }
  });

  test('舊 API 不能再認領或完成新流程出庫', () async {
    await create();
    await reserve();
    await dispatch();
    await expectLater(service.claimSupplyRequest(requestId: 'R1', volunteerId: 'V001', stationId: 'OFFICE001'), throwsException);
    await expectLater(service.completeSupplyRequest(requestId: 'R1', volunteerId: 'V001', stationId: 'OFFICE001'), throwsException);
    expect(stock(), [7, 0]);
    expect(row()['status'], 'dispatched');
  });

  test('獨立連線重複出庫與完成各僅一次，重開 SQLite 保留', () async {
    await create();
    await reserve();
    final directory = await Directory.systemTemp.createTemp('cares_offline_');
    final path = '${directory.path}/test.db';
    sql.execute('VACUUM INTO ?', [path]);
    try {
      expect((await Future.wait([offlineWorker(path, 'dispatch'), offlineWorker(path, 'dispatch')])).where((v) => v), hasLength(1));
      expect((await Future.wait([offlineWorker(path, 'complete'), offlineWorker(path, 'complete')])).where((v) => v), hasLength(1));
      final reopened = sqlite3.open(path);
      try {
        final saved = reopened.select('SELECT * FROM supply_requests').single;
        expect(saved['status'], 'completed');
        expect(saved['dispatchedBy'], 7);
        expect(saved['completedBy'], 7);
        expect(saved['dispatchedAt'], isNotNull);
        expect(saved['completedAt'], isNotNull);
        expect(reopened.select("SELECT stockQty,reservedQty FROM station_inventory WHERE stationId='OFFICE001' AND itemId=1").single.values.toList(), [7, 0]);
      } finally {
        reopened.dispose();
      }
    } finally {
      await directory.delete(recursive: true);
    }
  });

  test('獨立連線舊認領與管理員出庫競爭不會兩者成功', () async {
    await create();
    await reserve();
    final directory = await Directory.systemTemp.createTemp('cares_offline_race_');
    final path = '${directory.path}/test.db';
    sql.execute('VACUUM INTO ?', [path]);
    try {
      final results = await Future.wait([offlineWorker(path, 'dispatch'), offlineWorker(path, 'claim')]);
      expect(results.where((v) => v), hasLength(1));
      final reopened = sqlite3.open(path);
      try {
        expect(reopened.select('SELECT status FROM supply_requests').single['status'], results.first ? 'dispatched' : 'claimed');
        expect(reopened.select("SELECT stockQty FROM station_inventory WHERE stationId='OFFICE001' AND itemId=1").single['stockQty'], results.first ? 7 : 10);
      } finally {
        reopened.dispose();
      }
    } finally {
      await directory.delete(recursive: true);
    }
  });

  test('HTTP 登入、無 volunteerId 全流程、授權／參數拒絕及管理員稽核', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final listener = server.listen(api.handleRequest);
    final client = HttpClient();
    Future<(int, Map<String, dynamic>)> post(Map<String, dynamic> body, [String? auth]) async {
      final request = await client.postUrl(Uri.parse('http://127.0.0.1:${server.port}'));
      request.headers.contentType = ContentType.json;
      if (auth != null) request.headers.set('Authorization', auth);
      request.write(jsonEncode(body));
      final response = await request.close();
      return (response.statusCode, jsonDecode(await utf8.decoder.bind(response).join()) as Map<String, dynamic>);
    }
    try {
      final login = await post({'type': 'login', 'username': 'manager', 'password': 'test-secret'});
      expect(login.$1, 200);
      final auth = 'Bearer ${login.$2['token']}';
      final dispatchBody = {'type': 'adminDispatchSupplyRequest', 'requestId': 'R1', 'adminId': 999};
      final completeBody = {'type': 'adminCompleteSupplyRequest', 'requestId': 'R1', 'adminId': 999};
      for (final body in [dispatchBody, completeBody]) {
        expect((await post(body)).$1, 401);
        expect((await post(body, 'Bearer ${'0' * 64}')).$1, 401);
        expect((await post({...body, 'requestId': ''}, auth)).$1, 400);
        expect((await post({...body, 'stationId': 'S001'}, auth)).$1, 400);
      }
      final added = await post({'type': 'addSupplyRequest', 'requestId': 'R1', 'userId': 'U001', 'itemId': 1, 'qty': 3});
      expect(added.$2['success'], true);
      expect((await post({'type': 'reserveSupplyRequest', 'requestId': 'R1'})).$2['success'], true);
      expect((await post(completeBody, auth)).$1, 409);
      expect(stock(), [10, 3]);
      final shipped = await post(dispatchBody, auth);
      expect(shipped.$1, 200);
      expect(shipped.$2['data']['dispatchedBy'], 7);
      expect(stock(), [7, 0]);
      expect((await post(dispatchBody, auth)).$1, 409);
      final completed = await post(completeBody, auth);
      expect(completed.$1, 200);
      expect(completed.$2['data']['completedBy'], 7);
      expect((await post(completeBody, auth)).$1, 409);
      expect(stock(), [7, 0]);
      final details = await post({'type': 'getSupplyRequestDetails'});
      expect((details.$2['data'] as List).single['completedBy'], 7);
      sql.execute('DELETE FROM admins WHERE id=7');
      for (final body in [dispatchBody, completeBody]) {
        expect((await post(body, auth)).$1, 403);
      }
    } finally {
      client.close(force: true);
      await listener.cancel();
      await server.close(force: true);
    }
  });
}
