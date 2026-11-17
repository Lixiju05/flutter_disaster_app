import 'dart:async';
import 'dart:math' as Math;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_disaster_app/admin_APP/widgets/map_toggle_button.dart';
import 'package:flutter_disaster_app/admin_APP/widgets/page_header.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart'  as ll ;
import 'package:flutter_disaster_app/core/models/emergency_request.dart';
import 'package:flutter_disaster_app/core/api_config.dart';

import 'citizen_page.dart';
import 'emergency_page.dart';
import 'supply_page.dart';
import 'health_report_page.dart';
import 'notification_page.dart';
import 'login_page.dart';
import 'user_management_page.dart';
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
const Color kBorder    = Color(0xFFCBD5E1);

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
  // GPS 地圖全螢幕檢視（只放大內容區，不蓋住左側選單）
  bool _sosMapFullscreen = false;

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
    const t = ['指揮中心','災害資訊','緊急事件','救難管理','物資管理','健康回報','用戶管理','訊息通知'];
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
      // 氣象署即時 API 本身只回傳目前有效/最新的資料，沒有歷史區間可查，
      // 所以這裡不再額外限制天數或筆數，API 給多少就顯示多少
      final result = await WeatherService.fetchAllAlerts(apiKey: _cwaKey)
        ..sort((a, b) => b.time.compareTo(a.time));
      if (!mounted) return;
      setState(() {
        _disasterAlerts = result;
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


  void _go(int i) => setState(() { selectedIndex = i; });

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
      case 1: return _DisasterInfoPage(
          alerts: _disasterAlerts, isLoading: _alertsLoading,
          onRefresh: _loadAlerts, onAlertTap: _showAlertDetail);
      case 2: return EmergencyPage();
      case 3: return const CitizenPage();
      case 4: return const SupplyPage();
      case 5: return const HealthReportPage(showSearch: true);
      case 6: return const UserManagementPage();
      case 7: return const NotificationPage();
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
      width: 220,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [Color(0xFF1E3A5F), Color(0xFF132742)],
        ),
      ),
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
            _navItem(0, Icons.grid_view_rounded,         '指揮中心', const Color(0xFF60A5FA)),
            _navItem(1, Icons.cloud_outlined,            '災害資訊', const Color(0xFF38BDF8)),
            _navItem(2, Icons.warning_amber_rounded,     '緊急事件', const Color(0xFFFB923C)),
            _navItem(3, Icons.accessibility_new_rounded, '救難管理', const Color(0xFF4ADE80)),
            _navItem(4, Icons.inventory_2_outlined,      '物資管理', const Color(0xFFFBBF24)),
            _navItem(5, Icons.favorite_border_rounded,   '健康回報', const Color(0xFFF87171)),
            _navItem(6, Icons.people_alt_outlined,       '用戶管理', const Color(0xFFA78BFA)),
            _navItem(7, Icons.campaign_outlined,         '訊息通知', const Color(0xFF22D3EE)),
          ]),
        ),
        const Spacer(),
        _buildSystemStatus(vm),
        _buildProfileRow(),
      ]),
    );
  }

  Widget _buildLogo() => Container(
    padding: const EdgeInsets.fromLTRB(18, 22, 18, 18),
    decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: kSidebarBorder))),
    child: Row(children: [
      Container(width: 40, height: 40,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: kBlue.withValues(alpha: .45), blurRadius: 14, offset: const Offset(0, 5))],
          ),
          child: const Icon(Icons.shield_outlined, color: Colors.white, size: 22)),
      const SizedBox(width: 12),
      const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('互CARE', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800)),
        SizedBox(height: 2),
        Text('社區緊急災難管理系統', style: TextStyle(color: kSidebarTextSub, fontSize: 12, letterSpacing: 0.3)),
      ])),
    ]),
  );

  Widget _navItem(int idx, IconData icon, String label, Color accent) {
    final sel = selectedIndex == idx;
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: InkWell(
        borderRadius: BorderRadius.circular(12), onTap: () => _go(idx),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: sel ? kBlue : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: sel
                ? [BoxShadow(color: kBlue.withValues(alpha: .40), blurRadius: 18, offset: const Offset(0, 6))]
                : null,
          ),
          child: Row(children: [
            Icon(icon, color: sel ? Colors.white : accent, size: 19),
            const SizedBox(width: 12),
            Expanded(child: Text(label,
                style: TextStyle(color: sel ? Colors.white : kSidebarTextSub,
                    fontWeight: sel ? FontWeight.w700 : FontWeight.w500, fontSize: 15))),
          ]),
        ),
      ),
    );
  }

  Widget _buildSystemStatus(WeatherViewModel vm) {
    final color = _backendOk == false ? const Color(0xFFFC8181) : const Color(0xFF34D399);
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.06), borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(.10))),
      child: Row(children: [
        Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Text(_backendLabel,
            style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 14)),
      ]),
    );
  }

  /// 管理員身分卡（含登出入口），取代原本分開的登出按鈕
  Widget _buildProfileRow() => Padding(
    padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
    child: InkWell(
      borderRadius: BorderRadius.circular(14), onTap: _logout,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(.06), borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(.10)),
        ),
        child: Row(children: [
          Container(width: 38, height: 38,
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [Color(0xFF93C5FD), Color(0xFF3B82F6)]),
                shape: BoxShape.circle),
              child: const Center(child: Text('管',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)))),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('管理員', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
            Text('$_adminArea・系統管理者',
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: kSidebarTextSub, fontSize: 12)),
          ])),
          const Icon(Icons.chevron_right_rounded, color: kSidebarTextSub, size: 18),
        ]),
      ),
    ),
  );

  // ── DASHBOARD MAIN ───────────────────────────────────────
  void _toggleSosMapFullscreen() => setState(() => _sosMapFullscreen = !_sosMapFullscreen);

  Widget _buildDashboard() {
    final vm = context.watch<WeatherViewModel>();
    final map = _GpsEmergencyMapCard(
      adminArea: _adminArea, onViewAll: () => _go(2),
      fullscreen: _sosMapFullscreen, onToggleFullscreen: _toggleSosMapFullscreen,
    );

    // 放大檢視：只佔滿內容區（側邊選單維持顯示），不另外開新畫面
    if (_sosMapFullscreen) {
      return SafeArea(
        child: Padding(padding: const EdgeInsets.all(16), child: map),
      );
    }

    return SafeArea(
      child: Stack(children: [
        Column(children: [
        _buildTopBar(vm),
        Expanded(child: Scrollbar(
          controller: _vCtrl, thumbVisibility: true,
          child: SingleChildScrollView(
            controller: _vCtrl,
            padding: const EdgeInsets.fromLTRB(22, 12, 22, 24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _buildStatsRow(),
              const SizedBox(height: 16),
              // GPS 即時地圖為主區塊，旁邊只放精簡的緊急事件摘要（不重複顯示完整清單）
              SizedBox(height: 520, child: map),
            ]),
          ),
        )),
        ]),
        // 吉祥物：固定在指揮中心右下角，純裝飾、不擋點擊
        const Positioned(
          right: 12,
          bottom: 0,
          child: _FloatingMascot(),
        ),
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
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(color: kCardBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: kBorder)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.calendar_today_rounded, color: kBlue, size: 14),
      const SizedBox(width: 7),
      Text(_formattedDate, style: const TextStyle(color: kTextSub, fontSize: 13)),
      const SizedBox(width: 8),
      Container(width: 1, height: 14, color: kBorder),
      const SizedBox(width: 8),
      Text(_formattedTime, style: const TextStyle(color: kTextMain, fontSize: 15, fontWeight: FontWeight.w800)),
    ]),
  );

  Widget _notificationButton() => Stack(clipBehavior: Clip.none, children: [
    Container(
      width: 42, height: 42,
      decoration: _notificationCount > 0
          ? BoxDecoration(
              color: kOrange,
              borderRadius: BorderRadius.circular(11),
              boxShadow: [BoxShadow(color: kOrange.withValues(alpha: .35), blurRadius: 10, offset: const Offset(0, 3))],
            )
          : BoxDecoration(color: kCardBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: kBorder)),
      child: IconButton(
        onPressed: _showNotifications, padding: EdgeInsets.zero,
        icon: Icon(_notificationCount > 0 ? Icons.notifications_active_outlined : Icons.notifications_none,
            color: _notificationCount > 0 ? Colors.white : kTextSub, size: 21)),
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
  Expanded(child: _statCard(Icons.people_alt_outlined, '${citizenVm.citizens.length}', '用戶總數', kBlue, () => _go(6))),
  const SizedBox(width: 12),
  Expanded(child: _statCard(Icons.sos_rounded, '$pendingSos', 'SOS 求救中', kRed, () => _go(2),
      highlight: pendingSos > 0)),
  const SizedBox(width: 12),
  Expanded(child: _statCard(Icons.task_alt_rounded, '${emergencyVm.emergencies.where((e) => e.status == 'resolved').length}', '已處理事件', kGreen, () => _go(2))),
  const SizedBox(width: 12),
  Expanded(child: _statCard(Icons.inventory_2_outlined, '${supplyVm.supplies.length}', '物資項目', kOrange, () => _go(4))),
]);
  }

  /// 橫向統計卡：左圖示、中間數字＋名稱、右邊箭頭（點擊跳到該頁）
  /// highlight = true 時用淡色底強調（目前用在有未處理 SOS 時）
  Widget _statCard(IconData icon, String value, String label, Color color, VoidCallback onTap, {bool highlight = false}) {
    return InkWell(
      borderRadius: BorderRadius.circular(14), onTap: onTap,
      child: Container(
        height: 68,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: highlight ? color.withValues(alpha: .06) : kCardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: highlight ? color.withValues(alpha: .45) : kBorder, width: highlight ? 1.4 : 1),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: .10), blurRadius: 24, offset: const Offset(0, 8)),
            BoxShadow(color: Colors.black.withValues(alpha: .04), blurRadius: 4, offset: const Offset(0, 1)),
          ],
        ),
        child: Row(children: [
          Container(width: 40, height: 40,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(11),
                boxShadow: [BoxShadow(color: color.withValues(alpha: .32), blurRadius: 9, offset: const Offset(0, 3))],
              ),
              child: Icon(icon, color: Colors.white, size: 20)),
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
          Icon(Icons.chevron_right_rounded, color: highlight ? color : const Color(0xFFCBD5E1), size: 20),
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
class _GpsEmergencyMapCard extends StatefulWidget {
  final String adminArea;
  final VoidCallback onViewAll;
  final bool fullscreen;
  final VoidCallback onToggleFullscreen;
  const _GpsEmergencyMapCard({
    required this.adminArea, required this.onViewAll,
    this.fullscreen = false, required this.onToggleFullscreen,
  });

  @override
  State<_GpsEmergencyMapCard> createState() => _GpsEmergencyMapCardState();
}

class _GpsEmergencyMapCardState extends State<_GpsEmergencyMapCard> {
  /// 點地圖上的 SOS 標記選到的事件（非放大模式時顯示在右側摘要）
  EmergencyRequest? _selected;

  void _onMarkerTap(EmergencyRequest e) {
    if (widget.fullscreen) {
      _showSosDetailDialog(context, e);
    } else {
      setState(() => _selected = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm     = context.watch<EmergencyViewModel>();
    // 目前轄區先固定為暨南大學
    final bounds = _AdminAreaBounds.forArea('暨大');
    final sosOnly = vm.emergencies
    .where((e) => e.status != 'resolved')
    .toList()
  ..sort((a, b) => b.sentAt.compareTo(a.sentAt));
    // 選到的事件若已不在清單中（例如已被標記完成），改回顯示最新一筆
    final selected = sosOnly.any((e) => e.emergencyId == _selected?.emergencyId) ? _selected : null;

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
            Row(children: [
              const Text('只顯示未處理 SOS 求救位置', style: TextStyle(color: kTextSub, fontSize: 13),
                  overflow: TextOverflow.ellipsis, maxLines: 1),
              const SizedBox(width: 10),
              _legendDot('待救援', kRed),
              const SizedBox(width: 10),
              _legendDot('處理中', kOrange),
            ]),
          ])),
          const SizedBox(width: 8),
          _smallBadge(sosOnly.isEmpty ? '目前無 SOS' : '求救中 ${sosOnly.length}', sosOnly.isEmpty ? kGreen : kRed),
        ]),
      ),
      const Divider(height: 1, color: kBorder),
      Expanded(child: widget.fullscreen
          ? Padding(
              padding: const EdgeInsets.all(14),
              child: _GpsMapCanvas(bounds: bounds, events: sosOnly,
                  fullscreen: widget.fullscreen, onToggleFullscreen: widget.onToggleFullscreen,
                  onMarkerTap: _onMarkerTap))
          : Row(children: [
              Expanded(flex: 7, child: Padding(
                padding: const EdgeInsets.all(14),
                child: _GpsMapCanvas(bounds: bounds, events: sosOnly,
                    fullscreen: widget.fullscreen, onToggleFullscreen: widget.onToggleFullscreen,
                    onMarkerTap: _onMarkerTap))),
              Container(width: 1, color: kBorder),
              Expanded(flex: 4, child: _SosEventList(
                  events: sosOnly, onViewAll: widget.onViewAll, selected: selected,
                  onSelect: (e) => setState(() => _selected = e),
                  onClearSelection: () => setState(() => _selected = null))),
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
  final bool fullscreen;
  final VoidCallback onToggleFullscreen;
  final ValueChanged<EmergencyRequest> onMarkerTap;
  const _GpsMapCanvas({
    required this.bounds, required this.events,
    this.fullscreen = false, required this.onToggleFullscreen,
    required this.onMarkerTap,
  });
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

  double _panZoomStart = 0;

  /// 以游標位置為中心縮放（游標下的地點不動）—— 跟災民管理地圖相同的手勢
  void _zoomMapAt(Offset local, double zoom) {
    final cam = _mapCtrl.camera;
    final z = zoom.clamp(12.0, 18.0);
    if ((z - cam.zoom).abs() < 0.001) return;
    _mapCtrl.move(cam.focusedZoomCenter(Math.Point(local.dx, local.dy), z), z);
  }

  void _onMapPointerSignal(PointerSignalEvent event) {
    GestureBinding.instance.pointerSignalResolver.register(event, (e) {
      final zoom = _mapCtrl.camera.zoom;
      if (e is PointerScaleEvent) {
        // 觸控板雙指捏合
        _zoomMapAt(e.localPosition, zoom + Math.log(e.scale) / Math.ln2);
      } else if (e is PointerScrollEvent) {
        // 滑鼠滾輪 / 觸控板雙指上下滑
        _zoomMapAt(e.localPosition, zoom - e.scrollDelta.dy / 300);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Stack(children: [
        // ── 真實地圖 ───────────────────────────────────────
        // flutter_map 不處理觸控板雙指縮放，這裡自己接；滾輪也一起處理
        Listener(
          onPointerSignal: _onMapPointerSignal,
          onPointerPanZoomStart: (_) => _panZoomStart = _mapCtrl.camera.zoom,
          onPointerPanZoomUpdate: (e) =>
              _zoomMapAt(e.localPosition, _panZoomStart + Math.log(e.scale) / Math.ln2),
          child: FlutterMap(
            mapController: _mapCtrl,
            options: MapOptions(
              initialCameraFit: _homeFit,
              minZoom: 12,
              maxZoom: 18,
              // 拖曳移動、觸控螢幕雙指縮放；不用雙擊放大，滾輪交給上面的 Listener
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.drag | InteractiveFlag.pinchZoom | InteractiveFlag.flingAnimation,
              ),
            ),
            children: [
             TileLayer(
      urlTemplate: 'https://wmts.nlsc.gov.tw/wmts/EMAP/default/GoogleMapsCompatible/{z}/{y}/{x}',  // 國土測繪中心 台灣通用電子地圖（免費、免金鑰）,
      userAgentPackageName: 'com.example.flutter_disaster_app',
      maxNativeZoom: 16,
      maxZoom: 18,
    ),
              // ★ 只有未處理 SOS 紅點（處理中→橘色）── 點一下看詳情
              MarkerLayer(markers: widget.events.map((e) {
                final name = e.userName.isNotEmpty ? e.userName : '用戶 ${e.userId}';
                final color = e.status == 'processing' ? kOrange : kRed;
                return Marker(
                  point: ll.LatLng(e.lat, e.lng),
                  width: 44, height: 50,
                  child: GestureDetector(
                    onTap: () => widget.onMarkerTap(e),
                    child: Tooltip(
                      message: '$name\n${e.status}\n${_relativeTime(e.sentAt)}',
                      child: _SosMarkerWidget(color: color)),
                  ),
                );
              }).toList()),
            ],
          ),
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

        // 放大／縮小整個畫面
        Positioned(top: 12, right: 12,
            child: MapToggleButton(fullscreen: widget.fullscreen, onTap: widget.onToggleFullscreen)),

        // 縮放按鈕
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
//  吉祥物（指揮中心右下角，輕輕上下浮動＋微微擺動）
// ══════════════════════════════════════════════════════════
class _FloatingMascot extends StatefulWidget {
  const _FloatingMascot();
  @override
  State<_FloatingMascot> createState() => _FloatingMascotState();
}

class _FloatingMascotState extends State<_FloatingMascot> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this, duration: const Duration(milliseconds: 2200),
  )..repeat(reverse: true);

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, child) {
          final t = Curves.easeInOut.transform(_ctrl.value);
          return Transform.translate(
            offset: Offset(0, -14 * t),
            child: Transform.rotate(
              angle: (t - 0.5) * 0.05,
              alignment: Alignment.bottomCenter,
              child: child,
            ),
          );
        },
        child: const Image(
          image: AssetImage('assets/images/mascot_safety.png'),
          height: 210,
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  SOS MARKER WIDGET（閃爍紅點）
// ══════════════════════════════════════════════════════════
class _SosMarkerWidget extends StatefulWidget {
  final Color color;
  const _SosMarkerWidget({this.color = kRed});
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
            child: Container(width: r*2, height: r*2, decoration: BoxDecoration(color: widget.color.withOpacity(.30), shape: BoxShape.circle)));
      }),
      Container(width: 32, height: 32,
          decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2.5),
              boxShadow: [BoxShadow(color: widget.color.withOpacity(.50), blurRadius: 10, spreadRadius: 2)]),
          child: const Center(child: Text('SOS', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: .5)))),
    ])),
    CustomPaint(size: const Size(12, 6), painter: _TrianglePainter(widget.color)),
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
/// 地圖旁的精簡摘要（不重複顯示完整清單，完整清單在「緊急事件」頁面）
class _SosEventList extends StatelessWidget {
  final List<EmergencyRequest> events;
  final VoidCallback onViewAll;
  /// 點地圖標記（或下方清單）選到的事件；null 時顯示「全部事件」清單
  final EmergencyRequest? selected;
  final ValueChanged<EmergencyRequest> onSelect;
  final VoidCallback onClearSelection;
  const _SosEventList({
    required this.events, required this.onViewAll,
    this.selected, required this.onSelect, required this.onClearSelection,
  });

