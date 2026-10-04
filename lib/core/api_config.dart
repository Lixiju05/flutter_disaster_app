/// 後端 API 網址統一在這裡管理
///
/// ngrok 網址換了只要改這一行。
/// 也可以不改程式碼，啟動時用參數指定，例如連本機後端：
///   flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8080
class ApiConfig {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://delphine-eisteddfodic-afflictively.ngrok-free.dev',
  );
}
