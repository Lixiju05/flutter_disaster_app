import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';
import 'package:admin_server/database/database_service.dart';
import 'package:admin_server/services/supply/station_transfer_service.dart';
import '../bin/admin_server.dart' as api;

void createFixture(Database sql) {
  sql.execute('PRAGMA foreign_keys = ON');
  sql.execute('''CREATE TABLE stations (
    stationId TEXT PRIMARY KEY, name TEXT NOT NULL, type TEXT NOT NULL,
    lat REAL NOT NULL, lng REAL NOT NULL, address TEXT
  )''');
  sql.execute(
    "INSERT INTO stations VALUES ('OFFICE001','管理中心','office',0,0,NULL),('S001','A','shelter',0,0,NULL),('S002','B','shelter',0,0,NULL)",
  );
  sql.execute('''CREATE TABLE inventory (
    id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT, category TEXT, unit TEXT,
    stockQty INTEGER DEFAULT 0, reservedQty INTEGER DEFAULT 0,
    neededQty INTEGER DEFAULT 0, updatedAt TEXT
  )''');
  sql.execute(
    "INSERT INTO inventory VALUES (1,'泡麵','食品飲水','箱',999,88,4,'old'),(2,'飲水','食品飲水','瓶',888,77,0,'old')",
  );
  sql.execute('''CREATE TABLE station_inventory (
    stationId TEXT NOT NULL, itemId INTEGER NOT NULL, stockQty INTEGER NOT NULL DEFAULT 0,
    reservedQty INTEGER NOT NULL DEFAULT 0, updatedAt TEXT NOT NULL,
    PRIMARY KEY(stationId,itemId),
    FOREIGN KEY(stationId) REFERENCES stations(stationId),
    FOREIGN KEY(itemId) REFERENCES inventory(id)
  )''');
  sql.execute(
    "INSERT INTO station_inventory VALUES ('OFFICE001',1,2,1,'old'),('S001',1,100,2,'old'),('S002',1,200,3,'old'),('S001',2,7,0,'old')",
  );
}

Future<void> concurrentInbound(String path) async {
  final connection = sqlite3.open(path);
  connection.execute('PRAGMA busy_timeout = 5000');
  try {
    final db = DatabaseService(connection);
    for (var i = 0; i < 25; i++) {
      await db.addStock(1, 1);
    }
  } finally {
    connection.dispose();
  }
}

