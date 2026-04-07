import 'dart:io';
import 'dart:convert';

Future<void> main() async {
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

      // 如果你確定是 JSON，可以嘗試解碼
      try {
        var body = utf8.decode(data);
        print('Decoded JSON: $body');
      } catch (e) {
        print('Not UTF-8 text, raw bytes only.');
      }

      request.response
        ..statusCode = HttpStatus.ok
        ..write('Server received your message')
        ..close();
    } else {
      request.response
        ..statusCode = HttpStatus.methodNotAllowed
        ..write('Only POST is supported')
        ..close();
    }
  }
}