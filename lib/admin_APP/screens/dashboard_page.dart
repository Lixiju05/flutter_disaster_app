import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import 'citizen_page.dart';
import 'emergency_page.dart';
import 'supply_page.dart';
import 'health_report_page.dart';
import 'login_page.dart';
import 'user_management_page.dart';
import 'shelter_map_dialog.dart';
import 'weather_service.dart';
import '../viewModels/weather_viewmodel.dart';

// ══════════════════════════════════════════════════════════
//  COLOR SYSTEM
// ══════════════════════════════════════════════════════════
const Color kBg           = Color(0xFF020C18);
const Color kSidebarBg    = Color(0xFF010810);
const Color kCardBg       = Color(0xFF071828);
const Color kCardBg2      = Color(0xFF0A2035);
const Color kHighlight    = Color(0xFF0D3B5E);
const Color kCyan         = Color(0xFF00C8FF);
const Color kBlue         = Color(0xFF1A6EFF);
const Color kGreen        = Color(0xFF00D09C);
const Color kMuted        = Color(0xFF3E5872);
const Color kBorder       = Color(0xFF0E2A40);
const Color kBorderBright = Color(0xFF1A4A6E);

// ══════════════════════════════════════════════════════════
//  TIMELINE EVENT
// ══════════════════════════════════════════════════════════
class TimelineEvent {
  final String id;
  final String title;
  final String subtitle;
  final DateTime time;
  final Color color;
  final String category;
  const TimelineEvent({
    required this.id, required this.title, required this.subtitle,
    required this.time, required this.color, required this.category,
  });
}

