import 'dart:async';
import 'dart:math' as Math;
import 'package:flutter/material.dart';
import 'package:flutter_disaster_app/admin_APP/widgets/page_header.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart'  as ll ;
import 'package:flutter_disaster_app/core/models/emergency_request.dart';
import 'package:flutter_disaster_app/core/api_config.dart';
import 'package:flutter_disaster_app/core/models/supply_request.dart';
import 'package:flutter_disaster_app/core/repositories/admin_repository.dart';

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
const Color kSidebarTextSub = Color(0xFFB4CDE6);
const Color kSidebarSel     = Color(0xFF2A4E7A);

const Color kBlue   = Color(0xFF2563EB);
const Color kGreen  = Color(0xFF16A34A);
const Color kOrange = Color(0xFFF59E0B);
const Color kRed    = Color(0xFFDC2626);
const Color kTextMain = Color(0xFF0F172A);
const Color kTextSub  = Color(0xFF475569);
const Color kMuted    = Color(0xFF475569);

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
  '台北市': [25.0330, 121.5654], '新北市': [25.0169, 121.4627],
  '桃園市': [24.9937, 121.3010], '台中市': [24.1477, 120.6736],
  '台南市': [22.9999, 120.2269], '高雄市': [22.6273, 120.3014],
  '南投縣': [23.9609, 120.9718], '宜蘭縣': [24.7021, 121.7377],
  '花蓮縣': [23.9871, 121.6015], '台東縣': [22.7972, 121.1047],
  '屏東縣': [22.5519, 120.5487], '彰化縣': [24.0809, 120.5385],
  '雲林縣': [23.7092, 120.4313], '嘉義縣': [23.4518, 120.2555],
};

