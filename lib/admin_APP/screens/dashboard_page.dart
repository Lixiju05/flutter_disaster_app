import 'dart:async';
import 'dart:math' as Math;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart'  as ll ;
import 'package:flutter_disaster_app/core/models/emergency_request.dart';

import 'citizen_page.dart';
import 'emergency_page.dart';
import 'supply_page.dart';
import 'health_report_page.dart';
import 'login_page.dart';
import 'user_management_page.dart';
import 'shelter_map_dialog.dart';
import 'weather_service.dart';
import '../viewModels/weather_viewmodel.dart';
import '../viewModels/citizen_viewmodel.dart';
import '../viewModels/supply_viewmodel.dart';
import '../viewModels/emergency_viewmodel.dart';
import 'admin_setup_page.dart';
import 'area_data.dart';

// ══════════════════════════════════════════════════════════
//  THEME CONSTANTS
// ══════════════════════════════════════════════════════════
const Color kBg        = Color(0xFFF5F7FA);
const Color kCardBg    = Color(0xFFFFFFFF);
const Color kCardBg2   = Color(0xFFF8FAFC);
const Color kBorder    = Color(0xFFE5E7EB);

const Color kSidebarBg      = Color(0xFF1E3A5F);
const Color kSidebarBorder  = Color(0xFF2A4E7A);
const Color kSidebarTextSub = Color(0xFF7FA8CC);
const Color kSidebarSel     = Color(0xFF2A4E7A);

const Color kBlue   = Color(0xFF2563EB);
const Color kGreen  = Color(0xFF16A34A);
const Color kOrange = Color(0xFFF59E0B);
const Color kRed    = Color(0xFFDC2626);
const Color kTextMain = Color(0xFF0F172A);
const Color kTextSub  = Color(0xFF64748B);
const Color kMuted    = Color(0xFF64748B);

// ══════════════════════════════════════════════════════════
//  RADAR DATA
// ══════════════════════════════════════════════════════════
class RadarNodeStats {
  final String capacity;
  final String lastUpdate;
  const RadarNodeStats({this.capacity = '--', this.lastUpdate = '即時'});
}

class RadarNode {
  final String id, label, subtitle, description;
  final Color color;
  final IconData icon;
  final double relX, relY;
  final RadarNodeStats stats;
  const RadarNode({
    required this.id, required this.label, required this.subtitle,
    required this.description, required this.color, required this.icon,
    required this.relX, required this.relY,
    this.stats = const RadarNodeStats(),
  });
}

List<RadarNode> getNodesForArea(String adminArea) => [];

class AlertRadarNode {
  final DisasterAlert alert;
  final double relX, relY;
  const AlertRadarNode({required this.alert, required this.relX, required this.relY});
}

const Map<String, List<double>> kAreaCenterLatLng = {
  '花莲县': [23.9871, 121.6015], '南投縣': [23.9609, 120.9718],
  '台北市': [25.0330, 121.5654], '高雄市': [22.6273, 120.3014],
  '台中市': [24.1477, 120.6736], '台南市': [22.9999, 120.2269],
  '新北市': [25.0169, 121.4627], '桃园市': [24.9937, 121.3010],
  '宜兰县': [24.7021, 121.7377], '台东县': [22.7972, 121.1047],
  '屏东县': [22.5519, 120.5487],
};

List<AlertRadarNode> buildAlertNodes(List<DisasterAlert> alerts, String adminArea) {
  final city   = AreaDataHelper.toCityName(adminArea);
  final center = kAreaCenterLatLng[city] ?? [23.9871, 121.6015];
  final cLat = center[0], cLng = center[1];
  const radiusKm = 80.0;
  final kmPerLat = 111.0;
  final kmPerLng = 111.0 * Math.cos(cLat * Math.pi / 180);
  final result = <AlertRadarNode>[];
  final seen = <String>{};
  for (final alert in alerts) {
    if (result.length >= 5) break;
    double? aLat, aLng;
    final dirReg = RegExp(r'([东西南北]{1,3})\s*方?\s*(\d+\.?\d*)\s*公里');
    final m = dirReg.firstMatch('${alert.description} ${alert.location}');
    if (m != null) {
      final dir = m.group(1) ?? '';
      final dist = double.tryParse(m.group(2) ?? '') ?? 30.0;
      double dLat = 0, dLng = 0;
      if (dir.contains('北')) dLat =  dist / kmPerLat;
      if (dir.contains('南')) dLat = -dist / kmPerLat;
      if (dir.contains('东')) dLng =  dist / kmPerLng;
      if (dir.contains('西')) dLng = -dist / kmPerLng;
      aLat = cLat + dLat; aLng = cLng + dLng;
    }
    if (aLat == null) {
      final fb = [[cLat+0.18,cLng+0.12],[cLat-0.22,cLng+0.28],[cLat+0.08,cLng-0.18],[cLat-0.12,cLng-0.22],[cLat+0.28,cLng+0.22]];
      aLat = fb[result.length % fb.length][0];
      aLng = fb[result.length % fb.length][1];
    }
    final dxKm = (aLng! - cLng) * kmPerLng;
    final dyKm = (aLat  - cLat) * kmPerLat;
    double relX = (0.5 + (dxKm / radiusKm) * 0.40).clamp(0.12, 0.88);
    double relY = (0.5 - (dyKm / radiusKm) * 0.40).clamp(0.12, 0.88);
    final key = '${(relX*10).round()}_${(relY*10).round()}';
    if (seen.contains(key)) { relX = (relX+0.07).clamp(0.12,0.88); relY = (relY+0.07).clamp(0.12,0.88); }
    seen.add(key);
    result.add(AlertRadarNode(alert: alert, relX: relX, relY: relY));
  }
  return result;
}

// ══════════════════════════════════════════════════════════
//  TIMELINE EVENT
// ══════════════════════════════════════════════════════════
class TimelineEvent {
  final String id, title, subtitle, category;
  final DateTime time;
  final Color color;
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
  static const String _cwaKey = 'CWA-AFE44442-4E97-4836-A31F-0D743B56732B';

  int selectedIndex = 0;
  String _adminName = '管理員', _adminTitle = '管理員', _adminArea = '南投縣';

  late Timer _clockTimer, _alertTimer, _envTimer;
  DateTime _now = DateTime.now();
  DateTime? _lastSyncTime;

  List<DisasterAlert> _disasterAlerts = [];
  List<TimelineEvent> _timeline = [];
  bool _alertsLoading = false;
  int  _notificationCount = 0;