// ══════════════════════════════════════════════════════════
//  DASHBOARD PAGE
// ══════════════════════════════════════════════════════════
class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});
  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  static const String _baseUrl = 'http://localhost:8080';
  static const String _cwaKey  = 'CWA-AFE44442-4E97-4836-A31F-0D743B56732B';

  int selectedIndex = 0;
  int userCount = 0, healthReportCount = 0, _supplyCount = 0, _emergencyCount = 0;
  bool isLoading = true;

  late Timer _clockTimer;
  DateTime _now = DateTime.now();

  List<DisasterAlert> _disasterAlerts = [];
  bool _alertsLoading = false;
  late Timer _alertTimer;
  late Timer _envTimer;

  List<TimelineEvent> _timeline = [];
  int _notificationCount = 0;

  final ScrollController _vCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadCounts();
    _startClock();
    _loadAlerts();
    _alertTimer = Timer.periodic(const Duration(minutes: 5), (_) => _loadAlerts());
    _envTimer = Timer.periodic(const Duration(minutes: 10), (_) {
      if (mounted) context.read<WeatherViewModel>().refresh();
    });
  }

  @override
  void dispose() {
    _clockTimer.cancel();
    _alertTimer.cancel();
    _envTimer.cancel();
    _vCtrl.dispose();
    super.dispose();
  }

  void _startClock() {
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  String get _formattedTime {
    final h = _now.hour.toString().padLeft(2, '0');
    final m = _now.minute.toString().padLeft(2, '0');
    final s = _now.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  String get _formattedDate {
    const months = ['1月','2月','3月','4月','5月','6月',
        '7月','8月','9月','10月','11月','12月'];
    return '${_now.year}年 ${months[_now.month - 1]}${_now.day}日';
  }

  Future<void> _loadCounts() async {
    setState(() => isLoading = true);
    try {
      final r1 = await http.post(Uri.parse(_baseUrl),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'type': 'getAllUsers'}));
      final r2 = await http.post(Uri.parse(_baseUrl),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'type': 'getAllReports'}));
      final r3 = await http.post(Uri.parse(_baseUrl),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'type': 'getInventory'}));
      final d1 = jsonDecode(r1.body);
      final d2 = jsonDecode(r2.body);
      final d3 = jsonDecode(r3.body);
      setState(() {
        userCount         = d1['success'] == true ? (d1['data'] as List).length : 0;
        healthReportCount = d2['success'] == true ? (d2['data'] as List).length : 0;
        _emergencyCount   = d2['success'] == true ? (d2['data'] as List).length : 0;
        _supplyCount      = d3['success'] == true ? (d3['data'] as List).length : 0;
      });
    } catch (e) { debugPrint('load error: $e'); }
    setState(() => isLoading = false);
  }

  Future<void> _loadAlerts() async {
    if (_alertsLoading) return;
    setState(() => _alertsLoading = true);
    try {
      final all = await WeatherService.fetchAllAlerts(apiKey: _cwaKey);
      // 只保留 24 小時內，最多 20 筆
      final filtered = all
          .where((a) => DateTime.now().difference(a.time).inHours < 24)
          .take(20)
          .toList()
        ..sort((a, b) => b.time.compareTo(a.time));
      if (!mounted) return;
      setState(() {
        _disasterAlerts    = filtered;
        _notificationCount = filtered.length;
        _rebuildTimeline();
      });
    } catch (e) { debugPrint('alert error: $e'); }
    if (mounted) setState(() => _alertsLoading = false);
  }

  void _rebuildTimeline() {
    final List<TimelineEvent> events = [];
    for (final alert in _disasterAlerts.take(8)) {
      Color c;
      switch (alert.type) {
        case DisasterType.earthquake: c = Colors.redAccent; break;
        case DisasterType.typhoon:    c = Colors.orangeAccent; break;
        case DisasterType.rain:
        case DisasterType.flood:      c = kCyan; break;
        default:                      c = kMuted;
      }
      events.add(TimelineEvent(id: alert.id, title: alert.title,
          subtitle: alert.description, time: alert.time,
          color: c, category: 'disaster'));
    }
    if (_supplyCount > 0) {
      events.add(TimelineEvent(id: 'supply_check', title: '物資盤點完成',
          subtitle: '共 $_supplyCount 項物資，庫存狀態更新',
          time: DateTime.now().subtract(const Duration(hours: 1)),
          color: kGreen, category: 'supply'));
    }
    events.sort((a, b) => b.time.compareTo(a.time));
    _timeline = events;
  }

  void _go(int i) => setState(() => selectedIndex = i);

  void _logout() {
    showDialog(context: context, builder: (_) => AlertDialog(
      backgroundColor: kCardBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      title: const Text('確認登出', style: TextStyle(color: Colors.white)),
      content: const Text('確定要登出系統嗎？', style: TextStyle(color: kMuted)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            Navigator.pushAndRemoveUntil(context,
                MaterialPageRoute(builder: (_) => const LoginPage()), (_) => false);
          },
          style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
          child: const Text('登出'),
        ),
      ],
    ));
  }

  void _showShelterMap() => showDialog(context: context,
      barrierColor: Colors.black.withOpacity(.7),
      builder: (_) => const ShelterMapDialog());

  void _showNotifications() => showDialog(context: context,
      barrierColor: Colors.black.withOpacity(.5),
      builder: (_) => _NotificationDialog(
          alerts: _disasterAlerts, onClose: () => Navigator.pop(context)));

  void _showAlertDetail(DisasterAlert alert) => showDialog(context: context,
      barrierColor: Colors.black.withOpacity(.5),
      builder: (_) => _AlertDetailDialog(
          alert: alert, onClose: () => Navigator.pop(context)));

  Widget _currentPage() {
    switch (selectedIndex) {
      case 1: return const UserManagementPage();
      case 2: return CitizenPage();
      case 3: return EmergencyPage();
      case 4: return SupplyPage();
      case 5: return const HealthReportPage();
      default: return _buildDashboard();
    }
  }

  String get _pageTitle {
    const t = ['指揮中心','用戶管理','災民管理','緊急事件','物資管理','健康回報'];
    return t[selectedIndex];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: Row(children: [_buildSidebar(), Expanded(child: _currentPage())]),
    );
  }

  // ══════════════════════════════════════════════════════════
  //  SIDEBAR
  // ══════════════════════════════════════════════════════════
  Widget _buildSidebar() {
    return Container(
      width: 260,
      decoration: BoxDecoration(
        color: kSidebarBg,
        border: Border(right: BorderSide(color: kBorderBright)),
        boxShadow: [BoxShadow(color: kBlue.withOpacity(.15),
            blurRadius: 20, offset: const Offset(4, 0))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.fromLTRB(14, 20, 14, 16),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: kBorderBright))),
          child: Row(children: [
            Container(width: 38, height: 38,
              decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [kBlue, kCyan]),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [BoxShadow(color: kCyan.withOpacity(.3), blurRadius: 12, spreadRadius: 1)]),
              child: const Icon(Icons.settings_input_antenna, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('災難管理系統', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
              SizedBox(height: 2),
              Text('EMERGENCY COMMAND', style: TextStyle(color: kMuted, fontSize: 9, letterSpacing: 1.2)),
            ])),
          ]),
        ),
        const SizedBox(height: 16),
        Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text('主要功能', style: TextStyle(color: kMuted.withOpacity(.7), fontSize: 10, letterSpacing: 1.5))),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Column(children: [
            _navItem(0, Icons.grid_view_rounded,         '指揮中心'),
            _navItem(1, Icons.people_alt_outlined,       '用戶管理'),
            _navItem(2, Icons.accessibility_new_rounded, '災民管理'),
            _navItem(3, Icons.warning_amber_rounded,     '緊急事件'),
            _navItem(4, Icons.inventory_2_outlined,      '物資管理'),
            _navItem(5, Icons.favorite_border_rounded,   '健康回報'),
          ]),
        ),
        const Spacer(),
        Container(
          margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: kGreen.withOpacity(.06),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: kGreen.withOpacity(.2))),
          child: Row(children: [
            Container(width: 8, height: 8,
                decoration: BoxDecoration(color: kGreen, shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: kGreen.withOpacity(.6), blurRadius: 6)])),
            const SizedBox(width: 8),
            const Text('系統運作正常', style: TextStyle(color: kGreen, fontSize: 12, fontWeight: FontWeight.bold)),
          ]),
        ),
        Container(
          margin: const EdgeInsets.fromLTRB(10, 0, 10, 8),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: kCardBg, borderRadius: BorderRadius.circular(8),
              border: Border.all(color: kBorderBright)),
          child: Row(children: [
            Container(width: 32, height: 32,
              decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [kBlue, kCyan.withOpacity(.8)]),
                  shape: BoxShape.circle),
              child: const Center(child: Text('陳', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold))),
            ),
            const SizedBox(width: 10),
            const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('陳鎮長', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
              Text('管理員', style: TextStyle(color: kMuted, fontSize: 10)),
            ]),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 0, 10, 16),
          child: InkWell(
            borderRadius: BorderRadius.circular(8), onTap: _logout,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                  color: Colors.redAccent.withOpacity(.07),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.redAccent.withOpacity(.22))),
              child: const Row(children: [
                Icon(Icons.logout, color: Colors.redAccent, size: 16),
                SizedBox(width: 8),
                Text('登出系統', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 14)),
              ]),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _navItem(int idx, IconData icon, String label) {
    final sel = selectedIndex == idx;
    return Container(
      margin: const EdgeInsets.only(bottom: 3),
      child: InkWell(
        borderRadius: BorderRadius.circular(8), onTap: () => _go(idx),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            gradient: sel ? LinearGradient(colors: [kBlue.withOpacity(.25), kCyan.withOpacity(.08)]) : null,
            color: sel ? null : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: sel ? Border.all(color: kCyan.withOpacity(.3)) : null,
          ),
          child: Row(children: [
            Icon(icon, color: sel ? kCyan : kMuted, size: 18),
            const SizedBox(width: 10),
            Expanded(child: Text(label, style: TextStyle(
                color: sel ? Colors.white : kMuted,
                fontWeight: sel ? FontWeight.bold : FontWeight.w500,
                fontSize: 14))),
            if (sel) Container(width: 6, height: 6,
                decoration: BoxDecoration(color: kCyan, shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: kCyan.withOpacity(.6), blurRadius: 6)])),
          ]),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  //  DASHBOARD
  // ══════════════════════════════════════════════════════════
  Widget _buildDashboard() {
    return SafeArea(
      child: Scrollbar(
        controller: _vCtrl, thumbVisibility: true,
        child: SingleChildScrollView(
          controller: _vCtrl,
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _buildTopBar(),
            const SizedBox(height: 14),
            _buildStatusStrip(),
            const SizedBox(height: 16),
            _buildStatsRow(),
            const SizedBox(height: 16),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: Column(children: [
                SizedBox(height: 320, child: const _TacticalMapCard()),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(child: SizedBox(height: 360,
                      child: _EventListCard(alerts: _disasterAlerts,
                          isLoading: _alertsLoading,
                          onRefresh: _loadAlerts, onAlertTap: _showAlertDetail))),
                  const SizedBox(width: 16),
                  Expanded(child: SizedBox(height: 360,
                      child: _TimelineCard(events: _timeline,
                          onEventTap: _showAlertDetail, alerts: _disasterAlerts))),
                ]),
              ])),
              const SizedBox(width: 16),
              SizedBox(width: 300, child: Column(children: [
                _ShelterCard(onTap: _showShelterMap),
                const SizedBox(height: 16),
                const _EnvironmentCard(),
                const SizedBox(height: 16),
                _buildQuickActions(),
              ])),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _buildStatsRow() {
    if (isLoading) {
      return Container(height: 100,
          decoration: BoxDecoration(color: kCardBg, borderRadius: BorderRadius.circular(12),
              border: Border.all(color: kBorderBright)),
          child: const Center(child: CircularProgressIndicator(color: kCyan)));
    }
    return Row(children: [
      Expanded(child: _statCard(Icons.people_alt_outlined, '$userCount', '用戶總數', kCyan, '↗ +0%', () => _go(1))),
      const SizedBox(width: 12),
      Expanded(child: _statCard(Icons.warning_amber_rounded, '$_emergencyCount', '求救事件', Colors.amber, '進行中', () => _go(3))),
      const SizedBox(width: 12),
      Expanded(child: _statCard(Icons.inventory_2_outlined, '$_supplyCount', '物資項目', kGreen, '充足', () => _go(4))),
      const SizedBox(width: 12),
      Expanded(child: _statCard(Icons.favorite_border, '$healthReportCount', '健康回報', Colors.pinkAccent, '今日', () => _go(5))),
    ]);
  }

  Widget _statCard(IconData icon, String value, String label, Color color, String badge, VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(12), onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [kCardBg, color.withOpacity(.08)]),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(.25)),
          boxShadow: [BoxShadow(color: color.withOpacity(.08), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Row(children: [
          Container(width: 44, height: 44,
              decoration: BoxDecoration(color: color.withOpacity(.12), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: color, size: 22)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(value, style: TextStyle(color: color, fontSize: 28, fontWeight: FontWeight.bold, height: 1)),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(color: kMuted, fontSize: 12)),
          ])),
          Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(color: color.withOpacity(.12), borderRadius: BorderRadius.circular(4)),
            child: Text(badge, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
          ),
        ]),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: kCardBg, borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kBorderBright)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('快速操作', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        _quickBtn(Icons.people_alt_outlined,  '管理災民', kCyan,            () => _go(2)),
        const SizedBox(height: 8),
        _quickBtn(Icons.warning_amber_rounded,'緊急事件', Colors.amber,      () => _go(3)),
        const SizedBox(height: 8),
        _quickBtn(Icons.inventory_2_outlined, '物資管理', kGreen,            () => _go(4)),
        const SizedBox(height: 8),
        _quickBtn(Icons.favorite_border,      '健康回報', Colors.pinkAccent, () => _go(5)),
      ]),
    );
  }

  Widget _quickBtn(IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(8), onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(color: color.withOpacity(.06),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withOpacity(.2))),
        child: Row(children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 10),
          Text(label, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w600)),
          const Spacer(),
          Icon(Icons.chevron_right, color: color.withOpacity(.5), size: 16),
        ]),
      ),
    );
  }

  Widget _buildTopBar() {
    return Row(children: [
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(_pageTitle, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: .3)),
        const SizedBox(height: 2),
        Text('DISASTER MANAGEMENT SYSTEM', style: TextStyle(color: kMuted.withOpacity(.7), fontSize: 10, letterSpacing: 1.5)),
      ]),
      const SizedBox(width: 16),
      _statusChip('● 系統正常', kGreen),
      const Spacer(),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(color: kCardBg, borderRadius: BorderRadius.circular(8), border: Border.all(color: kBorderBright)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(_formattedDate, style: const TextStyle(color: kMuted, fontSize: 10)),
          Row(children: [
            const Icon(Icons.access_time, color: kCyan, size: 13),
            const SizedBox(width: 5),
            Text(_formattedTime, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: .5)),
          ]),
        ]),
      ),
      const SizedBox(width: 12),
      Stack(clipBehavior: Clip.none, children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(color: kCardBg, borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _notificationCount > 0 ? Colors.amberAccent.withOpacity(.4) : kBorderBright)),
          child: IconButton(
            onPressed: _showNotifications, padding: EdgeInsets.zero,
            icon: Icon(_notificationCount > 0 ? Icons.notifications_active : Icons.notifications_none,
              color: _notificationCount > 0 ? Colors.amberAccent : kMuted, size: 20),
          ),
        ),
        if (_notificationCount > 0)
          Positioned(top: -4, right: -4,
            child: Container(width: 18, height: 18,
              decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
              child: Center(child: Text(_notificationCount > 9 ? '9+' : '$_notificationCount',
                  style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold))),
            ),
          ),
      ]),
    ]);
  }

  Widget _buildStatusStrip() {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
          gradient: LinearGradient(colors: [kCardBg, kHighlight.withOpacity(.5), kCardBg]),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: kBorderBright)),
      child: Row(children: [
        _statusDot('系統運作正常', kGreen),
        _vline(),
        const Icon(Icons.signal_cellular_alt, color: kCyan, size: 13),
        const SizedBox(width: 5),
        _statusTxt('延遲 12ms', kCyan),
        _vline(),
        const Icon(Icons.radio_button_checked, color: Colors.amberAccent, size: 13),
        const SizedBox(width: 5),
        _statusTxt('監控頻道 CH-01', Colors.amberAccent),
        _vline(),
        if (_alertsLoading)
          const SizedBox(width: 12, height: 12,
              child: CircularProgressIndicator(strokeWidth: 2, color: kCyan))
        else if (_disasterAlerts.isNotEmpty)
          _statusTxt('⚠ ${_disasterAlerts.length} 則氣象通報', Colors.orange)
        else
          _statusTxt('氣象正常', kGreen),
        const Spacer(),
        Text('上次同步：剛剛', style: TextStyle(color: kMuted, fontSize: 11)),
        const SizedBox(width: 12),
        _pillBtn('↯ 即時監控中', kCyan),
      ]),
    );
  }

  Widget _statusDot(String t, Color c) => Row(children: [
    Container(width: 7, height: 7,
        decoration: BoxDecoration(color: c, shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: c.withOpacity(.6), blurRadius: 5)])),
    const SizedBox(width: 6),
    Text(t, style: TextStyle(color: c, fontWeight: FontWeight.bold, fontSize: 12)),
  ]);

  static Widget _statusTxt(String t, Color c) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Text(t, style: TextStyle(color: c, fontWeight: FontWeight.bold, fontSize: 12)));

  static Widget _vline() => Container(width: 1, height: 20, color: kBorderBright,
      margin: const EdgeInsets.symmetric(horizontal: 4));

  Widget _pillBtn(String text, Color color) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(.10),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: color.withOpacity(.26))),
      child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11)));

  Widget _statusChip(String text, Color color) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(.10),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: color.withOpacity(.26))),
      child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11)));
}

