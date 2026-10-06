import 'package:admin_server/database/database_service.dart';

Future<void> main() async {
  await DatabaseService.init();

  bool result = await DatabaseService.instance.checkLogin(
    "admin_ncnu",
    "1234",
  );

  if (result) {
    print("Login success");
  } else {
    print("Login failed");
  }
}