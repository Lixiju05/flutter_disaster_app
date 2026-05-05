import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiServices {
  static const String baseUrl = 'http://localhost:8080';

  // ═══════════════════════════
  // 通用 POST 方法（最重要！）
  // ═══════════════════════════
  static Future<dynamic> post(Map<String, dynamic> body) async {
    try {
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
      return jsonDecode(response.body);
    } catch (e) {
      print('API POST ERROR: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  // ═══════════════════════════
  // Login
  // ═══════════════════════════
  static Future<bool> login(String username, String password) async {
    try {
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'type': 'login',
          'username': username,
          'password': password,
        }),
      );
      final data = jsonDecode(response.body);
      return data['success'] == true;
    } catch (e) {
      print('LOGIN API error: $e');
      return false;
    }
  }

  // ═══════════════════════════
  // Users
  // ═══════════════════════════
  static Future<List<dynamic>> getAllUsers() async {
    try {
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'type': 'getAllUsers'}),
      );
      final data = jsonDecode(response.body);
      if (data['success'] == true) return data['data'] ?? [];
      return [];
    } catch (e) {
      print('GET USERS API error: $e');
      return [];
    }
  }

  static Future<List<dynamic>> searchUsers(String keyword) async {
    try {
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'type': 'searchUsers', 'keyword': keyword}),
      );
      final data = jsonDecode(response.body);
      if (data['success'] == true) return data['data'] ?? [];
      return [];
    } catch (e) {
      print('SEARCH USERS API error: $e');
      return [];
    }
  }

  // ═══════════════════════════
  // Reports
  // ═══════════════════════════
  static Future<List<dynamic>> getAllReports() async {
    try {
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'type': 'getAllReports'}),
      );
      final data = jsonDecode(response.body);
      if (data['success'] == true) return data['data'] ?? [];
      return [];
    } catch (e) {
      print('GET REPORTS API error: $e');
      return [];
    }
  }

  static Future<List<dynamic>> searchReports(String keyword) async {
    try {
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'type': 'searchReports', 'keyword': keyword}),
      );
      final data = jsonDecode(response.body);
      if (data['success'] == true) return data['data'] ?? [];
      return [];
    } catch (e) {
      print('SEARCH REPORTS API error: $e');
      return [];
    }
  }
}