import 'package:admin_server/services/reverse_geocoding_service.dart';
import 'package:admin_server/services/firebase/firebase_config.dart';
import 'package:admin_server/services/firebase/firebase_connection.dart';
import 'package:admin_server/services/firebase/firebase_users_bootstrap.dart';
import 'package:admin_server/services/firebase/firebase_users_service.dart';
import 'package:admin_server/services/isolated_request_pool.dart';
import 'package:admin_server/core/models/report_location.dart';
import 'dart:io';

import 'dart:convert';

import 'package:admin_server/services/admin_session_store.dart';
import 'package:admin_server/services/notifications/notification_bootstrap.dart';
import 'package:admin_server/services/notifications/notification_service.dart';
import 'package:admin_server/services/notifications/notification_store.dart';



import 'package:admin_server/database/database_service.dart';

import 'package:admin_server/core/models/healthReport.dart';

import 'package:admin_server/core/models/supply_request.dart';

import 'package:admin_server/core/models/emergency_request.dart';

import 'package:admin_server/services/supply/supply_request_service.dart';
import 'package:admin_server/services/supply/station_transfer_service.dart';

final adminSessions = AdminSessionStore();
NotificationService? notificationService;
ReverseGeocodingService? reverseGeocodingService;
FirebaseUsersService? firebaseUsersService;
IsolatedRequestPool firebaseUsersRequests = IsolatedRequestPool();





Future<void> main() async {
  try {
    reverseGeocodingService = createReverseGeocodingService();
  } catch (_) {
    stderr.writeln('Reverse geocoding disabled: invalid DEMO configuration.');
  }


  try {
    notificationService = await createNotificationServiceFromEnvironment();
  } on NotificationException catch (error) {
    // Configuration codes only; never log credentials, identities or raw errors.
    stderr.writeln('Notifications disabled: ${error.code}');
  } catch (_) {
    // No raw credential / OAuth / Google error details in application logs.
    stderr.writeln('Notifications disabled: server authorization/configuration is unavailable.');
  }

  await DatabaseService.init();



  var server = await HttpServer.bind(

    InternetAddress.anyIPv4,

    8080,

  );



  print('HTTP Server running at http\://${server.address.address}:${server.port}');



  try {
  try {
    firebaseUsersService = await createFirebaseUsersServiceFromEnvironment();
  } on FirebaseConfigurationException catch (error) {
    stderr.writeln('Firebase user queries disabled: ${error.code}');
  } on FirebaseConnectionException catch (error) {
    stderr.writeln('Firebase user queries disabled: ${error.code}');
  } catch (_) {
    stderr.writeln('Firebase user queries disabled: initialization failed.');
  }
    await serveRequests(server);
  } finally {
    firebaseUsersService?.close();
    await server.close(force: true);
  }

}

