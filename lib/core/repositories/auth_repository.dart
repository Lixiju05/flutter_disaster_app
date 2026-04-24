import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/login_response.dart';

class AuthRepository {
  Future<LoginResponse> login(String username, String password) async {
    final response = await http.post(
      Uri.parse("http:// https://delphine-eisteddfodic-afflictively.ngrok-free.dev/"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "type": "login",
        "username": username,
        "password": password,
      }),
    );

    final data = jsonDecode(response.body);

    return LoginResponse.fromJson(data);
  }
}