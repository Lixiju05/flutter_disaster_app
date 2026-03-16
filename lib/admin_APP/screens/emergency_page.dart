import 'package:flutter/material.dart';
import 'package:flutter_disaster_app/core/models/emergency_request.dart';
import 'package:flutter_disaster_app/core/repositories/admin_repository.dart';

import 'dashboard_page.dart';
import 'citizen_page.dart';
import 'supply_page.dart';

class EmergencyPage extends StatelessWidget {
  EmergencyPage({super.key});

  final AdminRepository repo = AdminRepository();

  @override
  Widget build(BuildContext context) {
    final List<EmergencyRequest> emergencies = repo.getEmergencies();

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
                  '防災後台系統',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 40),

                ListTile(
                  leading: const Icon(Icons.dashboard, color: Colors.white),
                  title: const Text(
                    'Dashboard',
                    style: TextStyle(color: Colors.white),
                  ),
                  onTap: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => DashboardPage(),
                      ),
                    );
                  },
                ),

                ListTile(
                  leading: const Icon(Icons.people, color: Colors.white),
                  title: const Text(
                    '災民管理',
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
                    '物資管理',
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

                Container(
                  color: Colors.white24,
                  child: ListTile(
                    leading: const Icon(Icons.warning, color: Colors.white),
                    title: const Text(
                      '緊急事件',
                      style: TextStyle(color: Colors.white),
                    ),
                    onTap: () {},
                  ),
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
                    '緊急事件管理',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),

                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          decoration: InputDecoration(
                            hintText: '請輸入事件類型搜尋',
                            prefixIcon: const Icon(Icons.search),
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.add_alert),
                        label: const Text('新增事件'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 18,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
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
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: const Row(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    '事件 ID',
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    '災民 ID',
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    '類型',
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ),
                                Expanded(
                                  flex: 3,
                                  child: Text(
                                    '座標',
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ),
                                Expanded(
                                  flex: 3,
                                  child: Text(
                                    '建立時間',
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    '操作',
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Divider(),
                          Expanded(
                            child: ListView.separated(
                              itemCount: emergencies.length,
                              separatorBuilder: (_, __) => const Divider(),
                              itemBuilder: (context, index) {
                                final event = emergencies[index];

                                return Row(
                                  children: [
                                    Expanded(
                                      flex: 2,
                                      child: Text(event.id),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text(event.citizenId),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: _buildTypeChip(event.type),
                                    ),
                                    Expanded(
                                      flex: 3,
                                      child: Text(
                                        '${event.latitude}, ${event.longitude}',
                                      ),
                                    ),
                                    Expanded(
                                      flex: 3,
                                      child: Text(
                                        event.createdAt.toString(),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Row(
                                        children: [
                                          IconButton(
                                            onPressed: () {},
                                            icon: const Icon(Icons.visibility),
                                          ),
                                          IconButton(
                                            onPressed: () {},
                                            icon: const Icon(Icons.edit),
                                          ),
                                          IconButton(
                                            onPressed: () {},
                                            icon: const Icon(Icons.delete),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ],
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

  Widget _buildTypeChip(String type) {
    Color bgColor;
    Color textColor;

    if (type.toLowerCase() == 'sos') {
      bgColor = Colors.red.shade100;
      textColor = Colors.red.shade800;
    } else {
      bgColor = Colors.blue.shade100;
      textColor = Colors.blue.shade800;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        type,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}