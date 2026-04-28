import 'dart:io';
import 'package:sqlite3/sqlite3.dart';
import 'package:admin_server/core/models/healthReport.dart';
import 'package:admin_server/core/models/admin.dart';
import 'package:admin_server/core/models/user.dart';

class DatabaseService {
  static late Database db;

  /// 初始化資料庫
  static Future<void> init() async {
    print('Initializing database...');

    final dataDir = Directory('data');
    if (!dataDir.existsSync()) {
      dataDir.createSync(recursive: true);
    }

    db = sqlite3.open('data/admin.db');

    // 管理者
    db.execute('''
      CREATE TABLE IF NOT EXISTS admins (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT UNIQUE,
        password TEXT
      );
    ''');

    // 使用者
    db.execute('''
      CREATE TABLE IF NOT EXISTS users (
        id TEXT PRIMARY KEY,
        name TEXT,
        phone TEXT,
        area TEXT,
        emergencyContactName TEXT,
        emergencyContactPhone TEXT,
        emergencyContactRelation TEXT,
        bloodType TEXT,
        medicalInfo TEXT,
        registeredAt TEXT
      );
    ''');

    // 災情回報
    db.execute('''
      CREATE TABLE IF NOT EXISTS health_reports (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        uuid TEXT UNIQUE,
        reporterId TEXT,
        name TEXT,
        phone TEXT,
        bloodType TEXT,
        status TEXT,
        description TEXT,
        lat REAL,
        lng REAL,
        reportTime TEXT
      );
    ''');

    // 物資
    db.execute('''
      CREATE TABLE IF NOT EXISTS inventory (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT,
        quantity INTEGER,
        updatedAt TEXT
      );
    ''');

    initDefaultAdmin();
    seedAll();

    print('Database ready');
  }

  // =====================
  // ADMIN
  // =====================
  static void insertAdmin(Admin admin) {
    db.execute(
      '''
      INSERT OR IGNORE INTO admins (username, password)
      VALUES (?, ?)
      ''',
      [admin.username, admin.password],
    );
  }

  static bool checkLogin(String username, String password) {
    final result = db.select(
      '''
      SELECT * FROM admins WHERE username = ? AND password = ?
      ''',
      [username, password],
    );

    return result.isNotEmpty;
  }

  static void initDefaultAdmin() {
    final result = db.select(
      "SELECT * FROM admins WHERE username = ?",
      ["admin"],
    );

    if (result.isEmpty) {
      db.execute(
        "INSERT INTO admins (username, password) VALUES (?, ?)",
        ["admin", "1234"],
      );
      print("Default admin created");
    }
  }

  // =====================
  // USER
  // =====================
  static void insertUser(AppUser user) {
    db.execute(
      '''
      INSERT OR REPLACE INTO users (
        id, name, phone, area,
        emergencyContactName,
        emergencyContactPhone,
        emergencyContactRelation,
        bloodType,
        medicalInfo,
        registeredAt
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''',
      [
        user.id,
        user.name,
        user.phone,
        user.area,
        user.emergencyContactName,
        user.emergencyContactPhone,
        user.emergencyContactRelation,
        user.bloodType,
        user.medicalInfo,
        user.registeredAt.toIso8601String(),
      ],
    );
  }

  static AppUser? getUser(String id) {
    final result = db.select(
      'SELECT * FROM users WHERE id = ?',
      [id],
    );

    if (result.isEmpty) return null;

    final row = result.first;

    return AppUser(
      id: row['id']?.toString() ?? '',
      name: row['name']?.toString() ?? '',
      phone: row['phone']?.toString() ?? '',
      area: row['area']?.toString() ?? '',
      emergencyContactName: row['emergencyContactName']?.toString() ?? '',
      emergencyContactPhone: row['emergencyContactPhone']?.toString() ?? '',
      emergencyContactRelation: row['emergencyContactRelation']?.toString() ?? '',
      bloodType: row['bloodType']?.toString(),
      medicalInfo: row['medicalInfo']?.toString(),
      registeredAt: DateTime.parse(
        row['registeredAt']?.toString() ??
            DateTime.now().toIso8601String(),
      ),
    );
  }

  static List<AppUser> getAllUsers() {
    final result = db.select('SELECT * FROM users');

    return result.map((row) {
      return AppUser(
        id: row['id']?.toString() ?? '',
        name: row['name']?.toString() ?? '',
        phone: row['phone']?.toString() ?? '',
        area: row['area']?.toString() ?? '',
        emergencyContactName: row['emergencyContactName']?.toString() ?? '',
        emergencyContactPhone: row['emergencyContactPhone']?.toString() ?? '',
        emergencyContactRelation: row['emergencyContactRelation']?.toString() ?? '',
        bloodType: row['bloodType']?.toString(),
        medicalInfo: row['medicalInfo']?.toString(),
        registeredAt: DateTime.parse(
          row['registeredAt']?.toString() ??
              DateTime.now().toIso8601String(),
        ),
      );
    }).toList();
  }