  @override
  Widget build(BuildContext context) {
    final waiting = events.where((e) => e.status != 'processing').length;
    final processing = events.where((e) => e.status == 'processing').length;
    // 選到的事件若已不在清單中（例如已被標記完成），視為沒有選擇
    final shown = events.any((e) => e.emergencyId == selected?.emergencyId) ? selected : null;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Expanded(child: Text('緊急事件摘要', style: TextStyle(color: kTextMain, fontSize: 15, fontWeight: FontWeight.w800))),
          _headerCount(waiting, '待救援', kRed),
          const SizedBox(width: 8),
          _headerCount(processing, '處理中', kOrange),
        ]),
        const SizedBox(height: 14),
        if (events.isEmpty)
          const Expanded(child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.check_circle_outline, color: kGreen, size: 32),
            SizedBox(height: 8),
            Text('目前無待處理 SOS', style: TextStyle(color: kGreen, fontSize: 14, fontWeight: FontWeight.w700)),
            SizedBox(height: 4),
            Text('轄區平安', style: TextStyle(color: kTextSub, fontSize: 13)),
          ])))
        else if (shown != null) ...[
          // 點了地圖標記／清單中某一筆：只顯示那一筆的詳情
          Row(children: [
            Expanded(child: Text('SOS 詳情', style: const TextStyle(color: kTextSub, fontSize: 12, fontWeight: FontWeight.w700))),
            InkWell(
              borderRadius: BorderRadius.circular(6),
              onTap: onClearSelection,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.arrow_back_rounded, size: 13, color: kBlue),
                  SizedBox(width: 3),
                  Text('全部事件', style: TextStyle(color: kBlue, fontSize: 12, fontWeight: FontWeight.w700)),
                ]),
              ),
            ),
          ]),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: kBlue.withOpacity(.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: kBlue.withOpacity(.30)),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                    color: (shown.status == 'processing' ? kOrange : kRed).withOpacity(.12),
                    shape: BoxShape.circle),
                child: Icon(Icons.sos_rounded, size: 19,
                    color: shown.status == 'processing' ? kOrange : kRed),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text(shown.userName.isNotEmpty ? shown.userName : '用戶 ${shown.userId}',
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: kTextMain, fontSize: 15, fontWeight: FontWeight.w800))),
                    _smallBadge(shown.status == 'processing' ? '處理中' : '待救援',
                        shown.status == 'processing' ? kOrange : kRed),
                  ]),
                  const SizedBox(height: 4),
                  Text((shown.address ?? '').isNotEmpty ? shown.address! : shown.phone,
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: kTextSub, fontSize: 13)),
                  const SizedBox(height: 4),
                  Row(children: [
                    const Icon(Icons.access_time_rounded, size: 12, color: kTextSub),
                    const SizedBox(width: 3),
                    Text('${_relativeTime(shown.sentAt)}送出', style: const TextStyle(color: kTextSub, fontSize: 12)),
                  ]),
                ]),
              ),
            ]),
          ),
          const Spacer(),
        ] else ...[
          // 沒有選擇任何一筆：顯示全部事件（依時間新到舊排序，最新在最上面）
          Text('全部事件', style: const TextStyle(color: kTextSub, fontSize: 12, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Expanded(
            child: ListView.separated(
              itemCount: events.length,
              separatorBuilder: (_, __) => const SizedBox(height: 6),
              itemBuilder: (_, i) => _sosRow(events[i], false, () => onSelect(events[i]), index: i),
            ),
          ),
        ],
        const SizedBox(height: 12),
        InkWell(
          borderRadius: BorderRadius.circular(8), onTap: onViewAll,
          child: Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 9),
              decoration: BoxDecoration(color: kBlue.withOpacity(.06), borderRadius: BorderRadius.circular(8), border: Border.all(color: kBlue.withOpacity(.16))),
              child: const Center(child: Text('查看全部緊急事件 →', style: TextStyle(color: kBlue, fontSize: 13, fontWeight: FontWeight.w800)))),
        ),
      ]),
    );
  }

  /// 標題列旁的小計數（取代原本的「共 N 件」徽章）
  Widget _headerCount(int n, String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: n > 0 ? color.withValues(alpha: .08) : kCardBg2,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: n > 0 ? color.withValues(alpha: .22) : kBorder),
        ),
        child: Text('$n $label',
            style: TextStyle(color: n > 0 ? color : const Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.w800)),
      );

  /// 下方「全部事件」清單的一列：點了只更新上方詳情，不跳頁、不開彈窗
  Widget _sosRow(EmergencyRequest e, bool isSelected, VoidCallback onTap, {required int index}) {
    final color = e.status == 'processing' ? kOrange : kRed;
    final name = e.userName.isNotEmpty ? e.userName : '用戶 ${e.userId}';
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? kBlue.withValues(alpha: .06) : (index.isEven ? kCardBg : kCardBg2),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isSelected ? kBlue.withValues(alpha: .25) : kBorder),
        ),
        child: Row(children: [
          Container(width: 7, height: 7, margin: const EdgeInsets.only(top: 3),
              decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: isSelected ? kTextMain : const Color(0xFF334155),
                        fontSize: 13.5, fontWeight: FontWeight.w700))),
                const SizedBox(width: 6),
                Text(e.status == 'processing' ? '處理中' : '待救援',
                    style: TextStyle(color: color, fontSize: 11.5, fontWeight: FontWeight.w700)),
              ]),
              Text((e.address ?? '').isNotEmpty ? e.address! : e.phone,
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: kTextSub, fontSize: 12)),
            ]),
          ),
          const SizedBox(width: 6),
          Text(_relativeTime(e.sentAt), style: const TextStyle(color: kTextSub, fontSize: 11)),
        ]),
      ),
    );
  }
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

  static Widget _alertTile(DisasterAlert alert, ValueChanged<DisasterAlert> onTap, {Color? bg}) {
    final color = _typeColor(alert.type);
    return InkWell(
      borderRadius: BorderRadius.circular(10), onTap: () => onTap(alert),
      child: Container(padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: bg ?? kCardBg2, borderRadius: BorderRadius.circular(10), border: Border.all(color: kBorder)),
        child: Row(children: [
          Container(width: 38, height: 38,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(11),
                boxShadow: [BoxShadow(color: color.withValues(alpha: .32), blurRadius: 8, offset: const Offset(0, 2))],
              ),
              child: Icon(_typeIcon(alert.type), color: Colors.white, size: 19)),
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
//  災害資訊（獨立頁面）── 沿用 _EventListCard._alertTile 同一套渲染邏輯
// ══════════════════════════════════════════════════════════
class _DisasterInfoPage extends StatelessWidget {
  final List<DisasterAlert> alerts;
  final bool isLoading;
  final VoidCallback onRefresh;
  final ValueChanged<DisasterAlert> onAlertTap;
  const _DisasterInfoPage({
    required this.alerts, required this.isLoading,
    required this.onRefresh, required this.onAlertTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      PageHeader(
        title: '災害資訊',
        subtitle: 'DISASTER INFORMATION',
        actions: [
          _smallBadge('即時最新', kBlue),
          const SizedBox(width: 8),
          PageHeaderButton(icon: Icons.refresh_rounded, tooltip: '重新整理', onPressed: onRefresh),
        ],
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(22, 10, 22, 0),
        child: Row(children: [
          const Icon(Icons.info_outline_rounded, size: 14, color: kTextSub),
          const SizedBox(width: 4),
          const Expanded(child: Text(
              '資料來源：交通部中央氣象署｜僅提供目前仍有效的最新資訊，無法查詢過去日期',
              style: TextStyle(color: kTextSub, fontSize: 12.5),
              overflow: TextOverflow.ellipsis)),
        ]),
      ),
      Expanded(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: isLoading
              ? const Center(child: CircularProgressIndicator(color: kBlue))
              : alerts.isEmpty
                  ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const Icon(Icons.check_circle_outline, color: kGreen, size: 48),
                      const SizedBox(height: 12),
                      const Text('目前轄區平安', style: TextStyle(color: kGreen, fontWeight: FontWeight.w700, fontSize: 17)),
                      const SizedBox(height: 4),
                      const Text('近 7 天內沒有重大通報', style: TextStyle(color: kTextSub, fontSize: 14)),
                    ]))
                  : ListView.separated(
                      itemCount: alerts.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, i) => _EventListCard._alertTile(alerts[i], onAlertTap,
                          bg: i.isEven ? kCardBg : kCardBg2),
                    ),
        ),
      ),
    ]);
  }
}


