import 'dart:convert';
import 'dart:io';
import 'package:http/io_client.dart';

class ApiService {
  // 使用 ngrok 網址，這樣手機實機與模擬器都能通
  static const String baseUrl =
      "https://delphine-eisteddfodic-afflictively.ngrok-free.dev";

  /// 建立支持開發環境 (如 SSL 憑證跳過) 的 HttpClient
  static IOClient createHttpClient() {
    HttpClient client = HttpClient()
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;

    return IOClient(client);
  }

  /// 1. 登入功能
  static Future<bool> login(String username, String password) async {
    try {
      final client = createHttpClient();
      final response = await client.post(
        Uri.parse(baseUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "type": "login",
          "username": username,
          "password": password,
        }),
      );

      final data = jsonDecode(response.body);
      return data["success"] == true;
    } catch (e) {
      print("LOGIN error: $e");
      return false;
    }
  }

  /// 2. 取得所有民眾
  static Future<List<dynamic>> getAllUsers() async {
    try {
      final client = createHttpClient();
      final response = await client.post(
        Uri.parse(baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'type': 'getAllUsers'}),
      );

      final data = jsonDecode(response.body);
      return (data['success'] == true) ? data['data'] : [];
    } catch (e) {
      print("GET ALL USERS error: $e");
      return [];
    }
  }

  /// 3. 取得所有回報
  static Future<List<dynamic>> getAllReports() async {
    try {
      final client = createHttpClient();
      final response = await client.post(
        Uri.parse(baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'type': 'getAllReports'}),
      );

      final data = jsonDecode(response.body);
      return (data['success'] == true) ? data['data'] : [];
    } catch (e) {
      print("GET ALL REPORTS error: $e");
      return [];
    }
  }

  /// 4. 搜尋回報
  static Future<List<dynamic>> searchReports(String keyword) async {
    try {
      final client = createHttpClient();
      final response = await client.post(
        Uri.parse(baseUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "type": "searchReports",
          "keyword": keyword,
        }),
      );

      final data = jsonDecode(response.body);
      return (data["success"] == true) ? data["data"] : [];
    } catch (e) {
      print("SEARCH REPORTS error: $e");
      return [];
    }
  }

  /// 5. 搜尋使用者
  static Future<List<dynamic>> searchUsers(String keyword) async {
    try {
      final client = createHttpClient();
      final response = await client.post(
        Uri.parse(baseUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "type": "searchUsers",
          "keyword": keyword,
        }),
      );

      final data = jsonDecode(response.body);
      return data["data"] ?? [];
    } catch (e) {
      print("SEARCH USERS error: $e");
      return [];
    }
  }
}