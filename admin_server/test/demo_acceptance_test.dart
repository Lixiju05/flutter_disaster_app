import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';

class DemoServer {
  final Directory directory;
  final String worker;
  final String packages;
  bool allowLegacyWrites = false;
  Process? process;
  int? port;
  final HttpClient client = HttpClient();
  final List<String> logs = [];

  DemoServer(this.directory, this.worker, this.packages);
  Future<void> start() async {
    final ready = Completer<int>();
    final sdk = File(Platform.resolvedExecutable).parent;
    final executable =
        '${sdk.path}${Platform.pathSeparator}'
        '${Platform.isWindows ? 'dart.exe' : 'dart'}';
    process = await Process.start(executable, [
      if (allowLegacyWrites) '-DALLOW_LEGACY_INVENTORY_WRITES=true',
      '--packages=$packages',
      worker,
    ], workingDirectory: directory.path);
    process!.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
          logs.add(line);
          if (line.startsWith('DEMO_READY:') && !ready.isCompleted) {
            ready.complete(int.parse(line.split(':').last));
          }
        });
    process!.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(logs.add);
    unawaited(
      process!.exitCode.then((code) {
        if (!ready.isCompleted) {
          ready.completeError(
            StateError('Worker exited $code: ${logs.join('\n')}'),
          );
        }
      }),
    );
    port = await ready.future.timeout(const Duration(seconds: 30));
  }

  Future<void> stop() async {
    final running = process;
    if (running == null) return;
    if (port != null) {
      running.stdin.writeln('STOP');
      await running.stdin.flush();
      await running.stdin.close();
    }
    try {
      await running.exitCode.timeout(const Duration(seconds: 10));
    } on TimeoutException {
      running.kill(); // Only the worker created by this test.
      await running.exitCode;
    }
    process = null;
    port = null;
  }

  Future<(int, Map<String, dynamic>)> post(Map<String, dynamic> body) async {
    final request = await client.postUrl(Uri.parse('http://127.0.0.1:$port'));
    request.headers.contentType = ContentType.json;
    request.write(jsonEncode(body));
    final response = await request.close();
    return (
      response.statusCode,
      jsonDecode(await utf8.decoder.bind(response).join())
          as Map<String, dynamic>,
    );
  }

  Future<List<dynamic>> list(
    String type, [
    Map<String, dynamic> parameters = const {},
  ]) async {
    final response = await post({'type': type, ...parameters});
    expect(response.$1, 200, reason: '$type: ${response.$2}');
    expect(response.$2['success'], true);
    return response.$2['data'] as List;
  }

  List<Map<String, Object?>> read(String query) {
    final db = sqlite3.open(
      '${directory.path}/data/admin.db',
      mode: OpenMode.readOnly,
    );
    try {
      return db.select(query).map((r) => Map<String, Object?>.from(r)).toList();
    } finally {
      db.dispose();
    }
  }
}