  final ScrollController _vCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadAdminInfo();
    _loadCounts();
    _startClock();
    _loadAlerts();
    _alertTimer = Timer.periodic(const Duration(minutes: 5),  (_) => _loadAlerts());
    _envTimer   = Timer.periodic(const Duration(minutes: 10), (_) {
      if (mounted) context.read<WeatherViewModel>().refresh();
    });
  }

  @override
  void dispose() {
    _clockTimer.cancel(); _alertTimer.cancel(); _envTimer.cancel(); _vCtrl.dispose();
    super.dispose();
  }

  void _startClock() {
    _clockTimer = Timer.periodic(const Duration(seconds: 1),
        (_) { if (mounted) setState(() => _now = DateTime.now()); });
  }

  String get _formattedTime =>
      '${_now.hour.toString().padLeft(2,'0')}:${_now.minute.toString().padLeft(2,'0')}:${_now.second.toString().padLeft(2,'0')}';

  String get _formattedDate {
    const months = ['1月','2月','3月','4月','5月','6月','7月','8月','9月','10月','11月','12月'];
    return '${_now.year}年${months[_now.month-1]}${_now.day}日';
  }

  String get _lastSyncText {
    if (_lastSyncTime == null) return '從未同步';
    final diff = DateTime.now().difference(_lastSyncTime!);
    if (diff.inSeconds < 60) return '剛剛';
    if (diff.inMinutes < 60) return '${diff.inMinutes} 分鐘前';
    return '${diff.inHours} 小時前';
  }

  String get _pageTitle {
    const t = ['指揮中心','用戶管理','災民管理','緊急事件','物資管理','健康回報'];
    return t[selectedIndex];
  }

  Future<void> _loadAdminInfo() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _adminName  = prefs.getString('adminName')  ?? '管理員';
      _adminTitle = prefs.getString('adminTitle') ?? '管理員';
      _adminArea  = prefs.getString('adminArea')  ?? '南投縣';
    });
  }

  void _loadCounts() {
    context.read<CitizenViewmodel>().loadCitizens();
    context.read<AdminSupplyViewModel>().loadSupplies();
    context.read<EmergencyViewModel>().loadEmergencies();
  }

  Future<void> _loadAlerts() async {
    if (_alertsLoading) return;
    final vm = context.read<WeatherViewModel>();
    if (vm.isSimulation) {
      setState(() {
        _disasterAlerts = vm.alerts;
        _notificationCount = vm.alerts.length;
        _lastSyncTime = DateTime.now();
        _rebuildTimeline();
      });
      return;
    }
    setState(() => _alertsLoading = true);
    try {
      final all = await WeatherService.fetchAllAlerts(apiKey: _cwaKey);
      final result = all
          .where((a) => DateTime.now().difference(a.time).inDays < 30)
          .toList()..sort((a, b) => b.time.compareTo(a.time));
      if (!mounted) return;
      setState(() {
        _disasterAlerts = result.take(30).toList();
        _notificationCount = _disasterAlerts.length;
        _lastSyncTime = DateTime.now();
        _rebuildTimeline();
      });
    } catch (e) {
      debugPrint('alert error: $e');
      if (!mounted) return;
      setState(() {
        _disasterAlerts = []; _notificationCount = 0;
        _lastSyncTime = DateTime.now();
        _rebuildTimeline();
      });
    }
    if (mounted) setState(() => _alertsLoading = false);
  }

  void _rebuildTimeline() {
    final supplyCount = context.read<AdminSupplyViewModel>().supplies.length;
    final List<TimelineEvent> events = [];
    for (final alert in _disasterAlerts.take(15)) {
      events.add(TimelineEvent(
        id: alert.id, title: alert.title,
        subtitle: '${alert.location} · ${alert.severity}',
        time: alert.time, color: _alertColor(alert.type), category: 'disaster',
      ));
    }
    if (supplyCount > 0) {
      events.add(TimelineEvent(
        id: 'supply_check', title: '物資盤點完成',
        subtitle: '共 $supplyCount 項物資，庫存狀態更新',
        time: DateTime.now().subtract(const Duration(hours: 1)),
        color: kGreen, category: 'supply',
      ));
    }
    events.sort((a, b) => b.time.compareTo(a.time));
    _timeline = events;
  }

  Color _alertColor(DisasterType type) {
    switch (type) {
      case DisasterType.earthquake: return kRed;
      case DisasterType.typhoon:    return kOrange;
      case DisasterType.landslide:  return Colors.deepOrange;
      case DisasterType.flood:      return kBlue;
      case DisasterType.rain:       return kBlue;
      default:                      return kMuted;
    }
  }

  void _go(int i) => setState(() => selectedIndex = i);

  void _toggleMode() {
    final vm = context.read<WeatherViewModel>();
    vm.toggleMode();
    setState(() { _disasterAlerts = []; _alertsLoading = false; });
    _loadAlerts();
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        backgroundColor: vm.isSimulation ? kOrange : kGreen,
        behavior: SnackBarBehavior.floating,
        content: Text(vm.isSimulation ? '已切換至警戒模擬模式' : '已切換至正常模式',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ));
  }

  void _logout() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title:   const Text('確認登出', style: TextStyle(color: kTextMain)),
        content: const Text('確定要登出系統嗎？', style: TextStyle(color: kTextSub)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushAndRemoveUntil(context,
                  MaterialPageRoute(builder: (_) => const LoginPage()), (_) => false);
            },
            style: ElevatedButton.styleFrom(backgroundColor: kRed, foregroundColor: Colors.white),
            child: const Text('登出'),
          ),
        ],
      ),
    );
  }

  void _showNotifications() {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(.35),
      builder: (_) => _NotificationDialog(
        alerts: _disasterAlerts,
        onClose: () => Navigator.pop(context),
        onAlertTap: (alert) { Navigator.pop(context); _showAlertDetail(alert); },
      ),
    );
  }

  void _showAlertDetail(DisasterAlert alert) {
    showGeneralDialog(
      context: context, barrierDismissible: true, barrierLabel: '',
      barrierColor: Colors.black.withOpacity(.35),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (ctx, a1, a2) =>
          _AlertDetailDialog(alert: alert, onClose: () => Navigator.pop(ctx)),
      transitionBuilder: (ctx, anim1, anim2, child) {
        final curved = CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic);
        return SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, .10), end: Offset.zero).animate(curved),
          child: FadeTransition(opacity: curved, child: child),
        );
      },
    );
  }

  Widget _currentPage() {
    switch (selectedIndex) {
      case 1: return const UserManagementPage();
      case 2: return const CitizenPage();
      case 3: return EmergencyPage();
      case 4: return const SupplyPage();
      case 5: return const HealthReportPage(showSearch: true);
      default: return _buildDashboard();
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<WeatherViewModel>();
    return Scaffold(
      backgroundColor: kBg,
      body: Row(children: [_buildSidebar(vm), Expanded(child: _currentPage())]),
    );
  }

  // ── SIDEBAR ─────────────────────────────────────────────
  Widget _buildSidebar(WeatherViewModel vm) {
    return Container(
      width: 260,
      decoration: const BoxDecoration(color: kSidebarBg),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _buildLogo(),
        const SizedBox(height: 14),
        _buildModeBox(vm),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 8),
          child: Text('主要功能',
              style: TextStyle(color: kSidebarTextSub, fontSize: 11,
                  fontWeight: FontWeight.w600, letterSpacing: 0.8)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
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
        _buildSystemStatus(vm),
        _buildAdminBox(),
        _buildLogoutButton(),
      ]),
    );
  }

  Widget _buildLogo() => Container(
    padding: const EdgeInsets.fromLTRB(18, 22, 18, 18),
    decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: kSidebarBorder))),
    child: Row(children: [
      Container(width: 40, height: 40,
          decoration: BoxDecoration(color: Colors.white.withOpacity(.15), borderRadius: BorderRadius.circular(12)),
          child: const Icon(Icons.shield_outlined, color: Colors.white, size: 22)),
      const SizedBox(width: 12),
      const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('災難管理系統', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800)),
        SizedBox(height: 2),
        Text('EMERGENCY COMMAND', style: TextStyle(color: kSidebarTextSub, fontSize: 11, letterSpacing: 1.1)),
      ])),
    ]),
  );

  Widget _buildModeBox(WeatherViewModel vm) {
    final color = vm.isSimulation ? kOrange : const Color(0xFF34D399);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12), onTap: _toggleMode,
        child: Container(
          width: double.infinity, padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(.08), borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(.12))),
          child: Row(children: [
            Icon(vm.isSimulation ? Icons.science_outlined : Icons.cloud_done_outlined, color: color, size: 18),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(vm.isSimulation ? '警戒模擬模式' : '正常模式',
                  style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 13)),
              const SizedBox(height: 2),
              const Text('近30天與即時資料', style: TextStyle(color: kSidebarTextSub, fontSize: 11)),
            ])),
            Text('切換', style: TextStyle(color: color, fontSize: 11)),
          ]),
        ),
      ),
    );
  }

  Widget _navItem(int idx, IconData icon, String label) {
    final sel = selectedIndex == idx;
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: InkWell(
        borderRadius: BorderRadius.circular(10), onTap: () => _go(idx),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: sel ? kSidebarSel : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: sel ? Border.all(color: Colors.white.withOpacity(.12)) : null),
          child: Row(children: [
            Icon(icon, color: sel ? Colors.white : kSidebarTextSub, size: 19),
            const SizedBox(width: 12),
            Expanded(child: Text(label,
                style: TextStyle(color: sel ? Colors.white : kSidebarTextSub,
                    fontWeight: sel ? FontWeight.w700 : FontWeight.w500, fontSize: 14))),
            if (sel) Container(width: 4, height: 4,
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
          ]),
        ),
      ),
    );
  }

  Widget _buildSystemStatus(WeatherViewModel vm) {
    final color = vm.isSimulation ? kOrange : const Color(0xFF34D399);
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.06), borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(.10))),
      child: Row(children: [
        Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Text(vm.isSimulation ? '模擬警戒中' : '系統運作正常',
            style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 13)),
      ]),
    );
  }

  Widget _buildAdminBox() => Container(
    margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(.06), borderRadius: BorderRadius.circular(10),
      border: Border.all(color: Colors.white.withOpacity(.10))),
    child: Row(children: [
      CircleAvatar(
        radius: 18, backgroundColor: Colors.white.withOpacity(.18),
        child: Text(_adminName.isNotEmpty ? _adminName[0] : '管',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800))),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(_adminName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
        Text('$_adminTitle · $_adminArea',
            style: const TextStyle(color: kSidebarTextSub, fontSize: 11), overflow: TextOverflow.ellipsis),
      ])),
      IconButton(
        visualDensity: VisualDensity.compact,
        onPressed: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminSetupPage(isEdit: true)));
          await _loadAdminInfo(); _loadAlerts();
        },
        icon: Icon(Icons.edit_outlined, color: kSidebarTextSub.withOpacity(.8), size: 16)),
    ]),
  );

  Widget _buildLogoutButton() => Padding(
    padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
    child: InkWell(
      borderRadius: BorderRadius.circular(10), onTap: _logout,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: kRed.withOpacity(.15), borderRadius: BorderRadius.circular(10),
          border: Border.all(color: kRed.withOpacity(.30))),
        child: const Row(children: [
          Icon(Icons.logout, color: Color(0xFFFC8181), size: 17),
          SizedBox(width: 10),
          Text('登出系統', style: TextStyle(color: Color(0xFFFC8181), fontWeight: FontWeight.w700, fontSize: 14)),
        ]),
      ),
    ),
  );

  // ── DASHBOARD MAIN ───────────────────────────────────────
  Widget _buildDashboard() {
    final vm = context.watch<WeatherViewModel>();
    return SafeArea(
      child: Scrollbar(
        controller: _vCtrl, thumbVisibility: true,
        child: SingleChildScrollView(
          controller: _vCtrl,
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _buildTopBar(vm),
            const SizedBox(height: 14),
            if (vm.isSimulation) ...[_buildSimulationBanner(), const SizedBox(height: 14)],
            _buildStatusStrip(vm),
            const SizedBox(height: 16),
            _buildStatsRow(),
            const SizedBox(height: 16),
            SizedBox(
              height: 360,
              child: Row(children: [
                Expanded(flex: 5, child: Builder(builder: (context) {
                  final cityName = AreaDataHelper.toCityName(_adminArea);
                  final radarAlerts = _disasterAlerts.where((a) => a.location.contains(cityName)).toList();
                  return _TacticalMapCard(
                    alerts: radarAlerts, isSimulation: vm.isSimulation,
                    adminArea: _adminArea, onAlertTap: _showAlertDetail);
                })),
                const SizedBox(width: 16),
                Expanded(flex: 7, child: _GpsEmergencyMapCard(adminArea: _adminArea, onViewAll: () => _go(3))),
              ]),
            ),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: SizedBox(height: 420, child: _EventListCard(
                alerts: _disasterAlerts, isLoading: _alertsLoading,
                isSimulation: vm.isSimulation, onRefresh: _loadAlerts, onAlertTap: _showAlertDetail))),
              const SizedBox(width: 16),
              Expanded(child: SizedBox(height: 420, child: _TimelineCard(
                events: _timeline, alerts: _disasterAlerts, onEventTap: _showAlertDetail))),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _buildTopBar(WeatherViewModel vm) => Row(children: [
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(_pageTitle, style: const TextStyle(color: kTextMain, fontSize: 28, fontWeight: FontWeight.w800),
          overflow: TextOverflow.ellipsis, maxLines: 1),
      const SizedBox(height: 2),
      const Text('DISASTER MANAGEMENT SYSTEM',
          style: TextStyle(color: kTextSub, fontSize: 12, letterSpacing: 1.4),
          overflow: TextOverflow.ellipsis, maxLines: 1),
    ])),
    const SizedBox(width: 12),
    _statusChip(vm.isSimulation ? '模擬警戒中' : '系統正常', vm.isSimulation ? kOrange : kGreen),
    const SizedBox(width: 12),
    _timeBox(),
    const SizedBox(width: 12),
    _notificationButton(),
  ]);

  Widget _timeBox() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 9),
    decoration: BoxDecoration(color: kCardBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: kBorder)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
      Text(_formattedDate, style: const TextStyle(color: kTextSub, fontSize: 11)),
      const SizedBox(height: 2),
      Row(children: [
        const Icon(Icons.access_time, color: kBlue, size: 14),
        const SizedBox(width: 5),
        Text(_formattedTime, style: const TextStyle(color: kTextMain, fontSize: 16, fontWeight: FontWeight.w800)),
      ]),
    ]),
  );

  Widget _notificationButton() => Stack(clipBehavior: Clip.none, children: [
    Container(
      width: 42, height: 42,
      decoration: BoxDecoration(color: kCardBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: kBorder)),
      child: IconButton(
        onPressed: _showNotifications, padding: EdgeInsets.zero,
        icon: Icon(_notificationCount > 0 ? Icons.notifications_active_outlined : Icons.notifications_none,
            color: _notificationCount > 0 ? kOrange : kTextSub, size: 21)),
    ),
    if (_notificationCount > 0)
      Positioned(top: -4, right: -4, child: Container(
        width: 18, height: 18,
        decoration: const BoxDecoration(color: kRed, shape: BoxShape.circle),
        child: Center(child: Text(
          _notificationCount > 9 ? '9+' : '$_notificationCount',
          style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800))))),
  ]);

  Widget _buildSimulationBanner() => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
    decoration: BoxDecoration(
      color: kOrange.withOpacity(.08), borderRadius: BorderRadius.circular(10),
      border: Border.all(color: kOrange.withOpacity(.22))),
    child: Row(children: [
      const Icon(Icons.science_outlined, color: kOrange, size: 18),
      const SizedBox(width: 10),
      const Expanded(child: Text('警戒模擬模式：目前顯示為展示情境，非真實即時資料。',
          style: TextStyle(color: kTextMain, fontSize: 13, fontWeight: FontWeight.w600))),
      TextButton(onPressed: _toggleMode, child: const Text('切換回正常模式')),
    ]),
  );

  Widget _buildStatusStrip(WeatherViewModel vm) => Container(
    height: 46, padding: const EdgeInsets.symmetric(horizontal: 16),
    decoration: BoxDecoration(color: kCardBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: kBorder)),
    child: Row(children: [
      _statusDot(vm.isSimulation ? '模擬警戒中' : '系統運作正常', vm.isSimulation ? kOrange : kGreen),
      _vline(), Flexible(child: _statusText('延迟 12ms', kBlue)),
      _vline(), Flexible(child: _statusText('监控频道 CH-01', kTextSub)),
      _vline(),
      if (_alertsLoading)
        const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: kBlue))
      else
        Flexible(child: _statusText(_disasterAlerts.isNotEmpty ? '${_disasterAlerts.length} 則通報' : '近期無重大警報',
            _disasterAlerts.isNotEmpty ? kOrange : kGreen)),
      const Spacer(),
      Flexible(child: Text('上次同步：$_lastSyncText', style: const TextStyle(color: kTextSub, fontSize: 13), overflow: TextOverflow.ellipsis)),
      const SizedBox(width: 8),
      _pillBtn(vm.isSimulation ? '模擬模式' : '即時監控中', vm.isSimulation ? kOrange : kBlue),
    ]),
  );

  Widget _buildStatsRow() {
    final citizenVm   = context.watch<CitizenViewmodel>();
    final supplyVm    = context.watch<AdminSupplyViewModel>();
    final emergencyVm = context.watch<EmergencyViewModel>();
    if (citizenVm.isLoading || supplyVm.isLoading || emergencyVm.isLoading) {
      return _card(height: 104, child: const Center(child: CircularProgressIndicator(color: kBlue)));
    }
    final pendingSos = emergencyVm.emergencies.where((e) => e.status != 'resolved').length;
return Row(children: [
  Expanded(child: _statCard(Icons.people_alt_outlined, '${citizenVm.citizens.length}', '用戶總數', kBlue, '查看', () => _go(1))),
  const SizedBox(width: 12),
  Expanded(child: _statCard(Icons.sos_rounded, '$pendingSos', 'SOS 求救中', kRed, '處理中', () => _go(3))),
  const SizedBox(width: 12),
  Expanded(child: _statCard(Icons.favorite_border, '${emergencyVm.emergencies.where((e) => e.status == 'resolved').length}', '已處理事件', kGreen, '今日', () => _go(3))),
  const SizedBox(width: 12),
  Expanded(child: _statCard(Icons.inventory_2_outlined, '${supplyVm.supplies.length}', '物資項目', kOrange, '庫存', () => _go(4))),
]);
  }

  Widget _statCard(IconData icon, String value, String label, Color color, String badge, VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(14), onTap: onTap,
      child: _card(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12), child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 34, height: 34,
              decoration: BoxDecoration(color: color.withValues(alpha: .10), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: color, size: 17)),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: TextStyle(color: color, fontSize: 26, fontWeight: FontWeight.w800, height: 1.1)),
          ),
          const SizedBox(height: 3),
          Text(label, style: const TextStyle(color: kTextSub, fontSize: 11), overflow: TextOverflow.ellipsis, maxLines: 1),
        ],
      )),
    );
  }

  static Widget _statusDot(String text, Color color) => Row(children: [
    Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
    const SizedBox(width: 7),
    Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 13)),
  ]);
  static Widget _statusText(String text, Color color) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 10),
    child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13),
        overflow: TextOverflow.ellipsis, maxLines: 1));
  static Widget _vline() => Container(width: 1, height: 20, color: kBorder, margin: const EdgeInsets.symmetric(horizontal: 4));
  static Widget _pillBtn(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(color: color.withOpacity(.08), borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withOpacity(.18))),
    child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12)));
  static Widget _statusChip(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(color: color.withOpacity(.08), borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withOpacity(.18))),
    child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 13)));
}