/// Production dispatch is also exercised by isolated HTTP tests. Only the two
/// Firebase user routes detach after JSON parsing; SQLite writers stay ordered.
Future<void> serveRequests(HttpServer server, {Set<String>? allowedTypes}) async {
  try {
    await for (final request in server) {
      await handleRequest(request, allowedTypes: allowedTypes);
    }
  } finally {
    await firebaseUsersRequests.close();
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

    'Origin, Content-Type, Accept, Authorization, ngrok-skip-browser-warning',

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
  return AdminSessionStore.generateToken();
}



/// 主請求入口

Future<void> handleRequest(HttpRequest request, {Set<String>? allowedTypes}) async {

  // URLs can contain PII or cursors. Do not log paths or query strings.
  print("INCOMING REQUEST: ${request.method}");



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

    // Do not log request bodies: login contains credentials.



    if (body.trim().isEmpty) {

      sendJson(request, HttpStatus.badRequest, {

        "success": false,

        "message": "Empty body",

      });

      return;

    }



    final jsonData = jsonDecode(body);

    final type = jsonData['type'];
    if (allowedTypes != null && !allowedTypes.contains(type)) {
      await sendJson(request, 404, {'success': false,
        'code': 'ROUTE_NOT_AVAILABLE', 'message': 'Route is unavailable in this test server'});
      return;
    }

    if (!DatabaseService.instance.allowLegacyInventoryWrites &&
        const ['allocate', 'dispatch', 'cancelAllocation'].contains(type)) {
      await sendJson(request, 409, {
        'success': false,
        'message': '單中心模式已停用舊 allocate/dispatch 寫入，請使用物資需求與義工取貨流程',
      });
      return;
    }

    print('REQUEST ROUTE SELECTED');



    /// API 分流

    switch (type) {
      case 'getFirebaseUsers':
      case 'getFirebaseUserById':
        await firebaseUsersRequests.dispatch(
          () => handleFirebaseUsers(jsonData, request),
          onUnavailable: (closing) => sendJson(request, closing ? 503 : 429, {
            'success': false, 'source': 'firestore',
            'code': closing ? 'FIREBASE_USERS_SHUTTING_DOWN' : 'FIREBASE_USERS_BUSY',
            'message': 'Firebase user queries are temporarily unavailable',
          }),
          onFailure: () async {
            try {
              await sendJson(request, 503, {'success': false, 'source': 'firestore',
                'code': 'FIREBASE_USERS_UNAVAILABLE', 'message': 'User query unavailable'});
            } catch (_) {
              try { await request.response.close(); } catch (_) { /* Disconnected. */ }
            }
          },
        );
        break;
      case 'createStationTransfer':
      case 'shipStationTransfer':
      case 'receiveStationTransfer':
      case 'getStationTransfers':
      case 'getStationInventory':
        await handleStationTransfer(jsonData, request);
        break;

      case 'healthReport':

        await handleHealthReport(jsonData, request);

        break;



      case 'login':

        await handleLogin(jsonData, request);

        break;

      case 'reverseGeocode':
        await handleReverseGeocode(jsonData, request);
        break;

      case 'getNotificationRecipients':
      case 'sendNotification':
      case 'getSentNotifications':
        await handleNotification(jsonData, request);
        break;

      case 'assignSupplyRequestVolunteer':
        await handleAssignSupplyRequestVolunteer(jsonData, request);
        break;

      case 'adminDispatchSupplyRequest':
      case 'adminCompleteSupplyRequest':
        await handleAdminSupplyDelivery(jsonData, request);
        break;

      case 'batchReserveSupplyRequests':
      case 'batchDispatchSupplyRequests':
      case 'batchCompleteSupplyRequests':
      case 'getSupplyRequestReviews':
      case 'reviewSupplyRequest':
        await handleSupplyBatchAndReview(jsonData, request);
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

      case 'getStations':
        await handleGetStations(request);
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

    // Invalid JSON may contain credentials/PII; never print its source.
    print('SERVER ERROR: invalid request');



    sendJson(request, HttpStatus.badRequest, {

      "success": false,

      "message": "Invalid request"

    });

  }

}



/// createdBy is audit input only; existing login does not authenticate requests.
Future<void> handleStationTransfer(
  Map<String, dynamic> data,
  HttpRequest request,
) async {
  String requiredText(String key) {
    final value = data[key];
    if (value is! String || value.trim().isEmpty) {
      throw StationTransferException('$key 必須是非空字串');
    }
    return value.trim();
  }

  int requiredInt(String key) {
    final value = data[key];
    if (value is! int || value <= 0) {
      throw StationTransferException('$key 必須是大於 0 的整數');
    }
    return value;
  }

  try {
    final service = StationTransferService(DatabaseService.instance);
    Object result;
    String message;
    switch (data['type']) {
      case 'createStationTransfer':
        result = service.create(
          fromStationId: data.containsKey('fromStationId')
              ? requiredText('fromStationId') : 'OFFICE001',
          toStationId: requiredText('toStationId'),
          itemId: requiredInt('itemId'),
          qty: requiredInt('qty'),
          createdBy: requiredText('createdBy'),
        );
        message = '調度已建立，來源庫存已預留';
        break;
      case 'shipStationTransfer':
        result = service.ship(requiredText('transferId'));
        message = '已確認出貨，目的據點尚未入庫';
        break;
      case 'receiveStationTransfer':
        result = service.receive(requiredText('transferId'));
        message = '已確認收貨，目的據點庫存已增加';
        break;
      case 'getStationInventory':
        result = service.getStationInventory(requiredText('stationId'));
        message = '據點庫存查詢成功';
        break;
      case 'getStationTransfers':
        result = await service.getTransfers(
          stationId: data['stationId'] == null ? null : requiredText('stationId'),
          status: data['status'] == null ? null : requiredText('status'),
        );
        message = '查詢成功';
        break;
      default:
        throw StationTransferException('Unknown type');
    }
    await sendJson(request, 200, {'success': true, 'message': message, 'data': result});
  } on StationTransferException catch (e) {
    await sendJson(request, e.statusCode, {'success': false, 'message': e.message});
  } catch (e) {
    print('STATION TRANSFER ERROR: $e');
    await sendJson(request, 500, {'success': false, 'message': '調度處理失敗，請檢查伺服器記錄'});
  }
}

Future<void> handleHealthReport(

  Map<String, dynamic> jsonData,

  HttpRequest request,

) async {

  try {

    print("1. ENTER handler");



    final report = HealthReport.fromJson({
      ...jsonData,
      'receivedAt': DateTime.now().toIso8601String(),
    });



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

      "token": adminSessions.create(adminRow['id'] as int),

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
  try {
    final items = await DatabaseService.instance.getAllInventory();
    await sendJson(request, 200, {"success": true, "data": items});
  } catch (e) {
    await sendInventoryError(request, e);
  }
}

String inventoryText(Map<String, dynamic> data, String key) {
  final value = data[key];
  if (value is! String || value.trim().isEmpty) {
    throw InventoryException('$key 必須是非空字串');
  }
  return value.trim();
}

int inventoryInt(Map<String, dynamic> data, String key, {bool allowZero = false}) {
  final value = data[key];
  if (value is! int || (allowZero ? value < 0 : value <= 0)) {
    throw InventoryException('$key 必須是${allowZero ? '非負' : '大於 0 的'}整數');
  }
  return value;
}

Future<void> sendInventoryError(HttpRequest request, Object error) async {
  if (error is InventoryException) {
    await sendJson(request, error.statusCode, {'success': false, 'message': error.message});
  } else {
    print('INVENTORY ERROR: $error');
    await sendJson(request, 500, {'success': false, 'message': '庫存處理失敗，請檢查伺服器記錄'});
  }
}

//新增物資

Future<void> handleAddInventory(

  Map<String, dynamic> jsonData,

  HttpRequest request,

) async {
  try {
    await DatabaseService.instance.addInventory(
      name: inventoryText(jsonData, 'name'),
      category: inventoryText(jsonData, 'category'),
      unit: inventoryText(jsonData, 'unit'),
      stockQty: inventoryInt(jsonData, 'stockQty'),
      neededQty: inventoryInt({'neededQty': jsonData['neededQty'] ?? 0}, 'neededQty', allowZero: true),
    );
    await sendJson(request, 200, {"success": true, "message": "Inventory added"});
  } catch (e) {
    await sendInventoryError(request, e);
  }
}

//補貨

Future<void> handleUpdateStock(

  Map<String, dynamic> jsonData,

  HttpRequest request,

) async {
  try {
    await DatabaseService.instance.addStock(
      inventoryInt(jsonData, 'itemId'),
      inventoryInt(jsonData, 'qty'),
    );
    await sendJson(request, 200, {"success": true, "message": "Stock updated"});
  } catch (e) {
    await sendInventoryError(request, e);
  }
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

        requestId: inventoryText(jsonData, 'requestId'),

        userId: inventoryText(jsonData, 'userId'),

        itemId: inventoryInt(jsonData, 'itemId'),

        qty: inventoryInt(jsonData, 'qty'),

        lat: ReportLocation.latitude(jsonData['lat']),

        lng: ReportLocation.longitude(jsonData['lng']),
        address: jsonData['address']?.toString(),
        reportedAt: ReportLocation.time(jsonData['reportedAt']),

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

  } on InventoryException catch (e) {
    await sendInventoryError(request, e);
  } catch (e) {
    await sendJson(request, 500, {"success": false, "message": e.toString()});
  }
}

Future<void> handleGetStations(HttpRequest request) async {
  try {
    final data = await DatabaseService.instance.getStations();
    await sendJson(request, 200, {'success': true, 'data': data});
  } catch (e) {
    print('GET STATIONS ERROR: $e');
    await sendJson(request, 500, {
      'success': false,
      'message': '據點查詢失敗，請檢查伺服器記錄',
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

        volunteerId.isEmpty ||
        stationId == null ||
        stationId.isEmpty) {

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

Future<void> handleNotification(Map<String, dynamic> data, HttpRequest request) async {
  try {
    final session = adminSessions.authenticate(request.headers.value(HttpHeaders.authorizationHeader));
    if (session == null) {
      throw const NotificationException(401, 'ADMIN_SESSION_REQUIRED', '需要有效的管理員 Bearer Token，請重新登入');
    }
    if ((await DatabaseService.instance.select('SELECT id FROM admins WHERE id=?', [session.adminId])).isEmpty) {
      throw const NotificationException(403, 'ADMIN_DISABLED', '管理員帳號已不存在');
    }
    final service = notificationService;
    if (service == null) {
      throw const NotificationException(503, 'NOTIFICATIONS_DISABLED', '通知服務尚未設定伺服器授權或尚未啟用');
    }
    service.policy.authorize(session.adminId);
    final result = switch (data['type']) {
      'getNotificationRecipients' => await service.recipients(session.adminId, data),
      'sendNotification' => await service.send(session.adminId, data),
      _ => await service.sent(session.adminId, data),
    };
    await sendJson(request, 200, {
      'success': true,
      'message': data['type'] == 'sendNotification' ? '通知已發布（不代表已送達或已讀）' : '查詢成功',
      'data': notificationJson(result),
    });
  } on NotificationException catch (e) {
    await sendJson(request, e.statusCode, {'success': false, 'code': e.code, 'message': e.message});
  } catch (_) {
    await sendJson(request, 503, {
      'success': false, 'code': 'NOTIFICATION_UNCONFIRMED',
      'message': '通知操作未確認，請使用相同 clientRequestId 重試或查詢紀錄',
    });
  }
}

Future<void> handleSupplyBatchAndReview(
  Map<String, dynamic> data, HttpRequest request,
) async {
  final session = adminSessions.authenticate(request.headers.value(HttpHeaders.authorizationHeader));
  if (session == null) {
    await sendJson(request, 401, {'success': false, 'message': '需要有效的管理員 Bearer Token，請重新登入'});
    return;
  }
  if ((await DatabaseService.instance.select('SELECT id FROM admins WHERE id=?', [session.adminId])).isEmpty) {
    await sendJson(request, 403, {'success': false, 'message': '管理員帳號已不存在'});
    return;
  }
  try {
    final service = SupplyRequestService(DatabaseService.instance);
    final type = data['type'];
    if (data.containsKey('stationId') && data['stationId'] != 'OFFICE001') {
      throw InventoryException('僅支援 OFFICE001', 400);
    }
    if (type == 'getSupplyRequestReviews' || type == 'reviewSupplyRequest') {
      final id = data['requestId'];
      if ((type == 'reviewSupplyRequest' || data.containsKey('requestId')) &&
          (id is! String || id.trim().isEmpty)) {
        throw InventoryException('requestId 必須為非空字串', 400);
      }
      if (type == 'getSupplyRequestReviews') {
        final rows = await service.getSupplyRequestReviews(adminId: session.adminId, requestId: id as String?);
        await sendJson(request, 200, {'success': true, 'data': rows});
      } else {
        if (data['decision'] is! String || data['note'] is! String) {
          throw InventoryException('decision、note 必須為字串', 400);
        }
        final result = await service.reviewSupplyRequest(adminId: session.adminId, requestId: id as String,
          decision: data['decision'] as String, note: data['note'] as String);
        await sendJson(request, 200, {'success': true, 'message': '審核處理完成', 'data': result});
      }
      return;
    }
    final ids = data['requestIds'];
    if (ids is! List || ids.any((id) => id is! String)) {
      throw InventoryException('requestIds 必須為字串陣列', 400);
    }
    final action = type == 'batchReserveSupplyRequests' ? 'reserve'
        : type == 'batchDispatchSupplyRequests' ? 'dispatch' : 'complete';
    final result = await service.batchSupplyRequests(adminId: session.adminId,
      action: action, requestIds: List<String>.from(ids));
    await sendJson(request, 200, {
      'success': result['failed'] == 0, 'message': '批次處理完成，請逐筆確認 results', 'data': result,
    });
  } catch (e) {
    await sendJson(request, e is InventoryException ? e.statusCode : 409, {
      'success': false, 'message': e.toString(),
      if (e is SupplyReviewRequired) 'anomalyReasons': e.reasons,
    });
  }
}

Future<void> handleAdminSupplyDelivery(
  Map<String, dynamic> data, HttpRequest request,
) async {
  final session = adminSessions.authenticate(
    request.headers.value(HttpHeaders.authorizationHeader),
  );
  if (session == null) {
    await sendJson(request, 401, {
      'success': false, 'message': '需要有效的管理員 Bearer Token，請重新登入',
    });
    return;
  }
  final admins = await DatabaseService.instance.select(
    'SELECT id FROM admins WHERE id = ?', [session.adminId],
  );
  if (admins.isEmpty) {
    await sendJson(request, 403, {'success': false, 'message': '管理員帳號已不存在'});
    return;
  }
  final requestId = data['requestId'];
  if (requestId is! String || requestId.trim().isEmpty ||
      (data.containsKey('stationId') && data['stationId'] != 'OFFICE001')) {
    await sendJson(request, 400, {
      'success': false, 'message': 'requestId 必須為非空字串；stationId 僅支援 OFFICE001',
    });
    return;
  }
  try {
    final service = SupplyRequestService(DatabaseService.instance);
    final dispatch = data['type'] == 'adminDispatchSupplyRequest';
    final result = dispatch
        ? await service.adminDispatchSupplyRequest(requestId: requestId, adminId: session.adminId)
        : await service.adminCompleteSupplyRequest(requestId: requestId, adminId: session.adminId);
    await sendJson(request, 200, {
      'success': true, 'message': dispatch ? '出庫成功' : '配送完成', 'data': result,
    });
  } catch (e) {
    await sendJson(request, e is InventoryException ? e.statusCode : 409, {
      'success': false, 'message': e.toString(),
    });
  }
}

Future<void> handleAssignSupplyRequestVolunteer(
  Map<String, dynamic> data,
  HttpRequest request,
) async {
  final session = adminSessions.authenticate(
    request.headers.value(HttpHeaders.authorizationHeader),
  );
  if (session == null) {
    await sendJson(request, 401, {
      'success': false,
      'message': '需要有效的管理員 Bearer Token，請重新登入',
    });
    return;
  }
  final admins = await DatabaseService.instance.select(
    'SELECT id FROM admins WHERE id = ?', [session.adminId],
  );
  if (admins.isEmpty) {
    await sendJson(request, 403, {
      'success': false, 'message': '管理員帳號已不存在',
    });
    return;
  }
  final requestId = data['requestId'];
  final volunteerId = data['volunteerId'];
  if (requestId is! String || requestId.trim().isEmpty ||
      volunteerId is! String || volunteerId.trim().isEmpty ||
      (data.containsKey('stationId') && data['stationId'] != 'OFFICE001')) {
    await sendJson(request, 400, {
      'success': false,
      'message': 'requestId、volunteerId 必須為非空字串；stationId 僅支援 OFFICE001',
    });
    return;
  }
  try {
    final result = await SupplyRequestService(DatabaseService.instance)
        .assignSupplyRequestVolunteer(
          requestId: requestId,
          volunteerId: volunteerId,
          adminId: session.adminId,
        );
    await sendJson(request, 200, {
      'success': true, 'message': '義工指派成功', 'data': result,
    });
  } catch (e) {
    await sendJson(request, 409, {
      'success': false, 'message': e.toString(),
    });
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

Future<void> handleReverseGeocode(Map<String, dynamic> data, HttpRequest request) async {
  try {
    final session = adminSessions.authenticate(request.headers.value(HttpHeaders.authorizationHeader));
    if (session == null) {
      throw const ReverseGeocodingException(401, 'ADMIN_SESSION_REQUIRED', '請重新登入管理員帳號');
    }
    if ((await DatabaseService.instance.select('SELECT id FROM admins WHERE id=?', [session.adminId])).isEmpty) {
      throw const ReverseGeocodingException(403, 'ADMIN_DISABLED', '管理員已無有效權限');
    }
    final service = reverseGeocodingService;
    if (service == null) {
      throw const ReverseGeocodingException(503, 'GEOCODING_DEMO_DISABLED', '尚未啟用測試座標限定的 DEMO 地址服務');
    }
    final result = await service.reverse(data['latitude'], data['longitude']);
    await sendJson(request, 200, {'success': true, 'data': result});
  } on ReverseGeocodingException catch (e) {
    if (e.retryAfterSeconds != null) request.response.headers.set('Retry-After', '${e.retryAfterSeconds}');
    await sendJson(request, e.statusCode, {
      'success': false, 'status': 'unavailable', 'code': e.code, 'message': e.message,
      if (e.retryAfterSeconds != null) 'retryAfterSeconds': e.retryAfterSeconds,
    });
  } catch (_) {
    await sendJson(request, 503, {'success': false, 'status': 'unavailable',
      'code': 'GEOCODING_UNAVAILABLE', 'message': '地址無法取得'});
  }
}

Future<int> authenticateFirebaseUsersAdmin(HttpRequest request) async {
  final session = adminSessions.authenticate(
    request.headers.value(HttpHeaders.authorizationHeader),
  );
  if (session == null) {
    throw const FirebaseUsersException(401, 'ADMIN_SESSION_REQUIRED',
      'A valid administrator session is required');
  }
  final rows = await DatabaseService.instance.select(
    'SELECT id FROM admins WHERE id=?', [session.adminId],
  );
  if (rows.isEmpty) {
    throw const FirebaseUsersException(403, 'ADMIN_DISABLED',
      'Administrator account is no longer available');
  }
  return session.adminId;
}

Future<void> handleFirebaseUsers(Map<String,dynamic> data, HttpRequest request) async {
  try {
    request.response.headers.set(HttpHeaders.cacheControlHeader, 'no-store');
    final adminId = await authenticateFirebaseUsersAdmin(request);
    final service = firebaseUsersService;
    if (service == null) {
      throw const FirebaseUsersException(503, 'FIREBASE_USERS_DISABLED',
        'Firebase user queries are disabled or not configured');
    }
    final result = data['type'] == 'getFirebaseUsers'
      ? await service.list(adminId, data) : await service.get(adminId, data);
    // Session expiry or account deletion during a slow read must not release PII.
    await authenticateFirebaseUsersAdmin(request);
    service.policy.authorize(adminId);
    await sendJson(request, 200, {'success':true,'source':'firestore','data':result});
  } on FirebaseUsersException catch (error) {
    await sendJson(request,error.statusCode,{'success':false,'source':'firestore',
      'code':error.code,'message':error.message});
  } on FirebaseConnectionException catch (error) {
    await sendJson(request,error.code == 'NETWORK_TIMEOUT' ? 504 : 503,{
      'success':false,'source':'firestore','code':'FIRESTORE_${error.code}',
      'message':'Firestore user query could not be completed',
    });
  } catch (_) {
    await sendJson(request,503,{'success':false,'source':'firestore',
      'code':'FIREBASE_USERS_UNAVAILABLE','message':'User query unavailable'});
  }
}