void main() {
  late DemoServer server;
  final root = Directory.current.absolute.path;
  setUp(() async {
    final isolated = await Directory.systemTemp.createTemp(
      'cares_demo_acceptance_',
    );
    server = DemoServer(
      isolated,
      '$root/test/support/demo_http_server.dart',
      '$root/.dart_tool/package_config.json',
    );
    print('ISOLATED_DEMO_DB: ${isolated.path}/data/admin.db');
    await server.start();
  });
  tearDown(() async {
    await server.stop();
    server.client.close(force: true);
    // Retain temporary DBs for review; no recursive deletion of user files.
  });

  test('DEMO：正確帳密可登入（驗收要求，失敗應明確回報）', () async {
    final result = await server.post({
      'type': 'login',
      'username': 'admin_ncnu',
      'password': '1234',
    });
    print('LOGIN_RESULT: $result');
    expect(
      result.$1,
      200,
      reason: '${result.$2}; server: ${server.logs.join('\n')}',
    );
    expect(result.$2['success'], true);
    expect(result.$2['username'], 'admin_ncnu');
    expect(result.$2['token'], isA<String>());
  });

  test('DEMO：錯誤帳密拒絕、災民／健康／SOS／據點／需求明細可查詢', () async {
    expect(
      (await server.post({
        'type': 'login',
        'username': 'admin_ncnu',
        'password': 'wrong',
      })).$1,
      403,
    );
    final users = await server.list('getAllUsers');
    expect(users.length, 14);
    expect(users.any((u) => u['id'] == 'U014' && u['name'] == '周延依'), true);
    final reports = await server.list('getAllReports');
    expect(reports.length, 5);
    expect(
      reports.first.keys,
      containsAll([
        'uuid',
        'reporterId',
        'name',
        'status',
        'lat',
        'lng',
        'address',
      ]),
    );
    final sos = await server.list('getEmergencyRequestsByAdmin', {
      'receiverAdminId': 'admin_ncnu',
    });
    expect(sos.length, 4);
    expect(
      sos.first.keys,
      containsAll([
        'emergencyId',
        'userId',
        'userName',
        'latitude',
        'longitude',
        'status',
      ]),
    );
    expect(
      sos.singleWhere((e) => e['emergencyId'] == 'SOS005')['userId'],
      'U014',
    );
    final stations = await server.list('getStations');
    expect(stations.map((s) => s['stationId']), ['OFFICE001', 'S001', 'S002']);
    final details = await server.list('getSupplyRequestDetails');
    expect(details.length, 4);
    expect(
      details.first.keys,
      containsAll([
        'requestId',
        'userId',
        'itemId',
        'qty',
        'stationId',
        'stationName',
      ]),
    );
    expect(details.every((r) => r['stationId'] == 'OFFICE001'), true);
    final reserve = await server.post({
      'type': 'autoAssignSupplyRequest',
      'requestId': 'REQ001',
    });
    expect(reserve.$1, 200);
    final assigned = (await server.list(
      'getSupplyRequestDetails',
    )).singleWhere((r) => r['requestId'] == 'REQ001');
    expect(assigned['stationId'], 'OFFICE001');
    expect(
      assigned['stationName'],
      stations.singleWhere((s) => s['stationId'] == 'OFFICE001')['name'],
    );
    expect(assigned['status'], 'reserved');
    print(
      'QUERY_APIS_OK; new seeded requests and autoAssign use OFFICE001/name',
    );
  });

  test('DEMO：SOS API 寫入 SQLite，重開隔離 Server 後保留', () async {
    final result = await server.post({
      'type': 'updateEmergencyStatus',
      'emergencyId': 'SOS005',
      'status': 'resolved',
    });
    expect(result.$1, 200);
    expect(
      server
          .read(
            "SELECT status FROM emergency_requests WHERE emergencyId='SOS005'",
          )
          .single['status'],
      'resolved',
    );
    await server.stop();
    await server.start();
    final sos = await server.list('getEmergencyRequestsByAdmin', {
      'receiverAdminId': 'admin_ncnu',
    });
    expect(
      sos.singleWhere((r) => r['emergencyId'] == 'SOS005')['status'],
      'resolved',
    );
  });

  test('DEMO：調度三階段、拒絕重複／不足、SQLite 與重開 Server 一致', () async {
    Future<List<int>> stock(String station) async {
      final row = (await server.list('getStationInventory', {
        'stationId': station,
      })).singleWhere((r) => r['itemId'] == 1);
      expect(row['itemName'], isA<String>());
      expect(row['unit'], isA<String>());
      return [
        row['stockQty'] as int,
        row['reservedQty'] as int,
        row['availableQty'] as int,
      ];
    }

    final office = await stock('OFFICE001');
    final shelter = await stock('S001');
    final originalInventory = server.read(
      'SELECT * FROM inventory ORDER BY id',
    );
    final originalAllocations = server.read(
      'SELECT * FROM allocations ORDER BY id',
    );
    final create = await server.post({
      'type': 'createStationTransfer',
      'toStationId': 'S001',
      'itemId': 1,
      'qty': 10,
      'createdBy': 'admin_ncnu',
    });
    expect(create.$1, 200);
    final id = create.$2['data']['transferId'] as String;
    expect(create.$2['data']['status'], 'reserved');
    expect(await stock('OFFICE001'), [
      office[0],
      office[1] + 10,
      office[2] - 10,
    ]);
    expect(await stock('S001'), shelter);
    final reservedList = await server.list('getStationTransfers', {
      'stationId': 'S001',
      'status': 'reserved',
    });
    expect(reservedList.single['transferId'], id);
    expect(
      reservedList.single.keys,
      containsAll(['itemName', 'unit', 'fromStationName', 'toStationName']),
    );
    expect(
      (await server.post({
        'type': 'receiveStationTransfer',
        'transferId': id,
      })).$1,
      409,
    );
    final insufficient = await server.post({
      'type': 'createStationTransfer',
      'toStationId': 'S001',
      'itemId': 1,
      'qty': 99999,
      'createdBy': 'admin_ncnu',
    });
    expect(insufficient.$1, 409);
    expect((await server.list('getStationTransfers')).length, 1);
    expect(
      (await server.post({'type': 'shipStationTransfer', 'transferId': id})).$1,
      200,
    );
    expect(await stock('OFFICE001'), [
      office[0] - 10,
      office[1],
      office[2] - 10,
    ]);
    expect(await stock('S001'), shelter);
    expect(
      (await server.post({'type': 'shipStationTransfer', 'transferId': id})).$1,
      409,
    );
    expect(
      (await server.post({
        'type': 'receiveStationTransfer',
        'transferId': id,
      })).$1,
      200,
    );
    expect(
      (await server.post({
        'type': 'receiveStationTransfer',
        'transferId': id,
      })).$1,
      409,
    );
    expect(await stock('S001'), [shelter[0] + 10, shelter[1], shelter[2] + 10]);
    final received = await server.list('getStationTransfers', {
      'stationId': 'S001',
      'status': 'received',
    });
    expect(received.single['transferId'], id);
    expect(received.single['shippedAt'], isNotNull);
    expect(received.single['receivedAt'], isNotNull);
    expect(
      server.read('SELECT * FROM inventory ORDER BY id'),
      originalInventory,
    );
    expect(
      server.read('SELECT * FROM allocations ORDER BY id'),
      originalAllocations,
    );
    expect(
      server
          .read(
            "SELECT stockQty FROM station_inventory WHERE stationId='S001' AND itemId=1",
          )
          .single['stockQty'],
      shelter[0] + 10,
    );
    final stockRows = server.read(
      'SELECT * FROM station_inventory ORDER BY stationId,itemId',
    );
    final transferRows = server.read(
      'SELECT * FROM station_transfers ORDER BY transferId',
    );
    await server.stop();
    await server.start();
    expect(
      server.read('SELECT * FROM station_inventory ORDER BY stationId,itemId'),
      stockRows,
    );
    expect(
      server.read('SELECT * FROM station_transfers ORDER BY transferId'),
      transferRows,
    );
    expect(
      (await server.list('getStationTransfers')).single['status'],
      'received',
    );
    expect(await stock('S001'), [shelter[0] + 10, shelter[1], shelter[2] + 10]);
    print(
      'TRANSFER_PERSISTENCE_OK: office $office -> ${await stock('OFFICE001')}; shelter $shelter -> ${await stock('S001')}',
    );
  });

  test('DEMO：舊寫入預設 409，明確開關可恢復且不碰 OFFICE001', () async {
    final originalOffice = server.read(
      "SELECT * FROM station_inventory WHERE stationId='OFFICE001' ORDER BY itemId",
    );
    for (final type in ['allocate', 'dispatch', 'cancelAllocation']) {
      final blocked = await server.post({
        'type': type,
        'itemId': 1,
        'qty': 10,
        'zoneId': 'S001',
        'allocationId': 1,
      });
      expect(blocked.$1, 409);
      expect(blocked.$2['success'], false);
    }
    expect(
      server
          .read('SELECT stockQty FROM inventory WHERE id=1')
          .single['stockQty'],
      120,
    );
    await server.stop();
    server.allowLegacyWrites = true;
    await server.start();
    expect(
      (await server.post({
        'type': 'allocate',
        'itemId': 1,
        'zoneId': 'S001',
        'qty': 10,
      })).$1,
      200,
    );
    final allocations = await server.list('getAllocations');
    final created = allocations
        .where(
          (r) => r['zoneId'] == 'S001' && r['itemId'] == 1 && r['qty'] == 10,
        )
        .toList();
    expect(created.length, 1);
    final id = created.single['allocationId'];
    expect(
      (await server.post({'type': 'dispatch', 'allocationId': id})).$1,
      200,
    );
    expect(
      server.read(
        "SELECT * FROM station_inventory WHERE stationId='OFFICE001' ORDER BY itemId",
      ),
      originalOffice,
    );
    expect(
      server
          .read('SELECT stockQty FROM inventory WHERE id=1')
          .single['stockQty'],
      110,
    );
    print('LEGACY_FLOW_DOES_NOT_UPDATE_OFFICE_STATION_STOCK');
  });

  test('單中心新需求及配送狀態在重啟後保存，取貨只扣一次', () async {
    Future<Map<String, dynamic>> stock() async =>
        (await server.list('getStationInventory', {
              'stationId': 'OFFICE001',
            })).singleWhere((r) => r['itemId'] == 1)
            as Map<String, dynamic>;
    final original = await stock();
    final request = await server.post({
      'type': 'addSupplyRequest',
      'requestId': 'OFFICE_RESTART',
      'userId': 'U001',
      'itemId': 1,
      'qty': 3,
      'stationId': 'S002',
    });
    expect(request.$1, 200);
    Future<(int, Map<String, dynamic>)> step(String type) => server.post({
      'type': type,
      'requestId': 'OFFICE_RESTART',
      'volunteerId': 'V001',
      'stationId': 'OFFICE001',
    });
    expect((await step('autoAssignSupplyRequest')).$1, 200);
    await server.stop();
    await server.start();
    final reserved = (await server.list(
      'getSupplyRequestDetails',
    )).singleWhere((r) => r['requestId'] == 'OFFICE_RESTART');
    expect(reserved['stationId'], 'OFFICE001');
    expect(reserved['status'], 'reserved');
    expect((await stock())['stockQty'], original['stockQty']);
    expect(
      (await stock())['reservedQty'],
      (original['reservedQty'] as int) + 3,
    );
    expect((await step('reserveSupplyRequest')).$2['success'], false);
    expect((await step('claimSupplyRequest')).$1, 200);
    expect((await step('dispatchSupplyRequest')).$1, 200);
    final afterPickup = await stock();
    expect(afterPickup['stockQty'], (original['stockQty'] as int) - 3);
    expect(afterPickup['reservedQty'], original['reservedQty']);
    await server.stop();
    await server.start();
    expect(
      (await server.list('getVolunteerClaims', {
        'volunteerId': 'V001',
        'stationId': 'OFFICE001',
      })).singleWhere((r) => r['requestId'] == 'OFFICE_RESTART')['status'],
      'dispatched',
    );
    expect((await step('dispatchSupplyRequest')).$2['success'], false);
    expect((await step('completeSupplyRequest')).$1, 200);
    final saved = server
        .read("SELECT * FROM supply_requests WHERE requestId='OFFICE_RESTART'")
        .single;
    expect(saved['completedAt'], isNotNull);
    await server.stop();
    await server.start();
    expect((await step('completeSupplyRequest')).$2['success'], false);
    expect(
      server
          .read(
            "SELECT * FROM supply_requests WHERE requestId='OFFICE_RESTART'",
          )
          .single,
      saved,
    );
    expect((await stock())['stockQty'], afterPickup['stockQty']);
    expect((await stock())['reservedQty'], afterPickup['reservedQty']);
  });
}
