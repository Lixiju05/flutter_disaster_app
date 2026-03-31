import 'package:flutter/material.dart';
import 'package:flutter_disaster_app/core/models/citizen.dart';
import 'package:flutter_disaster_app/core/repositories/admin_repository.dart';

import 'dashboard_page.dart';
import 'supply_page.dart';
import 'emergency_page.dart';
import 'health_report_page.dart';

class CitizenPage extends StatefulWidget {
  const CitizenPage({super.key});

  @override
  State<CitizenPage> createState() => _CitizenPageState();
}

class _CitizenPageState extends State<CitizenPage> {
  final AdminRepository repo = AdminRepository();
  final TextEditingController _searchController = TextEditingController();

  static const Color primaryBlue = Color(0xFF183A61);
  static const Color accentBlue = Color(0xFF4A90E2);
  static const Color pageBg = Color(0xFFF4F7FB);
  static const Color cardBg = Colors.white;
  static const Color titleColor = Color(0xFF183153);
  static const Color textSoft = Color(0xFF6B7A90);
  static const Color borderColor = Color(0xFFE6ECF3);

  late List<Citizen> _allCitizens;
  late List<Citizen> _filteredCitizens;

  @override
  void initState() {
    super.initState();
    _allCitizens = repo.getCitizens();
    _filteredCitizens = List.from(_allCitizens);
  }

  void _searchCitizen(String keyword) {
    setState(() {
      _filteredCitizens = _allCitizens.where((citizen) {
        return citizen.name.toLowerCase().contains(keyword.toLowerCase()) ||
            citizen.id.toLowerCase().contains(keyword.toLowerCase());
      }).toList();
    });
  }

  int get totalCount => _allCitizens.length;
  int get needRescueCount =>
      _allCitizens.where((c) => c.needsRescue).length;
  int get safeCount =>
      _allCitizens.where((c) => !c.needsRescue).length;

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
                    const SizedBox(height: 20),
                    Expanded(
                      child: _buildCitizenTableCard(),
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
                MaterialPageRoute(builder: (_) => DashboardPage()),
              );
            },
          ),
          _buildSidebarItem(
            icon: Icons.people_alt_rounded,
            title: '災民管理',
            selected: true,
            onTap: () {},
          ),
          _buildSidebarItem(
            icon: Icons.inventory_2_rounded,
            title: '物資管理',
            onTap: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => SupplyPage()),
              );
            },
          ),
          _buildSidebarItem(
            icon: Icons.warning_amber_rounded,
            title: '緊急事件',
            onTap: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => EmergencyPage()),
              );
            },
          ),
          _buildSidebarItem(
            icon: Icons.health_and_safety_rounded,
            title: '健康回報',
            onTap: () {
              Navigator.pushReplacement(
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
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.wifi_off_rounded,
                    color: Colors.white70,
                    size: 18,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '支援離線災情資料同步',
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
                  '災民管理',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: titleColor,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Citizen Management Center',
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
              Icons.person_rounded,
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
            Color(0xFF183A61),
            Color(0xFF29538A),
            Color(0xFF4A90E2),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: primaryBlue.withOpacity(0.18),
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
                  '即時掌握災民資訊',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 27,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  '在這裡可快速檢視民眾名單、救援狀態與座標位置，方便後續調度與管理。',
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
              Icons.groups_rounded,
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
          child: _buildMiniStatCard(
            title: '總災民數',
            value: totalCount.toString(),
            icon: Icons.people_alt_rounded,
            iconColor: const Color(0xFF4A90E2),
            iconBg: const Color(0xFFEAF2FF),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildMiniStatCard(
            title: '等待救援',
            value: needRescueCount.toString(),
            icon: Icons.warning_amber_rounded,
            iconColor: const Color(0xFFF59E0B),
            iconBg: const Color(0xFFFFF4E5),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildMiniStatCard(
            title: '安全狀態',
            value: safeCount.toString(),
            icon: Icons.check_circle_rounded,
            iconColor: const Color(0xFF43A047),
            iconBg: const Color(0xFFEAF7EC),
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
              onChanged: _searchCitizen,
              decoration: InputDecoration(
                hintText: '請輸入姓名或 ID 搜尋',
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
              colors: [Color(0xFF29538A), Color(0xFF4A90E2)],
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: accentBlue.withOpacity(0.25),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ElevatedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.add_rounded, color: Colors.white),
            label: const Text(
              '新增災民',
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

  Widget _buildCitizenTableCard() {
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
                  flex: 2,
                  child: Text(
                    '姓名',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: titleColor,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'ID',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: titleColor,
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    '座標',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: titleColor,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    '救援狀態',
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
            child: _filteredCitizens.isEmpty
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
                    itemCount: _filteredCitizens.length,
                    separatorBuilder: (_, __) => const Divider(
                      height: 1,
                      color: Color(0xFFEDF2F7),
                    ),
                    itemBuilder: (context, index) {
                      final citizen = _filteredCitizens[index];
                      final bool needsRescue = citizen.needsRescue;

                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 14,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: Text(
                                citizen.name,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: titleColor,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                citizen.id,
                                style: const TextStyle(
                                  fontSize: 14.5,
                                  color: textSoft,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: Text(
                                '${citizen.latitude}, ${citizen.longitude}',
                                style: const TextStyle(
                                  fontSize: 14.5,
                                  color: textSoft,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: needsRescue
                                        ? const Color(0xFFFFF4E5)
                                        : const Color(0xFFEAF7EC),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    needsRescue ? '需要救援' : '安全 / 已處理',
                                    style: TextStyle(
                                      color: needsRescue
                                          ? const Color(0xFFF59E0B)
                                          : const Color(0xFF43A047),
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
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
                                    onTap: () {},
                                  ),
                                  const SizedBox(width: 10),
                                  _buildActionButton(
                                    icon: Icons.delete_rounded,
                                    color: const Color(0xFFE53935),
                                    bgColor: const Color(0xFFFFEBEE),
                                    onTap: () {},
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