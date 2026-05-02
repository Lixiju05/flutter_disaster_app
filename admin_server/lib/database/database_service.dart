import 'dart:io';
import 'package:sqlite3/sqlite3.dart';
import 'package:admin_server/core/models/healthReport.dart';
import 'package:admin_server/core/models/admin.dart';
import 'package:admin_server/core/models/user.dart';

class DatabaseService {
  final Database _db; // 核心實例變數

  DatabaseService(this._db);

  // 全域唯一的靜態實例
  static late DatabaseService instance;

  /// 初始化資料庫
  static Future<void> init() async {
    print('Initializing database...');

    final dataDir = Directory('data');
    if (!dataDir.existsSync()) {
      dataDir.createSync(recursive: true);
    }

    final rawDb = sqlite3.open('data/admin.db');
    instance = DatabaseService(rawDb);

    // 建立所有資料表
    rawDb.execute('''CREATE TABLE IF NOT EXISTS admins (id INTEGER PRIMARY KEY AUTOINCREMENT, username TEXT UNIQUE, password TEXT);''');
    rawDb.execute('''CREATE TABLE IF NOT EXISTS users (id TEXT PRIMARY KEY, name TEXT, phone TEXT, area TEXT, emergencyContactName TEXT, emergencyContactPhone TEXT, emergencyContactRelation TEXT, bloodType TEXT, medicalInfo TEXT, registeredAt TEXT);''');
    rawDb.execute('''CREATE TABLE IF NOT EXISTS health_reports (id INTEGER PRIMARY KEY AUTOINCREMENT, uuid TEXT UNIQUE, reporterId TEXT, name TEXT, phone TEXT, bloodType TEXT, status TEXT, description TEXT, lat REAL, lng REAL, reportTime TEXT);''');
    rawDb.execute('''CREATE TABLE IF NOT EXISTS inventory (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT, category TEXT, unit TEXT, stockQty INTEGER DEFAULT 0, reservedQty INTEGER DEFAULT 0, neededQty INTEGER DEFAULT 0, updatedAt TEXT);''');
    rawDb.execute('''CREATE TABLE IF NOT EXISTS allocations (id INTEGER PRIMARY KEY AUTOINCREMENT, itemId INTEGER, zoneId TEXT, quantity INTEGER, status TEXT, createdAt TEXT);''');

    instance._initDefaultAdmin();
    instance.seedAll();

    print('Database ready');
  }

  // --- 工具方法 ---
  Future<void> transaction(Future<void> Function() action) async {
    try {
      _db.execute('BEGIN TRANSACTION');
      await action();
      _db.execute('COMMIT');
    } catch (e) {
      _db.execute('ROLLBACK');
      rethrow;
    }
  }

  Future<ResultSet> select(String sql, [List<Object?> parameters = const []]) async{
    return _db.select(sql,parameters);
  }
  Future<void> execute(String sql, [List<Object?> parameters = const []]) async {
    _db.execute(sql, parameters);
  }
  // =====================
  // ADMIN 邏輯
  // =====================
  Future <void> insertAdmin(Admin admin) async{
    await execute('INSERT OR IGNORE INTO admins (username, password) VALUES (?, ?)', [admin.username, admin.password]);
  }

  Future<bool> checkLogin(String username, String password) async {
    final result = await select('SELECT * FROM admins WHERE username = ? AND password = ?', [username, password]);
    return result.isNotEmpty;
  }

  Future <void> _initDefaultAdmin() async{
    final result = await select("SELECT * FROM admins WHERE username = ?", ["admin"]);
    if (result.isEmpty) {
      await execute("INSERT INTO admins (username, password) VALUES (?, ?)", ["admin", "1234"]);
    }
  }

  // =====================
  // USER 邏輯
  // =====================
  Future<void> insertUser(AppUser user) async {
    await execute('''
      INSERT OR REPLACE INTO users (id, name, phone, area, emergencyContactName, emergencyContactPhone, 
      emergencyContactRelation, bloodType, medicalInfo, registeredAt) 
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''', 
      [user.id, user.name, user.phone, user.area, user.emergencyContactName, user.emergencyContactPhone, 
       user.emergencyContactRelation, user.bloodType, user.medicalInfo, user.registeredAt.toIso8601String()]);
  }

  Future<AppUser?> getUser(String id) async {
    final result = await select('SELECT * FROM users WHERE id = ?', [id]);
    return result.isEmpty ? null : _rowToUser(result.first);
  }

  Future<List<AppUser>> getAllUsers() async {
    final result = await select('SELECT * FROM users');
    return result.map((row) => _rowToUser(row)).toList();
  }

  Future<List<AppUser>> searchUsers(String keyword) async {
    final result = await select('SELECT * FROM users WHERE name LIKE ? OR phone LIKE ? OR area LIKE ?', 
    ['%$keyword%', '%$keyword%', '%$keyword%']);
    return result.map((row) => _rowToUser(row)).toList();
  }
  // =====================
  // HEALTH REPORT 邏輯
  // =====================
  Future<void> insertHealthReport(HealthReport report) async {
    await execute('''
      INSERT OR IGNORE INTO health_reports (uuid, reporterId, name, phone, bloodType, status, description, lat, lng, reportTime) 
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''', 
      [report.uuid, report.reporterId, report.name, report.phone, report.bloodType, report.status, 
       report.description, report.lat, report.lng, report.reportTime.toIso8601String()]);
  }

  Future<List<HealthReport>> getAllReports() async {
    final result = await select('SELECT * FROM health_reports ORDER BY reportTime DESC');
    return result.map((row) => _rowToHealthReport(row)).toList();
  }

