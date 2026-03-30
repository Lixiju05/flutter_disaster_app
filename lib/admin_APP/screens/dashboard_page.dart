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

  @override
  Widget build(BuildContext context) {
    final citizens = repository.getCitizens();
    final emergencies = repository.getEmergencies();
    final supplies = repository.getAdminSupplies();
    final healthReports = HealthReportRepository().getReports();

    final rescuedCount = citizens.where((c) => c.needsRescue).length;
    final waitingRescueCount = citizens.where((c) => !c.needsRescue).length;

    final emergencyCount = emergencies.length;
    final supplyCount = supplies.length;
    final healthReportCount = healthReports.length;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF1E3A5F),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        centerTitle: true,
        title: const Text(
          '管理員儀表板',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.8,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildWelcomeBanner(),
            const SizedBox(height: 28),

            const Text(
              '系統統計',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Color(0xFF183153),
              ),
            ),
            const SizedBox(height: 16),

            GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 2.6,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildStatCard(
                  title: '等待救援',
                  value: waitingRescueCount.toString(),
                  icon: Icons.warning_amber_rounded,
                  iconColor: const Color(0xFFF59E0B),
                  iconBgColor: const Color(0xFFFFF4E5),
                ),
                _buildStatCard(
                  title: '已救援',
                  value: rescuedCount.toString(),
                  icon: Icons.check_circle_rounded,
                  iconColor: const Color(0xFF43A047),
                  iconBgColor: const Color(0xFFEAF7EC),
                ),
                _buildStatCard(
                  title: '緊急事件',
                  value: emergencyCount.toString(),
                  icon: Icons.campaign_rounded,
                  iconColor: const Color(0xFFE53935),
                  iconBgColor: const Color(0xFFFFEBEE),
                ),
                _buildStatCard(
                  title: '物資項目',
                  value: supplyCount.toString(),
                  icon: Icons.inventory_2_rounded,
                  iconColor: const Color(0xFF1E88E5),
                  iconBgColor: const Color(0xFFEAF2FF),
                ),
                _buildStatCard(
                  title: '健康回報',
                  value: healthReportCount.toString(),
                  icon: Icons.health_and_safety_rounded,
                  iconColor: const Color(0xFF009688),
                  iconBgColor: const Color(0xFFE8F7F5),
                ),
                _buildInfoCard(),
              ],
            ),

            const SizedBox(height: 32),

            const Text(
              '功能專區',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Color(0xFF183153),
              ),
            ),
            const SizedBox(height: 16),

            GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 2.1,
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
                  color: Colors.teal,
                  page: HealthReportPage(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 26),
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
            color: const Color(0xFF1E3A5F).withOpacity(0.18),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  '歡迎回來，管理員',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  '這裡可以快速查看災情資訊、救援進度、健康回報與物資狀況，協助你更有效率地管理防災後台。',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                    height: 1.7,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.14),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(
              Icons.admin_panel_settings_rounded,
              color: Colors.white,
              size: 42,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: iconBgColor,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E3A5F),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(18),
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
            color: Color(0xFF1E3A5F),
            size: 30,
          ),
          SizedBox(width: 14),
          Expanded(
            child: Text(
              '系統支援離線情境下的災情通報與資料同步管理。',
              style: TextStyle(
                fontSize: 15,
                color: Color(0xFF1E3A5F),
                height: 1.5,
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
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 18,
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
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E3A5F),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
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