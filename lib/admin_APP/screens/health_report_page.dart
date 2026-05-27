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
const Color _kCritical = Color(0xFFEC6C2D);   // 重傷（橘色）
const Color _kOrange   = Color(0xFFD3CA43);   // 輕傷（落日黃）
const Color _kRed      = Color(0xFFDC2626);   // 錯誤 / 緊急警示
const Color _kTextMain = Color(0xFF0F172A);
const Color _kTextSub  = Color(0xFF64748B);

class HealthReportPage extends StatefulWidget {
  const HealthReportPage({super.key, this.showSearch = false});
  final bool showSearch;

  @override
  State<HealthReportPage> createState() => _HealthReportPageState();
}

class _HealthReportPageState extends State<HealthReportPage> {
  Timer? _refreshTimer;

  List<HealthReport> _allReports = [];
  List<HealthReport> _reports    = [];

  bool   _isLoading    = false;
  String _errorMessage = '';
  String _filter       = 'all';
  String _searchQuery  = '';
  final  TextEditingController _searchCtrl = TextEditingController();

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
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: _kBlue))
            : _errorMessage.isNotEmpty
                ? _buildError()
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── 固定頂部（不隨清單滾動）──────────────
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 14, 24, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (widget.showSearch) _buildPageHeader(urgentCount),
                            if (widget.showSearch) const SizedBox(height: 12),
                            _buildStatsRow(
                              total: _allReports.length,
                              safe: safeCount,
                              injured: injuredCount,
                              critical: criticalCount,
                              onRefresh: widget.showSearch ? null : _loadReports,
                            ),
                            if (widget.showSearch) ...[
                              const SizedBox(height: 10),
                              _buildSearchBar(),
                              const SizedBox(height: 6),
                              _buildResultCount(),
                            ],
                            const SizedBox(height: 10),
                          ],
                        ),
                      ),
                      // ── 可滾動清單 ──────────────────────────
                      Expanded(
                        child: _allReports.isEmpty
                            ? _buildEmpty('目前沒有健康回報資料')
                            : _reports.isEmpty
                                ? _buildEmpty('沒有符合條件的資料')
                                : ListView(
                                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
                                    children: _filter == 'all'
                                        ? _buildGroupedCards()
                                        : _reports.map(_buildReportCard).toList(),
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
      height: 40,
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kBorder),
      ),
      child: Row(children: [
        const SizedBox(width: 12),
        const Icon(Icons.search_rounded, color: _kTextSub, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: _searchCtrl,
            style: const TextStyle(fontSize: 13, color: _kTextMain),
            decoration: const InputDecoration(
              hintText: '搜尋姓名 / ID…',
              hintStyle: TextStyle(color: _kTextSub, fontSize: 13),
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
            onChanged: (v) {
              setState(() => _searchQuery = v);
              _applyFilters();
            },
          ),
        ),
        if (_searchQuery.isNotEmpty)
          GestureDetector(
            onTap: () {
              _searchCtrl.clear();
              setState(() => _searchQuery = '');
              _applyFilters();
            },
            child: const Padding(
              padding: EdgeInsets.all(8),
              child: Icon(Icons.close_rounded, color: _kTextSub, size: 15),
            ),
          )
        else
          const SizedBox(width: 8),
      ]),
    );
  }

  // ── 完整頁面標題（管理員側欄使用）──────────────────────
  Widget _buildPageHeader(int urgentCount) {
    return Row(children: [
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('健康回報',
            style: TextStyle(color: _kTextMain, fontSize: 26, fontWeight: FontWeight.w800)),
        const SizedBox(height: 1),
        const Text('HEALTH REPORT MANAGEMENT',
            style: TextStyle(color: _kTextSub, fontSize: 11, letterSpacing: 1.3)),
      ]),
      const SizedBox(width: 12),
      if (urgentCount > 0)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(
            color: _kRed.withValues(alpha: .08),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: _kRed.withValues(alpha: .18)),
          ),
          child: Text('傷患 $urgentCount 件',
              style: const TextStyle(color: _kRed, fontSize: 10, fontWeight: FontWeight.w700)),
        ),
      const Spacer(),
      GestureDetector(
        onTap: _loadReports,
        child: Container(
          width: 34, height: 34,
          decoration: BoxDecoration(
            color: _kCardBg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _kBorder),
          ),
          child: const Icon(Icons.refresh_rounded, color: _kBlue, size: 16),
        ),
      ),
    ]);
  }

  // ── 搜尋結果筆數提示 ─────────────────────────────────
  Widget _buildResultCount() {
    final q = _searchQuery.trim();
    final isFiltered = _filter != 'all' || q.isNotEmpty;
    if (!isFiltered) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(left: 2),
      child: Text(
        q.isNotEmpty
            ? '搜尋「$q」：共 ${_reports.length} 筆'
            : '篩選結果：共 ${_reports.length} 筆',
        style: const TextStyle(color: _kTextSub, fontSize: 12),
      ),
    );
  }

  // ── 頂部重新整理按鈕（災民管理使用）──────────────────────
  Widget _buildTopBar() {
    return Align(
      alignment: Alignment.centerRight,
      child: InkWell(
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
    );
  }

  // ── 統計卡片（連排可點擊）──────────────────────────────
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
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kBorder),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: .028),
              blurRadius: 6,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Row(children: [
        _tapCell('全部回報', '$total', Icons.apps_rounded, _kBlue, 'all'),
        _vDivider(),
        _tapCell('重傷', '$critical', Icons.warning_amber_rounded, _kCritical, 'critical'),
        _vDivider(),
        _tapCell('輕傷', '$injured', Icons.healing_rounded, _kOrange, 'injured'),
        _vDivider(),
        _tapCell('安全', '$safe', Icons.verified_user_rounded, _kGreen, 'safe'),
        if (onRefresh != null) ...[
          _vDivider(),
          SizedBox(
            width: 44,
            child: IconButton(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh_rounded, color: _kBlue, size: 17),
              padding: EdgeInsets.zero,
            ),
          ),
        ],
      ]),
    );
  }

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
          ),
          child: Row(children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                  color: color.withValues(alpha: .10),
                  borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, color: color, size: 16),
            ),
            const SizedBox(width: 10),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    style: TextStyle(
                        color: sel ? color : _kTextMain,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        height: 1.1)),
                Text(label,
                    style: const TextStyle(color: _kTextSub, fontSize: 11)),
              ],
            )),
            if (sel) Icon(Icons.check_circle_rounded, color: color, size: 14),
          ]),
        ),
      ),
    );
  }

  Widget _vDivider() => Container(width: 1, height: 28, color: _kBorder);

  // ── 分組顯示（全部模式）────────────────────────────────
  List<Widget> _buildGroupedCards() {
    final critical = _reports.where((r) => _normalizeStatus(r.status) == 'critical').toList();
    final injured  = _reports.where((r) => _normalizeStatus(r.status) == 'injured').toList();
    final safe     = _reports.where((r) => _normalizeStatus(r.status) == 'safe').toList();

    return [
      if (critical.isNotEmpty) ...[
        _sectionHeader('重傷', _kCritical, critical.length),
        ...critical.map(_buildReportCard),
      ],
      if (injured.isNotEmpty) ...[
        _sectionHeader('輕傷', _kOrange, injured.length),
        ...injured.map(_buildReportCard),
      ],
      if (safe.isNotEmpty) ...[
        _sectionHeader('安全', _kGreen, safe.length),
        ...safe.map(_buildReportCard),
      ],
    ];
  }

  Widget _sectionHeader(String label, Color color, int count) {
    return Container(
      margin: const EdgeInsets.only(top: 4, bottom: 10),
      child: Row(children: [
        Container(
          width: 4, height: 18,
          decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(99)),
        ),
        const SizedBox(width: 8),
        Text(label,
            style: TextStyle(
                color: color,
                fontSize: 15,
                fontWeight: FontWeight.w700)),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
              color: color.withValues(alpha: .10),
              borderRadius: BorderRadius.circular(999)),
          child: Text('$count 筆',
              style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
        ),
        const SizedBox(width: 8),
        Expanded(
            child: Divider(
                color: color.withValues(alpha: .2), thickness: 1)),
      ]),
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
              color: Colors.black.withValues(alpha: .035),
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
              color: color.withValues(alpha: .10),
              borderRadius: BorderRadius.circular(13),
              border:
                  Border.all(color: color.withValues(alpha: .2))),
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
                  color: _kRed, fontSize: 14)),
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
          color: color.withValues(alpha: .06),
          borderRadius: BorderRadius.circular(8),
          border:
              Border.all(color: color.withValues(alpha: .2)),
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
          color: color.withValues(alpha: .06),
          borderRadius: BorderRadius.circular(7),
          border:
              Border.all(color: color.withValues(alpha: .18))),
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