/// 篩出某地區的警報（氣象署用「臺」，地區清單用「台」，統一後比對）
List<DisasterAlert> alertsForArea(List<DisasterAlert> all, String area) {
  final city = AreaDataHelper.toCityName(area).replaceAll('臺', '台');
  return all.where((a) => a.location.replaceAll('臺', '台').contains(city)).toList();
}

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
    // 1) 地震：直接用氣象署提供的震央經緯度
    final epi = alert.raw['EarthquakeInfo']?['Epicenter'];
    if (epi is Map) {
      aLat = double.tryParse('${epi['EpicenterLatitude']}');
      aLng = double.tryParse('${epi['EpicenterLongitude']}');
    }
    // 2) 其他警報：從文字「XX方 N 公里」推算（繁簡體都可）
    final dirReg = RegExp(r'([東西南北东]{1,3})\s*方?\s*(\d+\.?\d*)\s*公里');
    final m = dirReg.firstMatch('${alert.description} ${alert.location}');
    if (aLat == null && m != null) {
      final dir = (m.group(1) ?? '').replaceAll('东', '東');
      final dist = double.tryParse(m.group(2) ?? '') ?? 30.0;
      double dLat = 0, dLng = 0;
      if (dir.contains('北')) dLat =  dist / kmPerLat;
      if (dir.contains('南')) dLat = -dist / kmPerLat;
      if (dir.contains('東')) dLng =  dist / kmPerLng;
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
  String _adminArea = '南投縣';

  late Timer _clockTimer, _alertTimer, _envTimer;
  DateTime _now = DateTime.now();

  List<DisasterAlert> _disasterAlerts = [];
  bool _alertsLoading = false;
  int  _notificationCount = 0;

  // 後端連線狀態（實際測量，不再寫死）
  bool? _backendOk;   // null = 檢查中
  late Timer _backendTimer;

  final ScrollController _vCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadAdminInfo();
    _loadCounts();
    _startClock();
    _loadAlerts();
    _alertTimer = Timer.periodic(const Duration(minutes: 5),  (_) => _loadAlerts());
    _checkBackend();
    _backendTimer = Timer.periodic(const Duration(seconds: 30), (_) => _checkBackend());
    _envTimer   = Timer.periodic(const Duration(minutes: 10), (_) {
      if (mounted) context.read<WeatherViewModel>().refresh();
    });
  }

  @override
  void dispose() {
    _clockTimer.cancel(); _alertTimer.cancel(); _envTimer.cancel(); _backendTimer.cancel(); _vCtrl.dispose();
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

  String get _pageTitle {
    const t = ['指揮中心','用戶管理','災民管理','緊急事件','物資管理','健康回報'];
    return t[selectedIndex];
  }

  Future<void> _loadAdminInfo() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _adminArea  = prefs.getString('adminArea')  ?? '南投縣';
    });
  }

  /// 實際呼叫後端，量測連線是否正常與回應時間
  Future<void> _checkBackend() async {
    final sw = Stopwatch()..start();
    bool ok;
    try {
      final res = await http.post(
        Uri.parse(ApiConfig.baseUrl),
        headers: {'Content-Type': 'application/json', 'ngrok-skip-browser-warning': 'true'},
        body: '{"type":"getInventory"}',
      ).timeout(const Duration(seconds: 8));
      ok = res.statusCode == 200;
    } catch (_) {
      ok = false;
    }
    sw.stop();
    if (!mounted) return;
    setState(() => _backendOk = ok);
  }

  String get _backendLabel => _backendOk == null
      ? '連線檢查中'
      : (_backendOk! ? '後端連線正常' : '後端未連線');

  void _loadCounts() {
    context.read<CitizenViewmodel>().loadCitizens();
    context.read<AdminSupplyViewModel>().loadSupplies();
    context.read<EmergencyViewModel>().loadEmergencies();
  }

  Future<void> _loadAlerts() async {
    if (_alertsLoading) return;
    setState(() => _alertsLoading = true);
    try {
      final all = await WeatherService.fetchAllAlerts(apiKey: _cwaKey);
      final result = all
          .where((a) => DateTime.now().difference(a.time).inDays < 7)
          .toList()..sort((a, b) => b.time.compareTo(a.time));
      if (!mounted) return;
      setState(() {
        _disasterAlerts = result.take(30).toList();
        _notificationCount = _disasterAlerts.length;
      });
    } catch (e) {
      debugPrint('alert error: $e');
      if (!mounted) return;
      setState(() {
        _disasterAlerts = []; _notificationCount = 0;
      });
    }
    if (mounted) setState(() => _alertsLoading = false);
  }


  void _go(int i) => setState(() { selectedIndex = i; _supplyTab = 0; });

  /// 物資管理要打開哪個分頁（0 庫存管理 / 1 據點管理 / 2 出貨紀錄）
  int _supplyTab = 0;
  void _goSupply(int tab) => setState(() { selectedIndex = 4; _supplyTab = tab; });

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
      case 4: return SupplyPage(key: ValueKey('supply-$_supplyTab'), initialTab: _supplyTab);
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
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 8),
          child: Text('主要功能',
              style: TextStyle(color: kSidebarTextSub, fontSize: 13,
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
        Text('EMERGENCY COMMAND', style: TextStyle(color: kSidebarTextSub, fontSize: 13, letterSpacing: 1.1)),
      ])),
    ]),
  );

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
                    fontWeight: sel ? FontWeight.w700 : FontWeight.w500, fontSize: 15))),
            if (sel) Container(width: 4, height: 4,
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
          ]),
        ),
      ),
    );
  }

  Widget _buildSystemStatus(WeatherViewModel vm) {
    final color = _backendOk == false ? const Color(0xFFFC8181) : const Color(0xFF34D399);
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.06), borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(.10))),
      child: Row(children: [
        Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Text(_backendLabel,
            style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 14)),
      ]),
    );
  }

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
          Text('登出系統', style: TextStyle(color: Color(0xFFFC8181), fontWeight: FontWeight.w700, fontSize: 15)),
        ]),
      ),
    ),
  );

  // ── DASHBOARD MAIN ───────────────────────────────────────
  Widget _buildDashboard() {
    final vm = context.watch<WeatherViewModel>();
    return SafeArea(
      child: Column(children: [
      _buildTopBar(vm),
      Expanded(child: Scrollbar(
        controller: _vCtrl, thumbVisibility: true,
        child: SingleChildScrollView(
          controller: _vCtrl,
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _buildStatsRow(),
            const SizedBox(height: 16),
            // GPS 即時地圖佔滿整排（拿掉雷達圖）
            SizedBox(
              height: 420,
              child: _GpsEmergencyMapCard(adminArea: _adminArea, onViewAll: () => _go(3)),
            ),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: SizedBox(height: 420, child: _EventListCard(
                alerts: _disasterAlerts, isLoading: _alertsLoading,
                onRefresh: _loadAlerts, onAlertTap: _showAlertDetail))),
              const SizedBox(width: 16),
              // 右邊：管理員現在要處理的事（全部是後端真實資料）
              Expanded(child: SizedBox(height: 420, child: _TodoCard(onGo: _go, onGoSupply: _goSupply))),
            ]),
          ]),
        ),
      )),
      ]),
    );
  }

  Widget _buildTopBar(WeatherViewModel vm) => PageHeader(
    title: _pageTitle,
    subtitle: 'DISASTER MANAGEMENT SYSTEM',
    actions: [
      _statusChip(_backendOk == false ? '後端未連線' : '系統正常', _backendOk == false ? kRed : kGreen),
      const SizedBox(width: 4),
      _timeBox(),
      const SizedBox(width: 4),
      _notificationButton(),
    ],
  );

  Widget _timeBox() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 9),
    decoration: BoxDecoration(color: kCardBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: kBorder)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
      Text(_formattedDate, style: const TextStyle(color: kTextSub, fontSize: 13)),
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
          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800))))),
  ]);

  Widget _buildStatsRow() {
    final citizenVm   = context.watch<CitizenViewmodel>();
    final supplyVm    = context.watch<AdminSupplyViewModel>();
    final emergencyVm = context.watch<EmergencyViewModel>();
    if (citizenVm.isLoading || supplyVm.isLoading || emergencyVm.isLoading) {
      return _card(height: 68, child: const Center(child: CircularProgressIndicator(color: kBlue)));
    }
    final pendingSos = emergencyVm.emergencies.where((e) => e.status != 'resolved').length;
return Row(children: [
  Expanded(child: _statCard(Icons.people_alt_outlined, '${citizenVm.citizens.length}', '用戶總數', kBlue, '查看', () => _go(1))),
  const SizedBox(width: 12),
  Expanded(child: _statCard(Icons.sos_rounded, '$pendingSos', 'SOS 求救中', kRed, '處理中', () => _go(3))),
  const SizedBox(width: 12),
  Expanded(child: _statCard(Icons.task_alt_rounded, '${emergencyVm.emergencies.where((e) => e.status == 'resolved').length}', '已處理事件', kGreen, '今日', () => _go(3))),
  const SizedBox(width: 12),
  Expanded(child: _statCard(Icons.inventory_2_outlined, '${supplyVm.supplies.length}', '物資項目', kOrange, '庫存', () => _go(4))),
]);
  }

  /// 橫向統計卡：左圖示、中間數字＋名稱、右邊箭頭（點擊跳到該頁）
  Widget _statCard(IconData icon, String value, String label, Color color, String badge, VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(14), onTap: onTap,
      child: _card(
        height: 68,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(children: [
          Container(width: 40, height: 40,
              decoration: BoxDecoration(color: color.withValues(alpha: .10), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: color, size: 20)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.w800, height: 1.1)),
                Text(label, style: const TextStyle(color: kTextSub, fontSize: 13), overflow: TextOverflow.ellipsis, maxLines: 1),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: Color(0xFFCBD5E1), size: 20),
        ]),
      ),
    );
  }

  static Widget _statusChip(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(color: color.withOpacity(.08), borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withOpacity(.18))),
    child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 14)));
}