// ══════════════════════════════════════════════════════════
//  TACTICAL MAP CARD（雷達圖）
// ══════════════════════════════════════════════════════════
class _TacticalMapCard extends StatefulWidget {
  final List<DisasterAlert> alerts;
  final bool isSimulation;
  final String adminArea;
  final ValueChanged<DisasterAlert> onAlertTap;
  const _TacticalMapCard({required this.alerts, required this.isSimulation, required this.adminArea, required this.onAlertTap});
  @override
  State<_TacticalMapCard> createState() => _TacticalMapCardState();
}

class _TacticalMapCardState extends State<_TacticalMapCard> with TickerProviderStateMixin {
  late final AnimationController _radarCtrl;
  late final AnimationController _blinkCtrl;
  @override
  void initState() {
    super.initState();
    _radarCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();
    _blinkCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);
  }
  @override
  void dispose() { _radarCtrl.dispose(); _blinkCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final alertNodes = buildAlertNodes(widget.alerts, widget.adminArea);
    return _card(padding: EdgeInsets.zero, child: Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
        child: Row(children: [
          Container(width: 38, height: 38,
              decoration: BoxDecoration(color: kBlue.withOpacity(.10), borderRadius: BorderRadius.circular(11)),
              child: const Icon(Icons.radar_rounded, color: kBlue)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('轄區防災雷達圖', style: TextStyle(color: kTextMain, fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 3),
            Text('${widget.adminArea}｜氣象署災害警報', style: const TextStyle(color: kTextSub, fontSize: 12)),
          ])),
          _smallBadge(widget.alerts.isEmpty ? '目前無警報' : '${widget.alerts.length} 則警報',
              widget.alerts.isEmpty ? kGreen : kOrange),
        ]),
      ),
      const Divider(height: 1, color: kBorder),
      Expanded(child: ClipRRect(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(14)),
        child: LayoutBuilder(builder: (ctx, constraints) {
          final w = constraints.maxWidth, h = constraints.maxHeight;
          return Stack(children: [
            Positioned.fill(child: AnimatedBuilder(
              animation: _radarCtrl,
              builder: (_, __) => CustomPaint(painter: _RadarMapPainter(
                angle: _radarCtrl.value * Math.pi * 2,
                hasAlerts: widget.alerts.isNotEmpty,
                isSimulation: widget.isSimulation)))),
            Center(child: _buildCenterNode(widget.adminArea)),
            for (final an in alertNodes) _buildAlertNode(an, w, h),
            Positioned(left: 18, bottom: 18, child: _RadarLegend(hasAlerts: widget.alerts.isNotEmpty)),
            Positioned(right: 14, bottom: 18,
                child: Text('點擊節點查看詳情', style: TextStyle(color: kTextSub.withOpacity(.6), fontSize: 11))),
          ]);
        }),
      )),
    ]));
  }

  Widget _buildCenterNode(String adminArea) {
    final label = adminArea.replaceAll('县','').replaceAll('市','');
    return Container(
      width: 74, height: 74,
      decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle,
          border: Border.all(color: kBlue, width: 2),
          boxShadow: [BoxShadow(color: kBlue.withOpacity(.18), blurRadius: 18, spreadRadius: 2)]),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: kBlue, fontSize: 13, fontWeight: FontWeight.w900)),
        const SizedBox(height: 2),
        const Text('指揮區', style: TextStyle(color: kTextSub, fontSize: 10)),
      ]),
    );
  }

  Widget _buildAlertNode(AlertRadarNode an, double w, double h) {
    final color = _typeColor(an.alert.type);
    return Positioned(
      left: w * an.relX - 44, top: h * an.relY - 42,
      child: GestureDetector(
        onTap: () => widget.onAlertTap(an.alert),
        child: AnimatedBuilder(
          animation: _blinkCtrl,
          builder: (_, __) => Opacity(
            opacity: 0.5 + _blinkCtrl.value * 0.5,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: color.withOpacity(.15), borderRadius: BorderRadius.circular(6), border: Border.all(color: color.withOpacity(.6))),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(_typeIcon(an.alert.type), color: color, size: 10),
                  const SizedBox(width: 4),
                  Text(an.alert.title.length > 8 ? '${an.alert.title.substring(0,8)}…' : an.alert.title,
                      style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w800)),
                ]),
              ),
              const SizedBox(height: 4),
              Container(width: 12, height: 12,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: color.withOpacity(.6), blurRadius: 10, spreadRadius: 2)])),
            ]),
          ),
        ),
      ),
    );
  }
}

