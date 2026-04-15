import 'package:flutter/material.dart';
import '../repositories/healthReport_repository.dart';
import '../../core/models/healthReport.dart';
import 'full_map_page.dart';

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

  static const Color _bg = Color(0xFFF4F7FB);
  static const Color _navy = Color(0xFF163A63);
  static const Color _navy2 = Color(0xFF244E7A);
  static const Color _card = Colors.white;
  static const Color _border = Color(0xFFE2E8F0);
  static const Color _textMain = Color(0xFF0F172A);
  static const Color _textSub = Color(0xFF64748B);
  static const Color _blue = Color(0xFF2563EB);

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
    final filteredReports = _getFilteredReports(_reports);
    final safeCount =
        _reports.where((r) => r.status == 'safe' || r.status == '安全').length;
    final injuredCount = _reports
        .where((r) => r.status == 'injured' || r.status == '輕傷')
        .length;
    final criticalCount = _reports
        .where((r) => r.status == 'critical' || r.status == '重傷')
        .length;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: _textMain),
        title: const Text(
          '健康回報管理',
          style: TextStyle(
            color: _textMain,
            fontWeight: FontWeight.w800,
            fontSize: 22,
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16, top: 10, bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _border),
            ),
            child: const Center(
              child: Text(
                '只讀模式',
                style: TextStyle(
                  color: _textSub,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
      body: _reports.isEmpty
          ? const Center(
              child: Text(
                '目前沒有健康回報資料',
                style: TextStyle(color: _textSub),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _buildHeroHeader(),
                  const SizedBox(height: 18),
                  _buildStatsRow(
                    total: _reports.length,
                    safe: safeCount,
                    injured: injuredCount,
                    critical: criticalCount,
                  ),
                  const SizedBox(height: 18),
                  _buildSearchBar(),
                  const SizedBox(height: 18),
                  _buildFilterRow(),
                  const SizedBox(height: 18),
                  if (filteredReports.isEmpty)
                    _buildEmptyState()
                  else
                    ...filteredReports.map(_buildPremiumCard),
                ],
              ),
            ),
    );
  }

  Widget _buildHeroHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_navy, _navy2],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: _navy.withOpacity(0.18),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.14),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.health_and_safety,
              color: Colors.white,
              size: 30,
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '健康回報監控中心',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  '即時掌握災民健康狀況、位置與回報資訊',
                  style: TextStyle(
                    color: Color(0xFFDCE6F2),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow({
    required int total,
    required int safe,
    required int injured,
    required int critical,
  }) {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            title: '全部回報',
            value: total.toString(),
            icon: Icons.apps_rounded,
            color: _blue,
            filter: 'all',
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _buildStatCard(
            title: '安全',
            value: safe.toString(),
            icon: Icons.verified_user,
            color: const Color(0xFF22C55E),
            filter: 'safe',
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _buildStatCard(
            title: '輕傷',
            value: injured.toString(),
            icon: Icons.healing,
            color: const Color(0xFFF59E0B),
            filter: 'injured',
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _buildStatCard(
            title: '重傷',
            value: critical.toString(),
            icon: Icons.warning_amber_rounded,
            color: const Color(0xFFEF4444),
            filter: 'critical',
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
    required String filter,
  }) {
    final isSelected = selectedFilter == filter;

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => setState(() => selectedFilter = filter),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color.withOpacity(0.7) : _border,
            width: isSelected ? 1.6 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? color.withOpacity(0.14)
                  : Colors.black.withOpacity(0.04),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 12),
            Text(
              value,
              style: const TextStyle(
                color: _textMain,
                fontSize: 30,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(
                color: _textSub,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (v) => setState(() => searchKeyword = v.trim().toLowerCase()),
        decoration: const InputDecoration(
          hintText: '搜尋姓名 / ID...',
          hintStyle: TextStyle(color: _textSub),
          prefixIcon: Icon(Icons.search, color: _textSub),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }

  Widget _buildFilterRow() {
    return Row(
      children: [
        _buildFilterChip('全部', 'all'),
        const SizedBox(width: 10),
        _buildFilterChip('安全', 'safe'),
        const SizedBox(width: 10),
        _buildFilterChip('輕傷', 'injured'),
        const SizedBox(width: 10),
        _buildFilterChip('重傷', 'critical'),
      ],
    );
  }
  Widget _buildFilterChip(String label, String filter) {
  final isSelected = selectedFilter == filter;

  return InkWell(
    borderRadius: BorderRadius.circular(28),
    onTap: () => setState(() => selectedFilter = filter),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isSelected ? _blue : Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: isSelected ? _blue : _border,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : _textSub,
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
      ),
    ),
  );
}

 
  Widget _buildPremiumCard(HealthReport report) {
    final statusColor = _getStatusColor(report.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 6,
              height: 132,
              decoration: BoxDecoration(
                color: statusColor,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            const SizedBox(width: 14),
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                _getStatusIcon(report.status),
                color: statusColor,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 6,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        report.name,
                        style: const TextStyle(
                          color: _textMain,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 10),
                      _buildStatusBadge(report.status),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'ID: ${report.reporterId}',
                    style: const TextStyle(
                      color: _textSub,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _buildInfoPill(Icons.phone_outlined, report.phone),
                      _buildInfoPill(Icons.access_time, _formatTime(report.reportTime)),
                      _buildInfoPill(Icons.location_on_outlined, _getLocationName(report)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      _getShortDescription(report.description),
                      style: const TextStyle(
                        color: _textSub,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 2,
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        if (report.lat != null && report.lng != null) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => FullMapPage(
                                lat: report.lat!,
                                lng: report.lng!,
                              ),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.map_outlined, size: 18),
                      label: const Text('地圖'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor:_blue,
                        side: const BorderSide(color: _border),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _showDetailDialog(context, report),
                      icon: const Icon(Icons.visibility_outlined, size: 18),
                      label: const Text('詳情'),
                      style: ElevatedButton.styleFrom(
                        elevation: 0,
                        backgroundColor: _blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoPill(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: _blue),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              color: _textSub,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    final color = _getStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        _translateStatus(status),
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _border),
      ),
      child: const Column(
        children: [
          Icon(Icons.inbox_outlined, size: 44, color: _textSub),
          SizedBox(height: 12),
          Text(
            '沒有符合條件的資料',
            style: TextStyle(color: _textSub),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case '安全':
      case 'safe':
        return const Color(0xFF22C55E);
      case '輕傷':
      case 'injured':
        return const Color(0xFFF59E0B);
      case '重傷':
      case 'critical':
        return const Color(0xFFEF4444);
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
        return Icons.warning_amber_rounded;
      default:
        return Icons.info_outline;
    }
  }

  String _translateStatus(String status) {
    if (status == 'safe') return '安全';
    if (status == 'injured') return '輕傷';
    if (status == 'critical') return '重傷';
    return status;
  }

  String _formatTime(DateTime time) {
    return "${time.month}/${time.day} "
        "${time.hour.toString().padLeft(2, '0')}:"
        "${time.minute.toString().padLeft(2, '0')}";
  }

  String _getShortDescription(String? text) {
    if (text == null || text.trim().isEmpty) return '無補充說明';
    if (text.length <= 42) return text;
    return '${text.substring(0, 42)}...';
  }

  String _getLocationName(HealthReport report) {
    if (report.lat == null || report.lng == null) return '未知地點';

    final lat = report.lat!;
    final lng = report.lng!;

    if ((lat - 23.951178).abs() < 0.01 && (lng - 120.930978).abs() < 0.01) {
      return '暨大';
    }
    if ((lat - 23.966667).abs() < 0.01 && (lng - 120.966667).abs() < 0.01) {
      return '埔里';
    }
    if ((lat - 23.866664).abs() < 0.02 && (lng - 120.916664).abs() < 0.02) {
      return '日月潭';
    }

    return '其他地點';
  }

  List<HealthReport> _getFilteredReports(List<HealthReport> reports) {
    List<HealthReport> result = reports;

    switch (selectedFilter) {
      case 'safe':
        result = result.where((r) => r.status == 'safe' || r.status == '安全').toList();
        break;
      case 'injured':
        result = result.where((r) => r.status == 'injured' || r.status == '輕傷').toList();
        break;
      case 'critical':
        result = result.where((r) => r.status == 'critical' || r.status == '重傷').toList();
        break;
      case 'all':
      default:
        break;
    }

    if (searchKeyword.isNotEmpty) {
      result = result.where((r) {
        final name = r.name.toLowerCase();
        final id = r.reporterId.toLowerCase();
        return name.contains(searchKeyword) || id.contains(searchKeyword);
      }).toList();
    }

    return result;
  }

  void _showDetailDialog(BuildContext context, HealthReport report) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: 540,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(18),
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  report.name,
                  style: const TextStyle(
                    color: _textMain,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '回報者 ID：${report.reporterId}',
                  style: const TextStyle(
                    color: _textSub,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 18),
                _buildDialogItem('聯絡電話', report.phone),
                _buildDialogItem('血型', report.bloodType ?? '未填寫'),
                _buildDialogItem('狀態', _translateStatus(report.status)),
                _buildDialogItem('回報時間', _formatTime(report.reportTime)),
                _buildDialogItem('地點', _getLocationName(report)),
                _buildDialogItem(
                  '位置座標',
                  (report.lat != null && report.lng != null)
                      ? '${report.lat}, ${report.lng}'
                      : '未提供位置',
                ),
                _buildDialogItem(
                  '補充說明',
                  (report.description != null && report.description!.trim().isNotEmpty)
                      ? report.description!
                      : '無',
                ),
                const SizedBox(height: 10),
                if (report.lat != null && report.lng != null)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => FullMapPage(
                              lat: report.lat!,
                              lng: report.lng!,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.map_outlined),
                      label: const Text('打開全屏地圖'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      '關閉',
                      style: TextStyle(
                        color: _blue,
                        fontWeight: FontWeight.bold,
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
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
        ),
        child: RichText(
          text: TextSpan(
            style: const TextStyle(
              fontSize: 14,
              color: _textMain,
              height: 1.5,
            ),
            children: [
              TextSpan(
                text: '$label：',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              TextSpan(
                text: value,
                style: const TextStyle(color: _textSub),
              ),
            ],
          ),
        ),
      ),
    );
  }
}