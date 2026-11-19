import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_disaster_app/admin_APP/widgets/page_header.dart';
import 'package:flutter_disaster_app/admin_APP/widgets/firebase_reports_panel.dart';
import 'package:http/http.dart' as http;

import '../../core/models/healthReport.dart';
import 'full_map_page.dart';
import 'package:flutter_disaster_app/core/api_config.dart';

// ── 色系（與 dashboard 統一）────────────────────────────
const Color _kBg       = Color(0xFFF5F7FA);
const Color _kCardBg   = Color(0xFFFFFFFF);
const Color _kCardBg2  = Color(0xFFF8FAFC);
const Color _kBorder   = Color(0xFFE5E7EB);
const Color _kBlue     = Color(0xFF2563EB);
const Color _kGreen    = Color(0xFF16A34A);
const Color _kCritical = Color(0xFFDC2626);   // 重傷（紅色）
const Color _kOrange   = Color(0xFFD97706);   // 輕傷（橘色）
const Color _kRed      = Color(0xFFDC2626);   // 錯誤 / 緊急警示
const Color _kTextMain = Color(0xFF0F172A);
const Color _kTextSub  = Color(0xFF475569);

class HealthReportPage extends StatelessWidget {
  const HealthReportPage({super.key, this.showSearch = false});
  final bool showSearch;
  @override
  Widget build(BuildContext context) => ReportSourcePage(sosOnly: false,
      sqliteBuilder: (_) => SqliteHealthReportPage(showSearch: showSearch));
}

class SqliteHealthReportPage extends StatefulWidget {
  const SqliteHealthReportPage({super.key, this.showSearch = false});
  final bool showSearch;

  @override
  State<SqliteHealthReportPage> createState() => _HealthReportPageState();
}

class _HealthReportPageState extends State<SqliteHealthReportPage> {
  Timer? _refreshTimer;

  List<HealthReport> _allReports = [];
  List<HealthReport> _reports    = [];

  bool   _isLoading    = false;
  String _errorMessage = '';
  String _filter       = 'all';
  String _searchQuery  = '';
  final  TextEditingController _searchCtrl = TextEditingController();

  static const String _baseUrl = ApiConfig.baseUrl;

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
    _searchCtrl.dispose();
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
        // 回報本身沒帶電話 / 血型時，用後端用戶資料（getAllUsers）補上
        final users = await _loadUsers();
        final loaded = (data['data'] as List).map((e) {
          final m = Map<String, dynamic>.from(e);
          final u = users[m['reporterId']?.toString()];
          if (u != null) {
            if ((m['phone']?.toString() ?? '').trim().isEmpty) m['phone'] = u['phone'];
            if ((m['bloodType']?.toString() ?? '').trim().isEmpty) m['bloodType'] = u['bloodType'];
          }
          return HealthReport.fromJson(m);
        }).toList();
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