// ══════════════════════════════════════════════════════════
//  TACTICAL MAP CARD（雷達掃描戰術地圖）
// ══════════════════════════════════════════════════════════
class _TacticalMapCard extends StatefulWidget {
  const _TacticalMapCard();
  @override
  State<_TacticalMapCard> createState() => _TacticalMapCardState();
}

class _TacticalMapCardState extends State<_TacticalMapCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: kCardBg, borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kBorderBright)),
      clipBehavior: Clip.hardEdge,
      child: Stack(children: [
        Positioned.fill(child: CustomPaint(painter: GridPainter())),
        Positioned.fill(child: AnimatedBuilder(animation: _ctrl,
            builder: (_, __) => CustomPaint(painter: _RadarSweepPainter(_ctrl.value)))),
        // 標題列
        Positioned(top: 14, left: 14, right: 14,
          child: Row(children: [
            Container(width: 36, height: 36,
              decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [kBlue, kCyan]),
                  borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.location_on_outlined, color: Colors.white, size: 17),
            ),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: const [
                Text('戰術態勢圖', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                SizedBox(width: 8),
                _Badge(text: 'LIVE', color: kGreen),
              ]),
              const Text('SECTOR: 埔里鎮 | GRID: 23.96N 120.96E',
                  style: TextStyle(color: kCyan, fontSize: 10)),
            ]),
            const Spacer(),
            const _Chip('● 1 ACTIVE THREAT', Colors.redAccent),
            const SizedBox(width: 8),
            const _Chip('↯ SCANNING...', kCyan),
          ]),
        ),
        // HUD
        const Positioned(left: 14, top: 68, child: _HudBox(text: 'FRAME: 1248')),
        const Positioned(left: 120, top: 68, child: _HudBox(text: 'FPS: 60')),
        const Positioned(right: 14, top: 68, child: _HudBox(text: 'UTC+8 08:32:14')),
        // 地圖主體
        const Positioned(left: 14, top: 96, right: 14, bottom: 8, child: _MapBody()),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  MAP BODY
