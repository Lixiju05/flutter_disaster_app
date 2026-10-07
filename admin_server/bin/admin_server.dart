import 'dart:io';

import 'dart:convert';

import 'dart:math';



import 'package:admin_server/database/database_service.dart';

import 'package:admin_server/core/models/healthReport.dart';

import 'package:admin_server/core/models/supply_request.dart';

import 'package:admin_server/core/models/emergency_request.dart';

import 'package:admin_server/services/supply/supply_request_service.dart';





Future<void> main() async {

  await DatabaseService.init();



  var server = await HttpServer.bind(

    InternetAddress.anyIPv4,

    8080,

  );



  print('HTTP Server running at http\://${server.address.address}:${server.port}');



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



      case 'getSupplyRequestDetails':

        await handleGetSupplyRequestDetails(request);

        break;



      case 'getRequestsByAdmin':

        await handleGetRequestsByAdmin(jsonData, request);

        break;



      case 'addEmergencyRequest':

        await handleAddEmergencyRequest(jsonData, request);

        break;



      case 'getEmergencyRequestsByAdmin':

        await handleGetEmergencyRequestsByAdmin(jsonData, request);

        break;



      case 'updateEmergencyStatus':

        await handleUpdateEmergencyStatus(jsonData, request);

        break;



      case 'getHealthReportsByAdmin':

        await handleGetHealthReportsByAdmin(jsonData, request);

        break;



      case 'getVictimDashboard':

        await handleGetVictimDashboard(

          jsonData,

          request,      

        );

        break;



      case 'dispatchSupplyRequest':

        await handleDispatchSupplyRequest(jsonData, request);

        break;



      case 'claimSupplyRequest':

        await handleClaimSupplyRequest(request, jsonData);

        break;

      case 'getPendingSupplyRequests':

        await handleGetPendingSupplyRequests(jsonData, request);

        break;



      case 'deleteInventory':

        await handleDeleteInventory(jsonData, request);

        break;



      case 'cancelAllocation':

        await handleCancelAllocation(jsonData, request);

        break;



      case 'cancelSupplyRequestClaim':

        await handleCancelSupplyRequestClaim(

          request,

          jsonData,

        );

        break;



      case 'reserveSupplyRequest':

        await handleReserveSupplyRequest(

          request,

          jsonData,

        );

        break;



        case 'completeSupplyRequest':

          await handleCompleteSupplyRequest(

            jsonData,

            request,

          );

          break;



        case 'autoAssignSupplyRequest':

          await handleAutoAssignSupplyRequest(jsonData, request);

          break;

        case 'getVolunteerClaims':
          
          await handleGetVolunteerClaims(jsonData, request);
          
          break;
        case 'getVolunteerHistory':

          await handleGetVolunteerHistory(jsonData, request);
        
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

  print("DEBUG allocations: $data");



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

        jsonData['userId'] == null ||

        jsonData['itemId'] == null ||

        jsonData['qty'] == null) {

      sendJson(request, 400, {

        "success": false,

        "message": "missing required fields"

      });

      return;

    }



    await DatabaseService.instance.insertSupplyRequest(

      SupplyRequest(

        requestId: jsonData['requestId'],

        userId: jsonData['userId'],

        itemId: jsonData['itemId'],

        qty: jsonData['qty'],

        lat: (jsonData['lat'] as num?)?.toDouble(),

        lng: (jsonData['lng'] as num?)?.toDouble(),

        receiverAdminId: jsonData['receiverAdminId'],

        hopCount: jsonData['hopCount'] ?? 0,

        status: 'pending',

        createdAt: DateTime.now(),

        receivedAt: DateTime.now(),

      ),

    );



    sendJson(request, 200, {

      "success": true,

      "message": "request saved"

    });

  } catch (e) {

    sendJson(request, 500, {

      "success": false,

      "message": e.toString(),

    });

  }

}



Future<void> handleGetSupplyRequestDetails(HttpRequest request) async {

  final data = await DatabaseService.instance.getSupplyRequestDetails();



  sendJson(request, 200, {

    "success": true,

    "data": data,

  });

}





Future<void> handleGetRequestsByAdmin(

  Map<String, dynamic> jsonData,

  HttpRequest request,

) async {

  final receiverAdminId = jsonData['receiverAdminId'];



  final data =

      await DatabaseService.instance.getRequestsByAdmin(receiverAdminId);



  sendJson(request, 200, {

    "success": true,

    "data": data,

  });

}