// ══════════════════════════════════════════════════════════
//  SOS 詳情彈窗（點地圖標記、或放大檢視時點標記都走這裡）
// ══════════════════════════════════════════════════════════
void _showSosDetailDialog(BuildContext context, EmergencyRequest e) {
  final isProcessing = e.status == 'processing';
  final color = isProcessing ? kOrange : kRed;
  final label = isProcessing ? '處理中' : 'SOS';
  final name  = e.userName.isNotEmpty ? e.userName : '用戶 ${e.userId}';

  showDialog(
    context: context,
    barrierColor: Colors.black.withValues(alpha: .35),
    builder: (_) => Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 460,
        constraints: const BoxConstraints(maxHeight: 560),
        decoration: BoxDecoration(
          color: kCardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: kBorder),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 12, 14),
            child: Row(children: [
              Container(
                width: 42, height: 42,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: color.withValues(alpha: .32), blurRadius: 9, offset: const Offset(0, 3))],
                ),
                child: Icon(Icons.sos_rounded, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name, style: const TextStyle(color: kTextMain, fontSize: 17, fontWeight: FontWeight.w800)),
                const SizedBox(height: 3),
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                    decoration: BoxDecoration(
                        color: color.withValues(alpha: .08), borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: color.withValues(alpha: .2))),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                      const SizedBox(width: 4),
                      Text(label, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w700)),
                    ]),
                  ),
                  const SizedBox(width: 8),
                  Text('ID：${e.userId}', style: const TextStyle(color: kTextSub, fontSize: 13)),
                ]),
              ])),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, color: kTextSub, size: 18),
              ),
            ]),
          ),
          const Divider(height: 1, color: kBorder),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(18),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _dlgSectionHeader('基本資料'),
                _dlgInfoRow('電話', e.phone),
                const SizedBox(height: 4),
                _dlgSectionHeader('SOS 求救'),
                _dlgInfoRow('狀態', isProcessing ? '處理中' : '待處理'),
                _dlgInfoRow('發送時間', _formatTime(e.sentAt)),
                // SOS 由用戶端送出時只帶座標，地址是後端換算的參考值，不一定有
                if (!(e.lat == 0 && e.lng == 0))
                  _dlgInfoRow('座標', '${e.lat.toStringAsFixed(5)}, ${e.lng.toStringAsFixed(5)}'),
                if (e.address?.isNotEmpty == true)
                  _dlgInfoRow('地址（參考）', e.address!),
              ]),
            ),
          ),
        ]),
      ),
    ),
  );
}

