import 'package:flutter/material.dart';
import '../../core/repositories/admin_repository.dart';
import '../repositories/healthReport_repository.dart';

import 'citizen_page.dart';
import 'emergency_page.dart';
import 'supply_page.dart';
import 'health_report_page.dart';

class DashboardPage extends StatelessWidget {
  DashboardPage({super.key});

  final AdminRepository repository = AdminRepository();

  static const Color primaryBlue = Color(0xFF183A61);
  static const Color secondaryBlue = Color(0xFF29538A);
  static const Color accentBlue = Color(0xFF4A90E2);
  static const Color pageBg = Color(0xFFF4F7FB);
  static const Color cardBg = Colors.white;
  static const Color titleColor = Color(0xFF183153);
  static const Color textSoft = Color(0xFF6B7A90);
  static const Color borderColor = Color(0xFFE7EDF5);

  @override
  Widget build(BuildContext context) {
    final citizens = repository.getCitizens();
    final emergencies = repository.getEmergencies();
    final supplies = repository.getAdminSupplies();
    final healthReports = HealthReportRepository().getReports();

    // 这里依照你原本的逻辑保留
    final rescuedCount = citizens.where((c) => c.needsRescue).length;
    final waitingRescueCount = citizens.where((c) => !c.needsRescue).length;

    final emergencyCount = emergencies.length;
    final supplyCount = supplies.length;
    final healthReportCount = healthReports.length;

    return Scaffold(
      backgroundColor: pageBg,
      body: Row(
        children: [
          _buildSidebar(context),
          Expanded(
            child: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 22, 24, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTopBar(context),
                    const SizedBox(height: 22),
                    _buildHeroBanner(),
                    const SizedBox(height: 28),

                    _buildSectionHeader(
                      title: '系統總覽',
                      subtitle: '快速掌握目前災情、救援、物資與健康回報狀況',
                    ),
                    const SizedBox(height: 16),

                    LayoutBuilder(
                      builder: (context, constraints) {
                        int crossAxisCount = 4;
                        double ratio = 2.0;

                        if (constraints.maxWidth < 1200) {
                          crossAxisCount = 3;
                          ratio = 1.95;
                        }
                        if (constraints.maxWidth < 900) {
                          crossAxisCount = 2;
                          ratio = 1.85;
                        }

                        return GridView.count(
                          crossAxisCount: crossAxisCount,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: ratio,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          children: [
                            _buildStatCard(
                              title: '等待救援',
                              value: waitingRescueCount.toString(),
                              icon: Icons.warning_amber_rounded,
                              iconColor: const Color(0xFFF59E0B),
                              iconBgColor: const Color(0xFFFFF4E5),
                              note: '需優先關注',
                            ),
                            _buildStatCard(
                              title: '已救援',
                              value: rescuedCount.toString(),
                              icon: Icons.check_circle_rounded,
                              iconColor: const Color(0xFF43A047),
                              iconBgColor: const Color(0xFFEAF7EC),
                              note: '已完成處理',
                            ),
                            _buildStatCard(
                              title: '緊急事件',
                              value: emergencyCount.toString(),
                              icon: Icons.campaign_rounded,
                              iconColor: const Color(0xFFE53935),
                              iconBgColor: const Color(0xFFFFEBEE),
                              note: '持續監控中',
                            ),
                            _buildStatCard(
                              title: '物資項目',
                              value: supplyCount.toString(),
                              icon: Icons.inventory_2_rounded,
                              iconColor: const Color(0xFF1E88E5),
                              iconBgColor: const Color(0xFFEAF2FF),
                              note: '可進行盤點',
                            ),
                          ],
                        );
                      },
                    ),

                    const SizedBox(height: 18),

                    LayoutBuilder(
                      builder: (context, constraints) {
                        if (constraints.maxWidth < 950) {
                          return Column(
                            children: [
                              _buildHealthSummaryCard(healthReportCount),
                              const SizedBox(height: 16),
                              _buildOfflineSupportCard(),
                            ],
                          );
                        }

                        return Row(
                          children: [
                            Expanded(child: _buildHealthSummaryCard(healthReportCount)),
                            const SizedBox(width: 16),
                            Expanded(child: _buildOfflineSupportCard()),
                          ],
                        );
                      },
                    ),

                    const SizedBox(height: 32),

                    _buildSectionHeader(
                      title: '功能專區',
                      subtitle: '點選進入各模組進行管理',
                    ),
                    const SizedBox(height: 16),

                    LayoutBuilder(
                      builder: (context, constraints) {
                        int crossAxisCount = 2;
                        double ratio = 2.45;

                        if (constraints.maxWidth < 980) {
                          crossAxisCount = 1;
                          ratio = 2.8;
                        }

                        return GridView.count(
                          crossAxisCount: crossAxisCount,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: ratio,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          children: [
                            _buildMenuCard(
                              context,
                              title: '民眾管理',
                              subtitle: '查看民眾位置、狀態與救援資料',
                              icon: Icons.people_alt_rounded,
                              color: const Color(0xFF4A90E2),
                              page: CitizenPage(),
                            ),
                            _buildMenuCard(
                              context,
                              title: '緊急事件管理',
                              subtitle: '查看目前災情與緊急通報',
                              icon: Icons.report_problem_rounded,
                              color: const Color(0xFFE76F51),
                              page: EmergencyPage(),
                            ),
                            _buildMenuCard(
                              context,
                              title: '物資管理',
                              subtitle: '查看與管理目前救災物資',
                              icon: Icons.local_shipping_rounded,
                              color: const Color(0xFF2A9D8F),
                              page: SupplyPage(),
                            ),
                            _buildMenuCard(
                              context,
                              title: '健康回報管理',
                              subtitle: '查看民眾健康狀態與回報資料',
                              icon: Icons.health_and_safety_rounded,
                              color: const Color(0xFF009688),
                              page: HealthReportPage(),
                            ),
                          ],
                        );
                      },
                    ),
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
      decoration: BoxDecoration(
        color: primaryBlue,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(4, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 26, 20, 24),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Colors.white.withOpacity(0.08),
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.admin_panel_settings_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Disaster Admin',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '企業管理後台',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _buildSidebarItem(
            icon: Icons.dashboard_rounded,
            title: '儀表板',
            selected: true,
            onTap: () {},
          ),
          _buildSidebarItem(
            icon: Icons.people_alt_rounded,
            title: '民眾管理',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => CitizenPage()),
              );
            },
          ),
          _buildSidebarItem(
            icon: Icons.report_problem_rounded,
            title: '緊急事件',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => EmergencyPage()),
              );
            },
          ),
          _buildSidebarItem(
            icon: Icons.local_shipping_rounded,
            title: '物資管理',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => SupplyPage()),
              );
            },
          ),
          _buildSidebarItem(
            icon: Icons.health_and_safety_rounded,
            title: '健康回報',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => HealthReportPage()),
              );
            },
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: Colors.white.withOpacity(0.08),
                ),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.wifi_off_rounded,
                    color: Colors.white70,
                    size: 20,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '支援離線災情通報與同步',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12.5,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarItem({
    required IconData icon,
    required String title,
    bool selected = false,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: selected ? Colors.white.withOpacity(0.12) : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              border: selected
                  ? Border.all(color: Colors.white.withOpacity(0.08))
                  : null,
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: Colors.white,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.96),
                      fontSize: 14.5,
                      fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Container(
      height: 74,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () {
              Navigator.pop(context);
            },
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: titleColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 6),
          const Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '管理員儀表板',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: titleColor,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Disaster Management Control Center',
                  style: TextStyle(
                    fontSize: 13,
                    color: textSoft,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: const Color(0xFFEAF2FF),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.verified_user_rounded,
                  size: 18,
                  color: accentBlue,
                ),
                SizedBox(width: 8),
                Text(
                  'Admin',
                  style: TextStyle(
                    color: accentBlue,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF183A61),
            Color(0xFF29538A),
            Color(0xFF4A90E2),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: primaryBlue.withOpacity(0.18),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '歡迎回來，管理員',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  '這裡可以快速查看災情資訊、救援進度、健康回報與物資狀況，協助你更有效率地管理防災後台。',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 15,
                    height: 1.7,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Container(
            width: 86,
            height: 86,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.14),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(
              Icons.dashboard_customize_rounded,
              color: Colors.white,
              size: 42,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader({
    required String title,
    required String subtitle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: titleColor,
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
    required Color iconColor,
    required Color iconBgColor,
    required String note,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: iconBgColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13.5,
                    color: textSoft,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: titleColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  note,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: textSoft,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHealthSummaryCard(int healthReportCount) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              color: const Color(0xFFE8F7F5),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.health_and_safety_rounded,
              color: Color(0xFF009688),
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '健康回報概況',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: titleColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '目前共收到 $healthReportCount 筆健康狀態回報，可進一步查看詳細內容與後續追蹤。',
                  style: const TextStyle(
                    fontSize: 14,
                    color: textSoft,
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOfflineSupportCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFFEEF4FF),
            Color(0xFFF8FBFF),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFDCE8FF)),
      ),
      child: const Row(
        children: [
          Icon(
            Icons.wifi_off_rounded,
            color: titleColor,
            size: 32,
          ),
          SizedBox(width: 16),
          Expanded(
            child: Text(
              '系統支援離線情境下的災情通報與資料同步管理，確保災難發生時仍能持續運作。',
              style: TextStyle(
                fontSize: 14,
                color: titleColor,
                height: 1.6,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required Widget page,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => page),
          );
        },
        child: Ink(
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: borderColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            child: Row(
              children: [
                Container(
                  width: 62,
                  height: 62,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: titleColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 14,
                          color: textSoft,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 18,
                  color: Colors.black38,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}