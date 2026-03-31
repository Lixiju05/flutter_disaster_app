import 'package:flutter/material.dart';
import '../repositories/healthReport_repository.dart';
import '../../core/models/healthReport.dart';

import 'dashboard_page.dart';
import 'citizen_page.dart';
import 'emergency_page.dart';
import 'supply_page.dart';

class HealthReportPage extends StatefulWidget {
  const HealthReportPage({super.key});

  @override
  State<HealthReportPage> createState() => _HealthReportPageState();
}

class _HealthReportPageState extends State<HealthReportPage> {
  final HealthReportRepository repo = HealthReportRepository();
  final TextEditingController _searchController = TextEditingController();

  static const Color primaryBlue = Color(0xFF183A61);
  static const Color accentBlue = Color(0xFF4A90E2);
  static const Color pageBg = Color(0xFFF4F7FB);
  static const Color cardBg = Colors.white;
  static const Color titleColor = Color(0xFF183153);
  static const Color textSoft = Color(0xFF6B7A90);
  static const Color borderColor = Color(0xFFE6ECF3);

  late List<HealthReport> _allReports;
  List<HealthReport> _filteredReports = [];

  // 目前筛选状态：all / safe / injured / critical
  String _selectedStatus = 'all';

  @override
  void initState() {
    super.initState();
    _allReports = repo.getReports();
    _applyFilters();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // 统一套用：状态筛选 + 搜寻关键字
  void _applyFilters() {
    final keyword = _searchController.text.trim().toLowerCase();

    setState(() {
      _filteredReports = _allReports.where((report) {
        // 先筛选状态
        final bool statusMatch = _selectedStatus == 'all'
            ? true
            : report.status.toLowerCase() == _selectedStatus;

        // 再筛选搜寻关键字
        final bool keywordMatch = keyword.isEmpty ||
            report.name.toLowerCase().contains(keyword) ||
            report.reporterId.toLowerCase().contains(keyword) ||
            report.status.toLowerCase().contains(keyword) ||
            (report.description?.toLowerCase().contains(keyword) ?? false);

        return statusMatch && keywordMatch;
      }).toList();
    });
  }

  void _searchReports(String keyword) {
    _applyFilters();
  }

  void _filterByStatus(String status) {
    _selectedStatus = status;
    _applyFilters();
  }

  int get totalCount => _allReports.length;

  int get safeCount =>
      _allReports.where((r) => r.status.toLowerCase() == 'safe').length;

  int get injuredCount =>
      _allReports.where((r) => r.status.toLowerCase() == 'injured').length;

  int get criticalCount =>
      _allReports.where((r) => r.status.toLowerCase() == 'critical').length;

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
                      child: _buildReportListCard(),
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
            onTap: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const CitizenPage()),
              );
            },
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
                MaterialPageRoute(builder: (_) => const EmergencyPage()),
              );
            },
          ),
          _buildSidebarItem(
            icon: Icons.health_and_safety_rounded,
            title: '健康回報',
            selected: true,
            onTap: () {},
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
                    Icons.favorite_rounded,
                    color: Colors.white70,
                    size: 18,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '健康資料可協助後續調度',
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
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _selectedStatus == 'all'
                      ? '健康回報管理'
                      : '健康回報管理｜${_statusLabel(_selectedStatus)}',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: titleColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _selectedStatus == 'all'
                      ? 'Health Report Monitoring Center'
                      : 'Filtered by ${_statusLabel(_selectedStatus)}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: textSoft,
                  ),
                ),
              ],
            ),
          ),
          const CircleAvatar(
            radius: 20,
            backgroundColor: Color(0xFFE8F7F5),
            child: Icon(
              Icons.health_and_safety_rounded,
              color: Color(0xFF009688),
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
            Color(0xFF0F766E),
            Color(0xFF0E9F93),
            Color(0xFF43C6AC),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF009688).withOpacity(0.18),
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
                  '即時掌握健康回報',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 27,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  '集中查看民眾健康狀態、回報時間與備註資訊，協助管理單位迅速判斷後續應對。',
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
              Icons.monitor_heart_rounded,
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
            title: '回報總數',
            value: totalCount.toString(),
            icon: Icons.assignment_rounded,
            iconColor: const Color(0xFF4A90E2),
            iconBg: const Color(0xFFEAF2FF),
            filterValue: 'all',
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildMiniStatCard(
            title: '安全',
            value: safeCount.toString(),
            icon: Icons.check_circle_rounded,
            iconColor: const Color(0xFF43A047),
            iconBg: const Color(0xFFEAF7EC),
            filterValue: 'safe',
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildMiniStatCard(
            title: '受傷',
            value: injuredCount.toString(),
            icon: Icons.healing_rounded,
            iconColor: const Color(0xFFF59E0B),
            iconBg: const Color(0xFFFFF4E5),
            filterValue: 'injured',
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildMiniStatCard(
            title: '危急',
            value: criticalCount.toString(),
            icon: Icons.emergency_rounded,
            iconColor: const Color(0xFFE53935),
            iconBg: const Color(0xFFFFEBEE),
            filterValue: 'critical',
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
    required String filterValue,
  }) {
    final bool isSelected = _selectedStatus == filterValue;

    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: () {
        _filterByStatus(filterValue);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFF0F8FF) : cardBg,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isSelected ? accentBlue : borderColor,
            width: isSelected ? 1.8 : 1,
          ),
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
              onChanged: _searchReports,
              decoration: InputDecoration(
                hintText: '請輸入姓名、ID、狀態或備註搜尋',
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
              colors: [Color(0xFF0E9F93), Color(0xFF43C6AC)],
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF009688).withOpacity(0.22),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ElevatedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.add_chart_rounded, color: Colors.white),
            label: const Text(
              '新增回報',
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

  Widget _buildReportListCard() {
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
      child: _filteredReports.isEmpty
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
              itemCount: _filteredReports.length,
              separatorBuilder: (_, __) => const SizedBox(height: 14),
              itemBuilder: (context, index) {
                final report = _filteredReports[index];

                return Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFCFDFE),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFEDF2F7)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          color: _statusBgColor(report.status),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          _statusIcon(report.status),
                          color: _statusTextColor(report.status),
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    report.name,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: titleColor,
                                    ),
                                  ),
                                ),
                                _buildStatusChip(report.status),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              '回報 ID：${report.reporterId}',
                              style: const TextStyle(
                                fontSize: 13.5,
                                color: textSoft,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '備註：${report.description?.isNotEmpty == true ? report.description! : '無'}',
                              style: const TextStyle(
                                fontSize: 14,
                                color: textSoft,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                const Icon(
                                  Icons.access_time_rounded,
                                  size: 16,
                                  color: textSoft,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _formatDateTime(report.reportTime),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: textSoft,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        children: [
                          _buildActionButton(
                            icon: Icons.visibility_rounded,
                            color: const Color(0xFF4A90E2),
                            bgColor: const Color(0xFFEAF2FF),
                            onTap: () {
                              _showDetailDialog(context, report);
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Widget _buildStatusChip(String status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _statusBgColor(status),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _statusLabel(status),
        style: TextStyle(
          color: _statusTextColor(status),
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
      ),
    );
  }

  Color _statusBgColor(String status) {
    switch (status.toLowerCase()) {
      case 'safe':
        return const Color(0xFFEAF7EC);
      case 'injured':
        return const Color(0xFFFFF4E5);
      case 'critical':
        return const Color(0xFFFFEBEE);
      default:
        return const Color(0xFFF1F3F5);
    }
  }

  Color _statusTextColor(String status) {
    switch (status.toLowerCase()) {
      case 'safe':
        return const Color(0xFF43A047);
      case 'injured':
        return const Color(0xFFF59E0B);
      case 'critical':
        return const Color(0xFFE53935);
      default:
        return Colors.grey;
    }
  }

  IconData _statusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'safe':
        return Icons.check_circle_rounded;
      case 'injured':
        return Icons.healing_rounded;
      case 'critical':
        return Icons.emergency_rounded;
      default:
        return Icons.help_outline_rounded;
    }
  }

  String _statusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'all':
        return '全部';
      case 'safe':
        return '安全';
      case 'injured':
        return '受傷';
      case 'critical':
        return '危急';
      default:
        return status;
    }
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
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, size: 20, color: color),
      ),
    );
  }

  void _showDetailDialog(BuildContext context, HealthReport report) {
    showDialog(
      context: context,
      builder: (_) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Container(
            width: 460,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: _statusBgColor(report.status),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        _statusIcon(report.status),
                        color: _statusTextColor(report.status),
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        report.name,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: titleColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _buildDetailRow('回報 ID', report.reporterId),
                _buildDetailRow('狀態', _statusLabel(report.status)),
                _buildDetailRow('時間', _formatDateTime(report.reportTime)),
                _buildDetailRow(
                  '備註',
                  report.description?.isNotEmpty == true ? report.description! : '無',
                ),
                const SizedBox(height: 24),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      '關閉',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: accentBlue,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 82,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: titleColor,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: textSoft,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final year = dateTime.year.toString().padLeft(4, '0');
    final month = dateTime.month.toString().padLeft(2, '0');
    final day = dateTime.day.toString().padLeft(2, '0');
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');

    return '$year/$month/$day  $hour:$minute';
  }
}