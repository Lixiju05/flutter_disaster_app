import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dashboard_page.dart';

// ── 支援的地區清單 ────────────────────────────────────────
const List<Map<String, String>> kAreaList = [
  {'name': '暨大', 'keywords': '暨大,暨南,埔里,南投'},
  {'name': '埔里鎮', 'keywords': '南投,埔里,國姓,魚池,仁愛,信義,水里,鹿谷'},
  {'name': '南投市', 'keywords': '南投,埔里,國姓,魚池,仁愛,信義,水里,鹿谷'},
  {'name': '台中市', 'keywords': '台中,大甲,豐原,清水,梧棲,沙鹿,大肚,烏日,霧峰,太平,大里'},
  {'name': '台南市', 'keywords': '台南,新化,關廟,歸仁,仁德,永康,善化,麻豆,佳里'},
  {'name': '高雄市', 'keywords': '高雄,鳳山,岡山,旗山,美濃,茄萣,湖內,路竹'},
  {'name': '台北市', 'keywords': '台北,北市,信義,大安,中山,內湖,士林,文山'},
  {'name': '新北市', 'keywords': '新北,板橋,新莊,三重,中和,永和,土城,樹林,淡水'},
  {'name': '桃園市', 'keywords': '桃園,中壢,平鎮,龜山,八德,楊梅,蘆竹'},
  {'name': '新竹市', 'keywords': '新竹,竹北,竹東,關西'},
  {'name': '嘉義市', 'keywords': '嘉義,水上,民雄,太保'},
  {'name': '花蓮縣', 'keywords': '花蓮,秀林,玉里,壽豐,鳳林'},
  {'name': '台東縣', 'keywords': '台東,成功,關山,卑南,鹿野'},
  {'name': '宜蘭縣', 'keywords': '宜蘭,羅東,蘇澳,礁溪,頭城'},
  {'name': '屏東縣', 'keywords': '屏東,潮州,東港,恆春,萬丹'},
  {'name': '彰化縣', 'keywords': '彰化,員林,和美,鹿港,北斗'},
  {'name': '雲林縣', 'keywords': '雲林,斗六,斗南,虎尾,西螺'},
  {'name': '苗栗縣', 'keywords': '苗栗,竹南,頭份,通霄,苑裡'},
];

class AdminSetupPage extends StatefulWidget {
  final bool isEdit; // true = 從側邊欄點編輯進來
  const AdminSetupPage({super.key, this.isEdit = false});

  @override
  State<AdminSetupPage> createState() => _AdminSetupPageState();
}

