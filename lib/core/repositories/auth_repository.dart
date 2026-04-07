import '../models/user.dart';

class AuthRepository {
  final List<User> _users = [];

  bool register(String phone, String password) {
    final exists = _users.any((u) => u.phone == phone);
    if (exists) return false;

    _users.add(User(phone: phone, password: password));
    return true;
  }

  bool login(String phone, String password) {
    return _users.any(
      (u) => u.phone == phone && u.password == password,
    );
  }
}