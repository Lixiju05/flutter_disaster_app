import 'dart:io';
import 'dart:convert';
import 'dart:math';

import 'package:admin_server/database/database_service.dart';
import 'package:admin_server/core/models/healthReport.dart';

Future<void> main() async {
  await DatabaseService.init();
  DatabaseService.seedAll();

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
  request.response.headers
    ..add("Access-Control-Allow-Origin", "*")
    ..add("Access-Control-Allow-Methods", "POST, GET, OPTIONS")
    ..add("Access-Control-Allow-Headers", "Content-Type, Authorization");
}

/// 共用：JSON 回應
void sendJson(HttpRequest request, int status, Map<String, dynamic> data) {
  request.response.headers.contentType = ContentType.json;
  request.response
    ..statusCode = status
    ..write(jsonEncode(data))
    ..close();
}

///共用：產生 Token
String generateToken() {
  final rand = Random();
  return List.generate(32, (_) => rand.nextInt(16).toRadixString(16)).join();
}

/// 主請求入口
Future<void> handleRequest(HttpRequest request) async {
  setCorsHeaders(request);

  //  處理 preflight
  if (request.method == 'OPTIONS') {
    request.response
      ..statusCode = HttpStatus.ok
      ..close();
    return;
  }

  if (request.method != 'POST') {
    sendJson(request, HttpStatus.methodNotAllowed, {
      "success": false,
      "message": "Only POST supported"
    });
    return;
  }

  try {
    var data = await request.fold<List<int>>(
      [],
      (prev, element) => prev..addAll(element),
    );

    var body = utf8.decode(data);
    print("BODY: $body");
    var jsonData = jsonDecode(body);

    final type = jsonData['type'];

    /// API 分流
    switch (type) {
      case 'healthReport':
        await handleHealthReport(jsonData, request);
        break;

      case 'login':
        await handleLogin(jsonData, request);
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


/// 災情回報
Future<void> handleHealthReport(
  Map<String, dynamic> jsonData,
  HttpRequest request,
) async {
  var report = HealthReport(
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

  DatabaseService.insertHealthReport(report);

  sendJson(request, HttpStatus.ok, {
    "success": true,
    "message": "Saved to Database"
  });
}

/// 登入（含 Token）
Future<void> handleLogin(
  Map<String, dynamic> jsonData,
  HttpRequest request,
) async {
  final username = jsonData['username'];
  final password = jsonData['password'];

  final success = DatabaseService.checkLogin(username, password);

  if (success) {
    final token = generateToken();

    sendJson(request, HttpStatus.ok, {
      "success": true,
      "token": token,
      "adminId": username,
    });
  } else {
    sendJson(request, HttpStatus.forbidden, {
      "success": false,
      "message": "Invalid username or password"
    });
  }
}

/// 取得所有回報
Future<void> handleGetReports(HttpRequest request) async {
  final reports = DatabaseService.getAllReports();

  sendJson(request, HttpStatus.ok, {
    "success": true,
    "data": reports,
  });
}

/// 取得單一使用者
Future<void> handleGetUser(
  Map<String, dynamic> jsonData,
  HttpRequest request,
) async {
  final id = jsonData['id'];

  final user = DatabaseService.getUser(id);

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
    final users = DatabaseService.getAllUsers();

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
Future<void> handleSearchReports(
  Map<String, dynamic> jsonData,
  HttpRequest request,
) async {
  final keyword = jsonData['keyword'] ?? '';

  final results = DatabaseService.searchReports(keyword);

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

  final results = DatabaseService.searchUsers(keyword);

  sendJson(request, HttpStatus.ok, {
    "success": true,
    "data": results,
  });
}