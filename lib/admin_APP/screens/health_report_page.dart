import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../core/models/healthReport.dart';
import 'full_map_page.dart';

// ── 色系（與 dashboard 統一）────────────────────────────
const Color _kBg       = Color(0xFFF5F7FA);
const Color _kCardBg   = Color(0xFFFFFFFF);
const Color _kCardBg2  = Color(0xFFF8FAFC);
const Color _kBorder   = Color(0xFFE5E7EB);
const Color _kBlue     = Color(0xFF2563EB);
const Color _kGreen    = Color(0xFF16A34A);
const Color _kOrange   = Color(0xFFF59E0B);
const Color _kRed      = Color(0xFFDC2626);
const Color _kPurple   = Color(0xFF7C3AED);
const Color _kTextMain = Color(0xFF0F172A);
const Color _kTextSub  = Color(0xFF64748B);

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
  List<HealthReport> _reports    = [];

  bool   _isLoading    = false;
  String _errorMessage = '';
  String _filter       = 'all';
  String _keyword      = '';

  static const String _baseUrl =
      'https://delphine-eisteddfodic-afflictively.ngrok-free.dev';

  @override
  void initState() {
    super.initState();
    _loadReports();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _loadReports(showLoading: false),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _searchTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  // ── API ──────────────────────────────────────────────
  Future<void> _loadReports({bool showLoading = true}) async {
    if (showLoading && mounted) {
      setState(() { _isLoading = true; _errorMessage = ''; });
    }
    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: jsonEncode({'type': 'getAllReports'}),
      ).timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        final loaded = (data['data'] as List)
            .map((e) => HealthReport.fromJson(e))
            .toList();
        if (!mounted) return;
        setState(() {
          _allReports   = loaded;
          _isLoading    = false;
          _errorMessage = '';
        });
        _applyFilters();
      } else {
        if (!mounted) return;
        setState(() {
          _errorMessage = data['message'] ?? '取得健康回報資料失敗';
          _isLoading    = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() { _errorMessage = '連線錯誤：$e'; _isLoading = false; });
    }
  }

  // ── 篩選 ─────────────────────────────────────────────
  void _onSearchChanged(String v) {
    _searchTimer?.cancel();
    _searchTimer = Timer(const Duration(milliseconds: 280), () {
      setState(() => _keyword = v.trim().toLowerCase());
      _applyFilters();
    });
  }

  void _applyFilters() {
    List<HealthReport> result = List.from(_allReports);
    if (_filter != 'all') {
      result = result
          .where((r) => _normalizeStatus(r.status) == _filter)
          .toList();
    }
    if (_keyword.isNotEmpty) {
      result = result.where((r) {
        final ns = _normalizeStatus(r.status);
        return r.name.toLowerCase().contains(_keyword) ||
            r.reporterId.toLowerCase().contains(_keyword) ||
            r.phone.toLowerCase().contains(_keyword) ||
            (r.description ?? '').toLowerCase().contains(_keyword) ||
            _locationName(r).toLowerCase().contains(_keyword) ||
            ns.contains(_keyword) ||
            _translateStatus(ns).contains(_keyword);
      }).toList();
    }
    if (mounted) setState(() => _reports = result);
  }

  // ════════════════════════════════════════════════════
  //  BUILD
  // ════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final safeCount     = _allReports.where((r) => _normalizeStatus(r.status) == 'safe').length;
    final injuredCount  = _allReports.where((r) => _normalizeStatus(r.status) == 'injured').length;
    final criticalCount = _allReports.where((r) => _normalizeStatus(r.status) == 'critical').length;

    return Container(
      color: _kBg,
      child: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: _kBlue))
            : _errorMessage.isNotEmpty
                ? _buildError()
                : SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTopBar(),
                        const SizedBox(height: 16),
                        _buildStatsRow(
                          total: _allReports.length,
                          safe: safeCount,
                          injured: injuredCount,
                          critical: criticalCount,
                        ),
                        const SizedBox(height: 14),
                        _buildSearchBar(),
                        const SizedBox(height: 10),
                        _buildFilterRow(),
                        const SizedBox(height: 14),
                        if (_allReports.isEmpty)
                          _buildEmpty('目前沒有健康回報資料')
                        else if (_reports.isEmpty)
                          _buildEmpty('沒有符合條件的資料')
                        else
                          ..._reports.map(_buildReportCard),
                      ],
                    ),
                  ),
      ),
    );
  }

  // ── 頂部列 ────────────────────────────────────────────
  Widget _buildTopBar() {
    return Row(children: [
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
        Text('健康回報',
            style: TextStyle(
                color: _kTextMain,
                fontSize: 28,
                fontWeight: FontWeight.w800)),
        SizedBox(height: 2),
        Text('HEALTH REPORT CENTER',
            style: TextStyle(
                color: _kTextSub, fontSize: 12, letterSpacing: 1.4)),
      ]),
      const SizedBox(width: 14),
      _pill('只讀模式', _kPurple),
      const Spacer(),
      InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => _loadReports(),
        child: Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
            color: _kCardBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _kBorder),
          ),
          child: const Icon(Icons.refresh_rounded,
              color: _kBlue, size: 18),
        ),
      ),
    ]);
  }

  // ── 統計卡片 ─────────────────────────────────────────
  Widget _buildStatsRow({
    required int total,
    required int safe,
    required int injured,
    required int critical,
  }) {
    return Row(children: [
      Expanded(child: _statCard('全部回報', '$total',
          Icons.apps_rounded, _kBlue, 'all')),
      const SizedBox(width: 12),
      Expanded(child: _statCard('安全', '$safe',
          Icons.verified_user_rounded, _kGreen, 'safe')),
      const SizedBox(width: 12),
      Expanded(child: _statCard('輕傷', '$injured',
          Icons.healing_rounded, _kOrange, 'injured')),
      const SizedBox(width: 12),
      Expanded(child: _statCard('重傷', '$critical',
          Icons.warning_amber_rounded, _kRed, 'critical')),
    ]);
  }

  Widget _statCard(String label, String value, IconData icon,
      Color color, String filter) {
    final sel = _filter == filter;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () {
        setState(() => _filter = filter);
        _applyFilters();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _kCardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: sel ? color.withOpacity(.4) : _kBorder,
              width: sel ? 1.5 : 0.5),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(.035),
                blurRadius: 12,
                offset: const Offset(0, 4)),
          ],
        ),
        child: Row(children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
                color: color.withOpacity(.10),
                borderRadius: BorderRadius.circular(11)),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text(value,
                  style: TextStyle(
                      color: sel ? color : _kTextMain,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      height: 1)),
              const SizedBox(height: 4),
              Text(label,
                  style: const TextStyle(
                      color: _kTextSub, fontSize: 12)),
            ]),
          ),
          if (sel)
            Icon(Icons.check_circle_rounded,
                color: color, size: 16),
        ]),
      ),
    );
  }

  // ── 搜尋列 ────────────────────────────────────────────
  Widget _buildSearchBar() {
    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kBorder),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: _onSearchChanged,
        style: const TextStyle(color: _kTextMain, fontSize: 14),
        decoration: InputDecoration(
          hintText: '搜尋姓名 / 狀態 / 電話 / ID / 地點...',
          hintStyle:
              const TextStyle(color: _kTextSub, fontSize: 14),
          prefixIcon: const Icon(Icons.search,
              color: _kTextSub, size: 18),
          suffixIcon: _keyword.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close_rounded,
                      color: _kTextSub, size: 17),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _keyword = '');
                    _applyFilters();
                  })
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 13),
        ),
      ),
    );
  }

  // ── 篩選 Tab ─────────────────────────────────────────
  Widget _buildFilterRow() {
    return Row(children: [
      _filterChip('全部', 'all',      _kBlue),
      const SizedBox(width: 8),
      _filterChip('安全', 'safe',     _kGreen),
      const SizedBox(width: 8),
      _filterChip('輕傷', 'injured',  _kOrange),
      const SizedBox(width: 8),
      _filterChip('重傷', 'critical', _kRed),
      const Spacer(),
      Text('共 ${_reports.length} 筆',
          style: const TextStyle(
              color: _kTextSub, fontSize: 13)),
    ]);
  }

  Widget _filterChip(
      String label, String filter, Color color) {
    final sel = _filter == filter;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () {
        setState(() => _filter = filter);
        _applyFilters();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(
            horizontal: 13, vertical: 8),
        decoration: BoxDecoration(
          color: sel ? color.withOpacity(.08) : _kCardBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color:
                  sel ? color.withOpacity(.4) : _kBorder),
        ),
        child: Text(label,
            style: TextStyle(
                color: sel ? color : _kTextSub,
                fontSize: 13,
                fontWeight: sel
                    ? FontWeight.w700
                    : FontWeight.w500)),
      ),
    );
  }

  // ── 回報卡片 ─────────────────────────────────────────
  Widget _buildReportCard(HealthReport r) {
    final color = _statusColor(r.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBorder),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(.035),
              blurRadius: 12,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
        // 左側色條
        Container(
          width: 4, height: 100,
          decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(99)),
        ),
        const SizedBox(width: 14),
        // 頭像
        Container(
          width: 48, height: 48,
          decoration: BoxDecoration(
              color: color.withOpacity(.10),
              borderRadius: BorderRadius.circular(13),
              border:
                  Border.all(color: color.withOpacity(.2))),
          child: Icon(_statusIcon(r.status),
              color: color, size: 24),
        ),
        const SizedBox(width: 14),
        // 內容
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Row(children: [
              Expanded(
                child: Text(r.name,
                    style: const TextStyle(
                        color: _kTextMain,
                        fontSize: 17,
                        fontWeight: FontWeight.w800)),
              ),
              _statusBadge(r.status),
            ]),
            const SizedBox(height: 3),
            Text('回報者 ID：${r.reporterId}',
                style: const TextStyle(
                    color: _kTextSub, fontSize: 12)),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 6, children: [
              _tag(Icons.phone_outlined,
                  r.phone, _kBlue),
              _tag(Icons.access_time,
                  _fmt(r.reportTime), _kTextSub),
              _tag(Icons.location_on_outlined,
                  _locationName(r), _kGreen),
            ]),
            if (r.description != null &&
                r.description!.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 9),
                decoration: BoxDecoration(
                  color: _kCardBg2,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _kBorder),
                ),
                child: Text(
                  r.description!.length > 60
                      ? '${r.description!.substring(0, 60)}...'
                      : r.description!,
                  style: const TextStyle(
                      color: _kTextSub, fontSize: 12),
                ),
              ),
            ],
          ]),
        ),
        const SizedBox(width: 12),
        // 操作按鈕
        Column(children: [
          if (r.lat != null && r.lng != null)
            _actionBtn('地圖', Icons.map_outlined, _kBlue,
                () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => FullMapPage(
                            lat: r.lat!, lng: r.lng!)))),
          const SizedBox(height: 8),
          _actionBtn('詳情', Icons.visibility_outlined, color,
              () => _showDetail(r)),
        ]),
      ]),
    );
  }

  // ── 詳情 Dialog ──────────────────────────────────────
  void _showDetail(HealthReport r) {
    final color = _statusColor(r.status);
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(.35),
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: 480,
          decoration: BoxDecoration(
            color: _kCardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _kBorder),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // 標題
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 12, 14),
              child: Row(children: [
                Container(
                  width: 42, height: 42,
                  decoration: BoxDecoration(
                      color: color.withOpacity(.10),
                      borderRadius: BorderRadius.circular(11)),
                  child: Icon(_statusIcon(r.status),
                      color: color, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                    Text(r.name,
                        style: const TextStyle(
                            color: _kTextMain,
                            fontSize: 17,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 3),
                    Row(children: [
                      _statusBadge(r.status),
                      const SizedBox(width: 8),
                      Text('ID：${r.reporterId}',
                          style: const TextStyle(
                              color: _kTextSub,
                              fontSize: 12)),
                    ]),
                  ]),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close,
                      color: _kTextSub, size: 18),
                ),
              ]),
            ),
            const Divider(height: 1, color: _kBorder),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(children: [
                _dialogRow('聯絡電話', r.phone),
                _dialogRow('血型',
                    r.bloodType ?? '未填寫'),
                _dialogRow('狀態',
                    _translateStatus(
                        _normalizeStatus(r.status))),
                _dialogRow('回報時間', _fmt(r.reportTime)),
                _dialogRow('地點', _locationName(r)),
                _dialogRow(
                    '位置座標',
                    r.lat != null && r.lng != null
                        ? '${r.lat}, ${r.lng}'
                        : '未提供'),
                _dialogRow(
                    '補充說明',
                    (r.description != null &&
                            r.description!
                                .trim()
                                .isNotEmpty)
                        ? r.description!
                        : '無'),
                if (r.lat != null && r.lng != null) ...[
                  const SizedBox(height: 4),
                  SizedBox(
                    width: double.infinity,
                    child: InkWell(
                      borderRadius:
                          BorderRadius.circular(8),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) =>
                                    FullMapPage(
                                        lat: r.lat!,
                                        lng: r.lng!)));
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 11),
                        decoration: BoxDecoration(
                          color: _kBlue.withOpacity(.06),
                          borderRadius:
                              BorderRadius.circular(8),
                          border: Border.all(
                              color: _kBlue
                                  .withOpacity(.2)),
                        ),
                        child: const Row(
                            mainAxisAlignment:
                                MainAxisAlignment.center,
                            children: [
                          Icon(Icons.map_outlined,
                              color: _kBlue, size: 16),
                          SizedBox(width: 6),
                          Text('打開全屏地圖',
                              style: TextStyle(
                                  color: _kBlue,
                                  fontSize: 13,
                                  fontWeight:
                                      FontWeight.w600)),
                        ]),
                      ),
                    ),
                  ),
                ],
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _dialogRow(String label, String value) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(
          horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
          color: _kCardBg2,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _kBorder)),
      child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
        SizedBox(
          width: 80,
          child: Text(label,
              style: const TextStyle(
                  color: _kTextSub,
                  fontSize: 13,
                  fontWeight: FontWeight.w500)),
        ),
        Expanded(
          child: Text(
            value.isEmpty ? '未填寫' : value,
            style: const TextStyle(
                color: _kTextMain,
                fontSize: 13,
                fontWeight: FontWeight.w600),
          ),
        ),
      ]),
    );
  }

  // ── 錯誤 / 空狀態 ──────────────────────────────────────
  Widget _buildError() {
    return Center(
      child: Container(
        width: 420, padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: _kCardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _kRed.withOpacity(.2)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
                color: _kRed.withOpacity(.08),
                shape: BoxShape.circle),
            child: const Icon(Icons.error_outline,
                color: _kRed, size: 26),
          ),
          const SizedBox(height: 14),
          Text(_errorMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: _kRed, fontSize: 14)),
          const SizedBox(height: 18),
          OutlinedButton.icon(
            onPressed: () => _loadReports(),
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('重新載入'),
            style: OutlinedButton.styleFrom(
                foregroundColor: _kBlue,
                side: BorderSide(
                    color: _kBlue.withOpacity(.4))),
          ),
        ]),
      ),
    );
  }

  Widget _buildEmpty(String text) {
    return Container(
      width: double.infinity, padding: const EdgeInsets.all(48),
      decoration: BoxDecoration(
          color: _kCardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _kBorder)),
      child: Column(children: [
        Container(
          width: 52, height: 52,
          decoration: BoxDecoration(
              color: _kTextSub.withOpacity(.06),
              shape: BoxShape.circle),
          child: const Icon(Icons.inbox_outlined,
              size: 26, color: _kTextSub),
        ),
        const SizedBox(height: 12),
        Text(text,
            style: const TextStyle(
                color: _kTextSub,
                fontSize: 14,
                fontWeight: FontWeight.w500)),
      ]),
    );
  }

  // ── 共用小元件 ─────────────────────────────────────────
  Widget _actionBtn(String label, IconData icon,
      Color color, VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(.06),
          borderRadius: BorderRadius.circular(8),
          border:
              Border.all(color: color.withOpacity(.2)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }

  Widget _statusBadge(String status) {
    final color = _statusColor(status);
    final text  = _translateStatus(_normalizeStatus(status));
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
          color: color.withOpacity(.08),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withOpacity(.2))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 6, height: 6,
            decoration: BoxDecoration(
                color: color, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text(text,
            style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w700)),
      ]),
    );
  }

  static Widget _tag(
      IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
          color: color.withOpacity(.06),
          borderRadius: BorderRadius.circular(7),
          border:
              Border.all(color: color.withOpacity(.18))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Text(text.isEmpty ? '未填寫' : text,
            style: const TextStyle(
                color: _kTextSub,
                fontSize: 11,
                fontWeight: FontWeight.w500)),
      ]),
    );
  }

  static Widget _pill(String text, Color color) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
          color: color.withOpacity(.08),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withOpacity(.18))),
      child: Text(text,
          style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700)),
    );
  }

  // ── 工具方法 ──────────────────────────────────────────
  Color _statusColor(String status) {
    switch (_normalizeStatus(status)) {
      case 'safe':     return _kGreen;
      case 'injured':  return _kOrange;
      case 'critical': return _kRed;
      default:         return _kBlue;
    }
  }

  IconData _statusIcon(String status) {
    switch (_normalizeStatus(status)) {
      case 'safe':     return Icons.verified_user_rounded;
      case 'injured':  return Icons.healing_rounded;
      case 'critical': return Icons.warning_amber_rounded;
      default:         return Icons.info_outline_rounded;
    }
  }

  String _normalizeStatus(String status) {
    final s = status.trim().toLowerCase();
    if (s == 'safe'     || s == '安全') return 'safe';
    if (s == 'injured'  || s == '輕傷' || s == '轻伤') return 'injured';
    if (s == 'critical' || s == '重傷' || s == '重伤') return 'critical';
    return s;
  }

  String _translateStatus(String s) {
    switch (s) {
      case 'safe':     return '安全';
      case 'injured':  return '輕傷';
      case 'critical': return '重傷';
      default:         return s;
    }
  }

  String _fmt(DateTime t) =>
      '${t.month}/${t.day} '
      '${t.hour.toString().padLeft(2, '0')}:'
      '${t.minute.toString().padLeft(2, '0')}';

  String _locationName(HealthReport r) {
    if (r.lat == null || r.lng == null) return '未知地點';
    final lat = r.lat!, lng = r.lng!;
    if ((lat - 23.951178).abs() < 0.01 &&
        (lng - 120.930978).abs() < 0.01) return '暨大';
    if ((lat - 23.966667).abs() < 0.01 &&
        (lng - 120.966667).abs() < 0.01) return '埔里';
    if ((lat - 23.866664).abs() < 0.02 &&
        (lng - 120.916664).abs() < 0.02) return '日月潭';
    return '其他地點';
  }
}