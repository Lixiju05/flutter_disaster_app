import 'dart:io';
import 'package:sqlite3/sqlite3.dart';
import 'package:admin_server/core/models/healthReport.dart';
import 'package:admin_server/core/models/admin.dart';

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

    /// 管理者
    db.execute('''
      CREATE TABLE IF NOT EXISTS admins (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT UNIQUE,
        password TEXT
      );
    ''');

    /// 健康回報
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

    /// 物資
    db.execute('''
      CREATE TABLE IF NOT EXISTS inventory (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT,
        quantity INTEGER,
        updatedAt TEXT
      );
    ''');

    initDefaultAdmin();

    print('Database ready');
  }

  static void insertHealthReport(HealthReport report) {
    db.execute(
      '''
      INSERT OR IGNORE INTO health_reports (
        uuid, reporterId, name, phone,
        bloodType, status, description, lat, lng, reportTime
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
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

  /// 新增 admin
  static void insertAdmin(Admin admin) {
    db.execute(
      '''
      INSERT OR IGNORE INTO admins (username, password)
      VALUES (?, ?)
      ''',
      [admin.username, admin.password],
    );
  }

  /// 登入
  static bool checkLogin(String username, String password) {
    final result = db.select(
      '''
      SELECT * FROM admins WHERE username = ? AND password = ?
      ''',
      [username, password],
    );

    return result.isNotEmpty;
  }

  /// 預設 admin
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
}