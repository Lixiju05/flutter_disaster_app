import 'package:flutter/material.dart';
import 'dashboard_page.dart';
import 'supply_page.dart';
import 'emergency_page.dart';

class CitizenPage extends StatelessWidget {
  const CitizenPage({super.key});

  @override
  Widget build(BuildContext context) {
    final List<Map<String, String>> citizens = [
      {"name": "王小明", "status": "已安置", "shelter": "台北避难所"},
      {"name": "陈美华", "status": "待安排", "shelter": "新北避难所"},
      {"name": "李大同", "status": "处理中", "shelter": "台中避难所"},
      {"name": "林雅婷", "status": "已安置", "shelter": "高雄避难所"},
    ];

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
                  '防灾后台系统',
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
                        builder: (context) => const DashboardPage(),
                      ),
                    );
                  },
                ),

                Container(
                  color: Colors.white24,
                  child: ListTile(
                    leading: const Icon(Icons.people, color: Colors.white),
                    title: const Text(
                      '灾民管理',
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
                ),

                ListTile(
                  leading: const Icon(Icons.inventory, color: Colors.white),
                  title: const Text(
                    '物资管理',
                    style: TextStyle(color: Colors.white),
                  ),
                  onTap: () {},
                ),

                ListTile(
                  leading: const Icon(Icons.warning, color: Colors.white),
                  title: const Text(
                    '紧急事件',
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

          Expanded(
            child: Container(
              color: const Color(0xFFF5F7FA),
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '灾民管理',
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
                            hintText: '请输入姓名搜索',
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
                        label: const Text('新增灾民'),
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
                                    '姓名',
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    '状态',
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ),
                                Expanded(
                                  flex: 3,
                                  child: Text(
                                    '避难所',
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
                              itemCount: citizens.length,
                              separatorBuilder: (_, __) => const Divider(),
                              itemBuilder: (context, index) {
                                final citizen = citizens[index];
                                return Row(
                                  children: [
                                    Expanded(
                                      flex: 2,
                                      child: Text(citizen["name"]!),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text(citizen["status"]!),
                                    ),
                                    Expanded(
                                      flex: 3,
                                      child: Text(citizen["shelter"]!),
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