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
    if (request.method == 'POST') {
      // 讀取原始 bytes
      var data = await request.fold<List<int>>([], (prev, element) => prev..addAll(element));
      print('Received POST raw bytes: ${data.length} bytes');

      
      // 如果是 JSON，可以嘗試解碼
      try {
        var body = utf8.decode(data);
        var jsonData = jsonDecode(body);

        // 建立 HealthReport 物件
        var report = HealthReport(
          reporterId: jsonData['reporterId'],
          name: jsonData['name'],
          phone: jsonData['phone'],
          bloodType: jsonData['bloodType'],
          status: jsonData['status'],
          description: jsonData['description'],
          lat: jsonData['lat'] != null ? jsonData['lat'].toDouble() : null,
          lng: jsonData['lng'] != null ? jsonData['lng'].toDouble() : null,
          reportTime: DateTime.parse(jsonData['reportTime']),
        );
        DatabaseService.insertHealthReport(report);
        request.response
        ..statusCode = HttpStatus.ok
        ..write('Saved to Database')
        ..close();
      } catch (e) {
        print('Error decoding JSON or saving: $e');
        request.response
          ..statusCode = HttpStatus.badRequest
          ..write('Failed to save')
          ..close();
      }
    } else {
      request.response
        ..statusCode = HttpStatus.methodNotAllowed
        ..write('Only POST is supported')
        ..close();
    }
  }
}