  Future<List<Map<String, Object?>>> searchReports(String keyword) async {
    final result = await select('SELECT * FROM health_reports WHERE name LIKE ? OR status LIKE ? OR description LIKE ? ORDER BY reportTime DESC', 
    ['%$keyword%', '%$keyword%', '%$keyword%']);
    return result.toList();
  }

  // =====================
  // INVENTORY 邏輯
  // =====================
  Future<void> updateInventoryQty(int id, int stockQty) async {
    await execute('UPDATE inventory SET stockQty = ?, updatedAt = ? WHERE id = ?', [stockQty, DateTime.now().toIso8601String(), id]);
  }

  Future<List<Map<String, Object?>>> getAllInventory() async {
    final result = await select('SELECT * FROM inventory');
    return result.toList();
  }
  Future<void> addInventory({
    required String name,
    required String category,
    required String unit,
    required int stockQty,
    int neededQty = 0,
  }) async {
    await execute('''
      INSERT INTO inventory (
        name, category, unit,
        stockQty, reservedQty, neededQty,
        updatedAt
      )
      VALUES (?, ?, ?, ?, 0, ?, ?)
    ''', [
      name,
      category,
      unit,
      stockQty,
      neededQty,
      DateTime.now().toIso8601String(),
    ]);
  }

  //補貨
  Future<void> addStock(int id, int qty) async {
    await execute('''
      UPDATE inventory
      SET stockQty = stockQty + ?,
          updatedAt = ?
      WHERE id = ?
    ''', [
      qty,
      DateTime.now().toIso8601String(),
      id
    ]);
  }

  //更新需求量
  Future<void> updateNeeded(int id, int neededQty) async {
    await execute('''
      UPDATE inventory
      SET neededQty = ?,
          updatedAt = ?
      WHERE id = ?
    ''', [
      neededQty,
      DateTime.now().toIso8601String(),
      id
    ]);
  }
  //預留物資
  Future<void> allocate({
    required int itemId,
    required String zoneId,
    required int qty,
  }) async {

    await transaction(() async {

      // 1️⃣ 檢查庫存
      final item = await select(
        'SELECT * FROM inventory WHERE id = ?',
        [itemId],
      );

      if (item.isEmpty) {
        throw Exception("Item not found");
      }

      final row = item.first;
      final stock = row['stockQty'] as int;

      if (stock < qty) {
        throw Exception("Not enough stock");
      }

      // 2️⃣ 增加 reserved
      await execute('''
        UPDATE inventory
        SET reservedQty = reservedQty + ?
        WHERE id = ?
      ''', [qty, itemId]);

      // 3️⃣ 建立 allocation
      await execute('''
        INSERT INTO allocations (
          itemId, zoneId, quantity,
          status, createdAt
        )
        VALUES (?, ?, ?, 'reserved', ?)
      ''', [
        itemId,
        zoneId,
        qty,
        DateTime.now().toIso8601String(),
      ]);
    });
  }

  //查allocation
  Future<List<Map<String, Object?>>> getAllocations() async {
    final result = await select('''
      SELECT * FROM allocations
      ORDER BY createdAt DESC
    ''');
    return result.toList();
  }

  //出貨(扣庫存)
  Future<void> dispatch({
    required int allocationId,
  }) async {

    await transaction(() async {

      // 1️⃣ 找 allocation
      final alloc = await select(
        'SELECT * FROM allocations WHERE id = ?',
        [allocationId],
      );

      if (alloc.isEmpty) {
        throw Exception("Allocation not found");
      }

      final a = alloc.first;

      final itemId = a['itemId'] as int;
      final qty = a['quantity'] as int;
      final status = a['status'] as String;

      if (status == 'shipped') {
        throw Exception("Already shipped");
      }

      // 2️⃣ 更新 inventory
      await execute('''
        UPDATE inventory
        SET stockQty = stockQty - ?,
            reservedQty = reservedQty - ?
        WHERE id = ?
      ''', [
        qty,
        qty,
        itemId
      ]);

      // 3️⃣ 更新 allocation
      await execute('''
        UPDATE allocations
        SET status = 'shipped'
        WHERE id = ?
      ''', [allocationId]);
    });
  }

  //查daispatch
  Future<List<Map<String, Object?>>> getDispatches() async {
    final result = await select('''
      SELECT * FROM allocations
      WHERE status = 'shipped'
      ORDER BY createdAt DESC
    ''');
    return result.toList();
  }

  // =====================
  // SEED & HELPERS (重複的部分已刪除)
  // =====================
  Future<void> seedAll() async {
    final result = await select("SELECT id FROM users LIMIT 1");
    if (result.isEmpty) {
      await seedUsers();
      await seedHealthReports();
      print("Seed data completed.");
    }
  }

  Future<void> seedUsers() async {
    await execute("INSERT INTO users (id, name, phone, area, registeredAt) VALUES ('U001', '王小明', '0912345678', '台中', ?)", [DateTime.now().toIso8601String()]);
  }

  Future<void> seedHealthReports() async {
    await execute("INSERT INTO health_reports (uuid, reporterId, name, status, reportTime) VALUES ('R001', 'U001', '王小明', 'safe', ?)", [DateTime.now().toIso8601String()]);
  }

  AppUser _rowToUser(Row row) {
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
      registeredAt: DateTime.tryParse(row['registeredAt']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  HealthReport _rowToHealthReport(Row row) {
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
      reportTime: DateTime.tryParse(row['reportTime']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}