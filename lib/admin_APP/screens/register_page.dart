import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dashboard_page.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage>
    with SingleTickerProviderStateMixin {
  final TextEditingController _phoneController    = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmController  = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirm  = true;
  bool _isLoading       = false;

  late AnimationController _fadeCtrl;
  late Animation<double>   _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _fadeCtrl.dispose();
    super.dispose();
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
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold)),
    ));
  }

  Future<void> _handleRegister() async {
    final phone    = _phoneController.text.trim();
    final password = _passwordController.text.trim();
    final confirm  = _confirmController.text.trim();

    if (phone.isEmpty || password.isEmpty || confirm.isEmpty) {
      _showSnack('請完整填寫所有欄位', isError: true);
      return;
    }
    if (phone.length < 8) {
      _showSnack('手機號碼格式錯誤', isError: true);
      return;
    }
    if (password.length < 4) {
      _showSnack('密碼至少需要 4 碼', isError: true);
      return;
    }
    if (password != confirm) {
      _showSnack('兩次輸入的密碼不一致', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    // 模擬短暫延遲
    await Future.delayed(const Duration(milliseconds: 600));

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('username', phone);
    await prefs.setString('password', password);
    await prefs.setBool('isLogin', true);

    if (!mounted) return;

    _showSnack('註冊成功，正在進入系統', isError: false);

    setState(() => _isLoading = false);

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const DashboardPage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF020C18),
      body: Stack(children: [
        // 背景網格
        Positioned.fill(child: CustomPaint(painter: _GridBgPainter())),
        // 右上光暈
        Positioned(
          top: -200, right: -150,
          child: Container(
            width: 500, height: 500,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                const Color(0xFF00D09C).withOpacity(.12),
                Colors.transparent,
              ]),
            ),
          ),
        ),
        // 左下光暈
        Positioned(
          bottom: -150, left: -100,
          child: Container(
            width: 400, height: 400,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                const Color(0xFF1A6EFF).withOpacity(.12),
                Colors.transparent,
              ]),
            ),
          ),
        ),
        SafeArea(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: _buildCard(),
              ),
            ),
          ),
        ),
      ]),
    );
  }

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
            color: const Color(0xFF00D09C).withOpacity(.08),
            blurRadius: 40,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // 圖示
        Container(
          width: 72, height: 72,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [Color(0xFF00D09C), Color(0xFF00C8FF)]),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                  color: const Color(0xFF00D09C).withOpacity(.3),
                  blurRadius: 20,
                  spreadRadius: 2)
            ],
          ),
          child: const Icon(Icons.person_add_alt_1_rounded,
              size: 36, color: Colors.white),
        ),
        const SizedBox(height: 20),
        const Text('建立管理員帳號',
            style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white)),
        const SizedBox(height: 8),
        const Text('請輸入手機號碼與密碼完成註冊',
            style: TextStyle(fontSize: 13, color: Color(0xFF3E5872))),
        const SizedBox(height: 30),

        // 手機號碼
        _inputField(
          controller: _phoneController,
          hint: '請輸入手機號碼',
          icon: Icons.phone_rounded,
          keyboardType: TextInputType.phone,
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
              _obscurePassword
                  ? Icons.visibility_off_rounded
                  : Icons.visibility_rounded,
              color: const Color(0xFF3E5872), size: 18,
            ),
            onPressed: () =>
                setState(() => _obscurePassword = !_obscurePassword),
          ),
        ),
        const SizedBox(height: 16),

        // 確認密碼
        _inputField(
          controller: _confirmController,
          hint: '請再次輸入密碼',
          icon: Icons.verified_user_rounded,
          obscure: _obscureConfirm,
          suffixIcon: IconButton(
            icon: Icon(
              _obscureConfirm
                  ? Icons.visibility_off_rounded
                  : Icons.visibility_rounded,
              color: const Color(0xFF3E5872), size: 18,
            ),
            onPressed: () =>
                setState(() => _obscureConfirm = !_obscureConfirm),
          ),
        ),
        const SizedBox(height: 28),

        // 註冊按鈕
        SizedBox(
          width: double.infinity, height: 54,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _handleRegister,
            style: ElevatedButton.styleFrom(
              elevation: 0,
              backgroundColor: const Color(0xFF00D09C),
              foregroundColor: Colors.white,
              disabledBackgroundColor:
                  const Color(0xFF00D09C).withOpacity(.5),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 22, height: 22,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : const Text('完成註冊',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: .5)),
          ),
        ),
        const SizedBox(height: 14),

        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('已經有帳號？返回登入',
              style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF00C8FF),
                  fontWeight: FontWeight.w600)),
        ),
        const SizedBox(height: 12),

        // 提示
        Container(
          width: double.infinity,
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF0A2035),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF0E2A40)),
          ),
          child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.shield_outlined,
                    size: 15, color: Color(0xFF3E5872)),
                SizedBox(width: 8),
                Text('測試模式：帳號密碼儲存於本機',
                    style: TextStyle(
                        color: Color(0xFF3E5872), fontSize: 12)),
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
    TextInputType? keyboardType,
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
        keyboardType: keyboardType,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle:
              const TextStyle(color: Color(0xFF3E5872), fontSize: 14),
          prefixIcon:
              Icon(icon, color: const Color(0xFF3E5872), size: 18),
          suffixIcon: suffixIcon,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }
}

class _GridBgPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = const Color(0xFF00C8FF).withOpacity(.03)
      ..strokeWidth = .5;
    for (double x = 0; x < size.width; x += 40) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    }
    for (double y = 0; y < size.height; y += 40) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}