// ══════════════════════════════════════════════════════════
/// 暨南國際大學校園範圍（資料來源：OpenStreetMap way 207630685），用來讓地圖框住校園
final List<ll.LatLng> kNcnuCampus = [
  ll.LatLng(23.944908, 120.922468), ll.LatLng(23.944027, 120.923839),
  ll.LatLng(23.944001, 120.926033), ll.LatLng(23.945060, 120.928115),
  ll.LatLng(23.945985, 120.929843), ll.LatLng(23.947465, 120.935224),
  ll.LatLng(23.950618, 120.936402), ll.LatLng(23.952518, 120.935720),
  ll.LatLng(23.954042, 120.935200), ll.LatLng(23.956551, 120.931352),
  ll.LatLng(23.957618, 120.927095), ll.LatLng(23.955493, 120.924346),
  ll.LatLng(23.952905, 120.923714), ll.LatLng(23.952549, 120.923666),
  ll.LatLng(23.952181, 120.923616), ll.LatLng(23.948786, 120.923158),
  ll.LatLng(23.944908, 120.922468),
];

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
    if (area.contains('暨大') || area.contains('暨南')) return const _AdminAreaBounds(label: '暨南大學', minLat: 23.9440, maxLat: 23.9577, minLng: 120.9224, maxLng: 120.9365);
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
    // 目前轄區先固定為暨南大學
    final bounds = _AdminAreaBounds.forArea('暨大');
    final sosOnly = vm.emergencies
    .where((e) => e.status != 'resolved')
    .toList()
  ..sort((a, b) => b.sentAt.compareTo(a.sentAt));

    return _card(padding: EdgeInsets.zero, child: Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
        child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.location_on_outlined, color: kTextMain, size: 18),
              const SizedBox(width: 6),
              Flexible(child: Text('GPS 即時地圖 - ${bounds.label}',
                  style: const TextStyle(color: kTextMain, fontSize: 16, fontWeight: FontWeight.w800),
                  overflow: TextOverflow.ellipsis, maxLines: 1)),
            ]),
            const SizedBox(height: 3),
            const Text('只顯示未處理 SOS 求救位置', style: TextStyle(color: kTextSub, fontSize: 13),
                overflow: TextOverflow.ellipsis, maxLines: 1),
          ])),
          _smallBadge(sosOnly.isEmpty ? '目前無 SOS' : '求救中 ${sosOnly.length}', sosOnly.isEmpty ? kGreen : kRed),
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

  /// 校園範圍（含一點邊距）
  CameraFit get _homeFit => CameraFit.bounds(
        bounds: LatLngBounds.fromPoints(kNcnuCampus),
        padding: const EdgeInsets.all(24),
      );

  /// 回到暨大
  void _goHome() => _mapCtrl.fitCamera(_homeFit);

  void _zoomBy(double delta) {
    final z = (_mapCtrl.camera.zoom + delta).clamp(12.0, 18.0);
    _mapCtrl.move(_mapCtrl.camera.center, z);
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
            initialCameraFit: _homeFit,
            minZoom: 12,
            maxZoom: 18,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
          ),
          children: [
           TileLayer(
  urlTemplate: 'https://wmts.nlsc.gov.tw/wmts/EMAP/default/GoogleMapsCompatible/{z}/{y}/{x}',  // 國土測繪中心 台灣通用電子地圖（免費、免金鑰）,
  userAgentPackageName: 'com.example.flutter_disaster_app',
  maxNativeZoom: 16,
  maxZoom: 18,
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
        Positioned(top: 12, left: 12, child: GestureDetector(onTap: _goHome, child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(color: Colors.white.withOpacity(.92), borderRadius: BorderRadius.circular(8), border: Border.all(color: kBorder)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.my_location_rounded, color: kBlue, size: 14),
            const SizedBox(width: 5),
            Text(widget.bounds.label, style: const TextStyle(color: kTextMain, fontSize: 13, fontWeight: FontWeight.w800)),
          ]),
        ))),

        // 缩放按钮
        Positioned(right: 12, bottom: 12, child: Column(children: [
          _mapBtn(Icons.add,    () => _zoomBy(1), tooltip: '放大'),
          const SizedBox(height: 4),
          _mapBtn(Icons.remove, () => _zoomBy(-1), tooltip: '縮小'),
          const SizedBox(height: 4),
          _mapBtn(Icons.my_location_rounded, _goHome, tooltip: '回到暨大'),
        ])),
      ]),
    );
  }

  Widget _mapBtn(IconData icon, VoidCallback onTap, {String? tooltip}) => Tooltip(
    message: tooltip ?? '',
    child: InkWell(
      onTap: onTap, borderRadius: BorderRadius.circular(6),
      child: Container(width: 32, height: 32,
          decoration: BoxDecoration(color: Colors.white.withOpacity(.94), borderRadius: BorderRadius.circular(6), border: Border.all(color: kBorder)),
          child: Icon(icon, size: 17, color: kTextMain)),
    ),
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
          child: const Center(child: Text('SOS', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: .5)))),
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
      const Expanded(child: Text('轄區 SOS 清單', style: TextStyle(color: kTextMain, fontSize: 15, fontWeight: FontWeight.w800))),
    ])),
    Expanded(child: events.isEmpty
        ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.check_circle_outline, color: kGreen, size: 32),
            const SizedBox(height: 8),
            const Text('目前無待處理 SOS', style: TextStyle(color: kGreen, fontSize: 14, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            const Text('轄區平安', style: TextStyle(color: kTextSub, fontSize: 13)),
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
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: kTextMain, fontSize: 15, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text((e.address ?? '').isNotEmpty ? e.address! : e.phone, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: kTextSub, fontSize: 13)),
                  ])),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
                    Text(_relativeTime(e.sentAt), style: const TextStyle(color: kTextSub, fontSize: 13),
                        overflow: TextOverflow.ellipsis, maxLines: 1),
                    const SizedBox(height: 4),
                    Builder(builder: (_) {
                      final processing = e.status == 'processing';
                      final c = processing ? kBlue : kOrange;
                      return Container(padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(color: c.withValues(alpha: .10), borderRadius: BorderRadius.circular(4)),
                          child: Text(processing ? '處理中' : '待處理', style: TextStyle(color: c, fontSize: 13, fontWeight: FontWeight.w700)));
                    }),
                  ]),
                ]));
            })),
    Padding(padding: const EdgeInsets.fromLTRB(12,0,12,12), child: InkWell(
      borderRadius: BorderRadius.circular(8), onTap: onViewAll,
      child: Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(color: kBlue.withOpacity(.06), borderRadius: BorderRadius.circular(8), border: Border.all(color: kBlue.withOpacity(.16))),
          child: const Center(child: Text('查看全部緊急事件 →', style: TextStyle(color: kBlue, fontSize: 13, fontWeight: FontWeight.w800)))))),
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
              child: const Text('資料來源：中央氣象署開放資料平台', style: TextStyle(color: kTextSub, fontSize: 13))),
        ])),
      ]),
    ));
  }

  static Widget _dr(IconData icon, String label, String value) =>
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: kTextSub, size: 18), const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(color: kTextSub, fontSize: 13)),
          const SizedBox(height: 3),
          Text(value, style: const TextStyle(color: kTextMain, fontSize: 14, fontWeight: FontWeight.w600)),
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
          const Padding(padding: EdgeInsets.all(24), child: Text('近 7 天內沒有災害通報', style: TextStyle(color: kTextSub)))
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
  final bool isLoading;
  final VoidCallback onRefresh;
  final ValueChanged<DisasterAlert> onAlertTap;
  const _EventListCard({required this.alerts, required this.isLoading, required this.onRefresh, required this.onAlertTap});

  @override
  Widget build(BuildContext context) => _card(padding: const EdgeInsets.all(16), child: Column(children: [
    Row(children: [
      const Icon(Icons.flash_on_rounded, color: kTextMain, size: 18),
      const SizedBox(width: 6),
      const Expanded(child: Text('災害警報（氣象署）', style: TextStyle(color: kTextMain, fontSize: 16, fontWeight: FontWeight.w800))),
      _smallBadge('近 7 天｜最多 30 筆', kBlue),
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
        const Text('近 7 天內沒有重大通報', style: TextStyle(color: kTextSub, fontSize: 14)),
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
            Text(alert.title, style: const TextStyle(color: kTextMain, fontWeight: FontWeight.w800, fontSize: 15)),
            const SizedBox(height: 4),
            Text('${alert.location} · ${_formatTime(alert.time)}', maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: kTextSub, fontSize: 13)),
          ])),
          _smallBadge(alert.severity, color),
        ])),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  待處理事項：SOS / 物資待認領 / 配送中 / 庫存不足
