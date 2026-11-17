import 'package:admin_server/database/database_service.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';

void main() {
  test('SOS Seed 的使用者、姓名、電話一致，周延依綁定 U014', () async {
    final sql = sqlite3.openInMemory();
    addTearDown(sql.dispose);
    sql.execute('''CREATE TABLE users (
      id TEXT PRIMARY KEY, name TEXT, phone TEXT, area TEXT,
      emergencyContactName TEXT, emergencyContactPhone TEXT,
      emergencyContactRelation TEXT, bloodType TEXT, medicalInfo TEXT,
      registeredAt TEXT
    )''');
    sql.execute('''CREATE TABLE emergency_requests (
      id INTEGER PRIMARY KEY AUTOINCREMENT, emergencyId TEXT UNIQUE,
      userId TEXT, userName TEXT, phone TEXT, latitude REAL, longitude REAL,
      address TEXT, status TEXT, receiverAdminId TEXT, hopCount INTEGER,
      sentAt TEXT, receivedAt TEXT
    )''');
    final db = DatabaseService(sql);
    await db.seedUsers();
    await db.seedEmergencyRequests();
    final rows = sql.select('''
      SELECT e.emergencyId, e.userId, e.userName, e.phone, e.address,
             u.name AS expectedName, u.phone AS expectedPhone, u.area
      FROM emergency_requests e LEFT JOIN users u ON e.userId = u.id
      ORDER BY e.emergencyId
    ''');
    expect(rows.map((r) => r['emergencyId']).toList(), [
      'SOS002',
      'SOS003',
      'SOS004',
      'SOS005',
    ]);
    expect(rows.map((r) => r['userId']).toList(), [
      'U011',
      'U012',
      'U013',
      'U014',
    ]);
    for (final row in rows) {
      expect(row['userName'], row['expectedName']);
      expect(row['phone'], row['expectedPhone']);
      expect(row['address'], row['area']);
    }
    expect(rows.last['userName'], '周延依');
    await db.seedEmergencyRequests();
    expect(sql.select('SELECT * FROM emergency_requests').length, 4);
  });
}