Future<void> handleAddEmergencyRequest(

  Map<String, dynamic> jsonData,

  HttpRequest request,

) async {

  await DatabaseService.instance.insertEmergencyRequest(

    EmergencyRequest.fromJson({

      ...jsonData,

      'receivedAt': DateTime.now().toIso8601String(),

    }),

  );



  sendJson(request, 200, {

    "success": true,

    "message": "emergency request saved",

  });

}



Future<void> handleGetEmergencyRequestsByAdmin(

  Map<String, dynamic> jsonData,

  HttpRequest request,

) async {

  final receiverAdminId = jsonData['receiverAdminId'];



  final data = await DatabaseService.instance

      .getEmergencyRequestsByAdmin(receiverAdminId);



  sendJson(request, 200, {

    "success": true,

    "data": data,

  });

}



Future<void> handleUpdateEmergencyStatus(

  Map<String, dynamic> jsonData,

  HttpRequest request,

) async {

  await DatabaseService.instance.updateEmergencyStatus(

    jsonData['emergencyId'],

    jsonData['status'],

  );



  sendJson(request, 200, {

    "success": true,

    "message": "emergency status updated",

  });

}



Future<void> handleGetHealthReportsByAdmin(

  Map<String, dynamic> jsonData,

  HttpRequest request,

) async {

  final receiverAdminId = jsonData['receiverAdminId'];



  final reports = await DatabaseService.instance

      .getHealthReportsByAdmin(receiverAdminId);



  sendJson(request, 200, {

    "success": true,

    "data": reports.map((r) => r.toJson()).toList(),

  });

}



Future<void> handleGetVictimDashboard(

  Map<String, dynamic> jsonData,

  HttpRequest request,

) async {



  final receiverAdminId =

      jsonData['receiverAdminId'];



  final data =

      await DatabaseService.instance

          .getVictimDashboard(

            receiverAdminId,

          );



  sendJson(

    request,

    200,

    {

      "success": true,

      "data": data,

    },

  );

}



Future<void> handleDispatchSupplyRequest(
  Map<String, dynamic> jsonData,
  HttpRequest request,
) async {
  try {
    final requestId = jsonData['requestId']?.toString();
    final volunteerId = jsonData['volunteerId']?.toString();
    final stationId = jsonData['stationId']?.toString();
    if (requestId == null || requestId.isEmpty || volunteerId == null || volunteerId.isEmpty || stationId == null || stationId.isEmpty) {
      sendJson(request, 400, {'success': false, 'message': 'requestId、volunteerId、stationId 為必填'});
      return;
    }
    final service = SupplyRequestService(DatabaseService.instance);
    final result = await service.dispatchSupplyRequest(
      requestId: requestId, volunteerId: volunteerId, stationId: stationId,
    );
    sendJson(request, 200, {'success': true, 'message': '確認取貨成功', 'data': result});
  } catch (e) {
    sendJson(request, 400, {'success': false, 'message': e.toString()});
  }
}

Future<void> handleClaimSupplyRequest(

  HttpRequest request,

  Map<String, dynamic> data,

) async {

  try {

    final requestId = data['requestId']?.toString();

    final volunteerId = data['volunteerId']?.toString();

    final stationId = data['stationId']?.toString();



    // 檢查必要資料

    if (requestId == null ||

        requestId.isEmpty ||

        volunteerId == null ||

        volunteerId.isEmpty) {

      sendJson(

        request,

        HttpStatus.badRequest,

        {

          'success': false,

          'message': 'requestId、volunteerId、stationId 為必填',

        },

      );

      return;

    }



    // 建立 Service

    final service = SupplyRequestService(

      DatabaseService.instance,

    );



    // 執行認領

    await service.claimSupplyRequest(

      requestId: requestId.toString(),

      volunteerId: volunteerId.toString(),

      stationId: stationId.toString(),

    );



    // 成功

    sendJson(

      request,

      HttpStatus.ok,

      {

        'success': true,

        'message': '認領成功',

        'requestId': requestId,

        'volunteerId': volunteerId,

      },

    );

  } catch (e) {

    // 失敗

    sendJson(

      request,

      HttpStatus.badRequest,

      {

        'success': false,

        'message': e.toString(),

      },

    );

  }

}

Future<void> handleGetPendingSupplyRequests(

  Map<String, dynamic> jsonData,

  HttpRequest request,

) async {

  try {

    final stationId = jsonData['stationId'];



    if (stationId == null || stationId.toString().isEmpty) {

      sendJson(request, 400, {

        "success": false,

        "message": "missing stationId",

      });

      return;

    }



    final service = SupplyRequestService(

      DatabaseService.instance,

    );



    final result = await service.getPendingSupplyRequests(

      stationId: stationId.toString(),

    );



    sendJson(request, 200, {

      "success": true,

      "data": result,

    });

  } catch (e) {

    sendJson(request, 500, {

      "success": false,

      "message": e.toString(),

    });

  }

}



