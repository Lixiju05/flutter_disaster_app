import 'dart:convert';
import 'dart:io';
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';
import 'package:admin_server/database/database_service.dart';
import '../bin/admin_server.dart' as api;

void main() {
  late Database sql;
  late DatabaseService db;
  final originalFields = {
    'requestId',
    'userId',
    'itemId',
    'itemName',
    'unit',
    'qty',
    'lat',
    'lng',
    'receiverAdminId',
    'hopCount',
    'status',
    'createdAt',
    'receivedAt',
    'address',
    'volunteerId',
    'claimedAt',
  };

  setUp(() {
    sql = sqlite3.openInMemory();
    sql.execute(
      'CREATE TABLE stations (stationId TEXT PRIMARY KEY, name TEXT, type TEXT, lat REAL, lng REAL, address TEXT)',
    );
    sql.execute(
      "INSERT INTO stations VALUES ('OFFICE001','物資中心','office',23.95,120.93,'中心'),('S001','A 收容中心','shelter',23.951,120.927,'A'),('S002','B 收容中心','shelter',23.96,120.94,'B')",
    );
    sql.execute(
      'CREATE TABLE inventory (id INTEGER PRIMARY KEY, name TEXT, unit TEXT)',
    );
    sql.execute("INSERT INTO inventory VALUES (1,'泡麵','箱')");
    sql.execute('''CREATE TABLE supply_requests (
      requestId TEXT PRIMARY KEY, userId TEXT, itemId INTEGER, qty INTEGER,
      lat REAL, lng REAL, receiverAdminId TEXT, hopCount INTEGER, status TEXT,
      createdAt TEXT, receivedAt TEXT, address TEXT, volunteerId TEXT,
      claimedAt TEXT, stationId TEXT
    )''');
    for (final row in [
      ['assigned', 'S001', '2026-10-13T03:00:00Z'],
      ['unassigned', null, '2026-10-13T02:00:00Z'],
      ['missing-station', 'UNKNOWN', '2026-10-13T01:00:00Z'],
    ]) {
      sql.execute(
        '''INSERT INTO supply_requests VALUES
        (?, 'U001', 1, 10, 23.95, 120.93, 'admin_ncnu', 2, 'pending', ?,
         '2026-10-13T00:00:00Z', '地址', 'V001', '2026-10-13T00:00:00Z', ?)
      ''',
        [row[0], row[2], row[1]],
      );
    }
    DatabaseService.ensureSupplyRequestSchema(sql);
    db = DatabaseService(sql);
    DatabaseService.instance = db;
  });
  tearDown(() => sql.dispose());

  test('需求明細新增據點欄位並保留全部舊欄位與值', () async {
    final rows = await db.getSupplyRequestDetails();
    expect(rows.map((r) => r['requestId']).toList(), [
      'assigned',
      'unassigned',
      'missing-station',
    ]);
    final assigned = rows.first;
    expect(assigned.keys.toSet(), {
      ...originalFields,
      'stationId',
      'reportedAt',
      'stationName',
      'assignmentType',
      'assignedBy',
      'completedAt',
      'reservedAt', 'dispatchedAt', 'dispatchedBy', 'completedBy',
      'reviewStatus', 'reviewReasons', 'reviewedBy', 'reviewedAt', 'reviewNote',
    });
    expect(assigned, {
      'requestId': 'assigned',
      'userId': 'U001',
      'itemId': 1,
      'itemName': '泡麵',
      'unit': '箱',
      'qty': 10,
      'lat': 23.95,
      'lng': 120.93,
      'receiverAdminId': 'admin_ncnu',
      'hopCount': 2,
      'status': 'pending',
      'createdAt': '2026-10-13T03:00:00Z',
      'receivedAt': '2026-10-13T00:00:00Z',
      'address': '地址',
      'volunteerId': 'V001',
      'claimedAt': '2026-10-13T00:00:00Z',
      'stationId': 'S001',
      'reportedAt': null,
      'stationName': 'A 收容中心',
      'assignmentType': null,
      'assignedBy': null,
      'completedAt': null,
      'reservedAt': null, 'dispatchedAt': null, 'dispatchedBy': null, 'completedBy': null,
      'reviewStatus': null, 'reviewReasons': null, 'reviewedBy': null, 'reviewedAt': null, 'reviewNote': null,
    });
    expect(rows[1]['stationId'], isNull);
    expect(rows[1]['stationName'], isNull);
    expect(rows[2]['stationId'], 'UNKNOWN');
    expect(rows[2]['stationName'], isNull);
  });

  test('據點清單含 OFFICE001、S001、S002，空表回空清單', () async {
    final rows = await db.getStations();
    expect(rows.map((r) => r['stationId']), ['OFFICE001', 'S001', 'S002']);
    expect(rows[1]['name'], 'A 收容中心');
    expect(rows[1]['type'], 'shelter');
    sql.execute('DELETE FROM stations');
    expect(await db.getStations(), isEmpty);
  });

  test('既有 inventory JOIN 與無資料行為維持不變', () async {
    sql.execute(
      "INSERT INTO supply_requests (requestId,itemId,stationId) VALUES ('no-item',999,'S001')",
    );
    expect((await db.getSupplyRequestDetails()).length, 3);
    sql.execute('DELETE FROM supply_requests');
    expect(await db.getSupplyRequestDetails(), isEmpty);
  });

  test('POST getStations 與需求明細回應及錯誤處理', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final subscription = server.listen(api.handleRequest);
    final client = HttpClient();
    Future<(int, Map<String, dynamic>)> post(String type) async {
      final request = await client.postUrl(
        Uri.parse('http://127.0.0.1:${server.port}'),
      );
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode({'type': type}));
      final response = await request.close();
      return (
        response.statusCode,
        jsonDecode(await utf8.decoder.bind(response).join())
            as Map<String, dynamic>,
      );
    }

    try {
      final stations = await post('getStations');
      expect(stations.$1, 200);
      expect(stations.$2['success'], true);
      expect((stations.$2['data'] as List).map((r) => r['stationId']), [
        'OFFICE001',
        'S001',
        'S002',
      ]);
      final details = await post('getSupplyRequestDetails');
      expect(details.$1, 200);
      expect(details.$2['success'], true);
      final rows = details.$2['data'] as List;
      expect(rows.first['stationId'], 'S001');
      expect(rows.first['stationName'], 'A 收容中心');
      expect((rows.first as Map).keys.toSet(), {
        ...originalFields,
        'stationId',
        'reportedAt',
        'stationName',
        'assignmentType',
        'assignedBy',
        'completedAt',
        'reservedAt', 'dispatchedAt', 'dispatchedBy', 'completedBy',
        'reviewStatus', 'reviewReasons', 'reviewedBy', 'reviewedAt', 'reviewNote',
      });
      expect(rows[1]['stationName'], isNull);
      sql.execute('DELETE FROM stations');
      expect((await post('getStations')).$2['data'], isEmpty);
      sql.execute('DROP TABLE stations');
      final failure = await post('getStations');
      expect(failure.$1, 500);
      expect(failure.$2['success'], false);
    } finally {
      client.close(force: true);
      await subscription.cancel();
      await server.close(force: true);
    }
  });
}