class _RadarMapPainter extends CustomPainter {
  final double angle;
  final bool hasAlerts, isSimulation;
  const _RadarMapPainter({required this.angle, required this.hasAlerts, required this.isSimulation});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFFF8FAFC));
    final center = Offset(size.width / 2, size.height / 2);
    final maxR   = size.height * .46;
    final axis   = Paint()..color = const Color(0xFFE2E8F0)..strokeWidth = 1;
    canvas
      ..drawLine(Offset(center.dx, 0), Offset(center.dx, size.height), axis)
      ..drawLine(Offset(0, center.dy), Offset(size.width, center.dy), axis)
      ..drawLine(Offset(0, 0), Offset(size.width, size.height), axis)
      ..drawLine(Offset(size.width, 0), Offset(0, size.height), axis);
    final ringColor = (hasAlerts || isSimulation) ? kOrange.withOpacity(.35) : const Color(0xFFBFDBFE).withOpacity(.55);
    final ring = Paint()..color = ringColor..style = PaintingStyle.stroke..strokeWidth = 1;
    for (int i = 1; i <= 4; i++) canvas.drawCircle(center, maxR * i / 4, ring);
    final sweep = Path()..moveTo(center.dx, center.dy)
      ..arcTo(Rect.fromCircle(center: center, radius: maxR), angle, 0.78, false)..close();
    canvas.drawPath(sweep, Paint()..color = (isSimulation ? kOrange : kBlue).withOpacity(.12)..style = PaintingStyle.fill);
    final armColor = (isSimulation ? kOrange : kBlue).withOpacity(.50);
    final end = Offset(center.dx + maxR * Math.cos(angle), center.dy + maxR * Math.sin(angle));
    canvas.drawLine(center, end, Paint()..color = armColor..strokeWidth = 2.4..strokeCap = StrokeCap.round);
    final glow = Offset(center.dx + maxR * .72 * Math.cos(angle), center.dy + maxR * .72 * Math.sin(angle));
    canvas.drawCircle(glow, 4, Paint()..color = armColor.withOpacity(.80));
    final ns = TextStyle(color: kBlue.withOpacity(.35), fontSize: 10, fontWeight: FontWeight.w700);
    void dn(String t, Offset o) => (TextPainter(text: TextSpan(text: t, style: ns), textDirection: TextDirection.ltr)..layout()).paint(canvas, o);
    dn('1', Offset(center.dx + maxR*.34, center.dy - maxR*.34));
    dn('2', Offset(center.dx + maxR*.62, center.dy - maxR*.62));
    dn('3', Offset(center.dx - maxR*.18, center.dy + maxR*.66));
    dn('4', Offset(center.dx + maxR*.02, center.dy + maxR*.92));
  }

  @override
  bool shouldRepaint(covariant _RadarMapPainter old) =>
      old.angle != angle || old.hasAlerts != hasAlerts || old.isSimulation != isSimulation;
}