Future<void> handleGetVolunteerClaims(
  Map<String, dynamic> jsonData,
  HttpRequest request,
) async {
  try {
    final volunteerId = jsonData['volunteerId']?.toString();
    final stationId = jsonData['stationId']?.toString();
    if (volunteerId == null || volunteerId.isEmpty || stationId == null || stationId.isEmpty) {
      sendJson(request, 400, {'success': false, 'message': 'volunteerId、stationId 為必填'});
      return;
    }
    final service = SupplyRequestService(DatabaseService.instance);
    final result = await service.getVolunteerClaims(volunteerId: volunteerId, stationId: stationId);
    sendJson(request, 200, {'success': true, 'data': result});
  } catch (e) {
    sendJson(request, 400, {'success': false, 'message': e.toString()});
  }
}

/// 刪除物資

/// 若仍有「待認領/已認領的物資需求」或「已預留的分配」使用這項物資，就拒絕刪除，避免資料對不起來

Future<void> handleDeleteInventory(

  Map<String, dynamic> jsonData,

  HttpRequest request,

) async {

  try {

    final itemId = jsonData['itemId'];

    if (itemId == null) {

      sendJson(request, HttpStatus.badRequest, {

        'success': false,

        'message': 'itemId 為必填',

      });

      return;

    }



    final db = DatabaseService.instance;



    final item = await db.select('SELECT * FROM inventory WHERE id = ?', [itemId]);

    if (item.isEmpty) {

      throw Exception('找不到這項物資');

    }



    final inUseRequests = await db.select(

      "SELECT COUNT(*) AS c FROM supply_requests WHERE itemId = ? AND status IN ('pending', 'claimed')",

      [itemId],

    );

    final inUseAllocations = await db.select(

      "SELECT COUNT(*) AS c FROM allocations WHERE itemId = ? AND status = 'reserved'",

      [itemId],

    );

    final reqCount = inUseRequests.first['c'] as int;

    final allocCount = inUseAllocations.first['c'] as int;



    if (reqCount > 0 || allocCount > 0) {

      throw Exception(

        '此物資仍有 $reqCount 筆物資需求、$allocCount 筆預留分配使用中，無法刪除',

      );

    }



    await db.execute('DELETE FROM inventory WHERE id = ?', [itemId]);



    sendJson(request, HttpStatus.ok, {

      'success': true,

      'message': '刪除成功',

    });

  } catch (e) {

    sendJson(request, HttpStatus.badRequest, {

      'success': false,

      'message': e.toString().replaceFirst('Exception: ', ''),

    });

  }

}



/// 取消分配：把預留數量還回庫存

Future<void> handleCancelAllocation(

  Map<String, dynamic> jsonData,

  HttpRequest request,

) async {

  try {

    final allocationId = jsonData['allocationId'];

    if (allocationId == null) {

      sendJson(request, HttpStatus.badRequest, {

        'success': false,

        'message': 'allocationId 為必填',

      });

      return;

    }



    final db = DatabaseService.instance;



    await db.transaction(() async {

      final result = await db.select(

        'SELECT * FROM allocations WHERE id = ?',

        [allocationId],

      );

      if (result.isEmpty) {

        throw Exception('找不到這筆分配');

      }



      final allocation = result.first;

      if (allocation['status'] != 'reserved') {

        throw Exception('只有「已預留」的分配可以取消');

      }



      await db.execute(

        'UPDATE inventory SET reservedQty = MAX(reservedQty - ?, 0), updatedAt = ? WHERE id = ?',

        [allocation['quantity'], DateTime.now().toIso8601String(), allocation['itemId']],

      );

      await db.execute(

        "UPDATE allocations SET status = 'cancelled' WHERE id = ?",

        [allocationId],

      );

    });



    sendJson(request, HttpStatus.ok, {

      'success': true,

      'message': '已取消分配',

    });

  } catch (e) {

    sendJson(request, HttpStatus.badRequest, {

      'success': false,

      'message': e.toString().replaceFirst('Exception: ', ''),

    });

  }

}