class _AdminSetupPageState extends State<AdminSetupPage>
    with SingleTickerProviderStateMixin {
  final TextEditingController _nameCtrl  = TextEditingController();
  final TextEditingController _titleCtrl = TextEditingController();

  String _selectedArea = kAreaList[0]['name']!;
  bool   _isLoading    = false;

  late AnimationController _fadeCtrl;
  late Animation<double>   _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
    _loadExisting();
  }

  Future<void> _loadExisting() async {
    if (!widget.isEdit) return;
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _nameCtrl.text  = prefs.getString('adminName')  ?? '';
      _titleCtrl.text = prefs.getString('adminTitle') ?? '';
      _selectedArea   = prefs.getString('adminArea')  ?? kAreaList[0]['name']!;
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _titleCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name  = _nameCtrl.text.trim();
    final title = _titleCtrl.text.trim();

    if (name.isEmpty) {
      _showSnack('請輸入您的姓名', isError: true);
      return;
    }

    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 400));

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('adminName',  name);
    await prefs.setString('adminTitle', title.isEmpty ? '管理員' : title);
    await prefs.setString('adminArea',  _selectedArea);

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (widget.isEdit) {
      _showSnack('設定已更新', isError: false);
      Navigator.pop(context);
    } else {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const DashboardPage()),
        (route) => false,
      );
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
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF020C18),
      body: Stack(children: [
        Positioned.fill(child: CustomPaint(painter: _SetupGridPainter())),
        Positioned(top: -180, left: -120,
          child: Container(width: 500, height: 500,
            decoration: BoxDecoration(shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                const Color(0xFF1A6EFF).withOpacity(.15), Colors.transparent,
              ]),
            ),
          ),
        ),
        Positioned(bottom: -150, right: -100,
          child: Container(width: 400, height: 400,
            decoration: BoxDecoration(shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                const Color(0xFF00C8FF).withOpacity(.10), Colors.transparent,
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
      width: 500,
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
          child: const Icon(Icons.manage_accounts_rounded,
              size: 36, color: Colors.white),
        ),
        const SizedBox(height: 20),
        Text(widget.isEdit ? '編輯管理員資訊' : '設定管理員資訊',
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold,
                color: Colors.white)),
        const SizedBox(height: 8),
        Text(widget.isEdit ? '更新您的姓名、職稱與管轄地區' : '請填寫您的資訊，完成後進入系統',
            style: const TextStyle(fontSize: 13, color: Color(0xFF3E5872))),
        const SizedBox(height: 32),

        // 姓名
        _sectionLabel('姓名', Icons.person_rounded),
        const SizedBox(height: 8),
        _inputField(controller: _nameCtrl, hint: '請輸入您的姓名（例：陳志明）',
            icon: Icons.person_rounded),
        const SizedBox(height: 20),

        // 職稱
        _sectionLabel('職稱', Icons.badge_rounded),
        const SizedBox(height: 8),
        _inputField(controller: _titleCtrl, hint: '請輸入職稱（例：鎮長、消防局長）',
            icon: Icons.badge_rounded),
        const SizedBox(height: 20),

        // 管轄地區
        _sectionLabel('管轄地區', Icons.location_on_rounded),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0A2035),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF1A4A6E)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              dropdownColor: const Color(0xFF071828),
              value: _selectedArea,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              icon: const Icon(Icons.keyboard_arrow_down_rounded,
                  color: Color(0xFF3E5872)),
              items: kAreaList.map((area) => DropdownMenuItem(
                value: area['name'],
                child: Row(children: [
                  const Icon(Icons.location_on_outlined,
                      color: Color(0xFF00C8FF), size: 16),
                  const SizedBox(width: 8),
                  Text(area['name']!),
                ]),
              )).toList(),
              onChanged: (v) => setState(() => _selectedArea = v!),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF00C8FF).withOpacity(.05),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF00C8FF).withOpacity(.15)),
          ),
          child: const Row(children: [
            Icon(Icons.info_outline_rounded,
                color: Color(0xFF00C8FF), size: 14),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                '戰術地圖將優先顯示您管轄地區的災害警報',
                style: TextStyle(color: Color(0xFF00C8FF), fontSize: 12),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 28),

        // 確認按鈕
        SizedBox(
          width: double.infinity, height: 54,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _save,
            style: ElevatedButton.styleFrom(
              elevation: 0,
              backgroundColor: const Color(0xFF1A6EFF),
              foregroundColor: Colors.white,
              disabledBackgroundColor: const Color(0xFF1A6EFF).withOpacity(.4),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: _isLoading
                ? const SizedBox(width: 22, height: 22,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : Text(widget.isEdit ? '儲存變更' : '完成設定，進入系統',
                    style: const TextStyle(fontSize: 16,
                        fontWeight: FontWeight.w700, letterSpacing: .5)),
          ),
        ),

        if (widget.isEdit) ...[
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消',
                style: TextStyle(fontSize: 14, color: Color(0xFF3E5872))),
          ),
        ],
      ]),
    );
  }

  Widget _sectionLabel(String label, IconData icon) {
    return Row(children: [
      Icon(icon, color: const Color(0xFF00C8FF), size: 14),
      const SizedBox(width: 6),
      Text(label, style: const TextStyle(
          color: Color(0xFF00C8FF), fontSize: 13, fontWeight: FontWeight.bold)),
    ]);
  }

  Widget _inputField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0A2035),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1A4A6E)),
      ),
      child: TextField(
        controller: controller,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Color(0xFF3E5872), fontSize: 13),
          prefixIcon: Icon(icon, color: const Color(0xFF3E5872), size: 18),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }
}

class _SetupGridPainter extends CustomPainter {
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
  @override bool shouldRepaint(covariant CustomPainter _) => false;
}