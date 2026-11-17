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

Future<bool> batchRace(String path, bool batch) => Isolate.run(() async {
  final sql = sqlite3.open(path);
  sql.execute('PRAGMA busy_timeout=5000');
  try {
    final service = SupplyRequestService(DatabaseService(sql));
    if (batch) {
      final result = await service.batchSupplyRequests(adminId: 7, action: 'reserve', requestIds: ['A']);
      return result['succeeded'] == 1;
    }
    await service.reserveSupplyRequest(requestId: 'A');
    return true;
  } on Exception {
    return false;
  } finally {
    sql.dispose();
  }
});

Future<bool> reviewRace(String path, String id) => Isolate.run(() async {
  final sql = sqlite3.open(path);
  sql.execute('PRAGMA busy_timeout=5000');
  try {
    await SupplyRequestService(DatabaseService(sql)).reviewSupplyRequest(
      adminId: 7, requestId: id, decision: 'approve', note: '並行審核核對',
    );
    return true;
  } on Exception {
    return false;
  } finally { sql.dispose(); }
});

void main() {
  late Database sql;
  late DatabaseService db;
  late SupplyRequestService service;
  setUp(() {
    sql = sqlite3.openInMemory();
    createFixture(sql);
    sql.execute("UPDATE station_inventory SET stockQty=10,reservedQty=0 WHERE stationId='OFFICE001' AND itemId=1");
    sql.execute('CREATE TABLE admins (id INTEGER PRIMARY KEY,username TEXT,password TEXT,zoneId TEXT)');
    sql.execute("INSERT INTO admins VALUES (7,'manager','secret','OFFICE001')");
    sql.execute('''CREATE TABLE supply_requests (
      requestId TEXT PRIMARY KEY,userId TEXT,itemId INTEGER,qty INTEGER,stationId TEXT,
      lat REAL,lng REAL,address TEXT,status TEXT,createdAt TEXT,receiverAdminId TEXT,
      hopCount INTEGER,receivedAt TEXT,volunteerId TEXT,claimedAt TEXT,completedAt TEXT
    )''');
    DatabaseService.ensureSupplyRequestSchema(sql);
    db = DatabaseService(sql);
    DatabaseService.instance = db;
    service = SupplyRequestService(db);
  });
  tearDown(() => sql.dispose());
  Future<void> add(String id, {int qty = 3, String? user}) => db.insertSupplyRequest(SupplyRequest(
    requestId: id, userId: user ?? 'U$id', itemId: 1, qty: qty,
    createdAt: DateTime.utc(2026, 11, 10),
  ));
  Future<Map<String, Object?>> batch(String action, List<String> ids) => service.batchSupplyRequests(adminId: 7, action: action, requestIds: ids);
  Map<String, Object?> row(String id) => Map<String, Object?>.from(sql.select('SELECT * FROM supply_requests WHERE requestId=?', [id]).single);
  List<Object?> stock() => sql.select("SELECT stockQty,reservedQty FROM station_inventory WHERE stationId='OFFICE001' AND itemId=1").single.values.toList();
  Future<Map<String, dynamic>> approve(String id) => service.reviewSupplyRequest(adminId: 7, requestId: id, decision: 'approve', note: '已人工核對');

  test('批次完整流程保留單筆保護、總量與逐筆結果', () async {
    await add('A'); await add('B', qty: 4);
    expect((await batch('reserve', ['A','B']))['succeeded'], 2);
    expect(stock(), [10, 7]);
    expect((await batch('dispatch', ['A','B']))['succeeded'], 2);
    expect(stock(), [3, 0]);
    expect((await batch('complete', ['A','B']))['succeeded'], 2);
    expect((await batch('complete', ['A','B']))['failed'], 2);
    expect(stock(), [3, 0]);
    expect(row('A')['completedBy'], 7);
  });

  test('同批總量超過可用量後續失敗，重複 ID 與不存在 ID 可辨識', () async {
    await add('A', qty: 7); await add('B', qty: 7);
    final result = await batch('reserve', ['A','B','A','missing']);
    expect(result['succeeded'], 1);
    expect(result['failed'], 3);
    final results = result['results'] as List;
    expect(results[1]['code'], 'REVIEW_REQUIRED');
    expect(results[2]['code'], 'DUPLICATE_REQUEST_ID');
    expect(stock(), [10, 7]);
    expect(row('B')['status'], 'pending');
    expect(row('B')['reviewStatus'], 'needs_review');
    expect(jsonDecode(row('B')['reviewReasons'] as String).first['code'], 'INSUFFICIENT_STOCK');
  });

  test('疑似重複不可批次或單筆繞過，人工核准原子預留，暫緩非拒絕', () async {
    await add('A', user: 'same'); await add('B', user: 'same');
    expect((await batch('reserve', ['A','B']))['succeeded'], 0);
    await expectLater(service.autoAssignSupplyRequest(requestId: 'A'), throwsA(isA<SupplyReviewRequired>()));
    final approved = await approve('A');
    expect(approved['status'], 'reserved');
    expect(row('A')['reviewedBy'], 7);
    expect(row('A')['reviewStatus'], 'approved');
    expect(stock(), [10, 3]);
    await expectLater(approve('A'), throwsException);
    await service.reviewSupplyRequest(adminId: 7, requestId: 'B', decision: 'defer', note: '待確認是否另有需求');
    expect(row('B')['status'], 'pending');
    expect(row('B')['reviewStatus'], 'needs_review');
    expect((await batch('reserve', ['B']))['failed'], 1);
  });

  test('數量上限可設定，人工允許超量仍重新查庫存', () async {
    service = SupplyRequestService(db, maxRequestQty: 2);
    expect(() => SupplyRequestService(db, maxRequestQty: 0), throwsArgumentError);
    await add('A');
    final reviews = await service.getSupplyRequestReviews(adminId: 7);
    expect(reviews.single['maxRequestQty'], 2);
    expect((reviews.single['anomalyReasons'] as List).single['code'], 'QTY_LIMIT_EXCEEDED');
    expect((await batch('reserve', ['A']))['succeeded'], 0);
    sql.execute("UPDATE station_inventory SET stockQty=2 WHERE stationId='OFFICE001' AND itemId=1");
    await expectLater(approve('A'), throwsA(isA<SupplyReviewRequired>()));
    expect(row('A')['status'], 'pending');
    sql.execute("UPDATE station_inventory SET stockQty=10 WHERE stationId='OFFICE001' AND itemId=1");
    await approve('A');
    expect(stock(), [10, 3]);
  });

  test('必填與庫存硬性異常不得強行核准；修復後仍需人工審核', () async {
    await add('A');
    sql.execute("UPDATE supply_requests SET userId='' WHERE requestId='A'");
    expect((await batch('reserve', ['A']))['succeeded'], 0);
    await expectLater(approve('A'), throwsA(isA<SupplyReviewRequired>()));
    expect(stock(), [10, 0]);
    sql.execute("UPDATE supply_requests SET userId='UA',itemId=999 WHERE requestId='A'");
    await expectLater(approve('A'), throwsA(isA<SupplyReviewRequired>()));
    sql.execute("UPDATE supply_requests SET itemId=1,qty=0 WHERE requestId='A'");
    await expectLater(approve('A'), throwsA(isA<SupplyReviewRequired>()));
    sql.execute("UPDATE supply_requests SET qty=3 WHERE requestId='A'");
    expect((await batch('reserve', ['A']))['failed'], 1);
    final reviews = await service.getSupplyRequestReviews(adminId: 7);
    expect(reviews.single['anomalyReasons'], isEmpty);
    expect(reviews.single['requiresReview'], true);
    expect(reviews.single['flaggedReasons'], isNotEmpty);
    await approve('A');
    expect(stock(), [10, 3]);
  });

  test('庫存不足修復後不可由一般預留繞過已標記審核', () async {
    await add('A', qty: 12);
    await expectLater(service.reserveSupplyRequest(requestId: 'A'), throwsA(isA<SupplyReviewRequired>()));
    sql.execute("UPDATE station_inventory SET stockQty=20 WHERE stationId='OFFICE001' AND itemId=1");
    await expectLater(service.reserveSupplyRequest(requestId: 'A'), throwsA(isA<SupplyReviewRequired>()));
    await approve('A');
    expect(stock(), [20, 12]);
  });

  test('審核寫入失敗會回滾預留，逐筆出庫失敗不撤銷其他成功項', () async {
    await add('A'); await add('B');
    await service.reviewSupplyRequest(adminId: 7, requestId: 'A', decision: 'defer', note: '先核對');
    final before = row('A');
    sql.execute("CREATE TRIGGER fail_review BEFORE UPDATE OF reviewStatus ON supply_requests WHEN NEW.reviewStatus='approved' BEGIN SELECT RAISE(ABORT,'test rollback'); END");
    await expectLater(approve('A'), throwsException);
    expect(row('A'), before);
    expect(stock(), [10, 0]);
    sql.execute('DROP TRIGGER fail_review');
    await approve('A');
    await service.reserveSupplyRequest(requestId: 'B');
    sql.execute("CREATE TRIGGER fail_dispatch BEFORE UPDATE OF status ON supply_requests WHEN NEW.status='dispatched' AND NEW.requestId='A' BEGIN SELECT RAISE(ABORT,'test rollback'); END");
    final result = await batch('dispatch', ['A','B']);
    expect(result['succeeded'], 1);
    expect(result['failed'], 1);
    expect(row('A')['status'], 'reserved');
    expect(row('A')['dispatchedAt'], isNull);
    expect(row('B')['status'], 'dispatched');
    expect(stock(), [7, 3]);
  });

  test('獨立連線批次與單筆同時預留只成功一次，重開保留', () async {
    await add('A');
    final directory = await Directory.systemTemp.createTemp('cares_batch_race_');
    final path = '${directory.path}/test.db';
    sql.execute('VACUUM INTO ?', [path]);
    try {
      final results = await Future.wait([batchRace(path, true), batchRace(path, false)]);
      expect(results.where((v) => v), hasLength(1));
      final reopened = sqlite3.open(path);
      try {
        expect(reopened.select('SELECT status FROM supply_requests').single['status'], 'reserved');
        expect(reopened.select("SELECT reservedQty FROM station_inventory WHERE stationId='OFFICE001' AND itemId=1").single['reservedQty'], 3);
      } finally { reopened.dispose(); }
    } finally { await directory.delete(recursive: true); }
  });

  test('獨立連線同時核准兩筆例外仍不得超額預留', () async {
    await add('A', qty: 7); await add('B', qty: 7);
    await SupplyRequestService(db, maxRequestQty: 2).getSupplyRequestReviews(adminId: 7);
    final directory = await Directory.systemTemp.createTemp('cares_review_race_');
    final path = '${directory.path}/test.db';
    sql.execute('VACUUM INTO ?', [path]);
    try {
      final results = await Future.wait([reviewRace(path, 'A'), reviewRace(path, 'B')]);
      expect(results.where((v) => v), hasLength(1));
      final reopened = sqlite3.open(path);
      try {
        expect(reopened.select("SELECT COUNT(*) AS n FROM supply_requests WHERE status='reserved' AND reviewStatus='approved'").single['n'], 1);
        expect(reopened.select("SELECT reservedQty FROM station_inventory WHERE stationId='OFFICE001' AND itemId=1").single['reservedQty'], 7);
      } finally { reopened.dispose(); }
    } finally { await directory.delete(recursive: true); }
  });

  test('歷史任務不回填審核或轉換，空批次／過大批次拒絕', () async {
    await add('A');
    sql.execute("UPDATE supply_requests SET status='claimed',volunteerId='VOLD',claimedAt='old'");
    final before = row('A');
    expect((await batch('reserve', ['A']))['failed'], 1);
    expect((await batch('dispatch', ['A']))['failed'], 1);
    expect(await service.getSupplyRequestReviews(adminId: 7), isEmpty);
    DatabaseService.ensureSupplyRequestSchema(sql);
    expect(row('A'), before);
    await expectLater(batch('reserve', []), throwsException);
    await expectLater(batch('reserve', List.filled(101, 'A')), throwsException);
  });

  test('HTTP Session、逐筆回應、審核欄位與人工核准完整串接', () async {
    await add('A', qty: 101);
    sql.execute("UPDATE station_inventory SET stockQty=200 WHERE stationId='OFFICE001' AND itemId=1");
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
      final login = await post({'type':'login','username':'manager','password':'secret'});
      final auth = 'Bearer ${login.$2['token']}';
      final bodies = [
        for (final type in ['batchReserveSupplyRequests','batchDispatchSupplyRequests','batchCompleteSupplyRequests'])
          {'type':type,'requestIds':['A']},
        {'type':'getSupplyRequestReviews'},
        {'type':'reviewSupplyRequest','requestId':'A','decision':'approve','note':'已核對','adminId':999},
      ];
      for (final body in bodies) {
        expect((await post(body)).$1, 401);
        expect((await post(body,'Bearer ${'0' * 64}')).$1, 401);
      }
      expect((await post({'type':'batchReserveSupplyRequests','requestIds':[1]},auth)).$1, 400);
      final blocked = await post(bodies.first, auth);
      expect(blocked.$1, 200);
      expect(blocked.$2['success'], false);
      expect(blocked.$2['data']['results'][0]['code'], 'REVIEW_REQUIRED');
      final reviews = await post(bodies[3], auth);
      expect(reviews.$2['data'][0]['requiresReview'], true);
      final approved = await post(bodies[4], auth);
      expect(approved.$1, 200);
      expect(approved.$2['data']['reviewedBy'], 7);
      expect(row('A')['status'], 'reserved');
      for (final body in [bodies[1],bodies[2]]) {
        final result = await post(body,auth);
        expect(result.$1, 200);
        expect(result.$2['data']['succeeded'], 1);
      }
      expect(stock(), [99, 0]);
      final details = await post({'type':'getSupplyRequestDetails'},auth);
      expect(details.$2['data'][0]['reviewStatus'], 'approved');
      sql.execute('DELETE FROM admins');
      for (final body in bodies) { expect((await post(body,auth)).$1, 403); }
    } finally {
      client.close(force:true); await listener.cancel(); await server.close(force:true);
    }
  });
}