// ══════════════════════════════════════════════════════════
class _MapBody extends StatelessWidget {
  const _MapBody();

  @override
  Widget build(BuildContext context) {
    return Stack(clipBehavior: Clip.hardEdge, children: [
      // 紅色警戒圈
      Positioned(left: 40,  top: 10, child: _c(140, Colors.red, .04)),
      Positioned(left: 58,  top: 28, child: _c(104, Colors.red, .07)),
      Positioned(left: 76,  top: 46, child: _c(68,  Colors.red, .11)),
      // 警戒核心
      Positioned(left: 90, top: 60,
        child: Container(width: 40, height: 40,
          decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.deepOrange,
              boxShadow: [BoxShadow(color: Colors.red.withOpacity(.7), blurRadius: 16, spreadRadius: 4)]),
          child: const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 20),
        ),
      ),
      // 威脅面板
      Positioned(left: 145, top: 45, child: _threatPanel()),
      // 避難所標記
      Positioned(left: 360, top: 25,  child: _dot('埔里鎮公所',       const Color(0xFF00E5A8))),
      Positioned(left: 280, top: 75,  child: _dot('埔里國中活動中心', const Color(0xFF00E5A8))),
      Positioned(left: 390, top: 120, child: _dot('宏仁國中體育館',   const Color(0xFF00E5A8))),
      Positioned(left: 210, top: 135, child: _dot('眉溪水位監測站',   const Color(0xFF00B7FF))),
      Positioned(left: 260, top: 170, child: _dot('消防局物資站',     const Color(0xFF7D5CFF))),
      // 圖例
      Positioned(left: 8, bottom: 6, child: _legendBox()),
      // 座標
      const Positioned(right: 6, bottom: 36, child: _HudBox(text: 'COORDS   23.9642°N, 120.9682°E')),
      const Positioned(right: 6, bottom: 6,  child: _HudBox(text: 'ZOOM   14x   RANGE   2.5km')),
    ]);
  }

  static Widget _c(double s, Color c, double o) => Container(width: s, height: s,
      decoration: BoxDecoration(shape: BoxShape.circle,
          color: c.withOpacity(o), border: Border.all(color: c.withOpacity(.15))));

  static Widget _dot(String t, Color c) => Row(children: [
    Container(width: 10, height: 10,
        decoration: BoxDecoration(color: c, shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: c.withOpacity(.6), blurRadius: 10, spreadRadius: 2)])),
    const SizedBox(width: 6),
    Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(color: const Color(0xCC060C14),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: c.withOpacity(.2))),
        child: Text(t, style: TextStyle(color: c, fontSize: 10))),
  ]);

  static Widget _threatPanel() => Container(
      width: 200, padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: const Color(0xCC080E16),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.redAccent.withOpacity(.35))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('● THREAT ACTIVE', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 11)),
        const SizedBox(height: 5),
        const Text('土石流警戒', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 3),
        const Text('中山路北段 | 中度風險', style: TextStyle(color: Color(0xFF4A6580), fontSize: 10)),
        const SizedBox(height: 7),
        Row(children: [
          Container(padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(color: Colors.redAccent.withOpacity(.12),
                  borderRadius: BorderRadius.circular(3)),
              child: const Text('LV.2', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 9))),
          const SizedBox(width: 6),
          const Text('影響距離: 500m', style: TextStyle(color: Color(0xFF4A6580), fontSize: 9)),
        ]),
      ]));

  static Widget _legendBox() => Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(color: const Color(0xCC060C14),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: kBorderBright)),
      child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('圖例 LEGEND', style: TextStyle(color: kMuted, fontSize: 8, letterSpacing: .8)),
        SizedBox(height: 4),
        _LegendDot(color: Colors.redAccent,       text: '災害警戒區'),
        _LegendDot(color: Color(0xFF00E5A8),      text: '避難收容所'),
        _LegendDot(color: Color(0xFF7D5CFF),      text: '物資集散站'),
        _LegendDot(color: Color(0xFF00B7FF),      text: '環境監測站'),
      ]));
}

