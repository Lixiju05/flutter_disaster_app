import 'dart:io';
import 'dart:convert';
import 'dart:math';

import 'package:admin_server/database/database_service.dart';
import 'package:admin_server/core/models/healthReport.dart';
import 'package:admin_server/core/models/supply_request.dart';
import 'package:admin_server/utils/geo_helper.dart';


Future<void> main() async {
  await DatabaseService.init();

  var server = await HttpServer.bind(
    InternetAddress.anyIPv4,
    8080,
  );

  print('HTTP Server running at http://${server.address.address}:${server.port}');

  await for (HttpRequest request in server) {
    await handleRequest(request);
  }
}

///共用：CORS Header
void setCorsHeaders(HttpRequest request) {
  request.response.headers.set('Access-Control-Allow-Origin', '*');
  request.response.headers.set(
    'Access-Control-Allow-Methods',
    'GET, POST, OPTIONS',
  );
  request.response.headers.set(
    'Access-Control-Allow-Headers',
    'Origin, Content-Type, Accept, ngrok-skip-browser-warning',
  );
  request.response.headers.set('Access-Control-Max-Age', '86400');
}

/// 共用：JSON 回應
Future<void> sendJson(
  HttpRequest request,
  int statusCode,
  Map<String, dynamic> data,
) async {
  setCorsHeaders(request);

  request.response
    ..statusCode = statusCode
    ..headers.contentType = ContentType.json
    ..write(jsonEncode(data));

  await request.response.close();
}

///共用：產生 Token
String generateToken() {
  final rand = Random();
  return List.generate(32, (_) => rand.nextInt(16).toRadixString(16)).join();
}

/// 主請求入口
Future<void> handleRequest(HttpRequest request) async {
  print("INCOMING REQUEST: ${request.method} ${request.uri}");

  setCorsHeaders(request);

  if (request.method == 'OPTIONS') {
    request.response.statusCode = HttpStatus.noContent;
    await request.response.close();
    return;
  }

  if (request.method != 'POST') {
    sendJson(request, HttpStatus.methodNotAllowed, {
      "success": false,
      "message": "Only POST supported",
    });
    return;
  }

  try {
    final body = await utf8.decoder.bind(request).join();
    print("BODY RAW: $body");

    if (body.trim().isEmpty) {
      sendJson(request, HttpStatus.badRequest, {
        "success": false,
        "message": "Empty body",
      });
      return;
    }

    final jsonData = jsonDecode(body);
    final type = jsonData['type'];
    print("TYPE: $type");

    /// API 分流
    switch (type) {
      case 'healthReport':
        await handleHealthReport(jsonData, request);
        break;

      case 'login':
        await handleLogin(jsonData, request);
        break;
      case 'getAllReports':
        await handleGetAllReports(request);
        break;
      case 'getReports':
        await handleGetReports(request);
        break;

      case 'getUser':
        await handleGetUser(jsonData, request);
        break;

      case 'getAllUsers':
        await handleGetAllUsers(request);
        break;

      case 'searchUsers':
        await handleSearchUsers(jsonData, request);
        break;

      case 'searchReports':
        await handleSearchReports(jsonData, request);
        break;

      case 'getInventory':
        await handleGetInventory(request);
        break;

      case 'addInventory':
        await handleAddInventory(jsonData, request);
        break;

      case 'updateStock':
        await handleUpdateStock(jsonData, request);
        break;

      case 'updateNeeded':
        await handleUpdateNeeded(jsonData, request);
        break;

      case 'allocate':
        await handleAllocate(jsonData, request);
        break;

      case 'getAllocations':
        await handleGetAllocations(request);
        break;

      case 'dispatch':
        await handleDispatch(jsonData, request);
        break;

      case 'getDispatches':
        await handleGetDispatches(request);
        break;
      
      case 'addSupplyRequest':
        await handleAddSupplyRequest(jsonData, request);
        break;

      case 'getRequestSummaryByGrid':
        await handleGetRequestSummaryByGrid(request);
        break;

      case 'getHotZones':
        await handleGetHotZones(request);
        break;

      case 'getSupplyRequestDetails':
        await handleGetSupplyRequestDetails(request);
        break;

      default:
        sendJson(request, HttpStatus.badRequest, {
          "success": false,
          "message": "Unknown type"
        });
    }
  } catch (e) {
    print("SERVER ERROR: $e");

    sendJson(request, HttpStatus.badRequest, {
      "success": false,
      "message": "Invalid request"
    });
  }
}


