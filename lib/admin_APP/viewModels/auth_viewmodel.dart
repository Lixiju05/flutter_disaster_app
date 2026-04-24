import 'package:flutter/material.dart';
import 'package:flutter_disaster_app/core/repositories/auth_repository.dart';
import 'package:flutter_disaster_app/core/models/login_response.dart';

class AuthViewModel extends ChangeNotifier {
  final AuthRepository _repo = AuthRepository();

  bool isLoading = false;
  String? errorMessage;
  LoginResponse? loginResult;

  /// 登入
  Future<bool> login(String phone, String password) async {
    isLoading = true;
    notifyListeners();

    try {
      final result = await _repo.login(phone, password);

      loginResult = result;

      if (result.success) {
        errorMessage = null;
        return true;
      } else {
        errorMessage = "Login failed";
        return false;
      }
    } catch (e) {
      errorMessage = "Server error";
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}