// ══════════════════════════════════════════════════════════
//  ENVIRONMENT CARD（接 WeatherViewModel）
// ══════════════════════════════════════════════════════════
class _EnvironmentCard extends StatelessWidget {
  const _EnvironmentCard();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<WeatherViewModel>();
    final offline = vm.isOffline || vm.rainfallStations.isEmpty;
    final st = vm.rainfallStations.isNotEmpty ? vm.rainfallStations.first : null;
    final rain = (st != null && st.stationId != 'MOCK')
        ? '${st.rainfall24Hr.toStringAsFixed(1)}mm' : '--';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: kCardBg, borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kBorderBright)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.cloud_outlined, color: kCyan, size: 16),
          const SizedBox(width: 8),
          const Text('環境監測', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
          const Spacer(),
          if (vm.isLoading)
            const SizedBox(width: 14, height: 14,
                child: CircularProgressIndicator(strokeWidth: 2, color: kCyan))
          else
            _badge(offline ? '離線' : '即時', offline ? Colors.orange : kGreen),
          const SizedBox(width: 8),
          InkWell(onTap: () => vm.refresh(),
              child: const Icon(Icons.refresh, color: kMuted, size: 14)),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: _envBox(Icons.water_drop_outlined, kCyan, '累積雨量', rain, '過去24小時')),
          const SizedBox(width: 12),
          Expanded(child: _envBox(Icons.air, kGreen, 'AQI 空氣',
              vm.aqi > 0 ? '${vm.aqi}' : '--', vm.aqiStatus)),
        ]),
        if (!offline && st != null) ...[
          const SizedBox(height: 10),
          Row(children: [
            const Icon(Icons.location_on, color: kMuted, size: 10),
            const SizedBox(width: 4),
            Text('${st.stationName} 測站', style: const TextStyle(color: kMuted, fontSize: 10)),
            const Spacer(),
            Text('PM2.5: ${vm.aqiStation?.pm25.toStringAsFixed(1) ?? '--'} μg/m³',
                style: const TextStyle(color: kMuted, fontSize: 10)),
          ]),
        ],
      ]),
    );
  }

  static Widget _badge(String s, Color c) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(color: c.withOpacity(.12),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: c.withOpacity(.3))),
      child: Text(s, style: TextStyle(color: c, fontSize: 10, fontWeight: FontWeight.bold)));

  static Widget _envBox(IconData icon, Color ic, String label, String value, String sub) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          gradient: LinearGradient(colors: [ic.withOpacity(.06), Colors.transparent]),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: ic.withOpacity(.2))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, color: ic, size: 13),
          const SizedBox(width: 5),
          Text(label, style: const TextStyle(color: kMuted, fontSize: 12)),
        ]),
        const SizedBox(height: 6),
        Text(value, style: TextStyle(color: ic, fontSize: 26, fontWeight: FontWeight.bold)),
        Text(sub, style: const TextStyle(color: kMuted, fontSize: 9)),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  ALERT DETAIL DIALOG
// ══════════════════════════════════════════════════════════
class _AlertDetailDialog extends StatelessWidget {
  final DisasterAlert alert;
  final VoidCallback onClose;
  const _AlertDetailDialog({required this.alert, required this.onClose});

