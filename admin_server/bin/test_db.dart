import 'package:admin_server/database/database_service.dart';

Future<void> main() async {
  await DatabaseService.init();

  //測試登入
  bool result = DatabaseService.checkLogin("admin", "1234");

  if (result) {
    print("Login success");
  } else {
    print("Login failed");
  }
}