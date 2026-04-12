import 'dart:io';
import 'dart:convert';

import 'package:admin_server/database/database_service.dart';
import 'package:admin_server/core/models/healthReport.dart';

Future<void> main() async {
  await DatabaseService.init();

  var securityContext = SecurityContext()
    ..useCertificateChain('certs/server.crt')
    ..usePrivateKey('certs/server.key');

  var server = await HttpServer.bindSecure(
    InternetAddress.anyIPv4,
    8443,
    securityContext,
  );

  print('HTTPS Server running at https://${server.address.address}:${server.port}');

  await for (HttpRequest request in server) {
    await handleRequest(request); // 
  }
}

Future<void> handleRequest(HttpRequest request) async {
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