//  全部來自後端真實資料，點一下跳到對應頁面
// ══════════════════════════════════════════════════════════
class _TodoCard extends StatefulWidget {
  /// 跳頁：1 用戶 / 2 災民 / 3 緊急事件 / 4 物資管理
  final ValueChanged<int> onGo;
  /// 跳到物資管理的指定分頁：0 庫存管理 / 1 據點管理
  final ValueChanged<int> onGoSupply;
  const _TodoCard({required this.onGo, required this.onGoSupply});

  @override
  State<_TodoCard> createState() => _TodoCardState();
}

class _TodoCardState extends State<_TodoCard> {
  final AdminRepository _repo = AdminRepository();
  List<SupplyRequest> _requests = [];
  bool _loading = true;
  bool _requestsFailed = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _loadRequests();
    // 物資需求狀態會被義工改變，每 30 秒更新一次
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _loadRequests());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadRequests() async {
    try {
      final list = await _repo.getAllSupplyRequests();
      if (!mounted) return;
      setState(() { _requests = list; _requestsFailed = false; _loading = false; });
    } catch (_) {
      if (!mounted) return;
      setState(() { _requestsFailed = true; _loading = false; });
    }
  }

  Future<void> _refreshAll() async {
    context.read<EmergencyViewModel>().loadEmergencies();
    context.read<AdminSupplyViewModel>().loadSupplies();
    await _loadRequests();
  }

  @override
  Widget build(BuildContext context) {
    final emergencyVm = context.watch<EmergencyViewModel>();
    final supplyVm    = context.watch<AdminSupplyViewModel>();

    final sos       = emergencyVm.emergencies.where((e) => e.status != 'resolved').toList()
      ..sort((a, b) => b.sentAt.compareTo(a.sentAt));
    final waiting   = _requests.where((r) => r.isPending).toList();
    final delivering = _requests.where((r) => r.isClaimed || r.isDelivering).toList();
    final lowStock  = supplyVm.supplies.where((s) => s.isLowStock).toList();

    String names(Iterable<String> list, {int max = 3, String unit = '筆'}) {
      final l = list.where((s) => s.isNotEmpty).toList();
      if (l.isEmpty) return '';
      return l.length <= max ? l.join('・') : '${l.take(max).join('・')} 等 ${l.length} $unit';
    }

    final total = sos.length + waiting.length + delivering.length + lowStock.length;

    return _card(padding: const EdgeInsets.all(16), child: Column(children: [
      Row(children: [
        const Icon(Icons.checklist_rounded, color: kTextMain, size: 18),
        const SizedBox(width: 6),
        const Expanded(child: Text('待處理事項', style: TextStyle(color: kTextMain, fontSize: 16, fontWeight: FontWeight.w800))),
        _smallBadge(total == 0 ? '目前無待辦' : '共 $total 項', total == 0 ? kGreen : kOrange),
        IconButton(onPressed: _refreshAll, icon: const Icon(Icons.refresh, color: kBlue, size: 18)),
      ]),
      const SizedBox(height: 8),
      Expanded(child: _loading
          ? const Center(child: CircularProgressIndicator(color: kBlue))
          : ListView(children: [
              _todoRow(
                icon: Icons.sos_rounded, color: kRed,
                title: 'SOS 求救中', count: sos.length, unit: '件',
                detail: names(sos.map((e) => e.userName), unit: '件'),
                onTap: () => widget.onGo(3),
              ),
              _todoRow(
                icon: Icons.inventory_2_outlined, color: kBlue,
                title: '物資待義工認領', count: waiting.length, unit: '筆',
                detail: _requestsFailed
                    ? '無法取得物資需求資料'
                    : names(waiting.map((r) => '${r.itemName} × ${r.qty} ${r.unit}'), max: 2),
                onTap: () => widget.onGoSupply(1),
              ),
              _todoRow(
                icon: Icons.local_shipping_outlined, color: kOrange,
                title: '物資配送中', count: delivering.length, unit: '筆',
                detail: names(delivering.map((r) =>
                    '${r.itemName} × ${r.qty} ${r.unit}${r.volunteerId != null ? '（${r.volunteerId}）' : ''}'), max: 2),
                onTap: () => widget.onGoSupply(1),
              ),
              _todoRow(
                icon: Icons.warning_amber_rounded, color: const Color(0xFFD97706),
                title: '庫存不足', count: lowStock.length, unit: '項',
                detail: names(lowStock.map((s) => s.name), unit: '項'),
                onTap: () => widget.onGoSupply(0),
              ),
            ])),
    ]));
  }

  /// 一列待辦：數量為 0 時變灰、顯示「無」
  Widget _todoRow({
    required IconData icon, required Color color,
    required String title, required int count, required String unit,
    required String detail, required VoidCallback onTap,
  }) {
    final active = count > 0;
    final c = active ? color : const Color(0xFF94A3B8);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(10), onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: active ? color.withValues(alpha: .05) : kCardBg2,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: active ? color.withValues(alpha: .25) : kBorder),
          ),
          child: Row(children: [
            Container(width: 38, height: 38,
                decoration: BoxDecoration(color: c.withValues(alpha: .12), borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: c, size: 19)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: TextStyle(color: active ? kTextMain : kTextSub, fontWeight: FontWeight.w800, fontSize: 15)),
              if (active && detail.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(detail, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: kTextSub, fontSize: 13)),
              ],
            ])),
            const SizedBox(width: 8),
            Text(active ? '$count $unit' : '無',
                style: TextStyle(color: c, fontSize: active ? 18 : 15, fontWeight: FontWeight.w800)),
            Icon(Icons.chevron_right_rounded, color: c, size: 20),
          ]),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  SHARED HELPERS
// ══════════════════════════════════════════════════════════
Widget _card({required Widget child, EdgeInsetsGeometry padding = const EdgeInsets.all(14), double? height}) =>
    Container(height: height, padding: padding,
      decoration: BoxDecoration(color: kCardBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: kBorder)),
      child: child);

Widget _smallBadge(String text, Color color) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
  decoration: BoxDecoration(color: color.withOpacity(.08), borderRadius: BorderRadius.circular(999), border: Border.all(color: color.withOpacity(.16))),
  child: Text(text, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w800)));

Color _typeColor(DisasterType type) {
  switch (type) {
    case DisasterType.earthquake: return kRed;
    case DisasterType.typhoon:    return kOrange;
    case DisasterType.flood:      return kBlue;
    case DisasterType.rain:       return kBlue;
    default:                      return kMuted;
  }
}

IconData _typeIcon(DisasterType type) {
  switch (type) {
    case DisasterType.earthquake: return Icons.vibration;
    case DisasterType.typhoon:    return Icons.air;
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