Future<void> handleHealthReport(
  Map<String, dynamic> jsonData,
  HttpRequest request,
) async {
  try {
    print("1. ENTER handler");

    final report = HealthReport(
      uuid: jsonData['uuid'],
      reporterId: jsonData['reporterId'],
      name: jsonData['name'],
      phone: jsonData['phone'],
      bloodType: jsonData['bloodType'],
      status: jsonData['status'],
      description: jsonData['description'],
      lat: (jsonData['lat'] as num?)?.toDouble(),
      lng: (jsonData['lng'] as num?)?.toDouble(),
      reportTime: DateTime.tryParse(jsonData['reportTime'] ?? '') ?? DateTime.now(),
    );

    print("2. BEFORE DB");

    await DatabaseService.instance.insertHealthReport(report);

    print("3. AFTER DB");

    sendJson(request, 200, {
      "success": true,
      "message": "Saved"
    });

    print("4. AFTER RESPONSE");
  } catch (e, stack) {
    print("ERROR: $e");
    print(stack);

    try {
      sendJson(request, 500, {
        "success": false,
        "message": e.toString()
      });
    } catch (err) {
      print(" FAILED TO SEND ERROR RESPONSE: $err");
    }
  }
}
/// 登入（含 Token）
Future<void> handleLogin(Map<String, dynamic> jsonData, HttpRequest request) async {
  final username = jsonData['username'];
  final password = jsonData['password'];

  // 從資料庫查出該帳號完整的資訊
  final result = await DatabaseService.instance.select(
    'SELECT * FROM admins WHERE username = ? AND password = ?', 
    [username, password]
  );

  if (result.isNotEmpty) {
    final adminRow = result.first;
    sendJson(request, 200, {
      "success": true,
      "token": generateToken(),
      "username": adminRow['username'],
      "zoneId": adminRow['zoneId'], // 回傳這帳號管哪裡
    });
  } else {
    sendJson(request, 403, {"success": false, "message": "帳號密碼錯誤"});
  }
}

/// 取得所有回報
Future<void> handleGetReports(HttpRequest request) async {
  final reports =await DatabaseService.instance.getAllReports();

  sendJson(request, HttpStatus.ok, {
    "success": true,
    "data":reports.map((r) => r.toJson()).toList(),
  });
}

/// 取得單一使用者
Future<void> handleGetUser(
  Map<String, dynamic> jsonData,
  HttpRequest request,
) async {
  final id = jsonData['id'];

  final user =await DatabaseService.instance.getUser(id);

  if (user == null) {
    sendJson(request, HttpStatus.notFound, {
      "success": false,
      "message": "User not found"
    });
    return;
  }

  sendJson(request, HttpStatus.ok, {
    "success": true,
    "data": user.toMap(),
  });
}

