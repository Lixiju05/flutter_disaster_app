import 'dart:convert';
import 'dart:io';

import 'package:admin_server/core/models/emergency_request.dart';
import 'package:admin_server/core/models/healthReport.dart';
import 'package:admin_server/core/models/report_location.dart';
import 'package:admin_server/core/models/supply_request.dart';
import 'package:admin_server/database/database_service.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';
import '../bin/admin_server.dart' as api;

// Reuse production CREATE TABLE definitions, without running init(), seeds,
// or opening data/admin.db. Migration runs only on this isolated database.
void createReportFixture(Database sql) {
  final source = File('lib/database/database_service.dart').readAsStringSync();
  for (final table in [
    'health_reports',
    'supply_requests',
    'emergency_requests',
    'inventory',
    'stations',
    'users',
  ]) {
    final statement = RegExp(
      'CREATE TABLE IF NOT EXISTS $table \\([^;]+;',
    ).firstMatch(source)!.group(0)!.split("'''").first;
    sql.execute(statement);
  }
  DatabaseService.ensureSupplyRequestSchema(sql);
  sql.execute(
    "INSERT INTO inventory (id,name,unit) VALUES (1,'Water','bottle')",
  );
  sql.execute(
    "INSERT INTO stations VALUES ('OFFICE001','Center','office',24,121,NULL)",
  );
  sql.execute("INSERT INTO users (id,area) VALUES ('U1','residence only')");
}

