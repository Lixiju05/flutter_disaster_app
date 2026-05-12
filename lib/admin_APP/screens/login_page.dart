import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dashboard_page.dart';
import 'register_page.dart';
import 'admin_setup_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with TickerProviderStateMixin {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;

  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _fadeCtrl.dispose();
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
        Uri.parse('https://delphine-eisteddfodic-afflictively.ngrok-free.dev'),
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

        // 檢查是否已設定管理員資訊
        final prefs = await SharedPreferences.getInstance();
        final adminName = prefs.getString('adminName') ?? '';

        if (!mounted) return;

        if (adminName.isEmpty) {
          // 第一次登入，進入設定頁
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const AdminSetupPage()),
          );
        } else {
          // 已設定，直接進 dashboard
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const DashboardPage()),
          );
        }
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
      backgroundColor: isError
          ? const Color(0xFFFF3333).withOpacity(.9)
          : const Color(0xFF00D09C).withOpacity(.9),
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
    final screenWidth = MediaQuery.of(context).size.width;
    final isNarrow = screenWidth < 1100;

    return Scaffold(
      backgroundColor: const Color(0xFF020C18),
      body: Stack(children: [
        // ── 背景網格 ──────────────────────────────────────
        Positioned.fill(child: CustomPaint(painter: _GridBgPainter())),
        // ── 背景光暈 ──────────────────────────────────────
        Positioned(top: -200, left: -200,
          child: Container(width: 600, height: 600,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                const Color(0xFF1A6EFF).withOpacity(.18), Colors.transparent,
              ]),
            ),
          ),
        ),
        Positioned(bottom: -150, right: -150,
          child: Container(width: 500, height: 500,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                const Color(0xFF00C8FF).withOpacity(.12), Colors.transparent,
              ]),
            ),
          ),
        ),
        // ── 主體 ──────────────────────────────────────────
        SafeArea(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: isNarrow
                ? Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: _buildCard(),
                    ),
                  )
                : Row(children: [
                    Expanded(flex: 6, child: _buildLeftPanel()),
                    Expanded(flex: 5,
                      child: Center(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                          child: _buildCard(),
                        ),
                      ),
                    ),
                  ]),
          ),
        ),
      ]),
    );
  }

  // ── 左側說明欄 ────────────────────────────────────────
  Widget _buildLeftPanel() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 70, vertical: 50),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 系統標籤
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF00C8FF).withOpacity(.08),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: const Color(0xFF00C8FF).withOpacity(.25)),
            ),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.wifi_tethering, color: Color(0xFF00C8FF), size: 14),
              SizedBox(width: 8),
              Text('Disaster Admin Control Center',
                  style: TextStyle(color: Color(0xFF00C8FF), fontSize: 12,
                      fontWeight: FontWeight.w600, letterSpacing: .5)),
            ]),
          ),
          const SizedBox(height: 28),
          const Text('防災後台\n管理系統',
              style: TextStyle(fontSize: 52, fontWeight: FontWeight.bold,
                  color: Colors.white, height: 1.15)),
          const SizedBox(height: 6),
          Container(width: 60, height: 3,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFF1A6EFF), Color(0xFF00C8FF)]),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          const SizedBox(
            width: 580,
            child: Text(
              '集中管理災民資訊、物資調度、健康回報與緊急事件，協助管理員在災害發生時快速掌握現況、整合資源並提升整體應變效率。',
              style: TextStyle(fontSize: 16, color: Color(0xFF7E9CC0), height: 1.8),
            ),
          ),
          const SizedBox(height: 40),
          _featureItem(Icons.groups_rounded,      '災民資訊管理與救援狀態追蹤', const Color(0xFF00C8FF)),
          _featureItem(Icons.warning_amber_rounded,'緊急事件回報與即時處理',     const Color(0xFFFFB020)),
          _featureItem(Icons.inventory_2_rounded,  '救援物資調度與分配管理',     const Color(0xFF00D09C)),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFB020).withOpacity(.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFFB020).withOpacity(.25)),
            ),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.wifi_off_rounded, color: Color(0xFFFFB020), size: 18),
              SizedBox(width: 10),
              Text('支援離線通報情境，提升災害期間資訊整合能力',
                  style: TextStyle(color: Color(0xFFFFB020), fontSize: 14)),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _featureItem(IconData icon, String text, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(children: [
        Container(
          width: 42, height: 42,
          decoration: BoxDecoration(
            color: color.withOpacity(.10),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(.25)),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 14),
        Text(text, style: const TextStyle(color: Color(0xFFB0C8E0), fontSize: 15)),
      ]),
    );
  }

  // ── 登入卡片 ──────────────────────────────────────────
  Widget _buildCard() {
    return Container(
      width: 460,
      padding: const EdgeInsets.symmetric(horizontal: 34, vertical: 36),
      decoration: BoxDecoration(
        color: const Color(0xFF071828),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF1A4A6E)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00C8FF).withOpacity(.08),
            blurRadius: 40, offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // 圖示
        Container(
          width: 72, height: 72,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [Color(0xFF1A6EFF), Color(0xFF00C8FF)]),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(
                color: const Color(0xFF00C8FF).withOpacity(.3),
                blurRadius: 20, spreadRadius: 2)],
          ),
          child: const Icon(Icons.admin_panel_settings_rounded,
              size: 36, color: Colors.white),
        ),
        const SizedBox(height: 20),
        const Text('管理員登入',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold,
                color: Colors.white)),
        const SizedBox(height: 8),
        const Text('請輸入帳號與密碼以進入系統後台',
            style: TextStyle(fontSize: 13, color: Color(0xFF3E5872))),
        const SizedBox(height: 30),
        // 帳號
        _inputField(
          controller: _usernameController,
          hint: '請輸入帳號',
          icon: Icons.person_rounded,
        ),
        const SizedBox(height: 16),
        // 密碼
        _inputField(
          controller: _passwordController,
          hint: '請輸入密碼',
          icon: Icons.lock_rounded,
          obscure: _obscurePassword,
          suffixIcon: IconButton(
            icon: Icon(
              _obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded,
              color: const Color(0xFF3E5872), size: 18,
            ),
            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
          ),
        ),
        const SizedBox(height: 28),
        // 登入按鈕
        SizedBox(
          width: double.infinity, height: 54,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _handleLogin,
            style: ElevatedButton.styleFrom(
              elevation: 0,
              backgroundColor: const Color(0xFF1A6EFF),
              foregroundColor: Colors.white,
              disabledBackgroundColor: const Color(0xFF1A6EFF).withOpacity(.5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _isLoading
                ? const SizedBox(width: 22, height: 22,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : const Text('登入管理後台',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700,
                        letterSpacing: .5)),
          ),
        ),
        const SizedBox(height: 14),
        TextButton(
          onPressed: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const RegisterPage())),
          child: const Text('還沒有帳號？點我註冊',
              style: TextStyle(fontSize: 14, color: Color(0xFF00C8FF),
                  fontWeight: FontWeight.w600)),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF0A2035),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF0E2A40)),
          ),
          child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.info_outline_rounded, size: 15, color: Color(0xFF3E5872)),
            SizedBox(width: 8),
            Expanded(
              child: Text('目前登入使用後端 API 驗證，請使用後端提供的帳號密碼登入',
                  style: TextStyle(color: Color(0xFF3E5872), fontSize: 12),
                  textAlign: TextAlign.center),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _inputField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscure = false,
    Widget? suffixIcon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0A2035),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1A4A6E)),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Color(0xFF3E5872), fontSize: 14),
          prefixIcon: Icon(icon, color: const Color(0xFF3E5872), size: 18),
          suffixIcon: suffixIcon,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }
}

// ── 背景網格畫家 ──────────────────────────────────────────
class _GridBgPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = const Color(0xFF00C8FF).withOpacity(.03)
      ..strokeWidth = .5;
    for (double x = 0; x < size.width; x += 40)
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    for (double y = 0; y < size.height; y += 40)
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
  }
  @override bool shouldRepaint(covariant CustomPainter _) => false;
}