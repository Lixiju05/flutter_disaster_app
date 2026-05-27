import 'dart:io';
import 'package:sqlite3/sqlite3.dart';
import 'package:admin_server/core/models/healthReport.dart';
import 'package:admin_server/core/models/admin.dart';
import 'package:admin_server/core/models/user.dart';
import 'package:admin_server/core/models/supply_request.dart';
import 'package:admin_server/core/models/emergency_request.dart';

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
    rawDb.execute('''CREATE TABLE IF NOT EXISTS admins (id INTEGER PRIMARY KEY AUTOINCREMENT,username TEXT UNIQUE,password TEXT);''');
    rawDb.execute('''CREATE TABLE IF NOT EXISTS users (id TEXT PRIMARY KEY, name TEXT, phone TEXT, area TEXT, emergencyContactName TEXT, emergencyContactPhone TEXT, emergencyContactRelation TEXT, bloodType TEXT, medicalInfo TEXT, registeredAt TEXT);''');
    rawDb.execute('''CREATE TABLE IF NOT EXISTS health_reports (id INTEGER PRIMARY KEY AUTOINCREMENT, uuid TEXT UNIQUE, reporterId TEXT, name TEXT, phone TEXT, bloodType TEXT, status TEXT, description TEXT, lat REAL, lng REAL,address TEXT, reportTime TEXT,receiverAdminId TEXT,hopCount INTEGER DEFAULT 0,receivedAt TEXT);''');
    rawDb.execute('''CREATE TABLE IF NOT EXISTS inventory (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT, category TEXT, unit TEXT, stockQty INTEGER DEFAULT 0, reservedQty INTEGER DEFAULT 0, neededQty INTEGER DEFAULT 0, updatedAt TEXT);''');
    rawDb.execute('''CREATE TABLE IF NOT EXISTS allocations (id INTEGER PRIMARY KEY AUTOINCREMENT, itemId INTEGER, zoneId TEXT, quantity INTEGER, status TEXT, createdAt TEXT);''');
    rawDb.execute('''CREATE TABLE IF NOT EXISTS supply_requests (id INTEGER PRIMARY KEY AUTOINCREMENT,requestId TEXT UNIQUE,userId TEXT,itemId INTEGER,qty INTEGER,lat REAL,lng REAL,address TEXT,status TEXT,createdAt TEXT,receiverAdminId TEXT,hopCount INTEGER DEFAULT 0,receivedAt TEXT);''');
    rawDb.execute('''CREATE TABLE IF NOT EXISTS emergency_requests (id INTEGER PRIMARY KEY AUTOINCREMENT,emergencyId TEXT UNIQUE,userId TEXT,userName TEXT,phone TEXT,latitude REAL,longitude REAL,address TEXT,status TEXT,receiverAdminId TEXT,hopCount INTEGER DEFAULT 0,sentAt TEXT,receivedAt TEXT);''');

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

  Future<void> _initDefaultAdmin() async {
    final result = await select(
      "SELECT * FROM admins WHERE username = ?",
      ["admin_ncnu"],
    );

    if (result.isEmpty) {
      await execute(
        "INSERT INTO admins (username, password) VALUES (?, ?)",
        ["admin_ncnu", "1234"],
      );

      print("Default admin created");
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
      INSERT OR IGNORE INTO health_reports (
        uuid,
        reporterId,
        name,
        phone,
        bloodType,
        status,
        description,
        lat,
        lng,
        reportTime,
        receiverAdminId,
        hopCount,
        receivedAt
      )
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ''', [
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
      report.receiverAdminId,
      report.hopCount,
      report.receivedAt?.toIso8601String(),
    ]);
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

  Future<List<HealthReport>> getHealthReportsByAdmin(
    String receiverAdminId,
  ) async {
    final result = await select('''
      SELECT *
      FROM health_reports
      WHERE receiverAdminId = ?
      ORDER BY receivedAt DESC
    ''', [receiverAdminId]);

    return result.map((row) {
      return HealthReport.fromMap(row);
    }).toList();
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

    // 1️⃣ 先檢查有沒有同品項
    final result = await select(
      '''
      SELECT * FROM inventory
      WHERE name = ?
      ''',
      [name],
    );

    // 2️⃣ 有 -> 更新數量
    if (result.isNotEmpty) {

      final row = result.first;

      final currentStock =
          row['stockQty'] as int;

      final currentNeeded =
          row['neededQty'] as int;

      await execute(
        '''
        UPDATE inventory
        SET stockQty = ?,
            neededQty = ?,
            updatedAt = ?
        WHERE name = ?
        ''',
        [
          currentStock + stockQty,
          currentNeeded + neededQty,
          DateTime.now().toIso8601String(),
          name,
        ],
      );

    } else {

      // 3️⃣ 沒有 -> 新增
      await execute(
        '''
        INSERT INTO inventory (
          name,
          category,
          unit,
          stockQty,
          reservedQty,
          neededQty,
          updatedAt
        )
        VALUES (?, ?, ?, ?, 0, ?, ?)
        ''',
        [
          name,
          category,
          unit,
          stockQty,
          neededQty,
          DateTime.now().toIso8601String(),
        ],
      );
    }
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

  Future<void> insertSupplyRequest(SupplyRequest req) async {
    await execute('''
      INSERT OR IGNORE INTO supply_requests (
        requestId,
        userId,
        itemId,
        qty,
        lat,
        lng,
        receiverAdminId,
        hopCount,
        status,
        createdAt,
        receivedAt
      )
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ''', [
      req.requestId,
      req.userId,
      req.itemId,
      req.qty,
      req.lat,
      req.lng,
      req.receiverAdminId,
      req.hopCount,
      req.status,
      req.createdAt.toIso8601String(),
      req.receivedAt?.toIso8601String(),
    ]);
  }

  Future<List<Map<String, Object?>>> getAllRequests() async {
    final result = await select('SELECT * FROM supply_requests ORDER BY createdAt DESC');
    return result.toList();
  }

  Future<List<Map<String, Object?>>> getRequestsByAdmin(
    String receiverAdminId,
  ) async {
    final result = await select('''
      SELECT
        sr.requestId,
        sr.userId,
        sr.itemId,
        i.name AS itemName,
        i.unit AS unit,
        sr.qty,
        sr.lat,
        sr.lng,
        sr.receiverAdminId,
        sr.hopCount,
        sr.status,
        sr.createdAt,
        sr.receivedAt
      FROM supply_requests sr
      JOIN inventory i ON sr.itemId = i.id
      WHERE sr.receiverAdminId = ?
      ORDER BY sr.receivedAt DESC
    ''', [receiverAdminId]);

    return result.toList();
  }

  Future<void> updateRequestStatus(String requestId, String status) async {
    await execute('''
      UPDATE supply_requests
      SET status = ?
      WHERE requestId = ?
    ''', [status, requestId]);
  }

  // 1. 登入時抓取該帳號對應的轄區
  Future<String?> getZoneIdByAdmin(String username, String password) async {
    final result = await select(
      'SELECT zoneId FROM admins WHERE username = ? AND password = ?', 
      [username, password]
    );
    if (result.isEmpty) return null;
    return result.first['zoneId']?.toString();
  }


  Future<List<Map<String, Object?>>> getHotZones() async {
    final result = await select('''
      SELECT 
        gridId,
        zoneId,
        SUM(qty) AS totalQty,
        COUNT(*) AS requestCount
      FROM supply_requests
      WHERE status = 'pending'
      GROUP BY gridId, zoneId
      ORDER BY totalQty DESC
    ''');

    return result.toList();
  }
  Future<void> insertEmergencyRequest(EmergencyRequest req) async {
    await execute('''
      INSERT OR IGNORE INTO emergency_requests (
        emergencyId,
        userId,
        userName,
        phone,
        latitude,
        longitude,
        status,
        receiverAdminId,
        hopCount,
        sentAt,
        receivedAt
      )
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''', [
        req.emergencyId,
        req.userId,
        req.userName,
        req.phone,
        req.lat,
        req.lng,
        req.status,
        req.receiverAdminId,
        req.hopCount,
        req.sentAt.toIso8601String(),
        req.receivedAt?.toIso8601String(),
      ]);
  }

  Future<List<Map<String, Object?>>> getEmergencyRequestsByAdmin(
    String receiverAdminId,
  ) async {
    final result = await select('''
      SELECT *
      FROM emergency_requests
      WHERE receiverAdminId = ?
      ORDER BY receivedAt DESC
    ''', [receiverAdminId]);

    return result.toList();
  }

  Future<void> updateEmergencyStatus(
    String emergencyId,
    String status,
  ) async {
    await execute('''
      UPDATE emergency_requests
      SET status = ?
      WHERE emergencyId = ?
    ''', [status, emergencyId]);
  }

  Future<List<Map<String, dynamic>>> getVictimDashboard(
  String receiverAdminId,
) async {
  final victims = <String, Map<String, dynamic>>{};

  // 1. 健康回報
  final healthReports = await getHealthReportsByAdmin(receiverAdminId);

  for (final report in healthReports) {
    victims[report.reporterId] ??= {
      "userId": report.reporterId,
      "name": report.name,
      "phone": report.phone,
      "healthStatus": null,
      "healthDescription": null,
      "hasSOS": false,
      "sosStatus": null,
      "supplyRequests": [],
      "lat": report.lat,
      "lng": report.lng,
      "lastUpdatedAt": report.reportTime.toIso8601String(),
    };

    victims[report.reporterId]!["healthStatus"] = report.status;
    victims[report.reporterId]!["healthDescription"] = report.description;
    victims[report.reporterId]!["lat"] = report.lat;
    victims[report.reporterId]!["lng"] = report.lng;
    victims[report.reporterId]!["lastUpdatedAt"] =
        report.reportTime.toIso8601String();
  }

  // 2. SOS
  final sosList =
    await getEmergencyRequestsByAdmin(
      receiverAdminId,
    );

  for (final sos in sosList) {

    final userId =
        sos['userId']?.toString() ?? '';

    victims[userId] ??= {
      "userId": userId,

      "name":
          sos['userName']?.toString() ?? '',

      "phone":
          sos['phone']?.toString() ?? '',

      "healthStatus": null,

      "healthDescription": null,

      "hasSOS": false,

      "sosStatus": null,

      "supplyRequests": [],

      "lat": sos['latitude'],

      "lng": sos['longitude'],

      "lastUpdatedAt":
          sos['sentAt']?.toString(),
    };

    victims[userId]!["hasSOS"] = true;

    victims[userId]!["sosStatus"] =
        sos['status'];

    victims[userId]!["lat"] =
        sos['latitude'];

    victims[userId]!["lng"] =
        sos['longitude'];

    victims[userId]!["lastUpdatedAt"] =
        sos['sentAt']?.toString();
  }

    // 3. 物資需求
    final requests = await getRequestsByAdmin(receiverAdminId);

    for (final req in requests) {
      final userId = req['userId']?.toString() ?? '';
      if (userId.isEmpty) continue;

      victims[userId] ??= {
        "userId": userId,
        "name": "",
        "phone": "",
        "healthStatus": null,
        "healthDescription": null,
        "hasSOS": false,
        "sosStatus": null,
        "supplyRequests": [],
        "lat": req['lat'],
        "lng": req['lng'],
        "lastUpdatedAt": req['receivedAt']?.toString() ??
            req['createdAt']?.toString(),
      };

      (victims[userId]!["supplyRequests"] as List).add({
        "requestId": req['requestId'],
        "itemId": req['itemId'],
        "itemName": req['itemName'],
        "unit": req['unit'],
        "qty": req['qty'],
        "status": req['status'],
      });

      victims[userId]!["lat"] = req['lat'];
      victims[userId]!["lng"] = req['lng'];
      victims[userId]!["lastUpdatedAt"] =
          req['receivedAt']?.toString() ?? req['createdAt']?.toString();
    }

    final list = victims.values.toList();

    list.sort((a, b) {
      int priority(Map<String, dynamic> v) {
        if (v["hasSOS"] == true && v["sosStatus"] == "active") return 0;
        if (v["healthStatus"] == "critical") return 1;
        if (v["healthStatus"] == "missing") return 2;
        if ((v["supplyRequests"] as List).isNotEmpty) return 3;
        if (v["healthStatus"] == "minor") return 4;
        return 5;
      }

      return priority(a).compareTo(priority(b));
    });

    return list;
  }

 Future<Map<String, dynamic>> dispatchSupplyRequest({
  required String requestId,
}) async {
  Map<String, dynamic>? dispatchResult;

  await transaction(() async {
    final reqResult = await select('''
      SELECT *
      FROM supply_requests
      WHERE requestId = ?
    ''', [requestId]);

    if (reqResult.isEmpty) {
      throw Exception("Supply request not found");
    }

    final req = reqResult.first;

    final itemId = req['itemId'] as int;
    final qty = req['qty'] as int;
    final status = req['status']?.toString() ?? 'pending';

    if (status == 'dispatched') {
      throw Exception("Already dispatched");
    }

    final itemResult = await select('''
      SELECT *
      FROM inventory
      WHERE id = ?
    ''', [itemId]);

    if (itemResult.isEmpty) {
      throw Exception("Inventory item not found");
    }

    final item = itemResult.first;

    final stockQty = item['stockQty'] as int;
    final itemName = item['name']?.toString() ?? '';
    final unit = item['unit']?.toString() ?? '';

    if (stockQty < qty) {
      throw Exception("Not enough stock");
    }

    await execute('''
      UPDATE inventory
      SET stockQty = stockQty - ?,
          updatedAt = ?
      WHERE id = ?
    ''', [
      qty,
      DateTime.now().toIso8601String(),
      itemId,
    ]);

    await execute('''
      UPDATE supply_requests
      SET status = 'dispatched'
      WHERE requestId = ?
    ''', [requestId]);

    dispatchResult = {
      "requestId": requestId,
      "itemId": itemId,
      "itemName": itemName,
      "unit": unit,
      "qty": qty,
      "status": "dispatched",
    };
  });

  return dispatchResult!;
}

  // =====================
  // SEED & HELPERS 
  // =====================
  Future<void> seedAll() async {

  await seedUsers();

  await seedHealthReports();

  await seedInventory();

  await seedAllocations();

  await seedSupplyRequests();

  await seedEmergencyRequests();

  print("All seed data completed");
}

  Future<void> seedUsers() async {
    final users = [
      ['U001', '王小明', '0912345678', '南投縣埔里鎮大學路521號'],
      ['U002', '李小華', '0923456789', '南投縣埔里鎮大學路560號'],

      ['U003', '陳志明', '0934567891', '南投縣埔里鎮大學路470號'],
      ['U004', '林雅婷', '0945678912', '南投縣埔里鎮大學路301號'],

      ['U005', '黃建豪', '0956789123', '南投縣埔里鎮大學路480號'],
      ['U006', '張美玲', '0967891234', '南投縣埔里鎮大學路500號'],

      ['U007', '吳宗翰', '0978912345', '南投縣埔里鎮大學路490號'],
      ['U008', '蔡佩珊', '0989123456', '南投縣埔里鎮大學路502號'],

      ['U009', '劉志偉', '0990123456', '南投縣埔里鎮大學路506號'],
      ['U010', '陳美玲', '0910123456', '南投縣埔里鎮大學路511號'],
    ];


  for (final u in users) {
    await execute('''
      INSERT OR IGNORE INTO users (
        id, name, phone, area, registeredAt
      )
      VALUES (?, ?, ?, ?, ?)
    ''', [
      u[0],
      u[1],
      u[2],
      u[3],
      DateTime.now().toIso8601String(),
    ]);
  }

  print("Seed users created");
  }

  Future<void> seedHealthReports() async {
    final reports = [

  [
    'R001',
    'U001',
    '王小明',
    'safe',
    '目前安全，在宿舍區',
    23.9531,
    120.9302,
    '南投縣埔里鎮大學路521號'
  ],

  [
    'R002',
    'U002',
    '李小華',
    'minor',
    '腳受傷，需要醫療協助',
    23.9520,
    120.9290,
    '南投縣埔里鎮大學路560號'
  ],

  [
    'R003',
    'U003',
    '陳志明',
    'critical',
    '受困教學大樓',
    23.9505,
    120.9278,
    '南投縣埔里鎮大學路470號'

  ],

  [
    'R004',
    'U004',
    '林雅婷',
    'safe',
    '目前安全',
    23.9498,
    120.9269,
    '南投縣埔里鎮大學路301號'

  ],

  [
    'R005',
    'U005',
    '黃建豪',
    'minor',
    '需要簡單包紮',
    23.9521,
    120.9281,
    '南投縣埔里鎮大學路480號'

  ],

];

  for (final r in reports) {

    await execute('''
      INSERT OR IGNORE INTO health_reports (
        uuid,
        reporterId,
        name,
        status,
        description,
        lat,
        lng,
        address,
        reportTime
      )
      VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    ''', [

      r[0],
      r[1],
      r[2],
      r[3],
      r[4],
      r[5],
      r[6],
      r[7],
      DateTime.now().toIso8601String(),

    ]);
  }

  print("Seed health reports created");
  }

Future<void> seedInventory() async {

  final items = [

    ['礦泉水', '食品飲水', '箱', 120, 20, 300],
    ['泡麵', '食品飲水', '箱', 80, 10, 200],
    ['餅乾', '食品飲水', '箱', 50, 5, 100],

    ['毛毯', '生活用品', '件', 40, 15, 80],
    ['睡袋', '生活用品', '件', 25, 5, 50],

    ['口罩', '醫療衛生', '盒', 300, 50, 500],
    ['急救包', '醫療衛生', '組', 60, 10, 120],
    ['退燒藥', '醫療衛生', '盒', 45, 8, 100],

    ['雨衣', '衣物', '件', 70, 12, 150],
    ['保暖外套', '衣物', '件', 30, 3, 60],

  ];

  for (final i in items) {

    await execute('''
      INSERT INTO inventory (
        name,
        category,
        unit,
        stockQty,
        reservedQty,
        neededQty,
        updatedAt
      )
      VALUES (?, ?, ?, ?, ?, ?, ?)
    ''', [

      i[0],
      i[1],
      i[2],
      i[3],
      i[4],
      i[5],
      DateTime.now().toIso8601String(),

    ]);
  }

  print("Seed inventory created");
  }

Future<void> seedAllocations() async {

  await execute('''
    INSERT INTO allocations (
      itemId,
      zoneId,
      quantity,
      status,
      createdAt
    )
    VALUES (?, ?, ?, ?, ?)
  ''', [

    1,
    '宿舍區物資站',
    30,
    'reserved',
    DateTime.now().toIso8601String(),

  ]);

  await execute('''
    INSERT INTO allocations (
      itemId,
      zoneId,
      quantity,
      status,
      createdAt
    )
    VALUES (?, ?, ?, ?, ?)
  ''', [

    2,
    '教學大樓物資站',
    20,
    'shipped',
    DateTime.now().toIso8601String(),

  ]);

  print("Seed allocations created");
  }

  Future<void> seedSupplyRequests() async {
    final result = await select("SELECT id FROM supply_requests LIMIT 1");
    if (result.isNotEmpty) return;

    final requests = [
      ['REQ001', 'U001', 1, 20, 23.9512, 120.9285, 'admin_ncnu', 1],
      ['REQ002', 'U002', 1, 35, 23.9520, 120.9290, 'admin_ncnu', 2],
      ['REQ003', 'U003', 2, 15, 23.9505, 120.9278, 'admin_ncnu', 1],
      ['REQ004', 'U004', 7, 10, 23.9531, 120.9302, 'admin_ncnu', 3],
    ];

    for (final r in requests) {
      await execute('''
        INSERT OR IGNORE INTO supply_requests (
          requestId,
          userId,
          itemId,
          qty,
          lat,
          lng,
          receiverAdminId,
          hopCount,
          status,
          createdAt,
          receivedAt
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''', [
        r[0],
        r[1],
        r[2],
        r[3],
        r[4],
        r[5],
        r[6],
        r[7],
        'pending',
        DateTime.now().toIso8601String(),
        DateTime.now().toIso8601String(),
      ]);
    }

    print("Seed supply requests created");
  }
    Future<List<Map<String, Object?>>> getSupplyRequestDetails() async {
      final result = await select('''
        SELECT
          sr.requestId,
          sr.userId,
          sr.itemId,
          i.name AS itemName,
          i.unit AS unit,
          sr.qty,
          sr.lat,
          sr.lng,
          sr.receiverAdminId,
          sr.hopCount,
          sr.status,
          sr.createdAt,
          sr.receivedAt
        FROM supply_requests sr
        JOIN inventory i
        ON sr.itemId = i.id
        ORDER BY sr.createdAt DESC
      ''');

      return result.toList();
    }

  Future<void> seedEmergencyRequests() async {

  final now = DateTime.now();

  final sosData = [

    [
      'SOS002',
      'U002',
      '李小華',
      '0922333444',
      23.9520,
      120.9290,
      '南投縣埔里鎮大學路560號',
      'active',
      'admin_ncnu',
      3,
      now.subtract(Duration(minutes: 20)),
      now.subtract(Duration(minutes: 12)),
    ],

    [
      'SOS003',
      'U003',
      '陳志明',
      '0933555666',
      23.9505,
      120.9278,
      '南投縣埔里鎮大學路470號',
      'processing',
      'admin_ncnu',
      1,
      now.subtract(Duration(minutes: 30)),
      now.subtract(Duration(minutes: 25)),
    ],

    [
      'SOS004',
      'U004',
      '張雅婷',
      '0977888999',
      23.9498,
      120.9269,
      '南投縣埔里鎮大學路301號',
      'resolved',
      'admin_ncnu',
      4,
      now.subtract(Duration(hours: 1)),
      now.subtract(Duration(minutes: 50)),
    ],

    [
      'SOS005',
      'U005',
      '林建宏',
      '0988777666',
      23.9531,
      120.9302,
      '南投縣埔里鎮大學路480號',
      'active',
      'admin_ncnu',
      2,
      now.subtract(Duration(minutes: 8)),
      now.subtract(Duration(minutes: 5)),
    ],
    
  ];

  for (final s in sosData) {

    await execute('''
      INSERT OR IGNORE INTO emergency_requests (
        emergencyId,
        userId,
        userName,
        phone,
        latitude,
        longitude,
        address,
        status,
        receiverAdminId,
        hopCount,
        sentAt,
        receivedAt
      )
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ''', [
      s[0],
      s[1],
      s[2],
      s[3],
      s[4],
      s[5],
      s[6],
      s[7],
      s[8],
      s[9],
      (s[10] as DateTime).toIso8601String(),
      (s[11] as DateTime).toIso8601String(),
    ]);
  }

  print("Seed emergency requests created");
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
      address: row['address']?.toString() ?? '',
      reportTime: DateTime.tryParse(row['reportTime']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}