import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../core/models/healthReport.dart';
import 'full_map_page.dart';
import 'dashboard_page.dart' show kBg, kCardBg, kCyan, kGreen, kMuted, kBorder;

class HealthReportPage extends StatefulWidget {
  const HealthReportPage({super.key});

  @override
  State<HealthReportPage> createState() => _HealthReportPageState();
}

class _HealthReportPageState extends State<HealthReportPage> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _refreshTimer;
  Timer? _searchTimer;

  List<HealthReport> _allReports = [];
  List<HealthReport> _reports = [];

  bool _isLoading = false;
  String _errorMessage = '';

  String selectedFilter = 'all';
  String searchKeyword = '';

  static const String _baseUrl =
      'https://delphine-eisteddfodic-afflictively.ngrok-free.dev';

  static const Color _panel = Color(0xFF071828);
  static const Color _panel2 = Color(0xFF0A2035);
  static const Color _border = Color(0xFF14324A);
  static const Color _blue = Color(0xFF4A90E2);
  static const Color _orange = Color(0xFFFFB020);
  static const Color _red = Color(0xFFFF4D4F);
  static const Color _textSub = Color(0xFF7E91A6);

  @override
  void initState() {
    super.initState();
    loadReports();

    _refreshTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => loadReports(showLoading: false),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _searchTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> loadReports({bool showLoading = true}) async {
    if (showLoading && mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });
    }

    try {
      final response = await http
          .post(
            Uri.parse(_baseUrl),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'ngrok-skip-browser-warning': 'true',
            },
            body: jsonEncode({'type': 'getAllReports'}),
          )
          .timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        final loadedReports = (data['data'] as List)
            .map((e) => HealthReport.fromJson(e))
            .toList();

        if (!mounted) return;

        setState(() {
          _allReports = loadedReports;
          _reports = List.from(loadedReports);
        });

        _applyFilters();
      } else {
        if (!mounted) return;
        setState(() {
          _errorMessage = data['message'] ?? '取得健康回報資料失敗';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = '連線錯誤：$e';
      });
    } finally {
      if (mounted && showLoading) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _onSearchChanged(String value) {
    _searchTimer?.cancel();
    _searchTimer = Timer(const Duration(milliseconds: 300), () {
      setState(() {
        searchKeyword = value.trim().toLowerCase();
      });
      _applyFilters();
    });
  }

  void _applyFilters() {
    List<HealthReport> result = List.from(_allReports);

    if (selectedFilter != 'all') {
      result = result
          .where((r) => _normalizeStatus(r.status) == selectedFilter)
          .toList();
    }

    if (searchKeyword.isNotEmpty) {
      result = result.where((r) {
        final normalizedStatus = _normalizeStatus(r.status);
        final statusZh = _translateStatus(normalizedStatus).toLowerCase();

        return r.name.toLowerCase().contains(searchKeyword) ||
            r.reporterId.toLowerCase().contains(searchKeyword) ||
            r.phone.toLowerCase().contains(searchKeyword) ||
            (r.description ?? '').toLowerCase().contains(searchKeyword) ||
            _getLocationName(r).toLowerCase().contains(searchKeyword) ||
            normalizedStatus.contains(searchKeyword) ||
            statusZh.contains(searchKeyword);
      }).toList();
    }

    if (!mounted) return;
    setState(() => _reports = result);
  }

  String _normalizeStatus(String status) {
    final s = status.trim().toLowerCase();
    if (s == 'safe' || s == '安全') return 'safe';
    if (s == 'injured' || s == '輕傷' || s == '轻伤') return 'injured';
    if (s == 'critical' || s == '重傷' || s == '重伤') return 'critical';
    return s;
  }

  @override
  Widget build(BuildContext context) {
    final safeCount =
        _allReports.where((r) => _normalizeStatus(r.status) == 'safe').length;
    final injuredCount = _allReports
        .where((r) => _normalizeStatus(r.status) == 'injured')
        .length;
    final criticalCount = _allReports
        .where((r) => _normalizeStatus(r.status) == 'critical')
        .length;

    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: kCyan))
            : _errorMessage.isNotEmpty
                ? _buildErrorState()
                : SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(22, 18, 22, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(),
                        const SizedBox(height: 16),
                        _buildStatsRow(
                          total: _allReports.length,
                          safe: safeCount,
                          injured: injuredCount,
                          critical: criticalCount,
                        ),
                        const SizedBox(height: 16),
                        _buildSearchBar(),
                        const SizedBox(height: 14),
                        _buildFilterRow(),
                        const SizedBox(height: 16),
                        if (_allReports.isEmpty)
                          _buildEmptyState('目前沒有健康回報資料')
                        else if (_reports.isEmpty)
                          _buildEmptyState('沒有符合條件的資料')
                        else
                          ..._reports.map(_buildReportCard),
                      ],
                    ),
                  ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_panel, _red.withOpacity(.11)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: _red.withOpacity(.08),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: _red.withOpacity(.14),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _red.withOpacity(.35)),
            ),
            child: const Icon(
              Icons.health_and_safety_rounded,
              color: _red,
              size: 28,
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
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  '即時掌握災民健康狀況、位置與回報資訊',
                  style: TextStyle(
                    color: _textSub,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          _headerChip('只讀模式', _blue, Icons.lock_outline_rounded),
          const SizedBox(width: 10),
          IconButton(
            onPressed: () => loadReports(),
            icon: const Icon(Icons.refresh_rounded, color: kCyan),
            style: IconButton.styleFrom(
              backgroundColor: kCyan.withOpacity(.08),
              side: BorderSide(color: kCyan.withOpacity(.25)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _headerChip(String text, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: color.withOpacity(.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(.28)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 15),
          const SizedBox(width: 7),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.bold,
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
          child: _statCard(
            title: '全部回報',
            value: '$total',
            icon: Icons.apps_rounded,
            color: _blue,
            filter: 'all',
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _statCard(
            title: '安全',
            value: '$safe',
            icon: Icons.verified_user_rounded,
            color: kGreen,
            filter: 'safe',
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _statCard(
            title: '輕傷',
            value: '$injured',
            icon: Icons.healing_rounded,
            color: _orange,
            filter: 'injured',
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _statCard(
            title: '重傷',
            value: '$critical',
            icon: Icons.warning_amber_rounded,
            color: _red,
            filter: 'critical',
          ),
        ),
      ],
    );
  }

  Widget _statCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required String filter,
  }) {
    final selected = selectedFilter == filter;

    return InkWell(
      borderRadius: BorderRadius.circular(15),
      onTap: () {
        setState(() => selectedFilter = filter);
        _applyFilters();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: _panel,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: selected ? color.withOpacity(.7) : color.withOpacity(.22),
            width: selected ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: selected ? color.withOpacity(.13) : Colors.black.withOpacity(.13),
              blurRadius: 18,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: color.withOpacity(.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      color: color,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    title,
                    style: const TextStyle(
                      color: _textSub,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              Icon(Icons.check_circle_rounded, color: color, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: _onSearchChanged,
        style: const TextStyle(color: Colors.white, fontSize: 15),
        decoration: InputDecoration(
          hintText: '搜尋姓名 / 狀態 / 內容 / 電話 / ID / 地點...',
          hintStyle: const TextStyle(color: _textSub),
          prefixIcon: const Icon(Icons.search_rounded, color: _textSub),
          suffixIcon: searchKeyword.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close_rounded, color: _textSub),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => searchKeyword = '');
                    _applyFilters();
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }

  Widget _buildFilterRow() {
    return Row(
      children: [
        _filterChip('全部', 'all', _blue),
        const SizedBox(width: 10),
        _filterChip('安全', 'safe', kGreen),
        const SizedBox(width: 10),
        _filterChip('輕傷', 'injured', _orange),
        const SizedBox(width: 10),
        _filterChip('重傷', 'critical', _red),
      ],
    );
  }

  Widget _filterChip(String label, String filter, Color color) {
    final selected = selectedFilter == filter;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        setState(() => selectedFilter = filter);
        _applyFilters();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(.20) : _panel,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? color.withOpacity(.75) : _border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : _textSub,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildReportCard(HealthReport report) {
    final color = _getStatusColor(report.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.18),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 6,
            height: 118,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          const SizedBox(width: 14),
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: color.withOpacity(.13),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withOpacity(.25)),
            ),
            child: Icon(_getStatusIcon(report.status), color: color, size: 28),
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
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    _statusBadge(report.status),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  '回報者 ID：${report.reporterId}',
                  style: const TextStyle(
                    color: kCyan,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 13),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _infoPill(Icons.phone_outlined, report.phone, kCyan),
                    _infoPill(Icons.access_time, _formatTime(report.reportTime), _blue),
                    _infoPill(Icons.location_on_outlined, _getLocationName(report), _orange),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: _panel2,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _border.withOpacity(.7)),
                  ),
                  child: Text(
                    _getShortDescription(report.description),
                    style: const TextStyle(
                      color: _textSub,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          SizedBox(
            width: 126,
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  height: 40,
                  child: OutlinedButton.icon(
                    onPressed: report.lat != null && report.lng != null
                        ? () {
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
                        : null,
                    icon: const Icon(Icons.map_outlined, size: 15),
                    label: const Text('地圖'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: kCyan,
                      side: BorderSide(color: kCyan.withOpacity(.35)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 40,
                  child: ElevatedButton.icon(
                    onPressed: () => _showDetailDialog(context, report),
                    icon: const Icon(Icons.visibility_outlined, size: 15),
                    label: const Text('詳情'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: color.withOpacity(.20),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      side: BorderSide(color: color.withOpacity(.35)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoPill(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(.20)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Text(
            text.isEmpty ? '未填寫' : text,
            style: const TextStyle(
              color: _textSub,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusBadge(String status) {
    final color = _getStatusColor(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, color: color, size: 8),
          const SizedBox(width: 7),
          Text(
            _translateStatus(status),
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(42),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Column(
        children: [
          const Icon(Icons.inbox_outlined, size: 48, color: _textSub),
          const SizedBox(height: 14),
          Text(
            text,
            style: const TextStyle(
              color: _textSub,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Container(
        width: 460,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: _panel,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _red.withOpacity(.35)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, color: _red, size: 42),
            const SizedBox(height: 12),
            Text(
              _errorMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _red,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => loadReports(),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('重新載入'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _red.withOpacity(.18),
                foregroundColor: _red,
                elevation: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (_normalizeStatus(status)) {
      case 'safe':
        return kGreen;
      case 'injured':
        return _orange;
      case 'critical':
        return _red;
      default:
        return _blue;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (_normalizeStatus(status)) {
      case 'safe':
        return Icons.verified_user_rounded;
      case 'injured':
        return Icons.healing_rounded;
      case 'critical':
        return Icons.warning_amber_rounded;
      default:
        return Icons.info_outline_rounded;
    }
  }

  String _translateStatus(String status) {
    switch (_normalizeStatus(status)) {
      case 'safe':
        return '安全';
      case 'injured':
        return '輕傷';
      case 'critical':
        return '重傷';
      default:
        return status;
    }
  }

  String _formatTime(DateTime time) {
    return '${time.month}/${time.day} '
        '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}';
  }

  String _getShortDescription(String? text) {
    if (text == null || text.trim().isEmpty) return '無補充說明';
    if (text.length <= 48) return text;
    return '${text.substring(0, 48)}...';
  }

  String _getLocationName(HealthReport report) {
    if (report.lat == null || report.lng == null) return '未知地點';

    final lat = report.lat!;
    final lng = report.lng!;

    if ((lat - 23.951178).abs() < 0.01 &&
        (lng - 120.930978).abs() < 0.01) {
      return '暨大';
    }
    if ((lat - 23.966667).abs() < 0.01 &&
        (lng - 120.966667).abs() < 0.01) {
      return '埔里';
    }
    if ((lat - 23.866664).abs() < 0.02 &&
        (lng - 120.916664).abs() < 0.02) {
      return '日月潭';
    }

    return '其他地點';
  }

  void _showDetailDialog(BuildContext context, HealthReport report) {
    final color = _getStatusColor(report.status);

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(.65),
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: 560,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: _panel,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(.35),
                blurRadius: 30,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: color.withOpacity(.14),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(_getStatusIcon(report.status),
                          color: color, size: 28),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            report.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '回報者 ID：${report.reporterId}',
                            style: const TextStyle(
                              color: _textSub,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _statusBadge(report.status),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: Colors.white54),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _dialogItem('聯絡電話', report.phone),
                _dialogItem('血型', report.bloodType ?? '未填寫'),
                _dialogItem('狀態', _translateStatus(report.status)),
                _dialogItem('回報時間', _formatTime(report.reportTime)),
                _dialogItem('地點', _getLocationName(report)),
                _dialogItem(
                  '位置座標',
                  report.lat != null && report.lng != null
                      ? '${report.lat}, ${report.lng}'
                      : '未提供位置',
                ),
                _dialogItem(
                  '補充說明',
                  report.description != null &&
                          report.description!.trim().isNotEmpty
                      ? report.description!
                      : '無',
                ),
                const SizedBox(height: 10),
                if (report.lat != null && report.lng != null)
                  SizedBox(
                    width: double.infinity,
                    height: 44,
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
                        backgroundColor: color.withOpacity(.20),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        side: BorderSide(color: color.withOpacity(.35)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
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

  Widget _dialogItem(String label, String value) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _panel2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border.withOpacity(.7)),
      ),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(
            fontSize: 14,
            color: Colors.white,
            height: 1.5,
          ),
          children: [
            TextSpan(
              text: '$label：',
              style: const TextStyle(
                color: kCyan,
                fontWeight: FontWeight.bold,
              ),
            ),
            TextSpan(
              text: value.isEmpty ? '未填寫' : value,
              style: const TextStyle(color: _textSub),
            ),
          ],
        ),
      ),
    );
  }
}