  Color get _color {
    switch (alert.type) {
      case DisasterType.earthquake: return Colors.redAccent;
      case DisasterType.typhoon:    return Colors.orangeAccent;
      case DisasterType.rain:       return kCyan;
      default:                      return kMuted;
    }
  }
  IconData get _icon {
    switch (alert.type) {
      case DisasterType.earthquake: return Icons.vibration;
      case DisasterType.typhoon:    return Icons.air;
      case DisasterType.rain:       return Icons.water_drop;
      default:                      return Icons.warning_amber;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 420,
        decoration: BoxDecoration(color: kCardBg, borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _color.withOpacity(.35)),
            boxShadow: [BoxShadow(color: _color.withOpacity(.15), blurRadius: 30, spreadRadius: 2)]),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 18, 16, 16),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: _color.withOpacity(.2)))),
            child: Row(children: [
              Container(width: 40, height: 40,
                  decoration: BoxDecoration(color: _color.withOpacity(.12), borderRadius: BorderRadius.circular(8)),
                  child: Icon(_icon, color: _color, size: 20)),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(alert.title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 3),
                Row(children: [
                  _sevBadge(alert.severity),
                  const SizedBox(width: 8),
                  Text('氣象署通報', style: TextStyle(color: _color.withOpacity(.7), fontSize: 11)),
                ]),
              ])),
              IconButton(onPressed: onClose,
                  icon: const Icon(Icons.close, color: Colors.white54, size: 18),
                  padding: EdgeInsets.zero, constraints: const BoxConstraints()),
            ]),
          ),
          Padding(padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _row(Icons.location_on_outlined, '地點', alert.location),
              const SizedBox(height: 12),
              _row(Icons.description_outlined, '說明', alert.description),
              const SizedBox(height: 12),
              _row(Icons.access_time, '時間', _fmt(alert.time)),
              const SizedBox(height: 20),
              Container(width: double.infinity, padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: kCyan.withOpacity(.06),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: kCyan.withOpacity(.2))),
                child: Row(children: [
                  Icon(Icons.info_outline, color: kCyan.withOpacity(.7), size: 14),
                  const SizedBox(width: 8),
                  const Expanded(child: Text('此通報來自中央氣象署自動發布系統，\n非用戶端求救訊號。',
                      style: TextStyle(color: kMuted, fontSize: 11, height: 1.5))),
                ]),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _row(IconData icon, String label, String value) =>
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: kMuted, size: 15),
        const SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(color: kMuted, fontSize: 11)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
        ]),
      ]);

  Widget _sevBadge(String s) {
    final c = s == '重度' ? Colors.redAccent : s == '中度' ? Colors.orange : kGreen;
    return Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(color: c.withOpacity(.15), borderRadius: BorderRadius.circular(4)),
        child: Text(s, style: TextStyle(color: c, fontSize: 10, fontWeight: FontWeight.bold)));
  }

  String _fmt(DateTime t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '${t.year}/${t.month}/${t.day}  $h:$m';
  }
}

// ══════════════════════════════════════════════════════════
//  NOTIFICATION DIALOG
// ══════════════════════════════════════════════════════════
class _NotificationDialog extends StatelessWidget {
  final List<DisasterAlert> alerts;
  final VoidCallback onClose;
  const _NotificationDialog({required this.alerts, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      alignment: const Alignment(0.85, -0.8),
      child: Container(
        width: 360, constraints: const BoxConstraints(maxHeight: 480),
        decoration: BoxDecoration(color: kCardBg, borderRadius: BorderRadius.circular(10),
            border: Border.all(color: kBorderBright),
            boxShadow: [BoxShadow(color: kCyan.withOpacity(.08), blurRadius: 30)]),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 12),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: kBorderBright))),
            child: Row(children: [
              const Icon(Icons.notifications_active, color: Colors.amberAccent, size: 16),
              const SizedBox(width: 8),
              Text('氣象署通報 (${alerts.length})',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(width: 6),
              Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: kCyan.withOpacity(.1), borderRadius: BorderRadius.circular(3)),
                child: const Text('24h內', style: TextStyle(color: kCyan, fontSize: 9, fontWeight: FontWeight.bold)),
              ),
              const Spacer(),
              IconButton(onPressed: onClose,
                  icon: const Icon(Icons.close, color: Colors.white54, size: 16),
                  padding: EdgeInsets.zero, constraints: const BoxConstraints()),
            ]),
          ),
          if (alerts.isEmpty)
            const Padding(padding: EdgeInsets.all(24),
                child: Text('目前沒有任何氣象通報', style: TextStyle(color: kMuted)))
          else
            Flexible(child: ListView.builder(
              shrinkWrap: true, itemCount: alerts.length,
              itemBuilder: (_, i) {
                final a = alerts[i];
                Color c; IconData icon;
                switch (a.type) {
                  case DisasterType.earthquake: c = Colors.redAccent; icon = Icons.vibration; break;
                  case DisasterType.typhoon: c = Colors.orangeAccent; icon = Icons.air; break;
                  case DisasterType.rain: c = kCyan; icon = Icons.water_drop; break;
                  default: c = kMuted; icon = Icons.warning_amber;
                }
                return Container(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  decoration: BoxDecoration(border: Border(bottom: BorderSide(color: kBorderBright.withOpacity(.5)))),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(width: 32, height: 32,
                        decoration: BoxDecoration(color: c.withOpacity(.12), borderRadius: BorderRadius.circular(6)),
                        child: Icon(icon, color: c, size: 15)),
                    const SizedBox(width: 10),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(a.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 3),
                      Text(a.description, style: const TextStyle(color: kMuted, fontSize: 11)),
                    ])),
                  ]),
                );
              },
            )),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  EVENT LIST CARD
// ══════════════════════════════════════════════════════════
class _EventListCard extends StatelessWidget {
  final List<DisasterAlert> alerts;
  final bool isLoading;
  final VoidCallback onRefresh;
  final ValueChanged<DisasterAlert> onAlertTap;
  const _EventListCard({required this.alerts, required this.isLoading,
      required this.onRefresh, required this.onAlertTap});

  Color _sev(String s) => s == '重度' ? Colors.redAccent : s == '中度' ? Colors.orange : kGreen;

