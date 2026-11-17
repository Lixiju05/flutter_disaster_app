import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'admin_APP/services/reverse_geocoding_client.dart';
import 'admin_APP/widgets/sos_address_details.dart';
import 'core/api_config.dart';

/// Standalone entry point: avoids unrelated existing admin UI compile errors,
/// Firebase and all resident records. Uses the REAL backend login and lookup.
void main() => runApp(const MaterialApp(home: GeocodingDemoPage()));

class GeocodingDemoPage extends StatefulWidget {
  const GeocodingDemoPage({super.key});
  @override
  State<GeocodingDemoPage> createState() => _GeocodingDemoPageState();
}

class _GeocodingDemoPageState extends State<GeocodingDemoPage> {
  String? _error;
  bool _busy = false;
  bool _loggedIn = false;
  Future<void> _login() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      // This account exists ONLY in the dedicated isolated DEMO runner.
      final response = await http
          .post(Uri.parse(ApiConfig.baseUrl),
              headers: {
                'Content-Type': 'application/json',
                'ngrok-skip-browser-warning': 'true',
              },
              body: jsonEncode({
                'type': 'login',
                'username': 'demo_admin',
                'password': 'DemoOnly123!'
              }))
          .timeout(const Duration(seconds: 10));
      final data = jsonDecode(response.body);
      if (response.statusCode != 200 ||
          data['success'] != true ||
          data['token'] is! String) {
        throw StateError('Login failed');
      }
      AdminApiSession.token = data['token'] as String;
      if (mounted) setState(() => _loggedIn = true);
    } catch (_) {
      if (mounted) {
        setState(() => _error = '登入失敗，請確認使用獨立 DEMO Server 與正確 API_BASE_URL');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _detail({bool provided = false}) {
    showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
              title: const Text('SOS 詳細資料（公開地標測試，非真實居民）'),
              content: SizedBox(
                  width: 460,
                  child: SingleChildScrollView(
                      child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('DEMO_SOS_001；開啟單筆才查詢，不在列表查詢'),
                      const SizedBox(height: 12),
                      SosAddressDetails(
                          latitude: 25.033964,
                          longitude: 121.564468,
                          providedAddress:
                              provided ? 'App 提供的位置描述（測試文字，不是解析結果）' : null),
                      TextButton(
                          onPressed: () => launchUrl(Uri.parse(
                              'https://www.google.com/maps/search/?api=1&query=25.033964,121.564468')),
                          child: const Text('Google Maps 開啟地圖')),
                    ],
                  ))),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('關閉'))
              ],
            ));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('互CARES：GPS 逆地理編碼 DEMO')),
        body: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('後端：${ApiConfig.baseUrl}'),
                const Text('僅使用公開地標測試座標，不讀取正式資料或 Firebase。'),
                const SizedBox(height: 16),
                FilledButton(
                    onPressed: _busy ? null : _login,
                    child: Text(_loggedIn ? '重新登入 DEMO 管理員' : '登入獨立 DEMO 管理員')),
                if (_error != null) Text(_error!),
                if (_loggedIn) ...[
                  const SizedBox(height: 16),
                  FilledButton(
                      onPressed: () => _detail(),
                      child: const Text('開啟無地址 SOS 詳情（自動查詢）')),
                  TextButton(
                      onPressed: () => _detail(provided: true),
                      child: const Text('開啟已有 App 地址的 SOS（不查詢）')),
                ],
              ],
            )),
      );
}
