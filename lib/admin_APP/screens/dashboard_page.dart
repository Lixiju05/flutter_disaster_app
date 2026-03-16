import 'package:flutter/material.dart';
import 'package:flutter_disaster_app/core/repositories/admin_repository.dart';

import 'citizen_page.dart';
import 'supply_page.dart';
import 'emergency_page.dart';

class DashboardPage extends StatelessWidget {
  DashboardPage({super.key});

  final AdminRepository repo = AdminRepository();

  @override
  Widget build(BuildContext context) {
    final int citizenCount = repo.getCitizens().length;
    final int supplyCount = repo.getAdminSupplies().length;
    final int emergencyCount = repo.getEmergencies().length;

    return Scaffold(
      body: Row(
        children: [
          Container(
            width: 220,
            color: const Color(0xFF1E3A5F),
            child: Column(
              children: [
                const SizedBox(height: 40),
                const Text(
                  "防災後台系統",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 40),

                Container(
                  color: Colors.white24,
                  child: ListTile(
                    leading: const Icon(Icons.dashboard, color: Colors.white),
                    title: const Text(
                      "Dashboard",
                      style: TextStyle(color: Colors.white),
                    ),
                    onTap: () {},
                  ),
                ),

                ListTile(
                  leading: const Icon(Icons.people, color: Colors.white),
                  title: const Text(
                    "災民管理",
                    style: TextStyle(color: Colors.white),
                  ),
                  onTap: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CitizenPage(),
                      ),
                    );
                  },
                ),

                ListTile(
                  leading: const Icon(Icons.inventory, color: Colors.white),
                  title: const Text(
                    "物資管理",
                    style: TextStyle(color: Colors.white),
                  ),
                  onTap: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SupplyPage(),
                      ),
                    );
                  },
                ),

                ListTile(
                  leading: const Icon(Icons.warning, color: Colors.white),
                  title: const Text(
                    "緊急事件",
                    style: TextStyle(color: Colors.white),
                  ),
                  onTap: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => EmergencyPage(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          Expanded(
            child: Container(
              color: const Color(0xFFF5F7FA),
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "管理員 Dashboard",
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),

                  Row(
                    children: [
                      _buildStatCard(
                        "災民人數",
                        citizenCount.toString(),
                        Icons.people,
                      ),
                      const SizedBox(width: 20),
                      _buildStatCard(
                        "物資種類",
                        supplyCount.toString(),
                        Icons.inventory,
                      ),
                      const SizedBox(width: 20),
                      _buildStatCard(
                        "緊急事件",
                        emergencyCount.toString(),
                        Icons.warning,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
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
            ),
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
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}