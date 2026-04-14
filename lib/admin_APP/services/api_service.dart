class ApiService {
  static Future<bool> login(String username, String password) async {
    print("ApiService.login 被呼叫了");
    print("收到的帳號: $username");
    print("收到的密碼: $password");

    await Future.delayed(const Duration(seconds: 1)); // 模擬延遲

    // 假帳號密碼
    if (username == "admin" && password == "1234") {
      return true;
    } else {
      return false;
    }
  }
}