  static String _ago(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return '剛剛';
    if (d.inMinutes < 60) return '${d.inMinutes} 分鐘前';
    if (d.inHours < 24) return '${d.inHours} 小時前';
    return '${d.inDays} 天前';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: kCardBg, borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kBorderBright)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('⚡ 即時事件動態', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(width: 6),
          Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: kCyan.withOpacity(.08),
                borderRadius: BorderRadius.circular(3), border: Border.all(color: kCyan.withOpacity(.2))),
            child: const Text('24h｜最多20筆', style: TextStyle(color: kCyan, fontSize: 9, fontWeight: FontWeight.bold)),
          ),
          const Spacer(),
          InkWell(borderRadius: BorderRadius.circular(4), onTap: onRefresh,
            child: Padding(padding: const EdgeInsets.all(5),
              child: isLoading
                  ? const SizedBox(width: 14, height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: kCyan))
                  : const Icon(Icons.refresh, color: kCyan, size: 16)),
          ),
        ]),
        const SizedBox(height: 12),
        if (alerts.isEmpty)
          Expanded(child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.check_circle_outline, color: kGreen, size: 32),
            const SizedBox(height: 8),
            const Text('24小時內無災害通報', style: TextStyle(color: kMuted, fontSize: 13)),
          ])))
        else
          Expanded(child: ListView.builder(
            itemCount: alerts.length,
            itemBuilder: (_, i) {
              final a = alerts[i];
              Color ic; IconData icon;
              switch (a.type) {
                case DisasterType.earthquake: ic = Colors.redAccent; icon = Icons.vibration; break;
                case DisasterType.typhoon: ic = Colors.orangeAccent; icon = Icons.air; break;
                case DisasterType.rain: ic = kCyan; icon = Icons.water_drop_outlined; break;
                default: ic = kMuted; icon = Icons.warning_amber;
              }
              return InkWell(
                borderRadius: BorderRadius.circular(8), onTap: () => onAlertTap(a),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [ic.withOpacity(.04), Colors.transparent]),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: ic.withOpacity(.15))),
                  child: Row(children: [
                    Container(width: 34, height: 34,
                        decoration: BoxDecoration(color: ic.withOpacity(.10), borderRadius: BorderRadius.circular(8)),
                        child: Icon(icon, color: ic, size: 17)),
                    const SizedBox(width: 10),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(a.title, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 3),
                      Text('${a.location}   ${_ago(a.time)}', overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: kMuted, fontSize: 11)),
                    ])),
                    Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: _sev(a.severity).withOpacity(.12),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: _sev(a.severity).withOpacity(.28))),
                      child: Text(a.severity, style: TextStyle(color: _sev(a.severity),
                          fontWeight: FontWeight.bold, fontSize: 10)),
                    ),
                  ]),
                ),
              );
            },
          )),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  TIMELINE CARD
// ══════════════════════════════════════════════════════════
class _TimelineCard extends StatelessWidget {
  final List<TimelineEvent> events;
  final ValueChanged<DisasterAlert> onEventTap;
  final List<DisasterAlert> alerts;
  const _TimelineCard({required this.events, required this.onEventTap, required this.alerts});

  static String _ago(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return '剛剛';
    if (d.inMinutes < 60) return '${d.inMinutes} 分鐘前';
    if (d.inHours < 24) return '${d.inHours} 小時前';
    return '${d.inDays} 天前';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: kCardBg, borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kBorderBright)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: const [
          Text('⏱ 事件時間軸', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
          Spacer(),
          Text('最近 24 小時', style: TextStyle(color: kMuted, fontSize: 11)),
        ]),
        const SizedBox(height: 14),
        if (events.isEmpty)
          const Expanded(child: Center(child: Text('尚無事件記錄', style: TextStyle(color: kMuted, fontSize: 13))))
        else
          Expanded(child: ListView.builder(
            itemCount: events.length,
            itemBuilder: (_, i) {
              final e = events[i];
              final isLast = i == events.length - 1;
              final match = alerts.where((a) => a.id == e.id).firstOrNull;
              return InkWell(
                borderRadius: BorderRadius.circular(6),
                onTap: match != null ? () => onEventTap(match) : null,
                child: Padding(padding: const EdgeInsets.only(bottom: 14),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Column(children: [
                      Container(width: 14, height: 14,
                          decoration: BoxDecoration(color: e.color, shape: BoxShape.circle,
                              boxShadow: [BoxShadow(color: e.color.withOpacity(.5), blurRadius: 6)])),
                      if (!isLast) Container(width: 1, height: 30, color: kBorderBright),
                    ]),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Text(_ago(e.time), style: const TextStyle(color: kMuted, fontSize: 10)),
                        const SizedBox(width: 8),
                        Expanded(child: Text(e.title, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13))),
                      ]),
                      const SizedBox(height: 3),
                      Text(e.subtitle, style: const TextStyle(color: kMuted, fontSize: 11)),
                    ])),
                  ]),
                ),
              );
            },
          )),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  SHELTER CARD
// ══════════════════════════════════════════════════════════
class _ShelterCard extends StatelessWidget {
  final VoidCallback onTap;
  const _ShelterCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12), onTap: onTap,
      child: Container(
        height: 88, padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            gradient: LinearGradient(colors: [kCardBg, Colors.amber.withOpacity(.06)]),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.amber.withOpacity(.3))),
        child: Row(children: [
          Container(width: 40, height: 40,
              decoration: BoxDecoration(color: Colors.amber.withOpacity(.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.amber.withOpacity(.3))),
              child: const Icon(Icons.apartment, color: Colors.amber, size: 20)),
          const SizedBox(width: 14),
          const Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('防空避難設施', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
            SizedBox(height: 5),
            Text('查看 5 處避難地點', style: TextStyle(color: Colors.amber, fontSize: 12)),
          ])),
          const Icon(Icons.chevron_right, color: Colors.amber, size: 20),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  PAINTERS
