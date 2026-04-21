import 'package:flutter/material.dart';
import 'package:flutter_disaster_app/core/repositories/admin_repository.dart';
import 'package:flutter_disaster_app/core/models/supply.dart';

import 'dashboard_page.dart';
import 'user_management_page.dart';
import 'emergency_page.dart';
import 'health_report_page.dart';

class SupplyPage extends StatefulWidget {
  const SupplyPage({super.key});

  @override
  State<SupplyPage> createState() => _SupplyPageState();
}

class _SupplyPageState extends State<SupplyPage> {
  final AdminRepository repo = AdminRepository();
  final TextEditingController _searchController = TextEditingController();

  static const Color primaryBlue = Color(0xFF183A61);
  static const Color accentBlue = Color(0xFF4A90E2);
  static const Color pageBg = Color(0xFFF4F7FB);
  static const Color cardBg = Colors.white;
  static const Color titleColor = Color(0xFF183153);
  static const Color textSoft = Color(0xFF6B7A90);
  static const Color borderColor = Color(0xFFE6ECF3);

  late List<AdminSupply> _allSupplies;
  late List<AdminSupply> _filteredSupplies;

  String _selectedCategory = '全部';

  @override
  void initState() {
    super.initState();
    _allSupplies = List.from(repo.getAdminSupplies());
    _filteredSupplies = List.from(_allSupplies);
  }

  List<String> get categories {
    final names = _allSupplies.map((e) => e.itemName).toSet().toList();
    names.sort();
    return ['全部', ...names];
  }

  void _applyFilters() {
    final keyword = _searchController.text.trim().toLowerCase();

    setState(() {
      _filteredSupplies = _allSupplies.where((supply) {
        final matchKeyword =
            supply.itemName.toLowerCase().contains(keyword);

        final matchCategory = _selectedCategory == '全部'
            ? true
            : supply.itemName == _selectedCategory;

        return matchKeyword && matchCategory;
      }).toList();
    });
  }

  void _searchSupply(String keyword) {
    _applyFilters();
  }

  int get totalItemKinds => _allSupplies.length;

  int get totalQuantity => _allSupplies.fold(
        0,
        (sum, item) => sum + item.totalQuantity,
      );

  int get lowStockCount =>
      _allSupplies.where((item) => item.totalQuantity <= 10).length;

  void _addSupply(String name, int quantity) {
    setState(() {
      _allSupplies.add(
        AdminSupply(
          itemName: name,
          totalQuantity: quantity,
        ),
      );
    });
    _applyFilters();
  }

  void _editSupply(AdminSupply oldSupply, String newName, int newQuantity) {
    final index = _allSupplies.indexOf(oldSupply);
    if (index == -1) return;

    setState(() {
      _allSupplies[index] = AdminSupply(
        itemName: newName,
        totalQuantity: newQuantity,
      );
    });

    if (_selectedCategory != '全部' &&
        !categories.contains(_selectedCategory)) {
      _selectedCategory = '全部';
    }

    _applyFilters();
  }

  void _deleteSupply(AdminSupply supply) {
    setState(() {
      _allSupplies.remove(supply);
    });

    if (_selectedCategory != '全部' &&
        !categories.contains(_selectedCategory)) {
      _selectedCategory = '全部';
    }

    _applyFilters();
  }

