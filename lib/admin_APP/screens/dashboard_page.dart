import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../core/repositories/admin_repository.dart';
import 'emergency_page.dart';
import 'supply_page.dart';
import 'health_report_page.dart';
import 'login_page.dart';
import 'user_management_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final AdminRepository repository = AdminRepository();

  static const String _baseUrl = 'http://localhost:8080';

  static const Color primaryBlue = Color(0xFF183B6B);
  static const Color sidebarBlue = Color(0xFF163A63);
  static const Color pageBg = Color(0xFFF3F6FB);
  static const Color cardBg = Colors.white;
  static const Color textDark = Color(0xFF1F2937);
  static const Color textSoft = Color(0xFF6B7280);
  static const Color borderColor = Color(0xFFE5E7EB);

  int userCount = 0;
  int healthReportCount = 0;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDashboardCounts();
  }

  Future<void> _loadDashboardCounts() async {
    setState(() {
      isLoading = true;
    });

    try {
      final usersResponse = await http.post(
        Uri.parse(_baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'type': 'getAllUsers',
        }),
      );

      final reportsResponse = await http.post(
        Uri.parse(_baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'type': 'getAllReports',
        }),
      );

      final usersData = jsonDecode(usersResponse.body);
      final reportsData = jsonDecode(reportsResponse.body);

      setState(() {
        userCount = (usersData['success'] == true)
            ? (usersData['data'] as List).length
            : 0;
        healthReportCount = (reportsData['success'] == true)
            ? (reportsData['data'] as List).length
            : 0;
      });
    } catch (e) {
      debugPrint('Dashboard load error: $e');
    }

    setState(() {
      isLoading = false;
    });
  }

  void _logout(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text('確認登出'),
          content: const Text('確定要登出系統嗎？'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const LoginPage(),
                  ),
                  (route) => false,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
              ),
              child: const Text('登出'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final emergencies = repository.getEmergencies();
    final supplies = repository.getAdminSupplies();

    final emergencyCount = emergencies.length;
    final supplyCount = supplies.length;

    return Scaffold(
      backgroundColor: pageBg,
      body: Row(
        children: [
          _buildSidebar(context),
          Expanded(
            child: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(28, 24, 28, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTopBar(),
                    const SizedBox(height: 24),
                    _buildHeroSection(),
                    const SizedBox(height: 28),
                    _buildSectionTitle(
                      title: '系統總覽',
                      subtitle: '即時查看目前後台的重要統計資訊',
                    ),
                    const SizedBox(height: 18),
                    if (isLoading)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    else
                      Wrap(
                        spacing: 18,
                        runSpacing: 18,
                        children: [
                          _buildStatCard(
                            title: '用戶總數',
                            value: '$userCount',
                            icon: Icons.people_alt_rounded,
                            iconBg: const Color(0xFFE0F2FE),
                            iconColor: const Color(0xFF0284C7),
                          ),
                          _buildStatCard(
                            title: '緊急事件',
                            value: '$emergencyCount',
                            icon: Icons.warning_amber_rounded,
                            iconBg: const Color(0xFFFEF3C7),
                            iconColor: const Color(0xFFD97706),
                          ),
                          _buildStatCard(
                            title: '物資項目',
                            value: '$supplyCount',
                            icon: Icons.inventory_2_rounded,
                            iconBg: const Color(0xFFEDE9FE),
                            iconColor: const Color(0xFF7C3AED),
                          ),
                          _buildStatCard(
                            title: '健康回報',
                            value: '$healthReportCount',
                            icon: Icons.favorite_rounded,
                            iconBg: const Color(0xFFFCE7F3),
                            iconColor: const Color(0xFFDB2777),
                          ),
                        ],
                      ),
                    const SizedBox(height: 30),
                    _buildQuickAccess(context),
                    const SizedBox(height: 30),
                    _buildSystemStatusOnly(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar(BuildContext context) {
    return Container(
      width: 250,
      color: sidebarBlue,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 30),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 22),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: Colors.white24,
                  child: Icon(
                    Icons.admin_panel_settings_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '災難管理系統',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 34),
          _buildSidebarItem(
            icon: Icons.dashboard_rounded,
            title: '儀表板',
            selected: true,
            onTap: () {},
          ),
          _buildSidebarItem(
            icon: Icons.people_alt_rounded,
            title: '用戶管理',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const UserManagementPage(),
                ),
              );
            },
          ),
          _buildSidebarItem(
            icon: Icons.warning_amber_rounded,
            title: '緊急事件',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => EmergencyPage()),
              );
            },
          ),
          _buildSidebarItem(
            icon: Icons.inventory_2_rounded,
            title: '物資管理',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => SupplyPage()),
              );
            },
          ),
          _buildSidebarItem(
            icon: Icons.favorite_rounded,
            title: '健康回報',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const HealthReportPage(),
                ),
              );
            },
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: const Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: Colors.white24,
                        child: Icon(Icons.person, color: Colors.white),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '管理員模式',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () {
                    _logout(context);
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.redAccent.withOpacity(0.3),
                      ),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.logout, color: Colors.redAccent),
                        SizedBox(width: 10),
                        Text(
                          '登出系統',
                          style: TextStyle(
                            color: Colors.redAccent,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool selected = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: Material(
        color: selected ? Colors.white.withOpacity(0.14) : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: Colors.white,
                  size: 24,
                ),
                const SizedBox(width: 14),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Row(
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '管理員儀表板',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  color: textDark,
                ),
              ),
              SizedBox(height: 6),
              Text(
                '歡迎回來，這裡可以快速查看整體災難系統的營運狀態。',
                style: TextStyle(
                  fontSize: 15,
                  color: textSoft,
                ),
              ),
            ],
          ),
        ),
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: borderColor),
            boxShadow: const [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 10,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: const Icon(
            Icons.person,
            color: primaryBlue,
          ),
        ),
      ],
    );
  }

  Widget _buildHeroSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF183B6B),
            Color(0xFF28599A),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: const Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '災難管理總覽中心',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  '集中掌握用戶、緊急事件、物資與健康回報資訊，提升管理效率與決策速度。',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 15,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 20),
          CircleAvatar(
            radius: 36,
            backgroundColor: Colors.white24,
            child: Icon(
              Icons.analytics_rounded,
              size: 34,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle({
    required String title,
    required String subtitle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: textDark,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: const TextStyle(
            fontSize: 14,
            color: textSoft,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
  }) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: iconBg,
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(height: 18),
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              color: textSoft,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: textDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAccess(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(
          title: '快速入口',
          subtitle: '快速前往主要管理模組',
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 18,
          runSpacing: 18,
          children: [
            _buildQuickCard(
              title: '用戶管理',
              subtitle: '查詢姓名、電話、區域與詳細資料',
              icon: Icons.people_alt_rounded,
              color: const Color(0xFF0284C7),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const UserManagementPage(),
                  ),
                );
              },
            ),
            _buildQuickCard(
              title: '健康回報',
              subtitle: '查看健康狀況、內容與地圖位置',
              icon: Icons.favorite_rounded,
              color: const Color(0xFFDB2777),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const HealthReportPage(),
                  ),
                );
              },
            ),
            _buildQuickCard(
              title: '物資管理',
              subtitle: '查看並管理目前物資項目',
              icon: Icons.inventory_2_rounded,
              color: const Color(0xFF7C3AED),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => SupplyPage()),
                );
              },
            ),
            _buildQuickCard(
              title: '緊急事件',
              subtitle: '查看系統中的緊急事件清單',
              icon: Icons.warning_amber_rounded,
              color: const Color(0xFFD97706),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => EmergencyPage()),
                );
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        width: 280,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: color.withOpacity(0.12),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: textDark,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 13,
                      color: textSoft,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSystemStatusOnly() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        width: 420,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(22),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '系統狀態',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 14),
            Text(
              '目前後台系統運作正常，各模組可持續進行查看與管理。',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
                height: 1.6,
              ),
            ),
            SizedBox(height: 22),
            Row(
              children: [
                CircleAvatar(
                  radius: 7,
                  backgroundColor: Colors.greenAccent,
                ),
                SizedBox(width: 10),
                Text(
                  '系統連線正常',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}