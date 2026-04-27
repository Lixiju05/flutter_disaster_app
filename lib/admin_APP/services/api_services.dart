import 'dart:convert';
<<<<<<< Updated upstream
import 'dart:io';
import 'package:http/io_client.dart';

class ApiService {
  static const String baseUrl =
      "https://delphine-eisteddfodic-afflictively.ngrok-free.dev";

  static IOClient createHttpClient() {
    HttpClient client = HttpClient()
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;

    return IOClient(client);
  }

  /// LOGIN
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
      print("API error: $e");
      return false;
    }
  }

  /// SEARCH REPORTS
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

      if (data["success"] == true) {
        return data["data"];
      } else {
        return [];
      }
    } catch (e) {
      print("SEARCH API error: $e");
      return [];
    }
  }
  //SEARCH USERS
  static Future<List<dynamic>> searchUsers(String keyword) async {
    final client = createHttpClient();

    final response = await client.post(
      Uri.parse(baseUrl),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "type": "searchUsers",
        "keyword": keyword,
=======
import 'package:http/http.dart' as http;

class ApiServices {
  static const String baseUrl = 'http://localhost:8080';

  static Future<List<dynamic>> getAllUsers() async {
    final response = await http.post(
      Uri.parse(baseUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'type': 'getAllUsers',
>>>>>>> Stashed changes
      }),
    );

    final data = jsonDecode(response.body);

<<<<<<< Updated upstream
    return data["data"] ?? [];
=======
    if (data['success'] == true) {
      return data['data'];
    } else {
      return [];
    }
  }

  static Future<List<dynamic>> getAllReports() async {
    final response = await http.post(
      Uri.parse(baseUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'type': 'getAllReports',
      }),
    );

    final data = jsonDecode(response.body);

    if (data['success'] == true) {
      return data['data'];
    } else {
      return [];
    }
>>>>>>> Stashed changes
  }
}