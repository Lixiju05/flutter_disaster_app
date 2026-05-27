import 'dart:convert';
import 'package:http/http.dart' as http;

class GovShelterService {
  static const Map<String, String> urls = {
    // 先放一个测试，之后再补政府 JSON URL
    // '南投縣': '这里放政府开放资料 JSON URL',
  };

  static Future<List<Map<String, dynamic>>> fetchShelters(String area) async {
    final url = urls[area];

    if (url == null) {
      return [];
    }

    final response = await http.get(Uri.parse(url));

    if (response.statusCode != 200) {
      throw Exception('政府防空避難資料讀取失敗');
    }

    final decoded = jsonDecode(response.body);

    if (decoded is List) {
      return decoded.whereType<Map<String, dynamic>>().toList();
    }

    if (decoded is Map && decoded['data'] is List) {
      return (decoded['data'] as List).whereType<Map<String, dynamic>>().toList();
    }

    if (decoded is Map && decoded['result'] is List) {
      return (decoded['result'] as List).whereType<Map<String, dynamic>>().toList();
    }

    return [];
  }
}