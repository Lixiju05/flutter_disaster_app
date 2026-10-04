import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dashboard_page.dart';
import 'volunteer_page.dart';
import 'package:flutter_disaster_app/core/api_config.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      _showSnack('請輸入帳號與密碼', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse(ApiConfig.baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: jsonEncode({
          'type': 'login',
          'username': username,
          'password': password,
        }),
      ).timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);

      if (!mounted) return;

      if (data['success'] == true) {
        _showSnack('登入成功', isError: false);

        // 帳號由各地區／社區統一發放，登入後直接進 dashboard
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('adminId', (data['username'] ?? username).toString());
        // 後端帳號若有設定負責地區（zoneId），就以帳號的地區為準
        final zone = data['zoneId']?.toString() ?? '';
        if (zone.isNotEmpty) await prefs.setString('adminArea', zone);

        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const DashboardPage()),
        );
      } else {
        _showSnack(data['message'] ?? '帳號或密碼錯誤', isError: true);
      }
    } catch (e) {
      if (!mounted) return;
      _showSnack('連線失敗，請確認後端是否開啟', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnack(String msg, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: isError ? kRed : kGreen,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      duration: const Duration(seconds: 3),
      content: Text(msg,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kSidebarBg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _logo(),
                const SizedBox(height: 28),
                _buildLoginCard(),
                const SizedBox(height: 20),
                const Text('帳號由各地區／社區統一發放，如需帳號請洽系統管理單位',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: kSidebarTextSub, fontSize: 13)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Logo（與指揮中心側邊欄相同樣式，置中）────────────────
  Widget _logo() => Column(children: [
        Container(
          width: 56, height: 56,
          decoration: BoxDecoration(
              color: Colors.white.withOpacity(.15),
              borderRadius: BorderRadius.circular(16)),
          child: const Icon(Icons.shield_outlined, color: Colors.white, size: 30),
        ),
        const SizedBox(height: 14),
        const Text('災難管理系統',
            style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        const Text('EMERGENCY COMMAND',
            style: TextStyle(color: kSidebarTextSub, fontSize: 13, letterSpacing: 1.6)),
      ]);

  // ── 登入卡片（與指揮中心白色卡片相同）────────────────────
  Widget _buildLoginCard() {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 420),
      padding: const EdgeInsets.fromLTRB(28, 28, 28, 24),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('管理員登入',
              style: TextStyle(color: kTextMain, fontSize: 24, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          const Text('ADMIN LOGIN',
              style: TextStyle(color: kTextSub, fontSize: 13, letterSpacing: 1.3)),
          const SizedBox(height: 24),
          _label('帳號'),
          _input(
            controller: _usernameController,
            hint: '請輸入帳號',
            icon: Icons.person_outline_rounded,
          ),
          const SizedBox(height: 16),
          _label('密碼'),
          _input(
            controller: _passwordController,
            hint: '請輸入密碼',
            icon: Icons.lock_outline_rounded,
            obscure: _obscurePassword,
            onSubmitted: (_) {
              if (!_isLoading) _handleLogin();
            },
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                color: kTextSub, size: 18,
              ),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity, height: 46,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handleLogin,
              style: ElevatedButton.styleFrom(
                elevation: 0,
                backgroundColor: kBlue,
                foregroundColor: Colors.white,
                disabledBackgroundColor: kBlue.withOpacity(.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: _isLoading
                  ? const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('登入',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(height: 20),
          const Row(children: [
            Expanded(child: Divider(color: kBorder)),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: Text('義工', style: TextStyle(color: kTextSub, fontSize: 13)),
            ),
            Expanded(child: Divider(color: kBorder)),
          ]),
          const SizedBox(height: 16),
          // 義工 Demo 入口（正式版改成掃收容中心 QR Code 進入）
          SizedBox(
            width: double.infinity, height: 44,
            child: OutlinedButton.icon(
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const VolunteerPage())),
              style: OutlinedButton.styleFrom(
                foregroundColor: kTextMain,
                side: const BorderSide(color: kBorder),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.volunteer_activism_outlined, size: 18, color: kGreen),
              label: const Text('義工 Demo（A收容中心）',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text,
            style: const TextStyle(color: kTextMain, fontSize: 14, fontWeight: FontWeight.w600)),
      );

  Widget _input({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscure = false,
    Widget? suffixIcon,
    ValueChanged<String>? onSubmitted,
  }) {
    OutlineInputBorder border(Color c) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: c),
        );
    return TextField(
      controller: controller,
      obscureText: obscure,
      onSubmitted: onSubmitted,
      style: const TextStyle(color: kTextMain, fontSize: 15),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: kTextSub, fontSize: 15),
        prefixIcon: Icon(icon, color: kTextSub, size: 18),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: kCardBg2,
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
        enabledBorder: border(kBorder),
        focusedBorder: border(kBlue),
      ),
    );
  }
}