Future<void> handleCancelSupplyRequestClaim(
  HttpRequest request,
  Map<String, dynamic> data,
) async {
  try {
    final requestId = data['requestId']?.toString();
    final volunteerId = data['volunteerId']?.toString();
    final stationId = data['stationId']?.toString();

    if (requestId == null ||
        requestId.isEmpty ||
        volunteerId == null ||
        volunteerId.isEmpty ||
        stationId == null ||
        stationId.isEmpty) {
      sendJson(
        request,
        HttpStatus.badRequest,
        {
          'success': false,
          'message': 'requestId、volunteerId 和 stationId 為必填',
        },
      );
      return;
    }

    final service = SupplyRequestService(
      DatabaseService.instance,
    );

    await service.cancelClaim(
      requestId: requestId,
      volunteerId: volunteerId,
      stationId: stationId,
    );

    sendJson(
      request,
      HttpStatus.ok,
      {
        'success': true,
        'message': '取消配送成功',
        'requestId': requestId,
      },
    );
  } catch (e) {
    sendJson(
      request,
      HttpStatus.badRequest,
      {
        'success': false,
        'message': e.toString(),
      },
    );
  }
}


Future<void> handleReserveSupplyRequest(

  HttpRequest request,

  Map<String, dynamic> data,

) async {

  try {

    final requestId =

        data['requestId']?.toString();



    if (requestId == null ||

        requestId.isEmpty) {

      sendJson(

        request,

        HttpStatus.badRequest,

        {

          'success': false,

          'message': 'requestId 為必填',

        },

      );

      return;

    }



    final service = SupplyRequestService(

      DatabaseService.instance,

    );



    await service.reserveSupplyRequest(

      requestId: requestId,

    );



    sendJson(

      request,

      HttpStatus.ok,

      {

        'success': true,

        'message': '物資預留成功',

        'requestId': requestId,

      },

    );



  } catch (e) {

    sendJson(

      request,

      HttpStatus.badRequest,

      {

        'success': false,

        'message': e.toString(),

      },

    );

  }

}



Future<void> handleCompleteSupplyRequest(
  Map<String, dynamic> jsonData,
  HttpRequest request,
) async {
  try {
    final requestId = jsonData['requestId']?.toString();
    final volunteerId = jsonData['volunteerId']?.toString();
    final stationId = jsonData['stationId']?.toString();
    if (requestId == null || requestId.isEmpty || volunteerId == null || volunteerId.isEmpty || stationId == null || stationId.isEmpty) {
      sendJson(request, 400, {'success': false, 'message': 'requestId、volunteerId、stationId 為必填'});
      return;
    }
    final service = SupplyRequestService(DatabaseService.instance);
    final result = await service.completeSupplyRequest(
      requestId: requestId, volunteerId: volunteerId, stationId: stationId,
    );
    sendJson(request, 200, {'success': true, 'message': '配送完成', 'data': result});
  } catch (e) {
    sendJson(request, 400, {'success': false, 'message': e.toString()});
  }
}

Future<void> handleAutoAssignSupplyRequest(

  Map<String, dynamic> jsonData,

  HttpRequest request,

) async {

  try {

    final requestId = jsonData['requestId'];



    if (requestId == null || requestId.toString().isEmpty) {

      sendJson(request, 400, {

        "success": false,

        "message": "missing requestId",

      });

      return;

    }



    final service = SupplyRequestService(

      DatabaseService.instance,

    );



    final result = await service.autoAssignSupplyRequest(

      requestId: requestId.toString(),

    );



    sendJson(request, 200, {

      "success": true,

      "message": "supply request automatically assigned",

      "data": result,

    });

  } catch (e) {

    sendJson(request, 500, {

      "success": false,

      "message": e.toString(),

    });

  }

}

Future<void> handleGetVolunteerHistory(
  Map<String, dynamic> jsonData,
  HttpRequest request,
) async {
  try {
    final volunteerId = jsonData['volunteerId']?.toString();
    final stationId = jsonData['stationId']?.toString();

    if (volunteerId == null ||
        volunteerId.isEmpty ||
        stationId == null ||
        stationId.isEmpty) {
      sendJson(
        request,
        HttpStatus.badRequest,
        {
          'success': false,
          'message': 'volunteerId、stationId 為必填',
        },
      );
      return;
    }

    final service = SupplyRequestService(
      DatabaseService.instance,
    );

    final history = await service.getVolunteerHistory(
      volunteerId: volunteerId,
      stationId: stationId,
    );

    sendJson(
      request,
      HttpStatus.ok,
      {
        'success': true,
        'data': history,
      },
    );
  } catch (e) {
    sendJson(
      request,
      HttpStatus.internalServerError,
      {
        'success': false,
        'message': e.toString(),
      },
    );
  }
}