void main() {
  late Database sql;
  late DatabaseService db;
  late HttpServer server;
  late HttpClient client;
  late Future<void> Function() stop;
  setUp(() async {
    sql = sqlite3.openInMemory();
    createReportFixture(sql);
    db = DatabaseService(sql);
    DatabaseService.instance = db;
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
    sql.dispose();
  });

  Future<Map<String, dynamic>> post(Map<String, dynamic> body) async {
    final req = await client.postUrl(
      Uri.parse('http://127.0.0.1:${server.port}'),
    );
    req.headers.contentType = ContentType.json;
    req.write(jsonEncode(body));
    final response = await req.close();
    final data =
        jsonDecode(await utf8.decoder.bind(response).join())
            as Map<String, dynamic>;
    expect(response.statusCode, 200, reason: '$data');
    expect(data['success'], true);
    return data;
  }

  const eventTime = '2026-10-01T01:02:03.123456Z';
  final specs = [
    (
      'addEmergencyRequest',
      'emergency_requests',
      'emergencyId',
      'latitude',
      'longitude',
      'sentAt',
    ),
    ('healthReport', 'health_reports', 'uuid', 'lat', 'lng', 'reportTime'),
    (
      'addSupplyRequest',
      'supply_requests',
      'requestId',
      'lat',
      'lng',
      'reportedAt',
    ),
  ];
  Map<String, dynamic> payload(String type, String key, String id) => {
    'type': type, key: id, 'userId': 'U1', 'reporterId': 'U1',
    'name': 'User', 'userName': 'User', 'phone': 'test',
    'itemId': 1, 'qty': 1, 'status': 'safe', 'receiverAdminId': 'A',
    // Incoming receive time must never be trusted.
    'receivedAt': '2000-01-01T00:00:00Z',
  };

  for (final (type, table, key, latKey, lngKey, timeKey) in specs) {
    test(
      '$type saves address, full GPS precision and distinct event/receipt time over HTTP',
      () async {
        final before = DateTime.now().toUtc().subtract(
          const Duration(seconds: 1),
        );
        await post({
          ...payload(type, key, 'valid'),
          latKey: 23.9876543210123,
          lngKey: 120.1234567890123,
          'address': 'App supplied address',
          timeKey: eventTime,
        });
        final row = sql.select('SELECT * FROM $table').single;
        expect(row['address'], 'App supplied address');
        expect(row[latKey], 23.9876543210123);
        expect(row[lngKey], 120.1234567890123);
        expect(
          DateTime.parse(row[timeKey] as String),
          DateTime.parse(eventTime),
        );
        expect(
          DateTime.parse(row['receivedAt'] as String).toUtc().isAfter(before),
          true,
        );
        if (type == 'addSupplyRequest') {
          expect(row['stationId'], 'OFFICE001');
          expect(
            DateTime.parse(row['createdAt'] as String).toUtc().isAfter(before),
            true,
          );
          expect(
            (await db.getSupplyRequestDetails()).single['reportedAt'],
            row['reportedAt'],
          );
        } else if (type == 'healthReport') {
          expect(
            (await db.getAllReports()).single.toJson()['address'],
            'App supplied address',
          );
          expect(
            (await db.getHealthReportsByAdmin('A')).single.receivedAt,
            isNotNull,
          );
        }
      },
    );

    test(
      '$type accepts missing and invalid location/time without fabricating data',
      () async {
        final variants = [
          <String, dynamic>{},
          {latKey: 'not-a-number', lngKey: 181, timeKey: 'bad-time'},
          {latKey: 91, lngKey: true, timeKey: 123},
          {latKey: 'NaN', lngKey: 'Infinity', timeKey: '2026-02-30T00:00:00Z'},
        ];
        for (var i = 0; i < variants.length; i++) {
          await post({...payload(type, key, 'bad$i'), ...variants[i]});
          final row = sql.select('SELECT * FROM $table WHERE $key = ?', [
            'bad$i',
          ]).single;
          expect(row[latKey], isNull);
          expect(row[lngKey], isNull);
          expect(row['address'], isNull);
          expect(row[timeKey], isNull);
          expect(row['receivedAt'], isNotNull);
        }
        if (type == 'healthReport') {
          expect(
            (await db.getAllReports()).every((r) => r.reportTime == null),
            true,
          );
        }
      },
    );

    test(
      '$type preserves partial coordinates and explicit zero without guessing',
      () async {
        await post({
          ...payload(type, key, 'partial'),
          latKey: 24,
          timeKey: eventTime,
        });
        var row = sql.select('SELECT * FROM $table WHERE $key = ?', [
          'partial',
        ]).single;
        expect(row[latKey], 24);
        expect(row[lngKey], isNull);
        await post({
          ...payload(type, key, 'zero'),
          latKey: 0,
          lngKey: 0,
          timeKey: eventTime,
        });
        row = sql.select('SELECT * FROM $table WHERE $key = ?', [
          'zero',
        ]).single;
        expect(row[latKey], 0);
        expect(row[lngKey], 0);
        await post({...payload(type, key, 'no-gps'), timeKey: eventTime});
        row = sql.select('SELECT * FROM $table WHERE $key = ?', [
          'no-gps',
        ]).single;
        expect(row[latKey], isNull);
        expect(row[lngKey], isNull);
        expect(row[timeKey], eventTime);
      },
    );

    test(
      '$type duplicate report does not overwrite original report position/time',
      () async {
        await post({
          ...payload(type, key, 'same'),
          latKey: 24,
          lngKey: 121,
          timeKey: eventTime,
          'address': 'first',
        });
        await post({
          ...payload(type, key, 'same'),
          latKey: 25,
          lngKey: 122,
          timeKey: '2026-11-01T00:00:00Z',
          'address': 'second',
        });
        final rows = sql.select('SELECT * FROM $table');
        expect(rows.length, 1);
        expect(rows.single['address'], 'first');
        expect(rows.single[latKey], 24);
      },
    );
  }

  test(
    'parser handles zero, bounds, finite numbers, malformed dates and timezone comparison',
    () {
      expect(ReportLocation.latitude(0), 0);
      expect(ReportLocation.longitude(-180), -180);
      expect(ReportLocation.latitude(double.nan), isNull);
      expect(ReportLocation.longitude(double.infinity), isNull);
      for (final value in [
        null,
        '',
        'garbage',
        42,
        '2026-13-01T00:00:00Z',
        '2026-01-01T24:00:00Z',
        '2026-01-01T00:00:00+99:00',
      ]) {
        expect(ReportLocation.time(value), isNull, reason: '$value');
      }
      expect(
        ReportLocation.time('2026-01-01T08:00:00+08:00'),
        DateTime.utc(2026, 1, 1),
      );
      expect(ReportLocation.time('2024-02-29T00:00:00Z'), isNotNull);
    },
  );

  test(
    'legacy nullable rows and invalid historical times remain queryable, no fabricated now',
    () async {
      sql.execute(
        "INSERT INTO health_reports (uuid,reporterId,reportTime) VALUES ('old','U1','invalid')",
      );
      sql.execute(
        "INSERT INTO emergency_requests (emergencyId,userId) VALUES ('old','U1')",
      );
      sql.execute(
        "INSERT INTO supply_requests (requestId,userId,itemId,qty,createdAt) VALUES ('old','U1',1,1,'2020-01-01T00:00:00Z')",
      );
      final health = (await db.getAllReports()).single.toJson();
      expect(health['reportTime'], isNull);
      expect(health['address'], isNull);
      expect(health['receivedAt'], isNull);
      final emergency = EmergencyRequest.fromJson(
        sql.select('SELECT * FROM emergency_requests').single,
      ).toJson();
      expect(emergency['latitude'], isNull);
      expect(emergency['sentAt'], isNull);
      final supply = SupplyRequest.fromJson(
        (await db.getAllRequests()).single,
      ).toJson();
      expect(supply['reportedAt'], isNull);
      expect(supply['createdAt'], '2020-01-01T00:00:00.000Z');
    },
  );

  test(
    'dashboard selects newest valid event across tables, not receive/order time or residence',
    () async {
      for (final (id, time, lat) in [
        ('new', '2026-10-10T00:00:00Z', 24.123456789),
        ('old', '2026-10-01T00:00:00Z', 22.0),
      ]) {
        await db.insertHealthReport(
          HealthReport.fromJson({
            'uuid': id,
            'reporterId': 'U1',
            'receiverAdminId': 'A',
            'lat': lat,
            'lng': 121,
            'reportTime': time,
            'address': id,
          }),
        );
      }
      await db.insertEmergencyRequest(
        EmergencyRequest.fromJson({
          'emergencyId': 'sos',
          'userId': 'U1',
          'receiverAdminId': 'A',
          'latitude': 21,
          'longitude': 120,
          'sentAt': '2026-10-05T00:00:00Z',
          'receivedAt': '2026-12-01T00:00:00Z',
        }),
      );
      await db.insertSupplyRequest(
        SupplyRequest.fromJson({
          'requestId': 'supply',
          'userId': 'U1',
          'itemId': 1,
          'qty': 1,
          'receiverAdminId': 'A',
          'lat': 20,
          'lng': 120,
          'createdAt': '2026-12-02T00:00:00Z',
        }),
      );
      var victim = (await db.getVictimDashboard('A')).single;
      expect(victim['lat'], 24.123456789);
      expect(victim['address'], 'new');
      await db.insertSupplyRequest(
        SupplyRequest.fromJson({
          'requestId': 'latest',
          'userId': 'U1',
          'itemId': 1,
          'qty': 1,
          'receiverAdminId': 'A',
          'lat': 25,
          'lng': 122,
          'reportedAt': '2026-10-11T00:00:00Z',
          'address': 'latest',
        }),
      );
      await db.insertEmergencyRequest(
        EmergencyRequest.fromJson({
          'emergencyId': 'invalid-latest',
          'userId': 'U1',
          'receiverAdminId': 'A',
          'latitude': 99,
          'longitude': 120,
          'sentAt': '2026-10-12T00:00:00Z',
        }),
      );
      victim = (await db.getVictimDashboard('A')).single;
      expect(victim['lat'], 25);
      expect(victim['address'], 'latest');
      expect(victim['lastUpdatedAt'], '2026-10-11T00:00:00.000Z');
      expect((victim['supplyRequests'] as List).length, 2);
    },
  );

  test(
    'dashboard without known event time returns unknown position, retains source GPS',
    () async {
      await db.insertHealthReport(
        HealthReport.fromJson({
          'uuid': 'unknown',
          'reporterId': 'U1',
          'receiverAdminId': 'A',
          'lat': 24,
          'lng': 121,
        }),
      );
      final victim = (await db.getVictimDashboard('A')).single;
      expect(victim['lat'], isNull);
      expect(victim['lastUpdatedAt'], isNull);
      expect(sql.select('SELECT lat FROM health_reports').single['lat'], 24);
    },
  );

  test(
    'single INSERT statement failure rolls back trigger side effects and all report fields',
    () async {
      for (final (_, table, _, _, _, _) in specs) {
        sql.execute('''CREATE TRIGGER fail_$table BEFORE INSERT ON $table BEGIN
        UPDATE users SET area='corrupted';
        SELECT RAISE(ABORT,'injected failure'); END''');
      }
      final before = sql
          .select('SELECT * FROM users')
          .map((r) => Map.of(r))
          .toList();
      await expectLater(
        db.insertHealthReport(HealthReport.fromJson({'uuid': 'fail'})),
        throwsA(isA<SqliteException>()),
      );
      await expectLater(
        db.insertEmergencyRequest(
          EmergencyRequest.fromJson({'emergencyId': 'fail'}),
        ),
        throwsA(isA<SqliteException>()),
      );
      await expectLater(
        db.insertSupplyRequest(
          SupplyRequest.fromJson({
            'requestId': 'fail',
            'userId': 'U1',
            'itemId': 1,
            'qty': 1,
          }),
        ),
        throwsA(isA<SqliteException>()),
      );
      for (final (_, table, _, _, _, _) in specs) {
        expect(sql.select('SELECT * FROM $table'), isEmpty);
      }
      expect(
        sql.select('SELECT * FROM users').map((r) => Map.of(r)).toList(),
        before,
      );
      expect(sql.select('PRAGMA integrity_check').single.values.single, 'ok');
    },
  );

  test(
    'explicit transaction failure rolls back all report types together',
    () async {
      sql.execute(
        "CREATE TRIGGER reject_supply BEFORE INSERT ON supply_requests BEGIN SELECT RAISE(ABORT,'failure'); END",
      );
      sql.execute('BEGIN TRANSACTION');
      try {
        await db.insertHealthReport(
          HealthReport.fromJson({'uuid': 'rollback'}),
        );
        await db.insertEmergencyRequest(
          EmergencyRequest.fromJson({'emergencyId': 'rollback'}),
        );
        await db.insertSupplyRequest(
          SupplyRequest.fromJson({
            'requestId': 'rollback',
            'userId': 'U1',
            'itemId': 1,
            'qty': 1,
          }),
        );
        fail('Expected injected failure');
      } on SqliteException {
        sql.execute('ROLLBACK');
      }
      for (final (_, table, _, _, _, _) in specs) {
        expect(sql.select('SELECT * FROM $table'), isEmpty);
      }
    },
  );

  test('HTTP insert failures never report success', () async {
    for (final (type, table, key, _, _, _) in specs) {
      sql.execute(
        "CREATE TRIGGER reject_$table BEFORE INSERT ON $table BEGIN SELECT RAISE(ABORT,'failure'); END",
      );
      final req = await client.postUrl(
        Uri.parse('http://127.0.0.1:${server.port}'),
      );
      req.headers.contentType = ContentType.json;
      req.write(jsonEncode(payload(type, key, 'fail')));
      final response = await req.close();
      final result =
          jsonDecode(await utf8.decoder.bind(response).join()) as Map;
      expect(response.statusCode, greaterThanOrEqualTo(400));
      expect(result['success'], false);
      expect(sql.select('SELECT * FROM $table'), isEmpty);
    }
  });

  test(
    'additive migration is idempotent, preserves legacy values and file persistence',
    () async {
      final dir = await Directory.systemTemp.createTemp('report_location_');
      final path = '${dir.path}/isolated.db';
      Database? disk;
      try {
        disk = sqlite3.open(path);
        createReportFixture(disk);
        disk.execute('ALTER TABLE supply_requests DROP COLUMN reportedAt');
        disk.execute(
          "INSERT INTO supply_requests (requestId,userId,itemId,qty,address,createdAt) VALUES ('old','U1',1,1,'old address','2020-01-01T00:00:00Z')",
        );
        final before = Map.of(
          disk.select('SELECT * FROM supply_requests').single,
        );
        DatabaseService.ensureSupplyRequestSchema(disk);
        DatabaseService.ensureSupplyRequestSchema(disk);
        final migrated = Map.of(
          disk.select('SELECT * FROM supply_requests').single,
        );
        expect(migrated['reportedAt'], isNull);
        migrated.remove('reportedAt');
        expect(migrated, before);
        await DatabaseService(disk).insertSupplyRequest(
          SupplyRequest.fromJson({
            'requestId': 'persist',
            'userId': 'U1',
            'itemId': 1,
            'qty': 1,
            'lat': 24.123456789,
            'lng': 121.123456789,
            'address': 'persisted',
            'reportedAt': eventTime,
          }),
        );
        disk.dispose();
        disk = null;
        disk = sqlite3.open(path);
        final row = disk
            .select("SELECT * FROM supply_requests WHERE requestId='persist'")
            .single;
        expect(row['lat'], 24.123456789);
        expect(row['address'], 'persisted');
        expect(row['reportedAt'], eventTime);
      } finally {
        disk?.dispose();
        await dir.delete(recursive: true);
      }
    },
  );
}
