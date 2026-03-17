import 'package:flutter/material.dart';
import '../../core/repositories/admin_repository.dart';
import 'citizen_page.dart';
import 'emergency_page.dart';
import 'supply_page.dart';

class DashboardPage extends StatelessWidget {
  DashboardPage({super.key});

  final AdminRepository repository = AdminRepository();

  @override
  Widget build(BuildContext context) {
    final citizens = repository.getCitizens();
    final emergencies = repository.getEmergencies();
final supplies = repository.getAdminSupplies();

    final rescuedCount = citizens.where((c) => c.isRescued).length;
    final waitingRescueCount = citizens.where((c) => !c.isRescued).length;
    final emergencyCount = emergencies.length;
    final supplyCount = supplies.length;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF1E3A5F),
        title: const Text(
          '管理員儀表板',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            _buildWelcomeBanner(),

            const SizedBox(height: 20),

            const Text(
              '系統統計',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E3A5F),
              ),
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    '等待救援',
                    waitingRescueCount.toString(),
                    Icons.warning_amber_rounded,
                    Colors.orange,
                  ),
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: _buildStatCard(
                    '已救援',
                    rescuedCount.toString(),
                    Icons.check_circle,
                    Colors.green,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    '緊急事件',
                    emergencyCount.toString(),
                    Icons.campaign,
                    Colors.redAccent,
                  ),
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: _buildStatCard(
                    '物資項目',
                    supplyCount.toString(),
                    Icons.inventory_2,
                    Colors.blue,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            const Text(
              '功能專區',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E3A5F),
              ),
            ),

            const SizedBox(height: 12),

            _buildMenuCard(
              context,
              title: '民眾管理',
              subtitle: '查看民眾位置、狀態與救援資料',
              icon: Icons.people_alt_rounded,
              color: const Color(0xFF4A90E2),
              page: const CitizenPage(),
            ),

            const SizedBox(height: 12),

            _buildMenuCard(
              context,
              title: '緊急事件管理',
              subtitle: '查看目前災情與緊急通報',
              icon: Icons.report_problem_rounded,
              color: const Color(0xFFE76F51),
              page: const EmergencyPage(),
            ),

            const SizedBox(height: 12),

            _buildMenuCard(
              context,
              title: '物資管理',
              subtitle: '查看與管理目前救災物資',
              icon: Icons.local_shipping_rounded,
              color: const Color(0xFF2A9D8F),
              page: const SupplyPage(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E3A5F), Color(0xFF4A90E2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),

        borderRadius: BorderRadius.circular(20),

        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.18),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),

      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          Text(
            '歡迎回來，管理員',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),

          SizedBox(height: 8),

          Text(
            '這裡可以快速查看災情資訊、救援進度與物資狀況。',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color iconColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),

      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),

        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),

      child: Row(
        children: [

          CircleAvatar(
            radius: 24,
            backgroundColor: iconColor.withOpacity(0.12),
            child: Icon(icon, color: iconColor, size: 26),
          ),

          const SizedBox(width: 14),

          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              Text(
                title,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),

              const SizedBox(height: 6),

              Text(
                value,
                style: const TextStyle(
                  fontSize: 24,
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

  Widget _buildMenuCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required Widget page,
  }) {

    return InkWell(
      borderRadius: BorderRadius.circular(18),

      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => page),
        );
      },

      child: Container(
        padding: const EdgeInsets.all(18),

        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),

          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),

        child: Row(
          children: [

            CircleAvatar(
              radius: 26,
              backgroundColor: color.withOpacity(0.12),
              child: Icon(icon, color: color, size: 28),
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
                      color: Color(0xFF1E3A5F),
                    ),
                  ),

                  const SizedBox(height: 6),

                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),

            const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 18,
              color: Colors.grey,
            ),
          ],
        ),
      ),
    );
  }
}