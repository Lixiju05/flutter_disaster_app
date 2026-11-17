import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'package:admin_server/core/models/supply_request.dart';
import 'package:admin_server/database/database_service.dart';
import 'package:admin_server/services/supply/supply_request_service.dart';
import 'package:admin_server/services/supply/allocation_service.dart';
import 'package:admin_server/services/supply/dispatch_service.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';
import '../bin/admin_server.dart' as api;
import 'office_inventory_test.dart' show createFixture;

Future<bool> isolatedRequestAction(String path, String action) async {
  final connection = sqlite3.open(path);
  connection.execute('PRAGMA busy_timeout = 5000');
  final service = SupplyRequestService(DatabaseService(connection));
  try {
    if (action == 'reserve') {
      await service.autoAssignSupplyRequest(requestId: 'R1');
    } else if (action == 'claim') {
      await service.claimSupplyRequest(
        requestId: 'R1',
        volunteerId: 'V001',
        stationId: 'OFFICE001',
      );
    } else if (action == 'dispatch') {
      await service.dispatchSupplyRequest(
        requestId: 'R1',
        volunteerId: 'V001',
        stationId: 'OFFICE001',
      );
    } else {
      await service.completeSupplyRequest(
        requestId: 'R1',
        volunteerId: 'V001',
        stationId: 'OFFICE001',
      );
    }
    return true;
  } on Exception {
    return false;
  } finally {
    connection.dispose();
  }
}

// Keep the isolate closure outside main(), so it captures only strings,
// never the parent test's native SQLite connection.
Future<bool> runIsolatedRequest(String path, String action) =>
    Isolate.run(() => isolatedRequestAction(path, action));

