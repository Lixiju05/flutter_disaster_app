import 'dart:io';
import 'dart:convert';

import 'package:admin_server/database/database_service.dart';
import 'package:admin_server/core/models/healthReport.dart';

Future<void> main() async {
  await DatabaseService.init();
  DatabaseService.seedTestData();


  var server = await HttpServer.bind(
    InternetAddress.anyIPv4,
    8080,
  );

  print('HTTPS Server running at https://${server.address.address}:${server.port}');

  await for (HttpRequest request in server) {
    await handleRequest(request); // 
  }
  print("Server started");
}

Future<void> handleRequest(HttpRequest request) async {
    request.response.headers
    ..add("Access-Control-Allow-Origin", "*")
    ..add("Access-Control-Allow-Methods", "POST, GET, OPTIONS")
    ..add("Access-Control-Allow-Headers", "Content-Type");

  // 處理 OPTIONS
  if (request.method == 'OPTIONS') {
    request.response
      ..statusCode = HttpStatus.ok
      ..close();
    return;
  }
  if (request.method != 'POST') {
    request.response
      ..statusCode = HttpStatus.methodNotAllowed
      ..write('Only POST supported')
      ..close();
    return;
  }

  try {
    var data = await request.fold<List<int>>(
      [],
      (prev, element) => prev..addAll(element),
    );

    print('Received bytes: ${data.length}');

    var body = utf8.decode(data);
    var jsonData = jsonDecode(body);

    ///分流
    if (jsonData['type'] == 'healthReport') {
    await handleHealthReport(jsonData, request);
    } 
    else if (jsonData['type'] == 'login') {
      await handleLogin(jsonData, request);
    }
    else if (jsonData['type'] == 'getReports') {
      await handleGetReports(request);
    }
    else if (jsonData['type'] == 'getUser') {
      await handleGetUser(jsonData, request);
    }
    else if (jsonData['type'] == 'getAllUsers') {
      await handleGetAllUsers(request);
    }
    else {
      request.response
        ..statusCode = HttpStatus.badRequest
        ..write('Unknown type')
        ..close();
    }
  } catch (e) {
    print('Error: $e');
    request.response
      ..statusCode = HttpStatus.badRequest
      ..write('Invalid request')
      ..close();
  }
}

///處理災情
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
    lat: jsonData['lat']?.toDouble(),
    lng: jsonData['lng']?.toDouble(),
    reportTime: DateTime.parse(jsonData['reportTime']),
  );

  DatabaseService.insertHealthReport(report);

  request.response
    ..statusCode = HttpStatus.ok
    ..write('Saved to Database')
    ..close();
}
Future<void> handleLogin(
  Map<String, dynamic> jsonData,
  HttpRequest request,
) async {
  final username = jsonData['username'];
  final password = jsonData['password'];

  final success = DatabaseService.checkLogin(username, password);

  if (success) {
    request.response
      ..statusCode = HttpStatus.ok
      ..write(jsonEncode({"success": true}))
      ..close();
  } else {
    request.response
      ..statusCode = HttpStatus.forbidden
      ..write(jsonEncode({"success": false}))
      ..close();
  }
}
Future<void> handleGetReports(HttpRequest request) async {
  final reports = DatabaseService.getAllReports();

  request.response
    ..statusCode = HttpStatus.ok
    ..write(jsonEncode({
      "success": true,
      "data": reports,
    }))
    ..close();
}
//取得單一user
Future<void> handleGetUser(
  Map<String, dynamic> jsonData,
  HttpRequest request,
) async {
  final id = jsonData['id'];

  final user = DatabaseService.getUser(id);

  if (user == null) {
    request.response
      ..statusCode = HttpStatus.notFound
      ..write(jsonEncode({
        "success": false,
        "message": "user not found"
      }))
      ..close();
    return;
  }

  request.response
    ..statusCode = HttpStatus.ok
    ..write(jsonEncode({
      "success": true,
      "data": user.toMap(), // 如果你有 toMap()
    }))
    ..close();
}
//取得全部user
Future<void> handleGetAllUsers(HttpRequest request) async {
  try {
    final users = DatabaseService.getAllUsers();

    request.response
      ..statusCode = HttpStatus.ok
      ..write(jsonEncode({
        "success": true,
        "data": users.map((u) => u.toMap()).toList(),
      }))
      ..close();
  } catch (e) {
    print("SERVER ERROR: $e");

    request.response
      ..statusCode = HttpStatus.internalServerError
      ..write("server error")
      ..close();
  }
}