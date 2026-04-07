import 'package:flutter/material.dart';
import '../../core/repositories/auth_repository.dart';

class AuthViewModel extends ChangeNotifier {
  final AuthRepository _repo = AuthRepository();

  bool register(String phone, String password) {
    return _repo.register(phone, password);
  }

  bool login(String phone, String password) {
    return _repo.login(phone, password);
  }
}