  Future<void> _showAddDialog() async {
    final nameController = TextEditingController();
    final quantityController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: const Text('新增物資'),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: '物資名稱',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: quantityController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: '數量',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () {
                final name = nameController.text.trim();
                final quantity =
                    int.tryParse(quantityController.text.trim()) ?? 0;

                if (name.isEmpty) return;

                _addSupply(name, quantity);
                Navigator.pop(context);
              },
              child: const Text('新增'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showEditDialog(AdminSupply supply) async {
    final nameController = TextEditingController(text: supply.itemName);
    final quantityController =
        TextEditingController(text: supply.totalQuantity.toString());

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: const Text('編輯物資'),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: '物資名稱',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: quantityController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: '數量',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () {
                final name = nameController.text.trim();
                final quantity =
                    int.tryParse(quantityController.text.trim()) ?? 0;

                if (name.isEmpty) return;

                _editSupply(supply, name, quantity);
                Navigator.pop(context);
              },
              child: const Text('儲存'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showDeleteDialog(AdminSupply supply) async {
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: const Text('刪除物資'),
          content: Text('確定要刪除「${supply.itemName}」嗎？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                _deleteSupply(supply);
                Navigator.pop(context);
              },
              child: const Text('刪除'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: pageBg,
      body: Row(
        children: [
          _buildSidebar(context),
          Expanded(
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTopBar(),
                    const SizedBox(height: 22),
                    _buildHeaderBanner(),
                    const SizedBox(height: 20),
                    _buildSummaryCards(),
                    const SizedBox(height: 20),
                    _buildSearchAndActionBar(),
                    const SizedBox(height: 16),
                    _buildCategoryChips(),
                    const SizedBox(height: 20),
                    Expanded(
                      child: _buildSupplyTableCard(),
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
      width: 248,
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
            padding: const EdgeInsets.fromLTRB(20, 26, 20, 22),
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
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.admin_panel_settings_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    '防災後台系統',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _buildSidebarItem(
            icon: Icons.dashboard_rounded,
            title: 'Dashboard',
            onTap: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const DashboardPage()),
              );
            },
          ),
          _buildSidebarItem(
            icon: Icons.people_alt_rounded,
            title: '用戶管理',
            onTap: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => const UserManagementPage(),
                ),
              );
            },
          ),
          _buildSidebarItem(
            icon: Icons.inventory_2_rounded,
            title: '物資管理',
            selected: true,
            onTap: () {},
          ),
          _buildSidebarItem(
            icon: Icons.warning_amber_rounded,
            title: '緊急事件',
            onTap: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const EmergencyPage()),
              );
            },
          ),
          _buildSidebarItem(
            icon: Icons.health_and_safety_rounded,
            title: '健康回報',
            onTap: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const HealthReportPage()),
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
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.inventory_2_rounded,
                    color: Colors.white70,
                    size: 18,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '物資庫存需持續盤點更新',
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
    required VoidCallback onTap,
    bool selected = false,
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
                Icon(icon, color: Colors.white, size: 22),
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

  Widget _buildTopBar() {
    return Container(
      height: 72,
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
      child: const Row(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '物資管理',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: titleColor,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Supply Inventory Control Center',
                  style: TextStyle(
                    fontSize: 13,
                    color: textSoft,
                  ),
                ),
              ],
            ),
          ),
          CircleAvatar(
            radius: 20,
            backgroundColor: Color(0xFFEAF2FF),
            child: Icon(
              Icons.inventory_2_rounded,
              color: accentBlue,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF0F4C5C),
            Color(0xFF1C7C8C),
            Color(0xFF4FB3BF),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1C7C8C).withOpacity(0.18),
            blurRadius: 24,
            offset: const Offset(0, 10),
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
                  '即時掌握物資庫存',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 27,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  '在這裡可以快速查看物資名稱、總數量與庫存狀況，協助管理單位有效調度與補充資源。',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14.5,
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 16),
          CircleAvatar(
            radius: 34,
            backgroundColor: Color.fromRGBO(255, 255, 255, 0.16),
            child: Icon(
              Icons.local_shipping_rounded,
              size: 34,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards() {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () {
              setState(() {
                _selectedCategory = '全部';
              });
              _applyFilters();
            },
            child: _buildMiniStatCard(
              title: '物資種類',
              value: totalItemKinds.toString(),
              icon: Icons.category_rounded,
              iconColor: const Color(0xFF4A90E2),
              iconBg: const Color(0xFFEAF2FF),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildMiniStatCard(
            title: '總庫存量',
            value: totalQuantity.toString(),
            icon: Icons.warehouse_rounded,
            iconColor: const Color(0xFF2E7D32),
            iconBg: const Color(0xFFEAF7EC),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildMiniStatCard(
            title: '低庫存項目',
            value: lowStockCount.toString(),
            icon: Icons.warning_amber_rounded,
            iconColor: const Color(0xFFF59E0B),
            iconBg: const Color(0xFFFFF4E5),
          ),
        ),
      ],
    );
  }

  Widget _buildMiniStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.035),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: iconColor, size: 28),
          ),
          const SizedBox(width: 14),
          Column(
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
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: titleColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndActionBar() {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 58,
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: borderColor),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.025),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              onChanged: _searchSupply,
              decoration: InputDecoration(
                hintText: '請輸入物資名稱搜尋',
                hintStyle: const TextStyle(color: textSoft),
                prefixIcon: const Icon(Icons.search_rounded, color: textSoft),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Container(
          height: 58,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1C7C8C), Color(0xFF4FB3BF)],
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1C7C8C).withOpacity(0.22),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ElevatedButton.icon(
            onPressed: _showAddDialog,
            icon: const Icon(Icons.add_box_rounded, color: Colors.white),
            label: const Text(
              '新增物資',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            style: ElevatedButton.styleFrom(
              elevation: 0,
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              padding: const EdgeInsets.symmetric(horizontal: 22),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryChips() {
    final chips = categories;

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: chips.map((category) {
        final isSelected = _selectedCategory == category;

        return InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () {
            setState(() {
              _selectedCategory = category;
            });
            _applyFilters();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected ? accentBlue : Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isSelected ? accentBlue : borderColor,
              ),
            ),
            child: Text(
              category,
              style: TextStyle(
                color: isSelected ? Colors.white : titleColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSupplyTableCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.035),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFD),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Row(
              children: [
                Expanded(
                  flex: 4,
                  child: Text(
                    '物資名稱',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: titleColor,
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    '總數量',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: titleColor,
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    '庫存狀態',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: titleColor,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    '操作',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: titleColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: _filteredSupplies.isEmpty
                ? const Center(
                    child: Text(
                      '查無符合資料',
                      style: TextStyle(
                        fontSize: 16,
                        color: textSoft,
                      ),
                    ),
                  )
                : ListView.separated(
                    itemCount: _filteredSupplies.length,
                    separatorBuilder: (_, __) => const Divider(
                      height: 1,
                      color: Color(0xFFEDF2F7),
                    ),
                    itemBuilder: (context, index) {
                      final supply = _filteredSupplies[index];
                      final quantity = supply.totalQuantity;

                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 14,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 4,
                              child: Text(
                                supply.itemName,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: titleColor,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: Text(
                                quantity.toString(),
                                style: const TextStyle(
                                  fontSize: 14.5,
                                  color: textSoft,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: _buildStockChip(quantity),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Row(
                                children: [
                                  _buildActionButton(
                                    icon: Icons.edit_rounded,
                                    color: const Color(0xFF4A90E2),
                                    bgColor: const Color(0xFFEAF2FF),
                                    onTap: () => _showEditDialog(supply),
                                  ),
                                  const SizedBox(width: 10),
                                  _buildActionButton(
                                    icon: Icons.delete_rounded,
                                    color: const Color(0xFFE53935),
                                    bgColor: const Color(0xFFFFEBEE),
                                    onTap: () => _showDeleteDialog(supply),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStockChip(int quantity) {
    late final Color bgColor;
    late final Color textColor;
    late final String label;

    if (quantity <= 10) {
      bgColor = const Color(0xFFFFEBEE);
      textColor = const Color(0xFFE53935);
      label = '低庫存';
    } else if (quantity <= 30) {
      bgColor = const Color(0xFFFFF4E5);
      textColor = const Color(0xFFF59E0B);
      label = '需注意';
    } else {
      bgColor = const Color(0xFFEAF7EC);
      textColor = const Color(0xFF43A047);
      label = '庫存充足';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required Color bgColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Ink(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, size: 20, color: color),
      ),
    );
  }
}