void main() {
  late Database sql;
  late DatabaseService db;
  late SupplyRequestService service;
  setUp(() {
    sql = sqlite3.openInMemory();
    createFixture(sql);
    sql.execute(
      "UPDATE station_inventory SET stockQty=10,reservedQty=0 WHERE stationId='OFFICE001' AND itemId=1",
    );
    sql.execute('''CREATE TABLE supply_requests (
      id INTEGER PRIMARY KEY AUTOINCREMENT, requestId TEXT UNIQUE, userId TEXT,
      itemId INTEGER, qty INTEGER, stationId TEXT, lat REAL, lng REAL, address TEXT,
      status TEXT, createdAt TEXT, receiverAdminId TEXT, hopCount INTEGER DEFAULT 0,
      receivedAt TEXT, volunteerId TEXT, claimedAt TEXT, completedAt TEXT
    )''');
    sql.execute('''CREATE TABLE allocations (
      id INTEGER PRIMARY KEY AUTOINCREMENT, itemId INTEGER, zoneId TEXT,
      quantity INTEGER, status TEXT, createdAt TEXT
    )''');
    DatabaseService.ensureSupplyRequestSchema(sql);
    db = DatabaseService(sql);
    DatabaseService.instance = db;
    service = SupplyRequestService(db);
  });
  tearDown(() => sql.dispose());
  Future<void> create(String id, {int qty = 3}) => db.insertSupplyRequest(
    SupplyRequest(
      requestId: id,
      // Distinct citizens keep inventory/concurrency tests independent of duplicate review rules.
      userId: 'U$id',
      itemId: 1,
      qty: qty,
      createdAt: DateTime.utc(2026, 10, 20),
    ),
  );
  Map<String, Object?> row(String id) => Map<String, Object?>.from(
    sql.select('SELECT * FROM supply_requests WHERE requestId=?', [id]).single,
  );
  List<int> stock() {
    final r = sql
        .select(
          "SELECT stockQty,reservedQty FROM station_inventory WHERE stationId='OFFICE001' AND itemId=1",
        )
        .single;
    return [r['stockQty'] as int, r['reservedQty'] as int];
  }

  Future<void> claim(String id) => service.claimSupplyRequest(
    requestId: id,
    volunteerId: 'V001',
    stationId: 'OFFICE001',
  );
  Future<Map<String, dynamic>> dispatch(String id) =>
      service.dispatchSupplyRequest(
        requestId: id,
        volunteerId: 'V001',
        stationId: 'OFFICE001',
      );
  Future<Map<String, dynamic>> complete(String id) =>
      service.completeSupplyRequest(
        requestId: id,
        volunteerId: 'V001',
        stationId: 'OFFICE001',
      );

  test('新需求寫入 OFFICE001，無 GPS 可預留且回應欄位保留', () async {
    await create('R1');
    expect(row('R1')['stationId'], 'OFFICE001');
    final result = await service.autoAssignSupplyRequest(requestId: 'R1');
    expect(result.keys.toSet(), {
      'requestId',
      'stationId',
      'stationName',
      'distanceKm',
      'availableQtyBeforeReserve',
      'status',
    });
    expect(result['stationId'], 'OFFICE001');
    expect(result['distanceKm'], isNull);
    expect(result['availableQtyBeforeReserve'], 10);
    expect(row('R1')['status'], 'reserved');
    expect(stock(), [10, 3]);
    final details = (await db.getSupplyRequestDetails()).single;
    expect(details['stationId'], 'OFFICE001');
    expect(details['stationName'], '管理中心');
    expect(
      (await service.getPendingSupplyRequests(
        stationId: 'OFFICE001',
      )).single['requestId'],
      'R1',
    );
  });

  test('預留／認領／取消／取貨／完成，只有取貨扣一次', () async {
    await create('R1');
    await service.reserveSupplyRequest(requestId: 'R1');
    expect(stock(), [10, 3]);
    await claim('R1');
    expect(stock(), [10, 3]);
    await service.cancelClaim(
      requestId: 'R1',
      volunteerId: 'V001',
      stationId: 'OFFICE001',
    );
    expect(row('R1')['status'], 'reserved');
    expect(row('R1')['volunteerId'], isNull);
    expect(stock(), [10, 3]);
    await claim('R1');
    final taken = await dispatch('R1');
    expect(taken.keys.toSet(), {
      'requestId',
      'stationId',
      'itemId',
      'itemName',
      'unit',
      'qty',
      'status',
    });
    expect(stock(), [7, 0]);
    expect(
      (await service.getVolunteerClaims(
        volunteerId: 'V001',
        stationId: 'OFFICE001',
      )).single['status'],
      'dispatched',
    );
    expect(await complete('R1'), {'requestId': 'R1', 'status': 'completed'});
    expect(stock(), [7, 0]);
    expect(row('R1')['completedAt'], isNotNull);
    expect(
      (await service.getVolunteerHistory(
        volunteerId: 'V001',
        stationId: 'OFFICE001',
      )).single['completedAt'],
      row('R1')['completedAt'],
    );
    expect(
      (await service.getVolunteerClaims(
        volunteerId: 'V001',
        stationId: 'OFFICE001',
      )).single['status'],
      'completed',
    );
  });

  test('重複預留、認領、取貨、完成與跳階均拒絕', () async {
    await create('R1');
    await service.reserveSupplyRequest(requestId: 'R1');
    await expectLater(
      service.reserveSupplyRequest(requestId: 'R1'),
      throwsException,
    );
    await expectLater(
      service.autoAssignSupplyRequest(requestId: 'R1'),
      throwsException,
    );
    await expectLater(dispatch('R1'), throwsException);
    await expectLater(complete('R1'), throwsException);
    await claim('R1');
    await expectLater(claim('R1'), throwsException);
    await dispatch('R1');
    await expectLater(dispatch('R1'), throwsException);
    await complete('R1');
    final finishedAt = row('R1')['completedAt'];
    await expectLater(complete('R1'), throwsException);
    expect(row('R1')['completedAt'], finishedAt);
    expect(stock(), [7, 0]);
  });

  test('可用不足不預留，實際量／預留量不足不取貨', () async {
    await create('too-much', qty: 11);
    await expectLater(
      service.autoAssignSupplyRequest(requestId: 'too-much'),
      throwsException,
    );
    expect(row('too-much')['status'], 'pending');
    expect(stock(), [10, 0]);
    await create('R1');
    await service.reserveSupplyRequest(requestId: 'R1');
    await claim('R1');
    sql.execute(
      "UPDATE station_inventory SET stockQty=2 WHERE stationId='OFFICE001'",
    );
    await expectLater(dispatch('R1'), throwsException);
    expect(row('R1')['status'], 'claimed');
    expect(stock(), [2, 3]);
    sql.execute(
      "UPDATE station_inventory SET stockQty=10,reservedQty=2 WHERE stationId='OFFICE001'",
    );
    await expectLater(dispatch('R1'), throwsException);
    expect(stock(), [10, 2]);
  });

  test('並行預留與取貨不重複扣量，也不超額預留', () async {
    Future<bool> accepted(Future<dynamic> f) =>
        f.then((_) => true, onError: (_) => false);
    await create('R1', qty: 7);
    await create('R2', qty: 7);
    final reserved = await Future.wait([
      accepted(service.autoAssignSupplyRequest(requestId: 'R1')),
      accepted(service.autoAssignSupplyRequest(requestId: 'R2')),
      accepted(service.reserveSupplyRequest(requestId: 'R1')),
    ]);
    expect(reserved.where((v) => v).length, 1);
    expect(stock(), [10, 7]);
    await claim('R1');
    final taken = await Future.wait([
      accepted(dispatch('R1')),
      accepted(dispatch('R1')),
    ]);
    expect(taken.where((v) => v).length, 1);
    expect(stock(), [3, 0]);
    final done = await Future.wait([
      accepted(complete('R1')),
      accepted(complete('R1')),
    ]);
    expect(done.where((v) => v).length, 1);
  });

  test('獨立 SQLite 連線競爭同張需求，預留／取貨／完成各只成功一次', () async {
    await create('R1');
    final directory = await Directory.systemTemp.createTemp(
      'office_request_concurrency_',
    );
    final path = '${directory.path}/requests_test.db';
    sql.execute('VACUUM INTO ?', [path]);
    for (final action in ['reserve', 'dispatch', 'complete']) {
      if (action == 'dispatch') {
        expect(await isolatedRequestAction(path, 'claim'), true);
      }
      final results = await Future.wait([
        runIsolatedRequest(path, action),
        runIsolatedRequest(path, action),
      ]);
      expect(results.where((accepted) => accepted).length, 1, reason: action);
    }
    final persisted = sqlite3.open(path, mode: OpenMode.readOnly);
    try {
      final stock = persisted
          .select(
            "SELECT stockQty,reservedQty FROM station_inventory WHERE stationId='OFFICE001' AND itemId=1",
          )
          .single;
      expect(stock['stockQty'], 7);
      expect(stock['reservedQty'], 0);
      expect(
        persisted
            .select("SELECT status FROM supply_requests WHERE requestId='R1'")
            .single['status'],
        'completed',
      );
    } finally {
      persisted.dispose();
    }
  });

  test('SQL 失敗回滾預留／取貨，不部分更新庫存', () async {
    await create('R1');
    sql.execute(
      "CREATE TRIGGER reject_request BEFORE UPDATE ON supply_requests BEGIN SELECT RAISE(ABORT,'test'); END",
    );
    await expectLater(
      service.autoAssignSupplyRequest(requestId: 'R1'),
      throwsA(isA<SqliteException>()),
    );
    expect(stock(), [10, 0]);
    expect(row('R1')['status'], 'pending');
    sql.execute('DROP TRIGGER reject_request');
    await service.reserveSupplyRequest(requestId: 'R1');
    await claim('R1');
    sql.execute(
      "CREATE TRIGGER reject_request BEFORE UPDATE ON supply_requests BEGIN SELECT RAISE(ABORT,'test'); END",
    );
    await expectLater(dispatch('R1'), throwsA(isA<SqliteException>()));
    expect(stock(), [10, 3]);
    expect(row('R1')['status'], 'claimed');
  });

  test('錯誤義工或據點不能取貨，舊任務保留原據點', () async {
    await create('R1');
    await service.reserveSupplyRequest(requestId: 'R1');
    await expectLater(
      service.claimSupplyRequest(
        requestId: 'R1',
        volunteerId: 'V001',
        stationId: 'S001',
      ),
      throwsException,
    );
    await claim('R1');
    await expectLater(
      service.dispatchSupplyRequest(
        requestId: 'R1',
        volunteerId: 'V002',
        stationId: 'OFFICE001',
      ),
      throwsException,
    );
    await expectLater(
      service.dispatchSupplyRequest(
        requestId: 'R1',
        volunteerId: 'V001',
        stationId: 'S001',
      ),
      throwsException,
    );
    sql.execute(
      "INSERT INTO supply_requests (requestId,userId,itemId,qty,stationId,status,volunteerId) VALUES ('OLD','U001',1,2,'S001','claimed','VOLD')",
    );
    await service.dispatchSupplyRequest(
      requestId: 'OLD',
      volunteerId: 'VOLD',
      stationId: 'S001',
    );
    await service.completeSupplyRequest(
      requestId: 'OLD',
      volunteerId: 'VOLD',
      stationId: 'S001',
    );
    expect(row('OLD')['stationId'], 'S001');
    expect(row('OLD')['status'], 'completed');
    expect(stock(), [10, 3]);
    await create('old-pending');
    sql.execute(
      "UPDATE supply_requests SET stationId='S002' WHERE requestId='old-pending'",
    );
    await expectLater(
      service.autoAssignSupplyRequest(requestId: 'old-pending'),
      throwsException,
    );
    expect(row('old-pending')['stationId'], 'S002');
  });

  test('舊寫入預設封鎖，明確開關可恢復 DB 與 Service', () async {
    await expectLater(
      db.allocate(itemId: 1, zoneId: 'S001', qty: 1),
      throwsA(isA<InventoryException>()),
    );
    await expectLater(
      db.dispatch(allocationId: 1),
      throwsA(isA<InventoryException>()),
    );
    await expectLater(
      AllocationService(db).allocate(itemId: 1, zoneId: 'S001', qty: 1),
      throwsA(isA<InventoryException>()),
    );
    await expectLater(
      AllocationService(db).cancelAllocation(1),
      throwsA(isA<InventoryException>()),
    );
    await expectLater(
      DispatchService(db).dispatch(allocationId: 1),
      throwsA(isA<InventoryException>()),
    );
    final legacy = DatabaseService(sql, allowLegacyInventoryWrites: true);
    await legacy.allocate(itemId: 1, zoneId: 'S001', qty: 1);
    await legacy.dispatch(allocationId: 1);
    expect(
      sql
          .select('SELECT stockQty FROM inventory WHERE id=1')
          .single['stockQty'],
      998,
    );
    expect(stock(), [10, 0]);
  });

  test('HTTP 新需求覆寫傳入據點，查詢／義工操作格式相容與舊 API 409', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final subscription = server.listen(api.handleRequest);
    final client = HttpClient();
    Future<(int, Map<String, dynamic>)> post(Map<String, dynamic> body) async {
      final request = await client.postUrl(
        Uri.parse('http://127.0.0.1:${server.port}'),
      );
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(body));
      final response = await request.close();
      return (
        response.statusCode,
        jsonDecode(await utf8.decoder.bind(response).join())
            as Map<String, dynamic>,
      );
    }

    Future<(int, Map<String, dynamic>)> step(String type) => post({
      'type': type,
      'requestId': 'HTTP',
      'volunteerId': 'V001',
      'stationId': 'OFFICE001',
    });
    try {
      final created = await post({
        'type': 'addSupplyRequest',
        'requestId': 'HTTP',
        'userId': 'U001',
        'itemId': 1,
        'qty': 3,
        'stationId': 'S002',
      });
      expect(created.$1, 200);
      expect(created.$2, {'success': true, 'message': 'request saved'});
      expect(row('HTTP')['stationId'], 'OFFICE001');
      expect((await step('autoAssignSupplyRequest')).$1, 200);
      expect((await step('reserveSupplyRequest')).$2['success'], false);
      final claimed = await step('claimSupplyRequest');
      expect(claimed.$1, 200);
      expect(claimed.$2.keys.toSet(), {
        'success',
        'message',
        'requestId',
        'volunteerId',
      });
      expect(stock(), [10, 3]);
      expect(
        (await step('dispatchSupplyRequest')).$2['data']['status'],
        'dispatched',
      );
      expect((await step('dispatchSupplyRequest')).$2['success'], false);
      final mine = await post({
        'type': 'getVolunteerClaims',
        'volunteerId': 'V001',
        'stationId': 'OFFICE001',
      });
      expect((mine.$2['data'] as List).single['status'], 'dispatched');
      expect(
        (await step('completeSupplyRequest')).$2['data']['status'],
        'completed',
      );
      expect((await step('completeSupplyRequest')).$2['success'], false);
      expect(stock(), [7, 0]);
      final details = await post({'type': 'getSupplyRequestDetails'});
      expect((details.$2['data'] as List).single['stationId'], 'OFFICE001');
      for (final type in ['allocate', 'dispatch', 'cancelAllocation']) {
        final blocked = await post({
          'type': type,
          'itemId': 1,
          'zoneId': 'S001',
          'qty': 1,
          'allocationId': 1,
        });
        expect(blocked.$1, 409);
        expect(blocked.$2['success'], false);
      }
      for (final type in ['getAllocations', 'getDispatches']) {
        expect((await post({'type': type})).$1, 200);
      }
      expect(sql.select('SELECT * FROM allocations'), isEmpty);
      expect(
        sql
            .select('SELECT stockQty FROM inventory WHERE id=1')
            .single['stockQty'],
        999,
      );
      expect(
        (await post({
          'type': 'addSupplyRequest',
          'requestId': 'bad',
          'userId': 'U001',
          'itemId': 1,
          'qty': -1,
        })).$1,
        400,
      );
      expect(
        sql.select("SELECT * FROM supply_requests WHERE requestId='bad'"),
        isEmpty,
      );
    } finally {
      client.close(force: true);
      await subscription.cancel();
      await server.close(force: true);
    }
  });
}