class _RadarLegend extends StatelessWidget {
  final bool hasAlerts;
  const _RadarLegend({this.hasAlerts = false});
  @override
  Widget build(BuildContext context) => Container(
    width: 130, padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(color: Colors.white.withOpacity(.94), borderRadius: BorderRadius.circular(10), border: Border.all(color: kBorder)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      const Text('圖例', style: TextStyle(color: kTextSub, fontSize: 9, fontWeight: FontWeight.w800)),
      const SizedBox(height: 6),
      if (hasAlerts) ...[
        const Divider(height: 10, color: kBorder),
        const _MiniLegend(color: kRed,    text: '地震警報', isAlert: true),
        const _MiniLegend(color: kOrange, text: '颱風警報', isAlert: true),
        const _MiniLegend(color: kBlue,   text: '水災警報', isAlert: true),
      ] else const Text('目前轄區無警報', style: TextStyle(color: kTextSub, fontSize: 10)),
    ]),
  );
}

class _MiniLegend extends StatelessWidget {
  final Color color; final String text; final bool isAlert;
  const _MiniLegend({required this.color, required this.text, this.isAlert = false});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 3),
    child: Row(children: [
      Container(width: 7, height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle,
              border: isAlert ? Border.all(color: color.withOpacity(.4), width: 2) : null)),
      const SizedBox(width: 6),
      Text(text, style: const TextStyle(color: kTextSub, fontSize: 10)),
    ]),
  );
}

// ══════════════════════════════════════════════════════════
//  ADMIN AREA BOUNDS
// ══════════════════════════════════════════════════════════
class _AdminAreaBounds {
  final String label;
  final double minLat, maxLat, minLng, maxLng;
  const _AdminAreaBounds({required this.label, required this.minLat, required this.maxLat, required this.minLng, required this.maxLng});

  bool contains(double lat, double lng) =>
      lat >= minLat && lat <= maxLat && lng >= minLng && lng <= maxLng;

  ll.LatLng get center => ll.LatLng((minLat + maxLat) / 2, (minLng + maxLng) / 2);

  double get zoom {
    final span = maxLat - minLat;
    if (span < 0.02) return 16.0;
    if (span < 0.06) return 14.0;
    if (span < 0.20) return 12.0;
    return 10.0;
  }

  List<ll.LatLng> get polygon => [
    ll.LatLng(maxLat, minLng), ll.LatLng(maxLat, maxLng),
    ll.LatLng(minLat, maxLng),ll.LatLng (minLat, minLng),
  ];

  static _AdminAreaBounds forArea(String area) {
    if (area.contains('暨大') || area.contains('暨南')) return const _AdminAreaBounds(label: '暨南大學', minLat: 23.930, maxLat: 23.985, minLng: 120.895, maxLng: 120.960);
    if (area.contains('南村')) return const _AdminAreaBounds(label: '南村里', minLat: 23.9350, maxLat: 23.9850, minLng: 120.9350, maxLng: 121.0000);
    if (area.contains('埔里')) return const _AdminAreaBounds(label: '埔里鎮', minLat: 23.9000, maxLat: 24.0500, minLng: 120.8800, maxLng: 121.0500);
    if (area.contains('南投')) return const _AdminAreaBounds(label: '南投縣', minLat: 23.4500, maxLat: 24.2500, minLng: 120.6000, maxLng: 121.3500);
    return const _AdminAreaBounds(label: '管理轄區', minLat: 23.9000, maxLat: 24.0500, minLng: 120.8800, maxLng: 121.0500);
  }
}

// ══════════════════════════════════════════════════════════
//  GPS EMERGENCY MAP CARD
// ══════════════════════════════════════════════════════════
class _GpsEmergencyMapCard extends StatelessWidget {
  final String adminArea;
  final VoidCallback onViewAll;
  const _GpsEmergencyMapCard({required this.adminArea, required this.onViewAll});

