import 'package:flutter/material.dart';
import 'package:flutter_disaster_app/core/repositories/admin_repository.dart';
import 'package:flutter_disaster_app/core/models/supply.dart';
import 'package:flutter_disaster_app/core/repositories/admin_extra_repository.dart';
import 'package:flutter_disaster_app/core/models/prepared_supply.dart';

import 'dashboard_page.dart';
import 'citizen_page.dart';
import 'emergency_page.dart';

class SupplyPage extends StatelessWidget {
  SupplyPage({super.key});

  final AdminRepository repo = AdminRepository();
  final AdminExtraRepository extraRepo = AdminExtraRepository();
  

  @override
  Widget build(BuildContext context) {
    final List<AdminSupply> adminSupplies = repo.getAdminSupplies();
    final List<PreparedSupply> preparedSupplies = extraRepo.getPreparedSupplies();

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

                Container(
                  color: Colors.white24,
                  child: ListTile(
                    leading: const Icon(Icons.inventory, color: Colors.white),
                    title: const Text(
                      '物資管理',
                      style: TextStyle(color: Colors.white),
                    ),
                    onTap: () {},
                  ),
                ),

                ListTile(
                  leading: const Icon(Icons.warning, color: Colors.white),
                  title: const Text(
                    '緊急事件',
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
                    '物資管理',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
  '預備物資數量：${preparedSupplies.length}',
  style: const TextStyle(fontSize: 18),
),

                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          decoration: InputDecoration(
                            hintText: '請輸入物資名稱搜尋',
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
                        icon: const Icon(Icons.add),
                        label: const Text('新增物資'),
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
                                  flex: 4,
                                  child: Text(
                                    '物資名稱',
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ),
                                Expanded(
                                  flex: 3,
                                  child: Text(
                                    '總數量',
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
                              itemCount: adminSupplies.length,
                              separatorBuilder: (_, __) => const Divider(),
                              itemBuilder: (context, index) {
                                final supply = adminSupplies[index];
                                return Row(
                                  children: [
                                    Expanded(
                                      flex: 4,
                                      child: Text(supply.itemName),
                                    ),
                                    Expanded(
                                      flex: 3,
                                      child: Text(
                                        supply.totalQuantity.toString(),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Row(
                                        children: [
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
}