  // HEALTH REPORT
  static Future<void> insertHealthReport(HealthReport report) async{
    print("🔥 NEW DB METHOD CALLED");
    db.execute(
      '''
      INSERT OR IGNORE INTO health_reports (
        uuid, reporterId, name, phone,
        bloodType, status, description, lat, lng, reportTime
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''',
      [
        report.uuid,
        report.reporterId,
        report.name,
        report.phone,
        report.bloodType,
        report.status,
        report.description,
        report.lat,
        report.lng,
        report.reportTime.toIso8601String(),
      ],
    );
  }

  static List<HealthReport> getAllReports() {
    final result = db.select(
      'SELECT * FROM health_reports ORDER BY reportTime DESC',
    );

    return result.map((row) {
      return HealthReport(
        uuid: row['uuid']?.toString() ?? '',
        reporterId: row['reporterId']?.toString() ?? '',
        name: row['name']?.toString() ?? '',
        phone: row['phone']?.toString() ?? '',
        bloodType: row['bloodType']?.toString(),
        status: row['status']?.toString() ?? '',
        description: row['description']?.toString() ?? '',
        lat: (row['lat'] as num?)?.toDouble(),
        lng: (row['lng'] as num?)?.toDouble(),
        reportTime: DateTime.tryParse(
              row['reportTime']?.toString() ?? '',
            ) ??
            DateTime.now(),
      );
    }).toList();
  }

  // TEST DATA
  static void seedUsers() {
  final result = db.select("SELECT * FROM users");
  if (result.isNotEmpty) return;

  db.execute('''
    INSERT INTO users (
      id, name, phone, area,
      emergencyContactName,
      emergencyContactPhone,
      emergencyContactRelation,
      bloodType,
      medicalInfo,
      registeredAt
    ) VALUES (
      'U001',
      '王小明',
      '0912345678',
      '台中',
      '王爸爸',
      '0987654321',
      '父親',
      'A',
      '無',
      ?
    )
  ''', [DateTime.now().toIso8601String()]);

  db.execute('''
    INSERT INTO users VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
  ''', [
    'U002',
    '李小華',
    '0911111111',
    '台北',
    '李媽媽',
    '0922222222',
    '母親',
    'B',
    '氣喘',
    DateTime.now().toIso8601String(),
  ]);

  db.execute('''
    INSERT INTO users VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
  ''', [
    'U003',
    '陳大明',
    '0933333333',
    '高雄',
    '陳爸爸',
    '0944444444',
    '父親',
    'O',
    '糖尿病',
    DateTime.now().toIso8601String(),
  ]);
  db.execute('''
    INSERT INTO users VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
  ''', [
    'U004',
    '黃嘻嘻',
    '0925869345',
    '新竹',
    '鄭媽媽',
    '0911547852',
    '母親',
    'AB',
    '心悸',
    DateTime.now().toIso8601String(),
  ]);

  print("Seed users created");
}

static void seedHealthReports() {
  db.execute("DELETE FROM health_reports"); // 強制清空（開發用）

  db.execute('''
    INSERT INTO health_reports (
    uuid,
    reporterId,
    name,
    phone,
    bloodType,
    status,
    description,
    lat,
    lng,
    reportTime
  ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
  ''', [
    'R002',
    'U002',
    '李小華',
    '0911111111',
    'B',
    'safe',
    '狀況良好',
    25.0330,
    121.5654,
    DateTime.now().toIso8601String(),
  ]);

  db.execute('''
    INSERT INTO health_reports (
    uuid,
    reporterId,
    name,
    phone,
    bloodType,
    status,
    description,
    lat,
    lng,
    reportTime
  ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
  ''', [
    'R003',
    'U003',
    '陳大明',
    '0933333333',
    'O',
    'critical',
    '需要醫療協助',
    22.6273,
    120.3014,
    DateTime.now().toIso8601String(),
  ]);

  print("Seed health reports created");
}
//總控
static void seedAll() {
  seedUsers();
  seedHealthReports();
}

  // SEARCH
  static List<Map<String, Object?>> searchReports(String keyword) {
    final result = db.select(
      '''
      SELECT * FROM health_reports
      WHERE name LIKE ?
        OR status LIKE ?
        OR description LIKE ?
      ORDER BY reportTime DESC
      ''',
      ['%$keyword%', '%$keyword%', '%$keyword%'],
    );

    return result.toList();
  }

  static List<AppUser> searchUsers(String keyword) {
    final result = db.select(
      '''
      SELECT * FROM users
      WHERE name LIKE ?
        OR phone LIKE ?
        OR area LIKE ?
      ''',
      ['%$keyword%', '%$keyword%', '%$keyword%'],
    );

    return result.map((row) {
      return AppUser(
        id: row['id']?.toString() ?? '',
        name: row['name']?.toString() ?? '',
        phone: row['phone']?.toString() ?? '',
        area: row['area']?.toString() ?? '',
        emergencyContactName: row['emergencyContactName']?.toString() ?? '',
        emergencyContactPhone: row['emergencyContactPhone']?.toString() ?? '',
        emergencyContactRelation: row['emergencyContactRelation']?.toString() ?? '',
        bloodType: row['bloodType']?.toString(),
        medicalInfo: row['medicalInfo']?.toString(),
        registeredAt: DateTime.parse(
          row['registeredAt']?.toString() ??
              DateTime.now().toIso8601String(),
        ),
      );
    }).toList();
  }
}