void main() {
  late Database sql;
  late DatabaseService db;
  setUp(() {
    sql = sqlite3.openInMemory();
    createFixture(sql);
    db = DatabaseService(sql);
    DatabaseService.instance = db;
  });
  tearDown(() => sql.dispose());

  Map<String, Object?> office() => Map<String, Object?>.from(
    sql
        .select(
          "SELECT * FROM station_inventory WHERE stationId='OFFICE001' AND itemId=1",
        )
        .single,
  );

  test('查詢保留舊欄位，數量只讀 OFFICE001，缺庫存為 0', () async {
    final rows = await db.getAllInventory();
    expect(rows.first.keys.toSet(), {
      'id',
      'name',
      'category',
      'unit',
      'stockQty',
      'reservedQty',
      'availableQty',
      'neededQty',
      'updatedAt',
    });
    expect(rows.first, {
      'id': 1,
      'name': '泡麵',
      'category': '食品飲水',
      'unit': '箱',
      'stockQty': 2,
      'reservedQty': 1,
      'availableQty': 1,
      'neededQty': 4,
      'updatedAt': 'old',
    });
    expect(rows[1]['stockQty'], 0);
    expect(rows[1]['reservedQty'], 0);
    expect(rows[1]['availableQty'], 0);
  });

  test('庫存 2 入庫 3 得 5，連續入庫累加且不改預留或舊庫存', () async {
    final other = sql
        .select(
          "SELECT * FROM station_inventory WHERE stationId <> 'OFFICE001'",
        )
        .map((r) => Map<String, Object?>.from(r))
        .toList();
    final master = sql
        .select('SELECT * FROM inventory')
        .map((r) => Map<String, Object?>.from(r))
        .toList();
    await db.addStock(1, 3);
    expect(office()['stockQty'], 5);
    expect(office()['reservedQty'], 1);
    await db.addStock(1, 2);
    await db.addStock(1, 4);
    expect(office()['stockQty'], 11);
    expect((await db.getAllInventory()).first['availableQty'], 10);
    expect(
      sql
          .select('SELECT * FROM inventory')
          .map((r) => Map<String, Object?>.from(r))
          .toList(),
      master,
    );
    expect(
      sql
          .select(
            "SELECT * FROM station_inventory WHERE stationId <> 'OFFICE001'",
          )
          .map((r) => Map<String, Object?>.from(r))
          .toList(),
      other,
    );
  });

  test('同品項新增也是累加，不覆蓋舊 inventory 數量', () async {
    await db.addInventory(
      name: ' 泡麵 ',
      category: '食品飲水',
      unit: '箱',
      stockQty: 3,
      neededQty: 2,
    );
    expect(office()['stockQty'], 5);
    expect(office()['reservedQty'], 1);
    final row = sql.select('SELECT * FROM inventory WHERE id=1').single;
    expect(row['stockQty'], 999);
    expect(row['reservedQty'], 88);
    expect(row['neededQty'], 6);
    expect(sql.select('SELECT * FROM inventory').length, 2);
  });

  test('新物資主檔與 OFFICE001 同交易建立，舊數量欄位為 0', () async {
    await db.addInventory(name: '毛毯', category: '生活用品', unit: '件', stockQty: 3);
    final master = sql.select("SELECT * FROM inventory WHERE name='毛毯'").single;
    expect(master['stockQty'], 0);
    expect(master['reservedQty'], 0);
    final row = (await db.getAllInventory()).singleWhere(
      (r) => r['name'] == '毛毯',
    );
    expect(row['stockQty'], 3);
    expect(row['reservedQty'], 0);
    expect(row['availableQty'], 3);
  });

  test('同名不同單位或分類分開 itemId，禁止混算', () async {
    await db.addInventory(name: '泡麵', category: '食品飲水', unit: '包', stockQty: 3);
    await db.addInventory(name: '泡麵', category: '其他', unit: '箱', stockQty: 4);
    expect(office()['stockQty'], 2);
    final rows = await db.getAllInventory();
    expect(
      rows.singleWhere(
        (r) => r['name'] == '泡麵' && r['unit'] == '包',
      )['stockQty'],
      3,
    );
    expect(
      rows.singleWhere(
        (r) => r['name'] == '泡麵' && r['category'] == '其他',
      )['stockQty'],
      4,
    );
  });

  test('既有品項缺 OFFICE001 庫存列時，只加本次量，不引用舊數量', () async {
    await db.addStock(2, 3);
    expect((await db.getAllInventory())[1]['stockQty'], 3);
    expect(
      sql
          .select('SELECT stockQty FROM inventory WHERE id=2')
          .single['stockQty'],
      888,
    );
  });

  test('完全相同主檔重複時拒絕，避免任選 itemId', () async {
    sql.execute(
      "INSERT INTO inventory (name,category,unit) VALUES ('泡麵','食品飲水','箱')",
    );
    await expectLater(
      db.addInventory(name: '泡麵', category: '食品飲水', unit: '箱', stockQty: 3),
      throwsA(isA<InventoryException>()),
    );
    expect(office()['stockQty'], 2);
  });

  test('不存在物資、非正數及缺管理中心均拒絕', () async {
    for (final qty in [0, -3]) {
      await expectLater(
        db.addStock(1, qty),
        throwsA(isA<InventoryException>()),
      );
      await expectLater(
        db.addInventory(name: '泡麵', category: '食品飲水', unit: '箱', stockQty: qty),
        throwsA(isA<InventoryException>()),
      );
    }
    await expectLater(db.addStock(999, 3), throwsA(isA<InventoryException>()));
    expect(office()['stockQty'], 2);
    sql.execute("DELETE FROM station_inventory WHERE stationId='OFFICE001'");
    sql.execute("DELETE FROM stations WHERE stationId='OFFICE001'");
    await expectLater(
      db.addInventory(name: '新物資', category: '食品飲水', unit: '箱', stockQty: 3),
      throwsA(isA<InventoryException>()),
    );
    expect(sql.select("SELECT * FROM inventory WHERE name='新物資'"), isEmpty);
  });

  test('異常數量與整數溢位不入庫', () async {
    for (final stock in [-1, 0, 9223372036854775806]) {
      sql.execute(
        "UPDATE station_inventory SET stockQty=? WHERE stationId='OFFICE001'",
        [stock],
      );
      await expectLater(db.addStock(1, 3), throwsA(isA<InventoryException>()));
      expect(office()['stockQty'], stock);
    }
  });

  test('SQL 入庫失敗回滾新主檔及已有品項需求量', () async {
    sql.execute(
      "CREATE TRIGGER reject_stock BEFORE INSERT ON station_inventory BEGIN SELECT RAISE(ABORT,'test failure'); END",
    );
    await expectLater(
      db.addInventory(name: '新物資', category: '食品飲水', unit: '箱', stockQty: 3),
      throwsA(isA<SqliteException>()),
    );
    expect(sql.select("SELECT * FROM inventory WHERE name='新物資'"), isEmpty);
    await expectLater(
      db.addInventory(
        name: '泡麵',
        category: '食品飲水',
        unit: '箱',
        stockQty: 3,
        neededQty: 9,
      ),
      throwsA(isA<SqliteException>()),
    );
    expect(
      sql
          .select('SELECT neededQty FROM inventory WHERE id=1')
          .single['neededQty'],
      4,
    );
    expect(office()['stockQty'], 2);
  });

  test('多連線並行入庫 100 次不遺失更新', () async {
    final isolated = await Directory.systemTemp.createTemp(
      'office_inventory_test_',
    );
    final taskDbPath = '${isolated.path}/inventory_test.db';
    final setup = sqlite3.open(taskDbPath);
    createFixture(setup);
    setup.dispose();
    await Future.wait(
      List.generate(4, (_) => Isolate.run(() => concurrentInbound(taskDbPath))),
    );
    final result = sqlite3.open(taskDbPath, mode: OpenMode.readOnly);
    try {
      expect(
        result
            .select(
              "SELECT stockQty,reservedQty FROM station_inventory WHERE stationId='OFFICE001'",
            )
            .single['stockQty'],
        102,
      );
      expect(
        result
            .select('SELECT stockQty FROM inventory WHERE id=1')
            .single['stockQty'],
        999,
      );
    } finally {
      result.dispose();
    }
  });

  test('HTTP 相容回應、2+3、不同單位、錯誤參數、失敗不報成功', () async {
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

    try {
      final inbound = await post({
        'type': 'updateStock',
        'itemId': 1,
        'qty': 3,
      });
      expect(inbound.$1, 200);
      expect(inbound.$2, {'success': true, 'message': 'Stock updated'});
      expect(
        office()['stockQty'],
        5,
      ); // Visible in SQLite before success is consumed.
      final query = await post({'type': 'getInventory'});
      expect(query.$1, 200);
      expect(query.$2['success'], true);
      final row = (query.$2['data'] as List).first as Map<String, dynamic>;
      expect(row['stockQty'], 5);
      expect(row['reservedQty'], 1);
      expect(row['availableQty'], 4);
      expect(
        row.keys,
        containsAll([
          'id',
          'name',
          'category',
          'unit',
          'neededQty',
          'updatedAt',
        ]),
      );
      final stationRow = StationTransferService(
        db,
      ).getStationInventory('OFFICE001').first;
      expect(stationRow['itemId'], row['id']);
      for (final key in ['stockQty', 'reservedQty', 'availableQty', 'unit']) {
        expect(row[key], stationRow[key]);
      }
      final add = await post({
        'type': 'addInventory',
        'name': '泡麵',
        'category': '食品飲水',
        'unit': '箱',
        'stockQty': 3,
      });
      expect(add.$1, 200);
      expect(add.$2, {'success': true, 'message': 'Inventory added'});
      expect(office()['stockQty'], 8);
      expect(
        (await post({
          'type': 'addInventory',
          'name': '泡麵',
          'category': '食品飲水',
          'unit': '包',
          'stockQty': 3,
        })).$1,
        200,
      );
      expect(office()['stockQty'], 8);
      for (final qty in [0, -1, 1.5, '3', null, true]) {
        for (final body in [
          {'type': 'updateStock', 'itemId': 1, 'qty': qty},
          {
            'type': 'addInventory',
            'name': '泡麵',
            'category': '食品飲水',
            'unit': '箱',
            'stockQty': qty,
          },
        ]) {
          final rejected = await post(body);
          expect(rejected.$1, 400);
          expect(rejected.$2['success'], false);
        }
      }
      expect(
        (await post({'type': 'updateStock', 'itemId': 999, 'qty': 3})).$1,
        404,
      );
      expect(
        (await post({
          'type': 'addInventory',
          'name': '',
          'category': '食品飲水',
          'unit': '箱',
          'stockQty': 3,
        })).$1,
        400,
      );
      expect(
        (await post({
          'type': 'addInventory',
          'name': '泡麵',
          'category': '食品飲水',
          'unit': '箱',
          'stockQty': 3,
          'neededQty': -1,
        })).$1,
        400,
      );
      expect(office()['stockQty'], 8);
      sql.execute(
        "CREATE TRIGGER reject_stock BEFORE INSERT ON station_inventory BEGIN SELECT RAISE(ABORT,'test failure'); END",
      );
      for (final body in [
        {'type': 'updateStock', 'itemId': 1, 'qty': 3},
        {
          'type': 'addInventory',
          'name': '失敗物資',
          'category': '食品飲水',
          'unit': '箱',
          'stockQty': 3,
        },
      ]) {
        final failure = await post(body);
        expect(failure.$1, 500);
        expect(failure.$2['success'], false);
      }
      expect(office()['stockQty'], 8);
      expect(sql.select("SELECT * FROM inventory WHERE name='失敗物資'"), isEmpty);
    } finally {
      client.close(force: true);
      await subscription.cancel();
      await server.close(force: true);
    }
  });
}