Widget _dlgInfoRow(String label, String value) => Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(color: kCardBg2, borderRadius: BorderRadius.circular(8), border: Border.all(color: kBorder)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 78, child: Text(label, style: const TextStyle(color: kTextSub, fontSize: 13, fontWeight: FontWeight.w500))),
        Expanded(child: Text(value.isEmpty ? '未填寫' : value,
            style: const TextStyle(color: kTextMain, fontSize: 14, fontWeight: FontWeight.w600))),
      ]),
    );

Widget _dlgSectionHeader(String label) => Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      child: Row(children: [
        Container(width: 3, height: 14, decoration: BoxDecoration(color: kBlue, borderRadius: BorderRadius.circular(99))),
        const SizedBox(width: 7),
        Text(label, style: const TextStyle(color: kTextMain, fontSize: 14, fontWeight: FontWeight.w700)),
      ]),
    );

// ══════════════════════════════════════════════════════════
//  SHARED HELPERS
// ══════════════════════════════════════════════════════════
Widget _card({required Widget child, EdgeInsetsGeometry padding = const EdgeInsets.all(14), double? height}) =>
    Container(height: height, padding: padding,
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kBorder),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: .10), blurRadius: 24, offset: const Offset(0, 8)),
          BoxShadow(color: Colors.black.withValues(alpha: .04), blurRadius: 4, offset: const Offset(0, 1)),
        ],
      ),
      child: child);

Widget _legendDot(String text, Color color) => Row(mainAxisSize: MainAxisSize.min, children: [
  Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
  const SizedBox(width: 4),
  Text(text, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
]);

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