  @override
  Widget build(BuildContext context) {
    final vm     = context.watch<EmergencyViewModel>();
    final bounds = _AdminAreaBounds.forArea(adminArea);
    final sosOnly = vm.emergencies
    .where((e) => e.status != 'resolved')
    .toList()
  ..sort((a, b) => b.sentAt.compareTo(a.sentAt));

    return _card(padding: EdgeInsets.zero, child: Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
        child: Row(children: [
          Container(width: 38, height: 38,
              decoration: BoxDecoration(color: kRed.withOpacity(.10), borderRadius: BorderRadius.circular(11)),
              child: const Icon(Icons.sos_rounded, color: kRed)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('GPS 即時地圖 - $adminArea',
                style: const TextStyle(color: kTextMain, fontSize: 16, fontWeight: FontWeight.w800),
                overflow: TextOverflow.ellipsis, maxLines: 1),
            const SizedBox(height: 3),
            const Text('只顯示未處理 SOS 求救位置', style: TextStyle(color: kTextSub, fontSize: 12),
                overflow: TextOverflow.ellipsis, maxLines: 1),
          ])),
          sosOnly.isEmpty ? _smallBadge('目前无 SOS', kGreen) : _SosPendingBadge(count: sosOnly.length),
        ]),
      ),
      const Divider(height: 1, color: kBorder),
      Expanded(child: Row(children: [
        Expanded(flex: 7, child: Padding(
          padding: const EdgeInsets.all(14),
          child: _GpsMapCanvas(bounds: bounds, events: sosOnly))),
        Container(width: 1, color: kBorder),
        Expanded(flex: 4, child: _SosEventList(events: sosOnly, onViewAll: onViewAll)),
      ])),
    ]));
  }
}

// ══════════════════════════════════════════════════════════
//  ★ GPS MAP CANVAS — 真實 OpenStreetMap
// ══════════════════════════════════════════════════════════
class _GpsMapCanvas extends StatefulWidget {
  final _AdminAreaBounds bounds;
  final List<EmergencyRequest> events;
  const _GpsMapCanvas({required this.bounds, required this.events});
  @override
  State<_GpsMapCanvas> createState() => _GpsMapCanvasState();
}

class _GpsMapCanvasState extends State<_GpsMapCanvas> {
  late final MapController _mapCtrl;
  @override
  void initState() { super.initState(); _mapCtrl = MapController(); }
  @override
  void dispose() { _mapCtrl.dispose(); super.dispose(); }

  @override
  void didUpdateWidget(_GpsMapCanvas old) {
    super.didUpdateWidget(old);
    final boundsChanged = old.bounds.label != widget.bounds.label;
    final eventsChanged = old.events.length != widget.events.length;
    if (boundsChanged || eventsChanged) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (widget.events.isNotEmpty) {
          _fitToEvents();
        } else {
          _mapCtrl.move(widget.bounds.center, widget.bounds.zoom);
        }
      });
    }
  }

  void _fitToEvents() {
    if (widget.events.isEmpty) return;
    if (widget.events.length == 1) {
      _mapCtrl.move(ll.LatLng(widget.events.first.lat, widget.events.first.lng), 14.0);
      return;
    }
    final lats = widget.events.map((e) => e.lat);
    final lngs = widget.events.map((e) => e.lng);
    final minLat = lats.reduce((a, b) => a < b ? a : b);
    final maxLat = lats.reduce((a, b) => a > b ? a : b);
    final minLng = lngs.reduce((a, b) => a < b ? a : b);
    final maxLng = lngs.reduce((a, b) => a > b ? a : b);
    final centerLat = (minLat + maxLat) / 2;
    final centerLng = (minLng + maxLng) / 2;
    final span = maxLat - minLat;
    final zoom = span < 0.02 ? 14.0 : span < 0.10 ? 12.0 : span < 0.50 ? 10.0 : 8.0;
    _mapCtrl.move(ll.LatLng(centerLat, centerLng), zoom);
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Stack(children: [
        // ── 真實地圖 ───────────────────────────────────────
        FlutterMap(
          mapController: _mapCtrl,
          options: MapOptions(
            initialCenter: widget.bounds.center,
            initialZoom:   widget.bounds.zoom,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag),
          ),
          children: [
           TileLayer(
  urlTemplate: 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
  subdomains: const ['a', 'b', 'c', 'd'],
  userAgentPackageName: 'com.example.flutter_disaster_app',
  maxZoom: 19,
),
            // ★ 只有未處理 SOS 紅點
            MarkerLayer(markers: widget.events.map((e) {
              final name = e.userName.isNotEmpty ? e.userName : '用戶 ${e.userId}';
              return Marker(
                point: ll.LatLng(e.lat, e.lng),
                width: 44, height: 50,
                child: Tooltip(
                  message: '$name\n${e.status}\n${_relativeTime(e.sentAt)}',
                  child: const _SosMarkerWidget()),
              );
            }).toList()),
          ],
        ),

        // 轄區標籤
        Positioned(top: 12, left: 12, child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(color: Colors.white.withOpacity(.92), borderRadius: BorderRadius.circular(8), border: Border.all(color: kBorder)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.my_location_rounded, color: kBlue, size: 14),
            const SizedBox(width: 5),
            Text(widget.bounds.label, style: const TextStyle(color: kTextMain, fontSize: 12, fontWeight: FontWeight.w800)),
          ]),
        )),

        // 缩放按钮
        Positioned(right: 12, bottom: 12, child: Column(children: [
          _mapBtn(Icons.add,    () => _mapCtrl.move(_mapCtrl.camera.center, _mapCtrl.camera.zoom + 1)),
          const SizedBox(height: 4),
          _mapBtn(Icons.remove, () => _mapCtrl.move(_mapCtrl.camera.center, _mapCtrl.camera.zoom - 1)),
          const SizedBox(height: 4),
          _mapBtn(Icons.my_location_rounded, () => _mapCtrl.move(widget.bounds.center, widget.bounds.zoom)),
        ])),
      ]),
    );
  }

  Widget _mapBtn(IconData icon, VoidCallback onTap) => InkWell(
    onTap: onTap, borderRadius: BorderRadius.circular(6),
    child: Container(width: 30, height: 30,
        decoration: BoxDecoration(color: Colors.white.withOpacity(.94), borderRadius: BorderRadius.circular(6), border: Border.all(color: kBorder)),
        child: Icon(icon, size: 16, color: kTextMain)),
  );
}

// ══════════════════════════════════════════════════════════
//  SOS MARKER WIDGET（閃爍紅點）
// ══════════════════════════════════════════════════════════
class _SosMarkerWidget extends StatefulWidget {
  const _SosMarkerWidget();
  @override
  State<_SosMarkerWidget> createState() => _SosMarkerWidgetState();
}

class _SosMarkerWidgetState extends State<_SosMarkerWidget> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  @override
  void initState() { super.initState(); _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat(); }
  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Column(mainAxisSize: MainAxisSize.min, children: [
    SizedBox(width: 44, height: 44, child: Stack(alignment: Alignment.center, children: [
      AnimatedBuilder(animation: _ctrl, builder: (_, __) {
        final r = 16.0 + _ctrl.value * 14.0;
        return Opacity(opacity: (1 - _ctrl.value) * 0.55,
            child: Container(width: r*2, height: r*2, decoration: BoxDecoration(color: kRed.withOpacity(.30), shape: BoxShape.circle)));
      }),
      Container(width: 32, height: 32,
          decoration: BoxDecoration(color: kRed, shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2.5),
              boxShadow: [BoxShadow(color: kRed.withOpacity(.50), blurRadius: 10, spreadRadius: 2)]),
          child: const Center(child: Text('SOS', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: .5)))),
    ])),
    CustomPaint(size: const Size(12, 6), painter: _TrianglePainter(kRed)),
  ]);
}

