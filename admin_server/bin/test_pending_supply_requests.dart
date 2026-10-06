import 'dart:convert';
import 'package:http/http.dart' as http;

Future<void> main() async {
  const url = 'http://localhost:8080';

  try {
    final response = await http.post(
      Uri.parse(url),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'type': 'getPendingSupplyRequests',
        'stationId': 'S001',
      }),
    );

    print('HTTP Status: ${response.statusCode}');
    print('Response: ${response.body}');
  } catch (e) {
    print('❌ API 測試失敗：$e');
  }
}