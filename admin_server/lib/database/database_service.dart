import 'dart:io';
import 'package:sqlite3/sqlite3.dart';
import 'package:admin_server/core/models/healthReport.dart';
import 'package:admin_server/core/models/admin.dart';
import 'package:admin_server/core/models/user.dart';
import 'package:admin_server/core/models/supply_request.dart';

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
    rawDb.execute('''CREATE TABLE IF NOT EXISTS admins (id INTEGER PRIMARY KEY AUTOINCREMENT,username TEXT UNIQUE,password TEXT,zoneId TEXT);''');
    rawDb.execute('''CREATE TABLE IF NOT EXISTS users (id TEXT PRIMARY KEY, name TEXT, phone TEXT, area TEXT, emergencyContactName TEXT, emergencyContactPhone TEXT, emergencyContactRelation TEXT, bloodType TEXT, medicalInfo TEXT, registeredAt TEXT);''');
    rawDb.execute('''CREATE TABLE IF NOT EXISTS health_reports (id INTEGER PRIMARY KEY AUTOINCREMENT, uuid TEXT UNIQUE, reporterId TEXT, name TEXT, phone TEXT, bloodType TEXT, status TEXT, description TEXT, lat REAL, lng REAL, reportTime TEXT);''');
    rawDb.execute('''CREATE TABLE IF NOT EXISTS inventory (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT, category TEXT, unit TEXT, stockQty INTEGER DEFAULT 0, reservedQty INTEGER DEFAULT 0, neededQty INTEGER DEFAULT 0, updatedAt TEXT);''');
    rawDb.execute('''CREATE TABLE IF NOT EXISTS allocations (id INTEGER PRIMARY KEY AUTOINCREMENT, itemId INTEGER, zoneId TEXT, quantity INTEGER, status TEXT, createdAt TEXT);''');
    rawDb.execute('''CREATE TABLE IF NOT EXISTS supply_requests (id INTEGER PRIMARY KEY AUTOINCREMENT,requestId TEXT UNIQUE,itemId INTEGER,qty INTEGER,lat REAL,lng REAL,zoneId TEXT,gridId TEXT,status TEXT,createdAt TEXT);''');

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
    // 建立一個轄區配置清單
    final defaultOffices = [
      {'u': 'admin_puli', 'p': 'puli123', 'z': '埔里鎮公所'},
      {'u': 'admin_nanan', 'p': '1234', 'z': '南安里'},
      {'u': 'admin_danan', 'p': '1234', 'z': '大湳里'},
      {'u': 'admin_piba', 'p': '1234', 'z': '枇杷里'},
      {'u': 'admin_shuimen', 'p': '1234', 'z': '水門里'},
    ];

    for (var office in defaultOffices) {
      final result = await select(
        "SELECT * FROM admins WHERE username = ?", 
        [office['u']]
      );
      
      if (result.isEmpty) {
        await execute(
          "INSERT INTO admins (username, password, zoneId) VALUES (?, ?, ?)", 
          [office['u'], office['p'], office['z']]
        );
        print("建立轄區管理員: ${office['z']}");
      }
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
      INSERT INTO supply_requests (
        requestId, itemId, qty,
        lat, lng, zoneId, gridId,
        status, createdAt
      )
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
    ''', [
      req.requestId,
      req.itemId,
      req.qty,
      req.lat,
      req.lng,
      req.zoneId,
      req.gridId,
      req.status,
      req.createdAt.toIso8601String(),
    ]);
  }

  Future<List<Map<String, Object?>>> getAllRequests() async {
    final result = await select('SELECT * FROM supply_requests ORDER BY createdAt DESC');
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

  // 2. 所有的查詢方法都「強制帶入」zoneId
  Future<List<Map<String, Object?>>> getRequestsForOffice(String zoneId) async {
    return await select('''
      SELECT sr.*, i.name as itemName 
      FROM supply_requests sr
      JOIN inventory i ON sr.itemId = i.id
      WHERE sr.zoneId = ? 
      ORDER BY sr.createdAt DESC
    ''', [zoneId]);
  }

  Future<List<Map<String, Object?>>> getRequestSummaryByGrid() async {
    final result = await select('''
      SELECT 
        gridId,
        zoneId,
        itemId,
        SUM(qty) AS totalQty,
        COUNT(*) AS requestCount
      FROM supply_requests
      WHERE status = 'pending'
      GROUP BY gridId, zoneId, itemId
      ORDER BY totalQty DESC
    ''');

    return result.toList();
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
  // =====================
  // SEED & HELPERS 
  // =====================
  Future<void> seedAll() async {

  await seedUsers();

  await seedHealthReports();

  await seedInventory();

  await seedAllocations();

  await seedSupplyRequests();

  print("All seed data completed");
}

  Future<void> seedUsers() async {
    final users = [
    ['U001', '王小明', '0912345678', '台中'],
    ['U002', '李小華', '0923456789', '台北'],
    ['U003', '陳志明', '0934567891', '高雄'],
    ['U004', '林雅婷', '0945678912', '台南'],
    ['U005', '黃建豪', '0956789123', '新竹'],
    ['U006', '張美玲', '0967891234', '彰化'],
    ['U007', '吳宗翰', '0978912345', '南投'],
    ['U008', '蔡佩珊', '0989123456', '花蓮'],
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
      '目前安全，在避難所',
      24.1477,
      120.6736
    ],

    [
      'R002',
      'U002',
      '李小華',
      'injured',
      '腳受傷，需要醫療協助',
      25.0330,
      121.5654
    ],

    [
      'R003',
      'U003',
      '陳志明',
      'critical',
      '受困大樓內',
      22.6273,
      120.3014
    ],

    [
      'R004',
      'U004',
      '林雅婷',
      'safe',
      '家人平安',
      23.0000,
      120.2269
    ],

    [
      'R005',
      'U005',
      '黃建豪',
      'missing',
      '失去聯絡超過12小時',
      24.8138,
      120.9675
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
    '南投避難所',
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
    '台中救援站',
    20,
    'shipped',
    DateTime.now().toIso8601String(),

  ]);

  print("Seed allocations created");
  }

  Future<void> seedSupplyRequests() async {

  final result =
      await select("SELECT id FROM supply_requests LIMIT 1");

  if (result.isNotEmpty) return;

    final requests = [

      // 埔里市區（埔里鎮公所）
      [
        'REQ001',
        1,
        '礦泉水',
        '食品飲水',
        '箱',
        20,
        23.9660,
        120.9675,
        '埔里市區',
        'PULI_C',
      ],

      [
        'REQ002',
        1,
        '礦泉水',
        '食品飲水',
        '箱',
        35,
        23.9652,
        120.9688,
        '埔里市區',
        'PULI_C',
      ],

      // 埔里北區（埔里國中）
      [
        'REQ003',
        2,
        '泡麵',
        '食品飲水',
        '箱',
        15,
        23.9850,
        120.9700,
        '埔里北區',
        'PULI_N',
      ],

      [
        'REQ004',
        6,
        '口罩',
        '醫療衛生',
        '盒',
        25,
        23.9885,
        120.9720,
        '埔里北區',
        'PULI_N',
      ],

      // 埔里南區（埔里國小）
      [
        'REQ005',
        1,
        '礦泉水',
        '食品飲水',
        '箱',
        50,
        23.9450,
        120.9690,
        '埔里南區',
        'PULI_S',
      ],

      [
        'REQ006',
        7,
        '急救包',
        '醫療衛生',
        '組',
        10,
        23.9420,
        120.9680,
        '埔里南區',
        'PULI_S',
      ],

      // 埔里東區（埔里消防分隊）
      [
        'REQ007',
        3,
        '餅乾',
        '食品飲水',
        '箱',
        40,
        23.9680,
        120.9900,
        '埔里東區',
        'PULI_E',
      ],

      [
        'REQ008',
        8,
        '退燒藥',
        '醫療衛生',
        '盒',
        12,
        23.9700,
        120.9925,
        '埔里東區',
        'PULI_E',
      ],

      // 埔里西區（埔里轉運站）
      [
        'REQ009',
        4,
        '毛毯',
        '生活用品',
        '件',
        18,
        23.9670,
        120.9400,
        '埔里西區',
        'PULI_W',
      ],

      [
        'REQ010',
        9,
        '雨衣',
        '衣物',
        '件',
        30,
        23.9690,
        120.9420,
        '埔里西區',
        'PULI_W',
      ],

    ];

    for (final r in requests) {

      await execute('''
        INSERT INTO supply_requests (
          requestId,
          itemId,
          qty,
          lat,
          lng,
          zoneId,
          gridId,
          status,
          createdAt
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''', [

        r[0], // requestId
        r[1], // itemId
        r[5], // qty
        r[6], // lat
        r[7], // lng
        r[8], // zoneId
        r[9], // gridId
        'pending',
        DateTime.now().toIso8601String(),

      ]);
    }

    print("Seed supply requests created");
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