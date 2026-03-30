import 'dart:convert';
import 'dart:io';

class HttpServerService {
  static Future<void> start() async {
    final server =
        await HttpServer.bind(InternetAddress.anyIPv4, 8080);

    print('HTTP Server started on port 8080');

    await for (HttpRequest request in server) {
      if (request.method == 'POST' &&
          request.uri.path == '/health-report') {
        await _handleHealthReport(request);
      }
    }
  }

  static Future<void> _handleHealthReport(
      HttpRequest request) async {

    final body = await utf8.decoder.bind(request).join();

    print("收到資料:");
    print(body);

    request.response
      ..statusCode = 200
      ..write("OK");

    await request.response.close();
  }
}