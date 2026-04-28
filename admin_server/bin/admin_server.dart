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

    await DatabaseService.insertHealthReport(report);

    print("3. AFTER DB");

    sendJson(request, 200, {
      "success": true,
      "message": "Saved"
    });

    print("4. AFTER RESPONSE");
  } catch (e, stack) {
    print("❌ ERROR: $e");
    print(stack);

    try {
      sendJson(request, 500, {
        "success": false,
        "message": e.toString()
      });
    } catch (err) {
      print("❌ FAILED TO SEND ERROR RESPONSE: $err");
    }
  }
}
/// 登入（含 Token）
Future<void> handleLogin(
  Map<String, dynamic> jsonData,
  HttpRequest request,
) async {
  try {
    print("LOGIN ENTER");

    final username = jsonData['username'];
    final password = jsonData['password'];

    if (username == null || password == null) {
      sendJson(request, 400, {
        "success": false,
        "message": "Missing username or password"
      });
      return;
    }

    final success = DatabaseService.checkLogin(username, password);

    if (success) {
      sendJson(request, 200, {
        "success": true,
        "token": generateToken(),
        "adminId": username,
      });
    } else {
      sendJson(request, 403, {
        "success": false,
        "message": "Invalid credentials"
      });
    }
  } catch (e, stack) {
    print("LOGIN ERROR: $e");
    print(stack);

    sendJson(request, 500, {
      "success": false,
      "message": "Server error"
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
Future<void> handleGetAllReports(HttpRequest request) async {
  final reports = DatabaseService.getAllReports();

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