class _TrianglePainter extends CustomPainter {
  final Color color;
  const _TrianglePainter(this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()..moveTo(0,0)..lineTo(size.width,0)..lineTo(size.width/2,size.height)..close();
    canvas.drawPath(path, Paint()..color = color..style = PaintingStyle.fill);
  }
  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// ══════════════════════════════════════════════════════════
//  SOS PENDING BADGE
// ══════════════════════════════════════════════════════════
class _SosPendingBadge extends StatefulWidget {
  final int count;
  const _SosPendingBadge({required this.count});
  @override
  State<_SosPendingBadge> createState() => _SosPendingBadgeState();
}

class _SosPendingBadgeState extends State<_SosPendingBadge> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  @override
  void initState() { super.initState(); _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))..repeat(reverse: true); }
  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _ctrl,
    builder: (_, __) => Opacity(opacity: 0.55 + _ctrl.value * 0.45,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: kRed.withOpacity(.12), borderRadius: BorderRadius.circular(999), border: Border.all(color: kRed.withOpacity(.35))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 7, height: 7, decoration: const BoxDecoration(color: kRed, shape: BoxShape.circle)),
          const SizedBox(width: 5),
          Text('求救中 ${widget.count}', style: const TextStyle(color: kRed, fontSize: 12, fontWeight: FontWeight.w800)),
        ]),
      )),
  );
}

// ══════════════════════════════════════════════════════════
//  BLINK DOT
// ══════════════════════════════════════════════════════════
class _BlinkDot extends StatefulWidget {
  const _BlinkDot();
  @override
  State<_BlinkDot> createState() => _BlinkDotState();
}

class _BlinkDotState extends State<_BlinkDot> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  @override
  void initState() { super.initState(); _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))..repeat(reverse: true); }
  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _ctrl,
    builder: (_, __) => Container(width: 8, height: 8,
        decoration: BoxDecoration(color: kRed.withOpacity(0.4 + _ctrl.value * 0.6), shape: BoxShape.circle)));
}

// ══════════════════════════════════════════════════════════
//  SOS EVENT LIST
// ══════════════════════════════════════════════════════════
class _SosEventList extends StatelessWidget {
  final List<EmergencyRequest> events;
  final VoidCallback onViewAll;
  const _SosEventList({required this.events, required this.onViewAll});

  @override
  Widget build(BuildContext context) => Column(children: [
    Padding(padding: const EdgeInsets.fromLTRB(14,14,14,8), child: Row(children: [
      const Expanded(child: Text('轄區 SOS 清單', style: TextStyle(color: kTextMain, fontSize: 14, fontWeight: FontWeight.w800))),
      if (events.isNotEmpty)
        Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(color: kRed.withOpacity(.10), borderRadius: BorderRadius.circular(20), border: Border.all(color: kRed.withOpacity(.25))),
            child: Text('${events.length} 件待處理', style: const TextStyle(color: kRed, fontSize: 11, fontWeight: FontWeight.w800))),
    ])),
    Expanded(child: events.isEmpty
        ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.check_circle_outline, color: kGreen, size: 32),
            const SizedBox(height: 8),
            const Text('目前無待處理 SOS', style: TextStyle(color: kGreen, fontSize: 13, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            const Text('轄區平安', style: TextStyle(color: kTextSub, fontSize: 12)),
          ]))
        : ListView.separated(
            padding: const EdgeInsets.fromLTRB(12,0,12,8),
            itemCount: events.take(6).length,
            separatorBuilder: (_, __) => const Divider(height: 1, color: kBorder),
            itemBuilder: (_, i) {
              final e = events[i];
              final name = e.userName.isNotEmpty ? e.userName : '用戶 ${e.userId}';
              return Padding(padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(width: 30, height: 30,
                      decoration: BoxDecoration(color: kRed.withOpacity(.10), shape: BoxShape.circle, border: Border.all(color: kRed.withOpacity(.25))),
                      child: const Icon(Icons.sos_rounded, color: kRed, size: 16)),
                  const SizedBox(width: 9),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: kTextMain, fontSize: 13, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text(e.status, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: kTextSub, fontSize: 11)),
                  ])),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
                    Text(_relativeTime(e.sentAt), style: const TextStyle(color: kTextSub, fontSize: 10),
                        overflow: TextOverflow.ellipsis, maxLines: 1),
                    const SizedBox(height: 4),
                    Container(padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(color: kOrange.withValues(alpha: .10), borderRadius: BorderRadius.circular(4)),
                        child: const Text('處理中', style: TextStyle(color: kOrange, fontSize: 9, fontWeight: FontWeight.w700))),
                  ]),
                ]));
            })),
    Padding(padding: const EdgeInsets.fromLTRB(12,0,12,12), child: InkWell(
      borderRadius: BorderRadius.circular(8), onTap: onViewAll,
      child: Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(color: kBlue.withOpacity(.06), borderRadius: BorderRadius.circular(8), border: Border.all(color: kBlue.withOpacity(.16))),
          child: const Center(child: Text('查看全部緊急事件 →', style: TextStyle(color: kBlue, fontSize: 12, fontWeight: FontWeight.w800)))))),
  ]);
}

// ══════════════════════════════════════════════════════════
//  ALERT DETAIL DIALOG
// ══════════════════════════════════════════════════════════
class _AlertDetailDialog extends StatelessWidget {
  final DisasterAlert alert;
  final VoidCallback  onClose;
  const _AlertDetailDialog({required this.alert, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final color = _typeColor(alert.type);
    return Dialog(backgroundColor: Colors.transparent, child: Container(
      width: 440,
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: kBorder)),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Padding(padding: const EdgeInsets.fromLTRB(18,16,12,14), child: Row(children: [
          Container(width: 42, height: 42,
              decoration: BoxDecoration(color: color.withOpacity(.10), borderRadius: BorderRadius.circular(12)),
              child: Icon(_typeIcon(alert.type), color: color)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(alert.title, style: const TextStyle(color: kTextMain, fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            _smallBadge(alert.severity, color),
          ])),
          IconButton(onPressed: onClose, icon: const Icon(Icons.close, color: kTextSub)),
        ])),
        const Divider(height: 1, color: kBorder),
        Padding(padding: const EdgeInsets.all(18), child: Column(children: [
          _dr(Icons.location_on_outlined, '地點', alert.location),
          const SizedBox(height: 12),
          _dr(Icons.description_outlined, '說明', alert.description),
          const SizedBox(height: 12),
          _dr(Icons.access_time,          '時間', _formatTime(alert.time)),
          const SizedBox(height: 16),
          Container(width: double.infinity, padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: kCardBg2, borderRadius: BorderRadius.circular(10), border: Border.all(color: kBorder)),
              child: const Text('資料來源：中央氣象署 / 水土保持署開放資料平台', style: TextStyle(color: kTextSub, fontSize: 12))),
        ])),
      ]),
    ));
  }

  static Widget _dr(IconData icon, String label, String value) =>
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: kTextSub, size: 18), const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(color: kTextSub, fontSize: 12)),
          const SizedBox(height: 3),
          Text(value, style: const TextStyle(color: kTextMain, fontSize: 13, fontWeight: FontWeight.w600)),
        ])),
      ]);
}

// ══════════════════════════════════════════════════════════
//  NOTIFICATION DIALOG
// ══════════════════════════════════════════════════════════
class _NotificationDialog extends StatelessWidget {
  final List<DisasterAlert> alerts;
  final VoidCallback onClose;
  final ValueChanged<DisasterAlert> onAlertTap;
  const _NotificationDialog({required this.alerts, required this.onClose, required this.onAlertTap});

