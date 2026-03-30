import 'dart:io';
import 'dart:convert';

void main() async {
  var context = SecurityContext()
    ..useCertificateChain('cert.pem')
    ..usePrivateKey('key.pem');

  final server = await HttpServer.bindSecure(
    InternetAddress.anyIPv4,
    8443,
    context,
  );

  print('HTTPS Server running at https://localhost:8443');

  await for (HttpRequest request in server) {
    try {
      if (request.method == 'POST' &&
          request.uri.path == '/health-report') {

        final body = await utf8.decoder.bind(request).join();
        print('RAW BODY: $body');

        final data = jsonDecode(body);
        print('收到健康回報: $data');

        request.response.statusCode = HttpStatus.ok;
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode({'status': 'ok'}));
      } else {
        request.response.statusCode = HttpStatus.notFound;
        request.response.write('Not Found');
      }
    } catch (e) {
      print('ERROR: $e');
      request.response.statusCode = 500;
      request.response.write('Server Error');
    }

    await request.response.close();
  }
}