// ══════════════════════════════════════════════════════════
class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawRect(rect, Paint()..color = const Color(0xFF020C18));
    final tc = Offset(size.width * 0.18, size.height * 0.55);
    canvas.drawCircle(tc, size.height * 0.45,
        Paint()..shader = RadialGradient(colors: [
          const Color(0xFFFF2200).withOpacity(.15), Colors.transparent
        ]).createShader(Rect.fromCircle(center: tc, radius: size.height * 0.45)));
    final sc = Offset(size.width * 0.7, size.height * 0.35);
    canvas.drawCircle(sc, size.height * 0.4,
        Paint()..shader = RadialGradient(colors: [
          kBlue.withOpacity(.12), Colors.transparent
        ]).createShader(Rect.fromCircle(center: sc, radius: size.height * 0.4)));
    canvas.drawRect(rect, Paint()..shader = LinearGradient(
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [Colors.transparent, const Color(0xFF010608).withOpacity(.6)])
        .createShader(rect));
    final gp = Paint()..color = kCyan.withOpacity(.04)..strokeWidth = .5;
    for (double x = 0; x < size.width; x += 36)
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gp);
    for (double y = 0; y < size.height; y += 28)
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gp);
    final sp = Paint()..color = kBlue.withOpacity(.06)..strokeWidth = .8;
    for (double y = 0; y < size.height; y += 2.8)
      canvas.drawLine(Offset(0, y), Offset(size.width, y), sp);
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}

class _RadarSweepPainter extends CustomPainter {
  final double progress;
  _RadarSweepPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.18, size.height * 0.55);
    final radius = math.min(size.width, size.height) * 0.35;
    final angle = progress * 2 * math.pi;
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.save();
    canvas.clipRect(rect);
    final pulse = (math.sin(angle * 2) + 1) / 2;
    final glow = 0.03 + pulse * 0.08;
    canvas.drawRect(rect, Paint()..shader = RadialGradient(
        center: const Alignment(-0.65, 0.1), radius: 1.0,
        colors: [
          const Color(0xFF00FF88).withOpacity(glow * 1.4),
          const Color(0xFF00DD66).withOpacity(glow),
          const Color(0xFF00FF44).withOpacity(glow * 0.3),
          Colors.transparent,
        ],
        stops: const [0.0, 0.35, 0.65, 1.0]).createShader(rect));
    for (int i = 0; i < 3; i++) {
      canvas.drawCircle(center, radius * (0.33 + 0.33 * i),
          Paint()
            ..color = const Color(0xFF00FF88).withOpacity(0.15 + pulse * 0.12 - i * 0.04)
            ..strokeWidth = 0.8
            ..style = PaintingStyle.stroke);
    }
    final cRect = Rect.fromCircle(center: center, radius: radius);
    const tail = math.pi / 3.0;
    canvas.drawArc(cRect, angle - tail, tail, true,
        Paint()..shader = SweepGradient(
            startAngle: angle - tail, endAngle: angle,
            colors: [
              const Color(0xFF00FF88).withOpacity(.0),
              const Color(0xFF00FF88).withOpacity(.10),
              const Color(0xFF00FF88).withOpacity(.30),
            ],
            stops: const [0.0, 0.5, 1.0],
            transform: GradientRotation(angle - tail))
            .createShader(cRect)
          ..style = PaintingStyle.fill);
    canvas.drawLine(center,
        Offset(center.dx + radius * math.cos(angle), center.dy + radius * math.sin(angle)),
        Paint()
          ..color = const Color(0xFF00FF88).withOpacity(0.45 + pulse * 0.35)
          ..strokeWidth = 1.2);
    canvas.drawCircle(
        Offset(center.dx + radius * math.cos(angle), center.dy + radius * math.sin(angle)),
        2.5, Paint()..color = const Color(0xFF00FF88).withOpacity(0.6 + pulse * 0.4));
    canvas.restore();
  }

  @override
  bool shouldRepaint(_RadarSweepPainter old) => old.progress != progress;
}

// ══════════════════════════════════════════════════════════
//  SHARED WIDGETS
// ══════════════════════════════════════════════════════════
class _Chip extends StatelessWidget {
  final String text; final Color color;
  const _Chip(this.text, this.color);
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(.10),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: color.withOpacity(.26))),
      child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11)));
}

class _Badge extends StatelessWidget {
  final String text; final Color color;
  const _Badge({required this.text, required this.color});
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: color.withOpacity(.15), borderRadius: BorderRadius.circular(3)),
      child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: .8)));
}

class _HudBox extends StatelessWidget {
  final String text;
  const _HudBox({required this.text});
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(color: const Color(0xAA020C18),
          borderRadius: BorderRadius.circular(4), border: Border.all(color: kBorderBright)),
      child: Text(text, style: const TextStyle(color: kCyan, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: .8)));
}

class _LegendDot extends StatelessWidget {
  final Color color; final String text;
  const _LegendDot({required this.color, required this.text});
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(children: [
        CircleAvatar(radius: 4, backgroundColor: color),
        const SizedBox(width: 6),
        Text(text, style: const TextStyle(color: kMuted, fontSize: 9)),
      ]));
}

class ShelterItem extends StatelessWidget {
  final String name, distance;
  const ShelterItem({super.key, required this.name, required this.distance});
  @override
  Widget build(BuildContext context) => ListTile(
      dense: true,
      leading: const Icon(Icons.apartment, color: Colors.amber, size: 18),
      title: Text(name, style: const TextStyle(color: Colors.white, fontSize: 13)),
      subtitle: Text(distance, style: const TextStyle(color: kMuted, fontSize: 12)));
}

class MiniInfo extends StatelessWidget {
  final String title, value;
  const MiniInfo({super.key, required this.title, required this.value});
  @override
  Widget build(BuildContext context) => Container(
      height: 68,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: kCardBg2,
          borderRadius: BorderRadius.circular(8), border: Border.all(color: kBorderBright)),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(title, style: const TextStyle(color: kMuted, fontSize: 12)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
      ]));
}