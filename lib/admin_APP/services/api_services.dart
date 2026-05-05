import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiServices {
  static const String baseUrl = 'http://localhost:8080';

  /// 通用 POST 方法
  static Future<dynamic> post(Map<String, dynamic> body) async {
    try {
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );

      return jsonDecode(response.body);
    } catch (e) {
      print('API POST ERROR: $e');

      return {
        'success': false,
        'message': e.toString(),
      };
    }
  }

  /// Login
  static Future<bool> login(
    String username,
    String password,
  ) async {
    try {
      final data = await post({
        'type': 'login',
        'username': username,
        'password': password,
      });

      return data['success'] == true;
    } catch (e) {
      print('LOGIN API ERROR: $e');
      return false;
    }
  }

  /// Users
  static Future<List<dynamic>> getAllUsers() async {
    try {
      final data = await post({
        'type': 'getAllUsers',
      });

      if (data['success'] == true) {
        return data['data'] ?? [];
      }

      return [];
    } catch (e) {
      print('GET USERS API ERROR: $e');
      return [];
    }
  }

  static Future<List<dynamic>> searchUsers(
    String keyword,
  ) async {
    try {
      final data = await post({
        'type': 'searchUsers',
        'keyword': keyword,
      });

      if (data['success'] == true) {
        return data['data'] ?? [];
      }

      return [];
    } catch (e) {
      print('SEARCH USERS API ERROR: $e');
      return [];
    }
  }

  /// Reports
  static Future<List<dynamic>> getAllReports() async {
    try {
      final data = await post({
        'type': 'getAllReports',
      });

      if (data['success'] == true) {
        return data['data'] ?? [];
      }

      return [];
    } catch (e) {
      print('GET REPORTS API ERROR: $e');
      return [];
    }
  }

  static Future<List<dynamic>> searchReports(
    String keyword,
  ) async {
    try {
      final data = await post({
        'type': 'searchReports',
        'keyword': keyword,
      });

      if (data['success'] == true) {
        return data['data'] ?? [];
      }

      return [];
    } catch (e) {
      print('SEARCH REPORTS API ERROR: $e');
      return [];
    }
  }
}