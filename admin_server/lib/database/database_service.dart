import 'dart:io';
import 'package:sqlite3/sqlite3.dart';
import 'package:admin_server/core/models/healthReport.dart';

class DatabaseService {


  static late Database db;

  /// 初始化資料庫
  static Future<void> init() async {

    print('Initializing database...');

    /// 建立 data 資料夾
    final dataDir = Directory('data');
    if (!dataDir.existsSync()) {
      dataDir.createSync(recursive: true);
    }

    /// 開啟 SQLite
    db = sqlite3.open('data/admin.db');

    /// 建立資料表
    db.execute('''
      CREATE TABLE IF NOT EXISTS health_reports (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
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

    print('Database ready ');
  }

  /// 存入收到的封包
  static void insertHealthReport(HealthReport report) {
    db.execute(
      '''
      INSERT INTO health_reports (
        reporterId, name, phone, bloodType, status, description, lat, lng, reportTime
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''',
      [
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
}