  @override
  Widget build(BuildContext context) => Dialog(
    alignment: const Alignment(.86, -.80), backgroundColor: Colors.transparent,
    child: Container(width: 390, constraints: const BoxConstraints(maxHeight: 520),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: kBorder)),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Padding(padding: const EdgeInsets.fromLTRB(16,14,10,12), child: Row(children: [
          const Icon(Icons.notifications_active_outlined, color: kOrange, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text('災害通報 (${alerts.length})', style: const TextStyle(color: kTextMain, fontWeight: FontWeight.w800, fontSize: 15))),
          IconButton(onPressed: onClose, icon: const Icon(Icons.close, color: kTextSub, size: 18)),
        ])),
        const Divider(height: 1, color: kBorder),
        if (alerts.isEmpty)
          const Padding(padding: EdgeInsets.all(24), child: Text('近 30 天内没有災害通報', style: TextStyle(color: kTextSub)))
        else
          Flexible(child: ListView.separated(
            padding: const EdgeInsets.all(12), itemCount: alerts.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) => _EventListCard._alertTile(alerts[i], onAlertTap))),
      ]),
    ),
  );
}

// ══════════════════════════════════════════════════════════
//  EVENT LIST CARD
// ══════════════════════════════════════════════════════════
class _EventListCard extends StatelessWidget {
  final List<DisasterAlert> alerts;
  final bool isLoading, isSimulation;
  final VoidCallback onRefresh;
  final ValueChanged<DisasterAlert> onAlertTap;
  const _EventListCard({required this.alerts, required this.isLoading, required this.isSimulation, required this.onRefresh, required this.onAlertTap});

  @override
  Widget build(BuildContext context) => _card(padding: const EdgeInsets.all(16), child: Column(children: [
    Row(children: [
      const Icon(Icons.flash_on_rounded, color: kTextMain, size: 18),
      const SizedBox(width: 6),
      const Expanded(child: Text('即時事件動態', style: TextStyle(color: kTextMain, fontSize: 16, fontWeight: FontWeight.w800))),
      _smallBadge('30天｜最多30笔', kBlue),
      IconButton(onPressed: onRefresh, icon: const Icon(Icons.refresh, color: kBlue, size: 18)),
    ]),
    const SizedBox(height: 8),
    if (isLoading)
      const Expanded(child: Center(child: CircularProgressIndicator(color: kBlue)))
    else if (alerts.isEmpty)
      Expanded(child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.check_circle_outline, color: kGreen, size: 36),
        const SizedBox(height: 10),
        const Text('目前轄區平安', style: TextStyle(color: kGreen, fontWeight: FontWeight.w700, fontSize: 15)),
        const SizedBox(height: 4),
        const Text('近 30 天內沒有重大通報', style: TextStyle(color: kTextSub, fontSize: 13)),
      ])))
    else
      Expanded(child: ListView.separated(
        itemCount: alerts.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (ctx, i) => _alertTile(alerts[i], onAlertTap))),
  ]));

  static Widget _alertTile(DisasterAlert alert, ValueChanged<DisasterAlert> onTap) {
    final color = _typeColor(alert.type);
    return InkWell(
      borderRadius: BorderRadius.circular(10), onTap: () => onTap(alert),
      child: Container(padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: kCardBg2, borderRadius: BorderRadius.circular(10), border: Border.all(color: kBorder)),
        child: Row(children: [
          Container(width: 38, height: 38,
              decoration: BoxDecoration(color: color.withOpacity(.10), borderRadius: BorderRadius.circular(10)),
              child: Icon(_typeIcon(alert.type), color: color, size: 19)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(alert.title, style: const TextStyle(color: kTextMain, fontWeight: FontWeight.w800, fontSize: 14)),
            const SizedBox(height: 4),
            Text('${alert.location} · ${_formatTime(alert.time)}', maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: kTextSub, fontSize: 12)),
          ])),
          _smallBadge(alert.severity, color),
        ])),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  TIMELINE CARD
// ══════════════════════════════════════════════════════════
class _TimelineCard extends StatelessWidget {
  final List<TimelineEvent> events;
  final List<DisasterAlert> alerts;
  final ValueChanged<DisasterAlert> onEventTap;
  const _TimelineCard({required this.events, required this.alerts, required this.onEventTap});

  @override
  Widget build(BuildContext context) => _card(padding: const EdgeInsets.all(16), child: Column(children: [
    const Row(children: [
      Icon(Icons.timeline_rounded, color: kTextMain, size: 18), SizedBox(width: 7),
      Expanded(child: Text('事件時間轴', style: TextStyle(color: kTextMain, fontSize: 16, fontWeight: FontWeight.w800))),
      Text('最近 30 天', style: TextStyle(color: kTextSub, fontSize: 12)),
    ]),
    const SizedBox(height: 14),
    if (events.isEmpty)
      const Expanded(child: Center(child: Text('目前沒有事件紀錄', style: TextStyle(color: kTextSub))))
    else
      Expanded(child: ListView.builder(itemCount: events.length, itemBuilder: (ctx, i) {
        final e = events[i];
        return InkWell(
          onTap: () { final m = alerts.where((a) => a.id == e.id).toList(); if (m.isNotEmpty) onEventTap(m.first); },
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Column(children: [
              Container(width: 10, height: 10, decoration: BoxDecoration(color: e.color, shape: BoxShape.circle)),
              Container(width: 1, height: 54, color: kBorder),
            ]),
            const SizedBox(width: 12),
            Expanded(child: Padding(padding: const EdgeInsets.only(bottom: 15), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(e.title, style: const TextStyle(color: kTextMain, fontWeight: FontWeight.w800, fontSize: 14)),
              const SizedBox(height: 4),
              Text(e.subtitle, style: const TextStyle(color: kTextSub, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Text(_relativeTime(e.time), style: const TextStyle(color: kTextSub, fontSize: 11)),
            ]))),
          ]),
        );
      })),
  ]));
}

// ══════════════════════════════════════════════════════════
//  SHARED HELPERS
// ══════════════════════════════════════════════════════════
Widget _card({required Widget child, EdgeInsetsGeometry padding = const EdgeInsets.all(14), double? height}) =>
    Container(height: height, padding: padding,
      decoration: BoxDecoration(color: kCardBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: kBorder),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(.035), blurRadius: 12, offset: const Offset(0,4))]),
      child: child);

Widget _smallBadge(String text, Color color) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
  decoration: BoxDecoration(color: color.withOpacity(.08), borderRadius: BorderRadius.circular(999), border: Border.all(color: color.withOpacity(.16))),
  child: Text(text, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w800)));

Color _typeColor(DisasterType type) {
  switch (type) {
    case DisasterType.earthquake: return kRed;
    case DisasterType.typhoon:    return kOrange;
    case DisasterType.landslide:  return Colors.deepOrange;
    case DisasterType.flood:      return kBlue;
    case DisasterType.rain:       return kBlue;
    default:                      return kMuted;
  }
}

IconData _typeIcon(DisasterType type) {
  switch (type) {
    case DisasterType.earthquake: return Icons.vibration;
    case DisasterType.typhoon:    return Icons.air;
    case DisasterType.landslide:  return Icons.landslide_outlined;
    case DisasterType.flood:      return Icons.water;
    case DisasterType.rain:       return Icons.water_drop_outlined;
    default:                      return Icons.warning_amber_rounded;
  }
}

String _formatTime(DateTime t) =>
    '${t.year}/${t.month.toString().padLeft(2,'0')}/${t.day.toString().padLeft(2,'0')} ${t.hour.toString().padLeft(2,'0')}:${t.minute.toString().padLeft(2,'0')}';

String _relativeTime(DateTime t) {
  final diff = DateTime.now().difference(t);
  if (diff.inMinutes < 60) return '${diff.inMinutes} 分鐘前';
  if (diff.inHours   < 24) return '${diff.inHours} 小時前';
  return '${diff.inDays} 天前';
}