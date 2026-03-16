import 'package:flutter/material.dart';
import 'citizen_page.dart';
import 'supply_page.dart';
import 'emergency_page.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [

          // 左侧菜单
          Container(
            width: 220,
            color: const Color(0xFF1E3A5F),
            child: Column(
              children: [
                const SizedBox(height: 40),
                const Text(
                  "防灾后台系统",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 40),

                ListTile(
                  leading: const Icon(Icons.dashboard, color: Colors.white),
                  title: const Text("Dashboard",
                      style: TextStyle(color: Colors.white)),
                  onTap: () {},
                ),

                ListTile(
  leading: const Icon(Icons.people, color: Colors.white),
  title: const Text(
    "灾民管理",
    style: TextStyle(color: Colors.white),
  ),
  onTap: () {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => const CitizenPage(),
      ),
    );
  },
),

               ListTile(
  leading: const Icon(Icons.inventory, color: Colors.white),
  title: const Text(
    "物资管理",
    style: TextStyle(color: Colors.white),
  ),
  onTap: () {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => const SupplyPage(),
      ),
    );
  },
),

               ListTile(
  leading: const Icon(Icons.warning, color: Colors.white),
  title: const Text(
    "紧急事件",
    style: TextStyle(color: Colors.white),
  ),
  onTap: () {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => const EmergencyPage(),
      ),
    );
  },
),
              ],
            ),
          ),

          // 右侧内容
          Expanded(
            child: Container(
              color: const Color(0xFFF5F7FA),
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  const Text(
                    "管理员 Dashboard",
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 20),

                  Row(
                    children: [

                      _buildStatCard("灾民人数", "128", Icons.people),
                      const SizedBox(width: 20),

                      _buildStatCard("物资数量", "560", Icons.inventory),
                      const SizedBox(width: 20),

                      _buildStatCard("紧急事件", "12", Icons.warning),

                    ],
                  ),

                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon) {
    return Expanded(
      child: Container(
        height: 120,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              blurRadius: 6,
              color: Colors.black12,
              offset: Offset(0, 3),
            )
          ],
        ),
        child: Row(
          children: [
            Icon(icon, size: 40),
            const SizedBox(width: 20),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                )
              ],
            )
          ],
        ),
      ),
    );
  }
}