  /// 用戶資料（id → 用戶），失敗就回傳空的，不影響回報顯示
  Future<Map<String, Map<String, dynamic>>> _loadUsers() async {
    try {
      final res = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: jsonEncode({'type': 'getAllUsers'}),
      ).timeout(const Duration(seconds: 10));
      final data = jsonDecode(res.body);
      if (res.statusCode != 200 || data['success'] != true) return {};
      return {
        for (final u in data['data'] as List)
          (u['id'] ?? u['userId']).toString(): Map<String, dynamic>.from(u),
      };
    } catch (_) {
      return {};
    }
  }

  // ── 篩選 ─────────────────────────────────────────────
  void _applyFilters() {
    List<HealthReport> result = List.from(_allReports);
    if (_filter != 'all') {
      result = result
          .where((r) => _normalizeStatus(r.status) == _filter)
          .toList();
    }
    final q = _searchQuery.trim().toLowerCase();
    if (q.isNotEmpty) {
      result = result.where((r) {
        return r.name.toLowerCase().contains(q) ||
               r.reporterId.toLowerCase().contains(q);
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
    final urgentCount   = injuredCount + criticalCount;

    return Container(
      color: _kBg,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 固定頂部（不隨清單滾動）──────────────
            if (widget.showSearch) _buildPageHeader(urgentCount),
            Padding(
              padding: EdgeInsets.fromLTRB(24, widget.showSearch ? 16 : 14, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 統計格同時是篩選（點一下就只看該狀態）
                  _buildStatsRow(
                    total: _allReports.length,
                    safe: safeCount,
                    injured: injuredCount,
                    critical: criticalCount,
                    onRefresh: widget.showSearch ? null : _loadReports,
                  ),
                  if (widget.showSearch) ...[
                    const SizedBox(height: 12),
                    _buildSearchBar(),
                  ],
                  const SizedBox(height: 12),
                ],
              ),
            ),
            // ── 可滾動清單 ──────────────────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                child: _buildList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 搜尋列 ───────────────────────────────────────────
  Widget _buildSearchBar() {
    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kBorder),
      ),
      child: TextField(
        controller: _searchCtrl,
        style: const TextStyle(color: _kTextMain, fontSize: 16),
        decoration: InputDecoration(
          hintText: '搜尋姓名或 ID…',
          hintStyle: const TextStyle(color: _kTextSub, fontSize: 15),
          prefixIcon: const Icon(Icons.search_rounded, color: _kTextSub, size: 20),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close_rounded, color: _kTextSub, size: 18),
                  onPressed: () {
                    _searchCtrl.clear();
                    setState(() => _searchQuery = '');
                    _applyFilters();
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 13),
        ),
        onChanged: (v) {
          setState(() => _searchQuery = v);
          _applyFilters();
        },
      ),
    );
  }

  // ── 完整頁面標題（管理員側欄使用）──────────────────────
  Widget _buildPageHeader(int urgentCount) {
    return PageHeader(
      title: '健康回報',
      subtitle: 'HEALTH REPORT MANAGEMENT',
      badges: [
        if (urgentCount > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: _kRed.withValues(alpha: .08),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: _kRed.withValues(alpha: .18)),
            ),
            child: Text('傷患 $urgentCount 件',
                style: const TextStyle(color: _kRed, fontSize: 12, fontWeight: FontWeight.w700)),
          ),
      ],
      actions: [
        PageHeaderButton(
            icon: Icons.refresh_rounded, tooltip: '重新整理', onPressed: _loadReports),
      ],
    );
  }

  // ── 統計格（同緊急事件：點一下篩選）──────────────────────
  Widget _buildStatsRow({
    required int total,
    required int safe,
    required int injured,
    required int critical,
    VoidCallback? onRefresh,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(children: [
        _tapCell('全部', '$total', Icons.list_alt_rounded, _kBlue, 'all'),
        _vDivider(),
        _tapCell('重傷', '$critical', Icons.warning_amber_rounded, _kCritical, 'critical'),
        _vDivider(),
        _tapCell('輕傷', '$injured', Icons.healing_rounded, _kOrange, 'injured'),
        _vDivider(),
        _tapCell('安全', '$safe', Icons.verified_user_rounded, _kGreen, 'safe'),
        if (onRefresh != null) ...[
          _vDivider(),
          SizedBox(
            width: 48,
            child: IconButton(
              onPressed: onRefresh,
              tooltip: '重新整理',
              icon: const Icon(Icons.refresh_rounded, color: _kBlue, size: 20),
            ),
          ),
        ],
      ]),
    );
  }

  /// 統計格：選中時淡底色 + 底部色條
  Widget _tapCell(String label, String value, IconData icon, Color color, String filter) {
    final sel = _filter == filter;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _filter = filter);
          _applyFilters();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: sel ? color.withValues(alpha: .06) : Colors.transparent,
            border: Border(bottom: BorderSide(color: sel ? color : Colors.transparent, width: 3)),
          ),
          child: Row(children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 10),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(value,
                  style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.w800, height: 1.15)),
              Text(label,
                  style: TextStyle(
                      color: sel ? _kTextMain : _kTextSub,
                      fontSize: 14,
                      fontWeight: sel ? FontWeight.w700 : FontWeight.w500)),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _vDivider() => Container(width: 1, height: 32, color: _kBorder);

  // ── 清單（白底表格，重傷 → 輕傷 → 安全，同狀態新到舊）──────────
  Widget _buildList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: _kBlue, strokeWidth: 2.5));
    }
    if (_errorMessage.isNotEmpty) return _buildError();
    if (_allReports.isEmpty) return _buildEmpty('目前沒有健康回報資料');

    const rank = {'critical': 0, 'injured': 1, 'safe': 2};
    final list = List<HealthReport>.from(_reports)
      ..sort((a, b) {
        final ra = rank[_normalizeStatus(a.status)] ?? 3;
        final rb = rank[_normalizeStatus(b.status)] ?? 3;
        if (ra != rb) return ra.compareTo(rb);
        return b.reportTime.compareTo(a.reportTime);
      });
    final filterLabel = _filter == 'all' ? '' : '・${_translateStatus(_filter)}';
    final q = _searchQuery.trim();

    return Container(
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: [
        Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          decoration: const BoxDecoration(
            color: _kCardBg2,
            border: Border(bottom: BorderSide(color: _kBorder)),
          ),
          child: Row(children: [
            Text('健康回報$filterLabel',
                style: const TextStyle(color: _kTextMain, fontSize: 16, fontWeight: FontWeight.w800)),
            const Spacer(),
            Text('共 ${list.length} 筆',
                style: const TextStyle(color: _kTextMain, fontSize: 14, fontWeight: FontWeight.w600)),
          ]),
        ),
        Expanded(
          child: list.isEmpty
              ? Center(
                  child: Text(
                      q.isNotEmpty ? '找不到符合「$q」的回報' : '沒有「${_translateStatus(_filter)}」的回報',
                      style: const TextStyle(color: _kTextSub, fontSize: 15)))
              : ListView.separated(
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  itemBuilder: (_, i) => _buildReportRow(list[i]),
                ),
        ),
      ]),
    );
  }

  // ── 回報列（白底、狀態標籤、右側操作按鈕）──────────────────
  Widget _buildReportRow(HealthReport r) {
    final color = _statusColor(r.status);
    final hasLocation = r.lat != null && r.lng != null;
    final desc = r.description?.trim() ?? '';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
              color: color.withValues(alpha: .10), borderRadius: BorderRadius.circular(10)),
          child: Icon(_statusIcon(r.status), color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(
                child: Text(r.name.isNotEmpty ? r.name : '用戶 ${r.reporterId}',
                    style: const TextStyle(color: _kTextMain, fontSize: 16, fontWeight: FontWeight.w700),
                    overflow: TextOverflow.ellipsis, maxLines: 1),
              ),
              const SizedBox(width: 8),
              Text(r.reporterId, style: const TextStyle(color: _kTextSub, fontSize: 14)),
              const SizedBox(width: 8),
              _statusBadge(r.status),
              const SizedBox(width: 8),
              Text(_fmt(r.reportTime), style: const TextStyle(color: _kTextSub, fontSize: 13)),
            ]),
            const SizedBox(height: 4),
            Text(
              [if (r.phone.trim().isNotEmpty) r.phone, _locationName(r)].join('　'),
              style: const TextStyle(color: _kTextSub, fontSize: 14),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (desc.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('說明：$desc',
                  style: const TextStyle(color: _kTextMain, fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ],
          ]),
        ),
        const SizedBox(width: 12),
        // 操作：地圖 / 詳情
        if (hasLocation) ...[
          _outlineBtn('地圖', _kBlue, () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => FullMapPage(lat: r.lat!, lng: r.lng!)))),
          const SizedBox(width: 8),
        ],
        _outlineBtn('詳情', _kBlue, () => _showDetail(r)),
      ]),
    );
  }

  /// 白底外框按鈕（同緊急事件、用戶管理）
  static Widget _outlineBtn(String text, Color color, VoidCallback onTap) => InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: _kCardBg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: .4)),
          ),
          child: Text(text, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w700)),
        ),
      );

  // ── 詳情 Dialog ──────────────────────────────────────
  void _showDetail(HealthReport r) {
    final color = _statusColor(r.status);
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: .35),
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
                      color: color.withValues(alpha: .10),
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
                              fontSize: 13)),
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
                          color: _kBlue.withValues(alpha: .06),
                          borderRadius:
                              BorderRadius.circular(8),
                          border: Border.all(
                              color: _kBlue
                                  .withValues(alpha: .2)),
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
                                  fontSize: 14,
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
                  fontSize: 14,
                  fontWeight: FontWeight.w500)),
        ),
        Expanded(
          child: Text(
            value.isEmpty ? '未填寫' : value,
            style: const TextStyle(
                color: _kTextMain,
                fontSize: 14,
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
          border: Border.all(color: _kRed.withValues(alpha: .2)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
                color: _kRed.withValues(alpha: .08),
                shape: BoxShape.circle),
            child: const Icon(Icons.error_outline,
                color: _kRed, size: 26),
          ),
          const SizedBox(height: 14),
          Text(_errorMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: _kRed, fontSize: 15)),
          const SizedBox(height: 18),
          OutlinedButton.icon(
            onPressed: () => _loadReports(),
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('重新載入'),
            style: OutlinedButton.styleFrom(
                foregroundColor: _kBlue,
                side: BorderSide(
                    color: _kBlue.withValues(alpha: .4))),
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
              color: _kTextSub.withValues(alpha: .06),
              shape: BoxShape.circle),
          child: const Icon(Icons.inbox_outlined,
              size: 26, color: _kTextSub),
        ),
        const SizedBox(height: 12),
        Text(text,
            style: const TextStyle(
                color: _kTextSub,
                fontSize: 15,
                fontWeight: FontWeight.w500)),
      ]),
    );
  }

  // ── 共用小元件 ─────────────────────────────────────────
  Widget _statusBadge(String status) {
    final color = _statusColor(status);
    final text  = _translateStatus(_normalizeStatus(status));
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
          color: color.withValues(alpha: .08),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: .2))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 6, height: 6,
            decoration: BoxDecoration(
                color: color, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text(text,
            style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w700)),
      ]),
    );
  }

  // ── 工具方法 ──────────────────────────────────────────
  Color _statusColor(String status) {
    switch (_normalizeStatus(status)) {
      case 'safe':     return _kGreen;
      case 'injured':  return _kOrange;
      case 'critical': return _kCritical;
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
    if (s == 'injured'  || s == 'minor' || s == '輕傷' || s == '轻伤') return 'injured';
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
    if (r.address?.isNotEmpty == true) return r.address!;
    if (r.lat == null || r.lng == null) return '未知地點';
    return '${r.lat!.toStringAsFixed(5)}, ${r.lng!.toStringAsFixed(5)}';
  }
}
