import 'package:flutter/material.dart';
import '../repositories/healthReport_repository.dart';
import '../../core/models/healthReport.dart';

class HealthReportPage extends StatefulWidget {
  const HealthReportPage({super.key});

  @override
  State<HealthReportPage> createState() => _HealthReportPageState();
}

class _HealthReportPageState extends State<HealthReportPage> {
  final HealthReportRepository repo = HealthReportRepository();
  final TextEditingController _searchController = TextEditingController();

  List<HealthReport> _reports = [];
  String selectedFilter = 'all';
  String searchKeyword = '';

  @override
  void initState() {
    super.initState();
    _reports = List<HealthReport>.from(repo.getReports());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final safeCount =
        _reports.where((r) => r.status == 'safe' || r.status == '安全').length;
    final injuredCount = _reports
        .where((r) => r.status == 'injured' || r.status == '輕傷')
        .length;
    final criticalCount = _reports
        .where((r) => r.status == 'critical' || r.status == '重傷')
        .length;

    final filteredReports = _getFilteredReports(_reports);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF1E3A5F),
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          '健康回報管理',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
      ),
      body: _reports.isEmpty
          ? const Center(
              child: Text(
                '目前沒有健康回報資料',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildTopHeader(),
                  const SizedBox(height: 16),
                  _buildStatsSection(
                    totalCount: _reports.length,
                    safeCount: safeCount,
                    injuredCount: injuredCount,
                    criticalCount: criticalCount,
                  ),
                  const SizedBox(height: 16),
                  _buildToolbar(),
                  const SizedBox(height: 16),
                  filteredReports.isEmpty
                      ? Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(32),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.04),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Text(
                              '此分類目前沒有資料',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                        )
                      : ListView.builder(
                          itemCount: filteredReports.length,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemBuilder: (context, index) {
                            final report = filteredReports[index];
                            return _buildReportCard(report);
                          },
                        ),
                ],
              ),
            ),
    );
  }

  Widget _buildTopHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF1E3A5F),
            Color(0xFF2C5282),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E3A5F).withOpacity(0.15),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.14),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.health_and_safety,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '健康回報監控中心',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  '即時查看災民健康狀況、聯絡資訊與位置資料',
                  style: TextStyle(
                    color: Color(0xFFD6E4F0),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _buildHeaderBadge(
                icon: Icons.inventory_2_outlined,
                text: '只讀模式',
              ),
              const SizedBox(height: 8),
              _buildHeaderBadge(
                icon: Icons.sync,
                text: '用戶端上報資料',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderBadge({
    required IconData icon,
    required String text,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withOpacity(0.18),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSection({
    required int totalCount,
    required int safeCount,
    required int injuredCount,
    required int criticalCount,
  }) {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            title: '全部回報',
            value: totalCount.toString(),
            icon: Icons.list_alt,
            color: const Color(0xFF334155),
            filterValue: 'all',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            title: '安全',
            value: safeCount.toString(),
            icon: Icons.verified_user,
            color: Colors.green,
            filterValue: 'safe',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            title: '輕傷',
            value: injuredCount.toString(),
            icon: Icons.healing,
            color: Colors.orange,
            filterValue: 'injured',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            title: '重傷',
            value: criticalCount.toString(),
            icon: Icons.warning_rounded,
            color: Colors.red,
            filterValue: 'critical',
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required String filterValue,
  }) {
    final bool isSelected = selectedFilter == filterValue;

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () {
        setState(() {
          selectedFilter = filterValue;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color.withOpacity(0.55) : Colors.transparent,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 16),
            Text(
              value,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolbar() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildFilterChip('全部', 'all'),
              _buildFilterChip('安全', 'safe'),
              _buildFilterChip('輕傷', 'injured'),
              _buildFilterChip('重傷', 'critical'),
            ],
          ),
          const Spacer(),
          SizedBox(
            width: 280,
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() {
                  searchKeyword = value.trim().toLowerCase();
                });
              },
              decoration: InputDecoration(
                hintText: '搜尋姓名 / ID',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final bool isSelected = selectedFilter == value;

    return InkWell(
      borderRadius: BorderRadius.circular(30),
      onTap: () {
        setState(() {
          selectedFilter = value;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF1E3A5F)
              : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF475569),
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildReportCard(HealthReport report) {
    final statusColor = _getStatusColor(report.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 260,
            decoration: BoxDecoration(
              color: statusColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                bottomLeft: Radius.circular(24),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          _getStatusIcon(report.status),
                          color: statusColor,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              report.name,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '回報者 ID：${report.reporterId}',
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF94A3B8),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _buildStatusChip(report.status),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Wrap(
                    runSpacing: 10,
                    spacing: 20,
                    children: [
                      _buildInfoTag(
                        Icons.phone,
                        '聯絡電話',
                        report.phone,
                      ),
                      _buildInfoTag(
                        Icons.bloodtype,
                        '血型',
                        report.bloodType ?? '未填寫',
                      ),
                      _buildInfoTag(
                        Icons.access_time,
                        '回報時間',
                        _formatTime(report.reportTime),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.grey.withOpacity(0.10),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '位置資訊',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF334155),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          (report.lat != null && report.lng != null)
                              ? '${report.lat}, ${report.lng}'
                              : '未提供位置',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF475569),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    '補充說明',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF334155),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.grey.withOpacity(0.10),
                      ),
                    ),
                    child: Text(
                      (report.description != null &&
                              report.description!.trim().isNotEmpty)
                          ? report.description!
                          : '無補充說明',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF475569),
                        height: 1.6,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Text(
                        '資料來源：用戶端上報',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                      const Spacer(),
                      ElevatedButton.icon(
                        onPressed: () {
                          _showDetailDialog(context, report);
                        },
                        icon: const Icon(Icons.visibility_outlined, size: 18),
                        label: const Text('查看詳情'),
                        style: ElevatedButton.styleFrom(
                          elevation: 0,
                          backgroundColor: const Color(0xFF1E3A5F),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
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

  Widget _buildInfoTag(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.grey.withOpacity(0.08),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: const Color(0xFF1E3A5F),
          ),
          const SizedBox(width: 8),
          Text(
            '$label：',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF334155),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF475569),
            ),
          ),
        ],
      ),
    );
  }

  List<HealthReport> _getFilteredReports(List<HealthReport> reports) {
    List<HealthReport> result;

    switch (selectedFilter) {
      case 'safe':
        result = reports
            .where((r) => r.status == 'safe' || r.status == '安全')
            .toList();
        break;
      case 'injured':
        result = reports
            .where((r) => r.status == 'injured' || r.status == '輕傷')
            .toList();
        break;
      case 'critical':
        result = reports
            .where((r) => r.status == 'critical' || r.status == '重傷')
            .toList();
        break;
      case 'all':
      default:
        result = reports;
    }

    if (searchKeyword.isEmpty) return result;

    return result.where((r) {
      final name = r.name.toLowerCase();
      final id = r.reporterId.toLowerCase();
      return name.contains(searchKeyword) || id.contains(searchKeyword);
    }).toList();
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case '安全':
      case 'safe':
        return Colors.green;
      case '輕傷':
      case 'injured':
        return Colors.orange;
      case '重傷':
      case 'critical':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case '安全':
      case 'safe':
        return Icons.verified_user;
      case '輕傷':
      case 'injured':
        return Icons.healing;
      case '重傷':
      case 'critical':
        return Icons.warning_rounded;
      default:
        return Icons.info_outline;
    }
  }

  Widget _buildStatusChip(String status) {
    final color = _getStatusColor(status);

    String text;
    switch (status) {
      case 'safe':
        text = '安全';
        break;
      case 'injured':
        text = '輕傷';
        break;
      case 'critical':
        text = '重傷';
        break;
      default:
        text = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: color.withOpacity(0.18),
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    return "${time.year}/"
        "${time.month.toString().padLeft(2, '0')}/"
        "${time.day.toString().padLeft(2, '0')} "
        "${time.hour.toString().padLeft(2, '0')}:"
        "${time.minute.toString().padLeft(2, '0')}";
  }

  void _showDetailDialog(BuildContext context, HealthReport report) {
    String statusText;
    switch (report.status) {
      case 'safe':
        statusText = '安全';
        break;
      case 'injured':
        statusText = '輕傷';
        break;
      case 'critical':
        statusText = '重傷';
        break;
      default:
        statusText = report.status;
    }

    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: 560,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor:
                          _getStatusColor(report.status).withOpacity(0.12),
                      child: Icon(
                        _getStatusIcon(report.status),
                        color: _getStatusColor(report.status),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            report.name,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '回報者 ID：${report.reporterId}',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                      ),
                    ),
                    _buildStatusChip(report.status),
                  ],
                ),
                const SizedBox(height: 24),
                _buildDialogItem('聯絡電話', report.phone),
                _buildDialogItem('血型', report.bloodType ?? '未填寫'),
                _buildDialogItem('狀態', statusText),
                _buildDialogItem('回報時間', _formatTime(report.reportTime)),
                _buildDialogItem(
                  '位置',
                  (report.lat != null && report.lng != null)
                      ? '${report.lat}, ${report.lng}'
                      : '未提供位置',
                ),
                _buildDialogItem(
                  '補充說明',
                  (report.description != null &&
                          report.description!.trim().isNotEmpty)
                      ? report.description!
                      : '無',
                ),
                const SizedBox(height: 18),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      '關閉',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E3A5F),
                      ),
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

  Widget _buildDialogItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14),
        ),
        child: RichText(
          text: TextSpan(
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF334155),
              height: 1.5,
            ),
            children: [
              TextSpan(
                text: '$label：',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              TextSpan(text: value),
            ],
          ),
        ),
      ),
    );
  }
}