import 'dart:convert';
import 'dart:io';
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';
import 'package:admin_server/database/database_service.dart';
import 'package:admin_server/services/supply/station_transfer_service.dart';
import '../bin/admin_server.dart' as api;

void main() {
  late Database sql;
  late StationTransferService service;
  Map<String, Object?> create({
    int qty = 10,
    String to = 'S001',
    int item = 1,
    String from = 'OFFICE001',
  }) => service.create(
    fromStationId: from,
    toStationId: to,
    itemId: item,
    qty: qty,
    createdBy: 'admin_ncnu',
  );
  List<int> stock(String station) {
    final row = sql.select(
      'SELECT stockQty, reservedQty FROM station_inventory WHERE stationId = ? AND itemId = 1',
      [station],
    ).first;
    return [row['stockQty'] as int, row['reservedQty'] as int];
  }

  setUp(() {
    sql = sqlite3.openInMemory();
    sql.execute('PRAGMA foreign_keys = ON');
    sql.execute(
      'CREATE TABLE stations (stationId TEXT PRIMARY KEY, name TEXT, type TEXT)',
    );
    sql.execute(
      "INSERT INTO stations VALUES ('OFFICE001','物資中心','office'),('S001','A','shelter'),('S002','B','shelter')",
    );
    sql.execute(
      'CREATE TABLE inventory (id INTEGER PRIMARY KEY, name TEXT, unit TEXT, stockQty INTEGER)',
    );
    sql.execute("INSERT INTO inventory VALUES (1,'泡麵','箱',70)");
    sql.execute(
      'CREATE TABLE station_inventory (stationId TEXT, itemId INTEGER, stockQty INTEGER, reservedQty INTEGER, updatedAt TEXT, PRIMARY KEY(stationId,itemId))',
    );
    sql.execute(
      "INSERT INTO station_inventory VALUES ('OFFICE001',1,50,0,'before'),('S001',1,20,5,'before')",
    );
    DatabaseService.createStationTransferSchema(sql);
    DatabaseService.instance = DatabaseService(sql);
    service = StationTransferService(DatabaseService.instance);
  });
  tearDown(() => sql.dispose());

  test('調度資料表完整建立且重複遷移不清除資料', () {
    final columns = sql.select('PRAGMA table_info(station_transfers)');
    expect(columns.map((r) => r['name']).toSet(), {
      'transferId',
      'fromStationId',
      'toStationId',
      'itemId',
      'qty',
      'status',
      'createdBy',
      'createdAt',
      'shippedAt',
      'receivedAt',
    });
    expect(columns.singleWhere((r) => r['name'] == 'transferId')['pk'], 1);
    final id = create()['transferId'];
    DatabaseService.createStationTransferSchema(sql);
    expect(
      sql
          .select('SELECT transferId FROM station_transfers')
          .single['transferId'],
      id,
    );
  });

  test('據點庫存讀取名稱、單位與可用量，隔離據點且收貨後同步', () {
    final before = service.getStationInventory('S001').single;
    expect(before['stationId'], 'S001');
    expect(before['itemId'], 1);
    expect(before['itemName'], '泡麵');
    expect(before['unit'], '箱');
    expect(before['stockQty'], 20);
    expect(before['reservedQty'], 5);
    expect(before['availableQty'], 15);
    expect(service.getStationInventory('S002'), isEmpty);
    expect(
      () => service.getStationInventory('missing'),
      throwsA(isA<StationTransferException>()),
    );
    expect(
      () => service.getStationInventory(''),
      throwsA(isA<StationTransferException>()),
    );
    final id = create()['transferId'] as String;
    service.ship(id);
    expect(service.getStationInventory('S001').single['stockQty'], 20);
    service.receive(id);
    final after = service.getStationInventory('S001').single;
    expect(after['stockQty'], 30);
    expect(after['reservedQty'], 5);
    expect(after['availableQty'], 25);
    expect(service.getStationInventory('OFFICE001').single['stockQty'], 40);
  });

  test('完整流程只在正確階段變更庫存，保留目的預留量', () async {
    final id = create()['transferId'] as String;
    expect(stock('OFFICE001'), [50, 10]);
    expect(stock('S001'), [20, 5]);
    final shipped = service.ship(id);
    expect(shipped['shippedAt'], isNotNull);
    expect(stock('OFFICE001'), [40, 0]);
    expect(stock('S001'), [20, 5]);
    final received = service.receive(id);
    expect(received['status'], 'received');
    expect(received['receivedAt'], isNotNull);
    expect(stock('S001'), [30, 5]);
    expect(stock('OFFICE001'), [40, 0]);
    expect(sql.select('SELECT stockQty FROM inventory').first['stockQty'], 70);
    expect(
      (await service.getTransfers(
        stationId: 'S001',
        status: 'received',
      )).length,
      1,
    );
  });
  test('不足、非法數量、據點、物資不建立調度', () {
    for (final action in <void Function()>[
      () => create(qty: 51),
      () => create(qty: 0),
      () => create(qty: -1),
      () => create(to: 'OFFICE001'),
      () => create(to: 'MISSING'),
      () => create(item: 999),
      () => create(from: 'S001'),
    ]) {
      expect(action, throwsA(isA<StationTransferException>()));
    }
    expect(stock('OFFICE001'), [50, 0]);
    expect(sql.select('SELECT * FROM station_transfers'), isEmpty);
    sql.execute("DELETE FROM stations WHERE stationId = 'S002'");
    expect(() => create(to: 'S002'), throwsA(isA<StationTransferException>()));
  });
  test('已預留量不可再被其他調度使用', () {
    create(qty: 40);
    expect(() => create(qty: 11), throwsA(isA<StationTransferException>()));
    expect(stock('OFFICE001'), [50, 40]);
  });
  test('拒絕提前收貨及重複出貨／收貨', () {
    final id = create()['transferId'] as String;
    expect(() => service.receive(id), throwsA(isA<StationTransferException>()));
    service.ship(id);
    expect(() => service.ship(id), throwsA(isA<StationTransferException>()));
    service.receive(id);
    expect(() => service.receive(id), throwsA(isA<StationTransferException>()));
    expect(stock('OFFICE001'), [40, 0]);
    expect(stock('S001'), [30, 5]);
    expect(
      () => service.ship('missing'),
      throwsA(isA<StationTransferException>()),
    );
  });
  test('目的據點無該品項時收貨建立庫存', () {
    final id = create(to: 'S002')['transferId'] as String;
    service.ship(id);
    service.receive(id);
    expect(stock('S002'), [10, 0]);
  });
  test('庫存不足出貨失敗，狀態不改變', () {
    final id = create()['transferId'] as String;
    sql.execute(
      "UPDATE station_inventory SET stockQty = 5 WHERE stationId = 'OFFICE001'",
    );
    expect(() => service.ship(id), throwsA(isA<StationTransferException>()));
    expect(
      (sql.select('SELECT status FROM station_transfers').first)['status'],
      'reserved',
    );
    expect(stock('OFFICE001'), [5, 10]);
  });
  test('中途 SQL 失敗會回滾建立、出貨及收貨庫存', () {
    sql.execute(
      "CREATE TRIGGER reject_insert BEFORE INSERT ON station_transfers BEGIN SELECT RAISE(ABORT, 'test'); END",
    );
    expect(() => create(), throwsA(isA<SqliteException>()));
    expect(stock('OFFICE001'), [50, 0]);
    sql.execute('DROP TRIGGER reject_insert');
    final id = create()['transferId'] as String;
    sql.execute(
      "CREATE TRIGGER reject_update BEFORE UPDATE ON station_transfers BEGIN SELECT RAISE(ABORT, 'test'); END",
    );
    expect(() => service.ship(id), throwsA(isA<SqliteException>()));
    expect(stock('OFFICE001'), [50, 10]);
    sql.execute('DROP TRIGGER reject_update');
    service.ship(id);
    sql.execute(
      "CREATE TRIGGER reject_update BEFORE UPDATE ON station_transfers BEGIN SELECT RAISE(ABORT, 'test'); END",
    );
    expect(() => service.receive(id), throwsA(isA<SqliteException>()));
    expect(stock('S001'), [20, 5]);
    expect(
      sql.select('SELECT status FROM station_transfers').first['status'],
      'shipped',
    );
  });
  test('遷移可重複執行，篩選及歷史保持完整', () async {
    create();
    DatabaseService.createStationTransferSchema(sql);
    expect((await service.getTransfers()).length, 1);
    expect(await service.getTransfers(stationId: 'S002'), isEmpty);
    await expectLater(
      service.getTransfers(status: 'bad'),
      throwsA(isA<StationTransferException>()),
    );
    await expectLater(
      service.getTransfers(stationId: 'missing'),
      throwsA(isA<StationTransferException>()),
    );
  });
  test('POST 路由建立、出貨、收貨、查詢及輸入錯誤', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final subscription = server.listen(api.handleRequest);
    final client = HttpClient();
    Future<(int, Map<String, dynamic>)> post(Map<String, dynamic> body) async {
      final req = await client.postUrl(
        Uri.parse('http://127.0.0.1:${server.port}'),
      );
      req.headers.contentType = ContentType.json;
      req.write(jsonEncode(body));
      final res = await req.close();
      return (
        res.statusCode,
        jsonDecode(await utf8.decoder.bind(res).join()) as Map<String, dynamic>,
      );
    }

    try {
      Future<void> verifyStock(
        String station,
        int actual,
        int reserved,
        int available,
      ) async {
        final response = await post({
          'type': 'getStationInventory',
          'stationId': station,
        });
        expect(response.$1, 200);
        expect(response.$2['success'], true);
        final row =
            (response.$2['data'] as List).single as Map<String, dynamic>;
        expect(row['stationId'], station);
        expect(row['itemName'], '泡麵');
        expect(row['unit'], '箱');
        expect(row['stockQty'], actual);
        expect(row['reservedQty'], reserved);
        expect(row['availableQty'], available);
        expect(stock(station), [actual, reserved]);
      }

      await verifyStock('OFFICE001', 50, 0, 50);
      await verifyStock('S001', 20, 5, 15);
      final insufficient = await post({
        'type': 'createStationTransfer',
        'toStationId': 'S001',
        'itemId': 1,
        'qty': 51,
        'createdBy': 'admin_ncnu',
      });
      expect(insufficient.$1, 409);
      expect(insufficient.$2['success'], false);
      expect(sql.select('SELECT * FROM station_transfers'), isEmpty);
      await verifyStock('OFFICE001', 50, 0, 50);
      final result = await post({
        'type': 'createStationTransfer',
        'toStationId': 'S001',
        'itemId': 1,
        'qty': 10,
        'createdBy': 'admin_ncnu',
      });
      expect(result.$1, 200);
      expect(result.$2['data']['status'], 'reserved');
      final id = result.$2['data']['transferId'];
      await verifyStock('OFFICE001', 50, 10, 40);
      await verifyStock('S001', 20, 5, 15);
      expect(
        (await post({'type': 'receiveStationTransfer', 'transferId': id})).$1,
        409,
      );
      expect(
        (await post({'type': 'shipStationTransfer', 'transferId': id})).$1,
        200,
      );
      await verifyStock('OFFICE001', 40, 0, 40);
      await verifyStock('S001', 20, 5, 15);
      final repeatedShip = await post({
        'type': 'shipStationTransfer',
        'transferId': id,
      });
      expect(repeatedShip.$1, 409);
      expect(repeatedShip.$2['success'], false);
      await verifyStock('OFFICE001', 40, 0, 40);
      expect(
        (await post({'type': 'receiveStationTransfer', 'transferId': id})).$1,
        200,
      );
      expect(
        (await post({'type': 'receiveStationTransfer', 'transferId': id})).$1,
        409,
      );
      await verifyStock('OFFICE001', 40, 0, 40);
      await verifyStock('S001', 30, 5, 25);
      final absent = await post({
        'type': 'getStationInventory',
        'stationId': 'missing',
      });
      expect(absent.$1, 404);
      expect(absent.$2['success'], false);
      final empty = await post({
        'type': 'getStationInventory',
        'stationId': 'S002',
      });
      expect(empty.$1, 200);
      expect(empty.$2['data'], isEmpty);
      for (final station in [null, '', 1]) {
        expect(
          (await post({
            'type': 'getStationInventory',
            'stationId': station,
          })).$1,
          400,
        );
      }
      final list = await post({
        'type': 'getStationTransfers',
        'stationId': 'S001',
        'status': 'received',
      });
      expect((list.$2['data'] as List).length, 1);
      for (final qty in [0, -1, 1.5, '10', null]) {
        final bad = await post({
          'type': 'createStationTransfer',
          'toStationId': 'S001',
          'itemId': 1,
          'qty': qty,
          'createdBy': 'admin_ncnu',
        });
        expect(bad.$1, 400);
        expect(bad.$2['success'], false);
      }
      expect(stock('S001'), [30, 5]);
    } finally {
      client.close(force: true);
      await subscription.cancel();
      await server.close(force: true);
    }
  });
}