/// 取得全部使用者
Future<void> handleGetAllUsers(HttpRequest request) async {
  try {
    final users =await DatabaseService.instance.getAllUsers();

    sendJson(request, HttpStatus.ok, {
      "success": true,
      "data": users.map((u) => u.toMap()).toList(),
    });
  } catch (e) {
    print("SERVER ERROR: $e");

    sendJson(request, HttpStatus.internalServerError, {
      "success": false,
      "message": "Server error"
    });
  }
}
Future<void> handleGetAllReports(HttpRequest request) async {
  final reports =await DatabaseService.instance.getAllReports();

  sendJson(request, HttpStatus.ok, {
    "success": true,
    "data": reports.map((r) => r.toJson()).toList(),
  });
}
Future<void> handleSearchReports(
  Map<String, dynamic> jsonData,
  HttpRequest request,
) async {
  final keyword = jsonData['keyword'] ?? '';

  final results =await DatabaseService.instance.searchReports(keyword);

  sendJson(request, HttpStatus.ok, {
    "success": true,
    "data": results,
  });
}
Future<void> handleSearchUsers(
  Map<String, dynamic> jsonData,
  HttpRequest request,
) async {
  final keyword = jsonData['keyword'] ?? '';

  final results =await DatabaseService.instance.searchUsers(keyword);

  sendJson(request, HttpStatus.ok, {
    "success": true,
    "data": results,
  });
}
//查inventory
Future<void> handleGetInventory(HttpRequest request) async {
  final items =await DatabaseService.instance.getAllInventory();

  sendJson(request, 200, {
    "success": true,
    "data": items,
  });
}
//新增物資
Future<void> handleAddInventory(
  Map<String, dynamic> jsonData,
  HttpRequest request,
) async {
  DatabaseService.instance.addInventory(
    name: jsonData['name'],
    category: jsonData['category'],
    unit: jsonData['unit'],
    stockQty: jsonData['stockQty'],
    neededQty: jsonData['neededQty'] ?? 0,
  );

  sendJson(request, 200, {
    "success": true,
    "message": "Inventory added",
  });
}
//補貨
Future<void> handleUpdateStock(
  Map<String, dynamic> jsonData,
  HttpRequest request,
) async {
  DatabaseService.instance.addStock(
    jsonData['itemId'],
    jsonData['qty'],
  );

  sendJson(request, 200, {
    "success": true,
    "message": "Stock updated",
  });
}
//更新需求量
Future<void> handleUpdateNeeded(
  Map<String, dynamic> jsonData,
  HttpRequest request,
) async {
  DatabaseService.instance.updateNeeded(
    jsonData['itemId'],
    jsonData['neededQty'],
  );

  sendJson(request, 200, {
    "success": true,
    "message": "Needed updated",
  });
}
//分配物資
Future<void> handleAllocate(
  Map<String, dynamic> jsonData,
  HttpRequest request,
) async {
  await DatabaseService.instance.allocate(
    itemId: jsonData['itemId'],
    zoneId: jsonData['zoneId'],
    qty: jsonData['qty'],
  );

  sendJson(request, 200, {
    "success": true,
    "message": "Allocated",
  });
}
//查allocation
Future<void> handleGetAllocations(HttpRequest request) async {
  final data =await DatabaseService.instance.getAllocations();

  sendJson(request, 200, {
    "success": true,
    "data": data,
  });
}
//出貨
Future<void> handleDispatch(
  Map<String, dynamic> jsonData,
  HttpRequest request,
) async {
  await DatabaseService.instance.dispatch(
    allocationId: jsonData['allocationId'],
  );

  sendJson(request, 200, {
    "success": true,
    "message": "Dispatched",
  });
}
//查出貨紀錄
Future<void> handleGetDispatches(HttpRequest request) async {
  final data =await DatabaseService.instance.getDispatches();

  sendJson(request, 200, {
    "success": true,
    "data": data,
  });
}

//處理物資需求
Future<void> handleAddSupplyRequest(
  Map<String, dynamic> jsonData,
  HttpRequest request,
) async {
  try {
    if (jsonData['requestId'] == null ||
        jsonData['itemId'] == null ||
        jsonData['qty'] == null ||
        jsonData['lat'] == null ||
        jsonData['lng'] == null) {
      sendJson(request, 400, {
        "success": false,
        "message": "missing required fields"
      });
      return;
    }

    final lat = (jsonData['lat'] as num).toDouble();
    final lng = (jsonData['lng'] as num).toDouble();

    // 自動轉換 gridId / zoneId
    final gridId = GeoHelper.getGridId(lat, lng);
    final zoneId = GeoHelper.getZone(lat, lng);

    await DatabaseService.instance.insertSupplyRequest(
      SupplyRequest(
        requestId: jsonData['requestId'],
        itemId: jsonData['itemId'],
        qty: jsonData['qty'],
        lat: lat,
        lng: lng,
        zoneId: zoneId,
        gridId: gridId,
        status: 'pending',
        createdAt: DateTime.now(),
      ),
    );

    sendJson(request, 200, {
      "success": true,
      "message": "request saved",
      "gridId": gridId,
      "zoneId": zoneId,
    });
  } catch (e) {
    print("ADD SUPPLY REQUEST ERROR: $e");

    sendJson(request, 500, {
      "success": false,
      "message": e.toString(),
    });
  }
}

Future<void> handleGetRequestSummaryByGrid(HttpRequest request) async {
  final data = await DatabaseService.instance.getRequestSummaryByGrid();

  sendJson(request, 200, {
    "success": true,
    "data": data,
  });
}

Future<void> handleGetHotZones(HttpRequest request) async {
  final data = await DatabaseService.instance.getHotZones();

  sendJson(request, 200, {
    "success": true,
    "data": data,
  });
}

Future<void> handleGetSupplyRequestDetails(HttpRequest request) async {
  final data = await DatabaseService.instance.getSupplyRequestDetails();

  sendJson(request, 200, {
    "success": true,
    "data": data,
  });
}