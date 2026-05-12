import 'dart:async';
import 'dart:convert';
import 'dart:math' as Math;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
const Color kHighlight = Color(0xFFEFF6FF);
const Color kBorder    = Color(0xFFE5E7EB);

// ★ 深蓝侧边栏色系
const Color kSidebarBg      = Color(0xFF1E3A5F);  // 主背景深蓝
const Color kSidebarBg2     = Color(0xFF162E4D);  // 更深一层（hover/selected）
const Color kSidebarBorder  = Color(0xFF2A4E7A);  // 分隔线
const Color kSidebarText    = Color(0xFFE2EAF4);  // 主文字（亮白蓝）
const Color kSidebarTextSub = Color(0xFF7FA8CC);  // 次要文字（淡蓝）
const Color kSidebarSel     = Color(0xFF2A4E7A);  // 选中背景

const Color kBlue   = Color(0xFF2563EB);
const Color kGreen  = Color(0xFF16A34A);
const Color kOrange = Color(0xFFF59E0B);
const Color kRed    = Color(0xFFDC2626);

const Color kTextMain = Color(0xFF0F172A);
const Color kTextSub  = Color(0xFF64748B);
const Color kMuted    = Color(0xFF64748B);

// ══════════════════════════════════════════════════════════
//  RADAR NODE DATA
// ══════════════════════════════════════════════════════════
class RadarNodeStats {
  final String capacity;
  final String lastUpdate;
  const RadarNodeStats({this.capacity = '--', this.lastUpdate = '即時'});
}

class RadarNode {
  final String         id;
  final String         label;
  final String         subtitle;
  final String         description;
  final Color          color;
  final IconData       icon;
  final double         relX;
  final double         relY;
  final RadarNodeStats stats;

  const RadarNode({
    required this.id,
    required this.label,
    required this.subtitle,
    required this.description,
    required this.color,
    required this.icon,
    required this.relX,
    required this.relY,
    this.stats = const RadarNodeStats(),
  });
}

const Map<String, List<RadarNode>> kAreaNodes = {
  '花蓮縣': [
    RadarNode(id:'shelter', label:'花蓮收容站', subtitle:'開設待命',
      description:'花蓮市北濱避難收容站，位於花蓮市北區。\n提供緊急住宿、餐飲與醫療服務。',
      color:kGreen, icon:Icons.home_outlined, relX:0.32, relY:0.22,
      stats: RadarNodeStats(capacity:'800 人', lastUpdate:'5 分鐘前')),
    RadarNode(id:'gov', label:'花蓮縣政府', subtitle:'指揮中心',
      description:'花蓮縣政府緊急應變中心，統籌全縣救災指揮協調。\n24 小時值班運作中。',
      color:kOrange, icon:Icons.account_balance_outlined, relX:0.62, relY:0.30,
      stats: RadarNodeStats(capacity:'--', lastUpdate:'即時')),
    RadarNode(id:'supply', label:'鳳林物資站', subtitle:'庫存充足',
      description:'鳳林鎮區域物資儲備站，位於縣政府南方 30km。\n存有飲用水、糧食包、醫療包等應急物資。',
      color:Color(0xFF3B82F6), icon:Icons.inventory_2_outlined, relX:0.55, relY:0.72,
      stats: RadarNodeStats(capacity:'1,200 箱', lastUpdate:'1 小時前')),
    RadarNode(id:'monitor', label:'地震監測站', subtitle:'資料回傳中',
      description:'花蓮海岸地震監測站，位於縣政府東南方海岸。\n即時回傳震動、位移、海嘯預警數據。',
      color:Color(0xFF93C5FD), icon:Icons.sensors, relX:0.75, relY:0.65,
      stats: RadarNodeStats(capacity:'--', lastUpdate:'即時')),
  ],
  '南投縣': [
    RadarNode(id:'shelter', label:'埔里收容站', subtitle:'開設待命',
      description:'埔里鎮避難收容站，位於縣政府北方 25km。\n提供緊急住宿與物資發放，鄰近集集斷層帶。',
      color:kGreen, icon:Icons.home_outlined, relX:0.28, relY:0.20,
      stats: RadarNodeStats(capacity:'500 人', lastUpdate:'15 分鐘前')),
    RadarNode(id:'gov', label:'南投縣政府', subtitle:'指揮中心',
      description:'南投縣政府緊急應變中心，統籌全縣救災指揮協調。\n24 小時值班運作中。',
      color:kOrange, icon:Icons.account_balance_outlined, relX:0.62, relY:0.45,
      stats: RadarNodeStats(capacity:'--', lastUpdate:'即時')),
    RadarNode(id:'supply', label:'草屯物資站', subtitle:'庫存確認中',
      description:'草屯鎮區域物資儲備站，位於縣政府北方 15km。\n存有飲用水、糧食包、醫療包等應急物資。',
      color:Color(0xFF3B82F6), icon:Icons.inventory_2_outlined, relX:0.65, relY:0.25,
      stats: RadarNodeStats(capacity:'800 箱', lastUpdate:'30 分鐘前')),
    RadarNode(id:'monitor', label:'日月潭監測站', subtitle:'資料回傳中',
      description:'日月潭氣象監測站，位於縣政府西北方 20km。\n即時回傳雨量、風速、水位、震動數據。',
      color:Color(0xFF93C5FD), icon:Icons.sensors, relX:0.28, relY:0.60,
      stats: RadarNodeStats(capacity:'--', lastUpdate:'即時')),
  ],
  '台北市': [
    RadarNode(id:'shelter', label:'大安收容站', subtitle:'開設待命',
      description:'大安運動中心避難收容站，位於市政府西方。\n可容納約 1,200 人，提供緊急住宿與物資發放。',
      color:kGreen, icon:Icons.home_outlined, relX:0.28, relY:0.50,
      stats: RadarNodeStats(capacity:'1,200 人', lastUpdate:'1 小時前')),
    RadarNode(id:'gov', label:'台北市政府', subtitle:'指揮中心',
      description:'台北市政府緊急應變中心，統籌全市救災指揮協調。\n24 小時值班運作中。',
      color:kOrange, icon:Icons.account_balance_outlined, relX:0.60, relY:0.55,
      stats: RadarNodeStats(capacity:'--', lastUpdate:'即時')),
    RadarNode(id:'supply', label:'內湖物資站', subtitle:'庫存充足',
      description:'內湖區域物資儲備站，位於市政府東北方。\n存有飲用水、糧食包、醫療包等應急物資。',
      color:Color(0xFF3B82F6), icon:Icons.inventory_2_outlined, relX:0.72, relY:0.28,
      stats: RadarNodeStats(capacity:'2,000 箱', lastUpdate:'2 小時前')),
    RadarNode(id:'monitor', label:'陽明山監測站', subtitle:'資料回傳中',
      description:'陽明山氣象監測站，位於市政府北方。\n即時回傳雨量、風速、土石流預警數據。',
      color:Color(0xFF93C5FD), icon:Icons.sensors, relX:0.42, relY:0.20,
      stats: RadarNodeStats(capacity:'--', lastUpdate:'即時')),
  ],
  '高雄市': [
    RadarNode(id:'shelter', label:'鳳山收容站', subtitle:'開設待命',
      description:'鳳山運動中心避難收容站，位於市政府東方。\n可容納約 1,000 人，提供緊急住宿與物資發放。',
      color:kGreen, icon:Icons.home_outlined, relX:0.72, relY:0.55,
      stats: RadarNodeStats(capacity:'1,000 人', lastUpdate:'1 小時前')),
    RadarNode(id:'gov', label:'高雄市政府', subtitle:'指揮中心',
      description:'高雄市政府緊急應變中心，統籌全市救災指揮協調。\n24 小時值班運作中。',
      color:kOrange, icon:Icons.account_balance_outlined, relX:0.45, relY:0.55,
      stats: RadarNodeStats(capacity:'--', lastUpdate:'即時')),
    RadarNode(id:'supply', label:'左營物資站', subtitle:'庫存確認中',
      description:'左營區域物資儲備站，位於市政府西北方。\n存有飲用水、糧食包、醫療包等應急物資。',
      color:Color(0xFF3B82F6), icon:Icons.inventory_2_outlined, relX:0.28, relY:0.28,
      stats: RadarNodeStats(capacity:'1,500 箱', lastUpdate:'45 分鐘前')),
    RadarNode(id:'monitor', label:'旗山監測站', subtitle:'資料回傳中',
      description:'旗山區氣象監測站，位於市政府北偏東方。\n即時回傳雨量、風速、河川水位數據。',
      color:Color(0xFF93C5FD), icon:Icons.sensors, relX:0.55, relY:0.22,
      stats: RadarNodeStats(capacity:'--', lastUpdate:'即時')),
  ],
  '台中市': [
    RadarNode(id:'shelter', label:'豐原收容站', subtitle:'開設待命',
      description:'豐原體育場避難收容站，位於市政府東北方。\n可容納約 900 人，提供緊急住宿與物資發放。',
      color:kGreen, icon:Icons.home_outlined, relX:0.68, relY:0.22,
      stats: RadarNodeStats(capacity:'900 人', lastUpdate:'2 小時前')),
    RadarNode(id:'gov', label:'台中市政府', subtitle:'指揮中心',
      description:'台中市政府緊急應變中心，統籌全市救災指揮協調。\n24 小時值班運作中。',
      color:kOrange, icon:Icons.account_balance_outlined, relX:0.38, relY:0.48,
      stats: RadarNodeStats(capacity:'--', lastUpdate:'即時')),
    RadarNode(id:'supply', label:'烏日物資站', subtitle:'庫存確認中',
      description:'烏日區域物資儲備站，位於市政府南方。\n存有飲用水、糧食包、醫療包等應急物資。',
      color:Color(0xFF3B82F6), icon:Icons.inventory_2_outlined, relX:0.40, relY:0.72,
      stats: RadarNodeStats(capacity:'1,000 箱', lastUpdate:'1 小時前')),
    RadarNode(id:'monitor', label:'梨山監測站', subtitle:'資料回傳中',
      description:'梨山氣象監測站，位於市政府東方山區。\n即時回傳雨量、土石流、山區氣象數據。',
      color:Color(0xFF93C5FD), icon:Icons.sensors, relX:0.75, relY:0.55,
      stats: RadarNodeStats(capacity:'--', lastUpdate:'即時')),
  ],
  '台南市': [
    RadarNode(id:'shelter', label:'永康收容站', subtitle:'開設待命',
      description:'永康運動中心避難收容站，位於市政府東北方。\n可容納約 700 人，提供緊急住宿與物資發放。',
      color:kGreen, icon:Icons.home_outlined, relX:0.65, relY:0.35,
      stats: RadarNodeStats(capacity:'700 人', lastUpdate:'2 小時前')),
    RadarNode(id:'gov', label:'台南市政府', subtitle:'指揮中心',
      description:'台南市政府緊急應變中心，統籌全市救災指揮協調。\n24 小時值班運作中。',
      color:kOrange, icon:Icons.account_balance_outlined, relX:0.35, relY:0.52,
      stats: RadarNodeStats(capacity:'--', lastUpdate:'即時')),
    RadarNode(id:'supply', label:'新營物資站', subtitle:'庫存確認中',
      description:'新營區域物資儲備站，位於市政府北方。\n存有飲用水、糧食包、醫療包等應急物資。',
      color:Color(0xFF3B82F6), icon:Icons.inventory_2_outlined, relX:0.52, relY:0.22,
      stats: RadarNodeStats(capacity:'900 箱', lastUpdate:'1 小時前')),
    RadarNode(id:'monitor', label:'玉井監測站', subtitle:'資料回傳中',
      description:'玉井區氣象監測站，位於市政府東方山區。\n即時回傳雨量、水位、土石流預警數據。',
      color:Color(0xFF93C5FD), icon:Icons.sensors, relX:0.72, relY:0.62,
      stats: RadarNodeStats(capacity:'--', lastUpdate:'即時')),
  ],
};

List<RadarNode> getNodesForArea(String adminArea) {
  final city = AreaDataHelper.toCityName(adminArea);
  if (kAreaNodes.containsKey(city)) return kAreaNodes[city]!;
  return [
    RadarNode(id:'shelter', label:'收容站', subtitle:'開設待命',
      description:'$adminArea 避難收容站，提供緊急住宿與物資發放。',
      color:kGreen, icon:Icons.home_outlined, relX:0.26, relY:0.22),
    RadarNode(id:'gov', label:'政府機關', subtitle:'指揮節點',
      description:'$adminArea 緊急應變中心，負責統籌各單位協調指揮工作。',
      color:kOrange, icon:Icons.account_balance_outlined, relX:0.74, relY:0.26),
    RadarNode(id:'supply', label:'物資據點', subtitle:'庫存確認中',
      description:'$adminArea 物資儲備站，存有飲用水、糧食包、醫療包等應急物資。',
      color:Color(0xFF3B82F6), icon:Icons.inventory_2_outlined, relX:0.27, relY:0.72),
    RadarNode(id:'monitor', label:'監測站', subtitle:'資料回傳中',
      description:'$adminArea 自動監測站，即時回傳各項環境數據至指揮中心。',
      color:Color(0xFF93C5FD), icon:Icons.sensors, relX:0.70, relY:0.66),
  ];
}

class AlertRadarNode {
  final DisasterAlert alert;
  final double        relX;
  final double        relY;
  const AlertRadarNode({required this.alert, required this.relX, required this.relY});
}

const Map<String, List<double>> kAreaCenterLatLng = {
  '花蓮縣': [23.9871, 121.6015], '南投縣': [23.9609, 120.9718],
  '台北市': [25.0330, 121.5654], '高雄市': [22.6273, 120.3014],
  '台中市': [24.1477, 120.6736], '台南市': [22.9999, 120.2269],
  '新北市': [25.0169, 121.4627], '桃園市': [24.9937, 121.3010],
  '宜蘭縣': [24.7021, 121.7377], '台東縣': [22.7972, 121.1047],
  '屏東縣': [22.5519, 120.5487],
};

List<AlertRadarNode> buildAlertNodes(List<DisasterAlert> alerts, String adminArea) {
  final city   = AreaDataHelper.toCityName(adminArea);
  final center = kAreaCenterLatLng[city] ?? [23.9871, 121.6015];
  final cLat   = center[0];
  final cLng   = center[1];
  const radiusKm = 80.0;
  final kmPerLat = 111.0;
  final kmPerLng = 111.0 * Math.cos(cLat * Math.pi / 180);
  final result = <AlertRadarNode>[];
  final seen   = <String>{};

  for (final alert in alerts) {
    if (result.length >= 5) break;
    double? alertLat, alertLng;
    final dirReg   = RegExp(r'([東西南北]{1,3})\s*方?\s*(\d+\.?\d*)\s*公里');
    final text     = '${alert.description} ${alert.location}';
    final dirMatch = dirReg.firstMatch(text);
    if (dirMatch != null) {
      final dir  = dirMatch.group(1) ?? '';
      final dist = double.tryParse(dirMatch.group(2) ?? '') ?? 30.0;
      double dLat = 0, dLng = 0;
      if (dir.contains('北')) dLat =  dist / kmPerLat;
      if (dir.contains('南')) dLat = -dist / kmPerLat;
      if (dir.contains('東')) dLng =  dist / kmPerLng;
      if (dir.contains('西')) dLng = -dist / kmPerLng;
      alertLat = cLat + dLat;
      alertLng = cLng + dLng;
    }
    if (alertLat == null) {
      final fallbacks = [
        [cLat+0.18, cLng+0.12], [cLat-0.22, cLng+0.28],
        [cLat+0.08, cLng-0.18], [cLat-0.12, cLng-0.22],
        [cLat+0.28, cLng+0.22],
      ];
      final idx = result.length % fallbacks.length;
      alertLat = fallbacks[idx][0]; alertLng = fallbacks[idx][1];
    }
    final dxKm = (alertLng! - cLng) * kmPerLng;
    final dyKm = (alertLat  - cLat) * kmPerLat;
    double relX = (0.5 + (dxKm / radiusKm) * 0.40).clamp(0.12, 0.88);
    double relY = (0.5 - (dyKm / radiusKm) * 0.40).clamp(0.12, 0.88);
    final key = '${(relX*10).round()}_${(relY*10).round()}';
    if (seen.contains(key)) {
      relX = (relX + 0.07).clamp(0.12, 0.88);
      relY = (relY + 0.07).clamp(0.12, 0.88);
    }
    seen.add(key);
    result.add(AlertRadarNode(alert: alert, relX: relX, relY: relY));
  }
  return result;
}

// ══════════════════════════════════════════════════════════
//  TIMELINE EVENT
// ══════════════════════════════════════════════════════════
class TimelineEvent {
  final String   id, title, subtitle, category;
  final DateTime time;
  final Color    color;
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
  DateTime  _now          = DateTime.now();
  DateTime? _lastSyncTime;

  List<DisasterAlert> _disasterAlerts = [];
  List<TimelineEvent> _timeline       = [];
  bool _alertsLoading     = false;
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
    _clockTimer.cancel(); _alertTimer.cancel();
    _envTimer.cancel();   _vCtrl.dispose();
    super.dispose();
  }

  void _startClock() {
    _clockTimer = Timer.periodic(
        const Duration(seconds: 1), (_) { if (mounted) setState(() => _now = DateTime.now()); });
  }

  String get _formattedTime {
    return '${_now.hour.toString().padLeft(2,'0')}:${_now.minute.toString().padLeft(2,'0')}:${_now.second.toString().padLeft(2,'0')}';
  }

  String get _formattedDate {
    const months = ['1月','2月','3月','4月','5月','6月','7月','8月','9月','10月','11月','12月'];
    return '${_now.year}年${months[_now.month-1]}${_now.day}日';
  }

  String get _lastSyncText {
    if (_lastSyncTime == null) return '從未同步';
    final diff = DateTime.now().difference(_lastSyncTime!);
    if (diff.inSeconds < 60)  return '剛剛';
    if (diff.inMinutes < 60)  return '${diff.inMinutes} 分鐘前';
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
        _disasterAlerts    = vm.alerts;
        _notificationCount = vm.alerts.length;
        _lastSyncTime      = DateTime.now();
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
        _disasterAlerts    = result.take(30).toList();
        _notificationCount = _disasterAlerts.length;
        _lastSyncTime      = DateTime.now();
        _rebuildTimeline();
      });
    } catch (e) {
      debugPrint('alert error: $e');
      if (!mounted) return;
      setState(() {
        _disasterAlerts = []; _notificationCount = 0;
        _lastSyncTime   = DateTime.now();
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
        content: Text(
          vm.isSimulation ? '已切換至警戒模擬模式' : '已切換至正常模式',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
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

  void _showShelterMap() {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(.35),
      builder: (_) => ShelterMapDialog(adminArea: _adminArea),
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
      pageBuilder: (ctx, a1, a2) => _AlertDetailDialog(alert: alert, onClose: () => Navigator.pop(ctx)),
      transitionBuilder: (ctx, anim1, anim2, child) {
        final curved = CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic);
        return SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, .10), end: Offset.zero).animate(curved),
          child: FadeTransition(opacity: curved, child: child),
        );
      },
    );
  }

  void _showRadarNodeDetail(RadarNode node) {
    final citizenVm = context.read<CitizenViewmodel>();
    final supplyVm  = context.read<AdminSupplyViewModel>();
    final weatherVm = context.read<WeatherViewModel>();
    showGeneralDialog(
      context: context, barrierDismissible: true, barrierLabel: '',
      barrierColor: Colors.black.withOpacity(.35),
      transitionDuration: const Duration(milliseconds: 320),
      pageBuilder: (ctx, anim1, anim2) => _RadarNodeDetailDialog(
        node: node, citizenVm: citizenVm, supplyVm: supplyVm, weatherVm: weatherVm),
      transitionBuilder: (ctx, anim1, anim2, child) {
        final curved = CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic);
        return SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, .12), end: Offset.zero).animate(curved),
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
      case 5: return const HealthReportPage();
      default: return _buildDashboard();
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<WeatherViewModel>();
    return Scaffold(
      backgroundColor: kBg,
      body: Row(children: [
        _buildSidebar(vm),
        Expanded(child: _currentPage()),
      ]),
    );
  }

  // ══════════════════════════════════════════════════════
  //  ★ SIDEBAR — 深蓝色系
  // ══════════════════════════════════════════════════════
  Widget _buildSidebar(WeatherViewModel vm) {
    return Container(
      width: 260,
      decoration: const BoxDecoration(
        color: kSidebarBg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLogo(),
          const SizedBox(height: 14),
          _buildModeBox(vm),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 8),
            child: Text('主要功能',
                style: TextStyle(
                    color: kSidebarTextSub,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8)),
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
        ],
      ),
    );
  }

  Widget _buildLogo() {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 18),
      decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: kSidebarBorder))),
      child: Row(children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
              color: Colors.white.withOpacity(.15),
              borderRadius: BorderRadius.circular(12)),
          child: const Icon(Icons.shield_outlined, color: Colors.white, size: 22),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('災難管理系統',
                style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800)),
            SizedBox(height: 2),
            Text('EMERGENCY COMMAND',
                style: TextStyle(color: kSidebarTextSub, fontSize: 11, letterSpacing: 1.1)),
          ]),
        ),
      ]),
    );
  }

  Widget _buildModeBox(WeatherViewModel vm) {
    final color = vm.isSimulation ? kOrange : const Color(0xFF34D399);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: _toggleMode,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color:        Colors.white.withOpacity(.08),
            borderRadius: BorderRadius.circular(12),
            border:       Border.all(color: Colors.white.withOpacity(.12)),
          ),
          child: Row(children: [
            Icon(vm.isSimulation ? Icons.science_outlined : Icons.cloud_done_outlined,
                color: color, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(vm.isSimulation ? '警戒模擬模式' : '正常模式',
                    style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 13)),
                const SizedBox(height: 2),
                const Text('近30天與即時資料',
                    style: TextStyle(color: kSidebarTextSub, fontSize: 11)),
              ]),
            ),
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
        borderRadius: BorderRadius.circular(10),
        onTap: () => _go(idx),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding:  const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color:        sel ? kSidebarSel : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: sel
                ? Border.all(color: Colors.white.withOpacity(.12))
                : null,
          ),
          child: Row(children: [
            Icon(icon,
                color: sel ? Colors.white : kSidebarTextSub,
                size: 19),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label,
                  style: TextStyle(
                      color:      sel ? Colors.white : kSidebarTextSub,
                      fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                      fontSize:   14)),
            ),
            if (sel)
              Container(
                width: 4, height: 4,
                decoration: const BoxDecoration(
                    color: Colors.white, shape: BoxShape.circle),
              ),
          ]),
        ),
      ),
    );
  }

  Widget _buildSystemStatus(WeatherViewModel vm) {
    final color = vm.isSimulation ? kOrange : const Color(0xFF34D399);
    return Container(
      margin:  const EdgeInsets.fromLTRB(12, 0, 12, 10),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color:        Colors.white.withOpacity(.06),
        borderRadius: BorderRadius.circular(10),
        border:       Border.all(color: Colors.white.withOpacity(.10)),
      ),
      child: Row(children: [
        Container(width: 7, height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Text(vm.isSimulation ? '模擬警戒中' : '系統運作正常',
            style: TextStyle(
                color: color, fontWeight: FontWeight.w700, fontSize: 13)),
      ]),
    );
  }

  Widget _buildAdminBox() {
    return Container(
      margin:  const EdgeInsets.fromLTRB(12, 0, 12, 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color:        Colors.white.withOpacity(.06),
        borderRadius: BorderRadius.circular(10),
        border:       Border.all(color: Colors.white.withOpacity(.10)),
      ),
      child: Row(children: [
        CircleAvatar(
          radius:          18,
          backgroundColor: Colors.white.withOpacity(.18),
          child: Text(
            _adminName.isNotEmpty ? _adminName[0] : '管',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_adminName,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
            Text('$_adminTitle · $_adminArea',
                style: const TextStyle(color: kSidebarTextSub, fontSize: 11),
                overflow: TextOverflow.ellipsis),
          ]),
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          onPressed: () async {
            await Navigator.push(context,
                MaterialPageRoute(builder: (_) => const AdminSetupPage(isEdit: true)));
            await _loadAdminInfo();
            _loadAlerts();
          },
          icon: Icon(Icons.edit_outlined,
              color: kSidebarTextSub.withOpacity(.8), size: 16),
        ),
      ]),
    );
  }

  Widget _buildLogoutButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: _logout,
        child: Container(
          width:   double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color:        kRed.withOpacity(.15),
            borderRadius: BorderRadius.circular(10),
            border:       Border.all(color: kRed.withOpacity(.30)),
          ),
          child: const Row(children: [
            Icon(Icons.logout, color: Color(0xFFFC8181), size: 17),
            SizedBox(width: 10),
            Text('登出系統',
                style: TextStyle(
                    color:      Color(0xFFFC8181),
                    fontWeight: FontWeight.w700,
                    fontSize:   14)),
          ]),
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────
  //  DASHBOARD MAIN（不變）
  // ──────────────────────────────────────────────────────
  Widget _buildDashboard() {
    final vm = context.watch<WeatherViewModel>();
    return SafeArea(
      child: Scrollbar(
        controller:      _vCtrl,
        thumbVisibility: true,
        child: SingleChildScrollView(
          controller: _vCtrl,
          padding:    const EdgeInsets.fromLTRB(22, 18, 22, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTopBar(vm),
              const SizedBox(height: 14),
              if (vm.isSimulation) ...[
                _buildSimulationBanner(),
                const SizedBox(height: 14),
              ],
              _buildStatusStrip(vm),
              const SizedBox(height: 16),
              _buildStatsRow(),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(children: [
                      SizedBox(
                        height: 360,
                        child: Builder(builder: (context) {
                          final cityName   = AreaDataHelper.toCityName(_adminArea);
                          final radarAlerts = _disasterAlerts
                              .where((a) => a.location.contains(cityName))
                              .toList();
                          return _TacticalMapCard(
                            alerts:       radarAlerts,
                            isSimulation: vm.isSimulation,
                            adminArea:    _adminArea,
                            onNodeTap:    _showRadarNodeDetail,
                            onAlertTap:   _showAlertDetail,
                          );
                        }),
                      ),
                      const SizedBox(height: 16),
                      Row(children: [
                        Expanded(child: SizedBox(height: 420,
                          child: _EventListCard(
                            alerts: _disasterAlerts, isLoading: _alertsLoading,
                            isSimulation: vm.isSimulation,
                            onRefresh: _loadAlerts, onAlertTap: _showAlertDetail,
                          ))),
                        const SizedBox(width: 16),
                        Expanded(child: SizedBox(height: 420,
                          child: _TimelineCard(
                            events: _timeline, alerts: _disasterAlerts,
                            onEventTap: _showAlertDetail,
                          ))),
                      ]),
                    ]),
                  ),
                  const SizedBox(width: 16),
                  SizedBox(
                    width: 310,
                    child: Column(children: [
                      _ShelterCard(onTap: _showShelterMap),
                      const SizedBox(height: 16),
                      _EnvironmentCard(
                          isSimulation: vm.isSimulation, adminArea: _adminArea),
                    ]),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(WeatherViewModel vm) {
    return Row(children: [
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(_pageTitle,
            style: const TextStyle(
                color: kTextMain, fontSize: 28, fontWeight: FontWeight.w800)),
        const SizedBox(height: 2),
        const Text('DISASTER MANAGEMENT SYSTEM',
            style: TextStyle(color: kTextSub, fontSize: 12, letterSpacing: 1.4)),
      ]),
      const SizedBox(width: 16),
      _statusChip(
          vm.isSimulation ? '模擬警戒中' : '系統正常',
          vm.isSimulation ? kOrange : kGreen),
      const Spacer(),
      _timeBox(),
      const SizedBox(width: 12),
      _notificationButton(),
    ]);
  }

  Widget _timeBox() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 9),
      decoration: BoxDecoration(
          color: kCardBg, borderRadius: BorderRadius.circular(10),
          border: Border.all(color: kBorder)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text(_formattedDate, style: const TextStyle(color: kTextSub, fontSize: 11)),
        const SizedBox(height: 2),
        Row(children: [
          const Icon(Icons.access_time, color: kBlue, size: 14),
          const SizedBox(width: 5),
          Text(_formattedTime,
              style: const TextStyle(
                  color: kTextMain, fontSize: 16, fontWeight: FontWeight.w800)),
        ]),
      ]),
    );
  }

  Widget _notificationButton() {
    return Stack(clipBehavior: Clip.none, children: [
      Container(
        width: 42, height: 42,
        decoration: BoxDecoration(
            color: kCardBg, borderRadius: BorderRadius.circular(10),
            border: Border.all(color: kBorder)),
        child: IconButton(
          onPressed: _showNotifications,
          padding: EdgeInsets.zero,
          icon: Icon(
            _notificationCount > 0
                ? Icons.notifications_active_outlined
                : Icons.notifications_none,
            color: _notificationCount > 0 ? kOrange : kTextSub, size: 21),
        ),
      ),
      if (_notificationCount > 0)
        Positioned(
          top: -4, right: -4,
          child: Container(
            width: 18, height: 18,
            decoration: const BoxDecoration(color: kRed, shape: BoxShape.circle),
            child: Center(
              child: Text(
                _notificationCount > 9 ? '9+' : '$_notificationCount',
                style: const TextStyle(
                    color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800)),
            ),
          ),
        ),
    ]);
  }

  Widget _buildSimulationBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      decoration: BoxDecoration(
        color:        kOrange.withOpacity(.08),
        borderRadius: BorderRadius.circular(10),
        border:       Border.all(color: kOrange.withOpacity(.22)),
      ),
      child: Row(children: [
        const Icon(Icons.science_outlined, color: kOrange, size: 18),
        const SizedBox(width: 10),
        const Expanded(
          child: Text('警戒模擬模式：目前顯示為展示情境，非真實即時資料。',
              style: TextStyle(color: kTextMain, fontSize: 13, fontWeight: FontWeight.w600)),
        ),
        TextButton(onPressed: _toggleMode, child: const Text('切換回正常模式')),
      ]),
    );
  }

  Widget _buildStatusStrip(WeatherViewModel vm) {
    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
          color: kCardBg, borderRadius: BorderRadius.circular(10),
          border: Border.all(color: kBorder)),
      child: Row(children: [
        _statusDot(
            vm.isSimulation ? '模擬警戒中' : '系統運作正常',
            vm.isSimulation ? kOrange : kGreen),
        _vline(),
        _statusText('延遲 12ms', kBlue),
        _vline(),
        _statusText('監控頻道 CH-01', kTextSub),
        _vline(),
        if (_alertsLoading)
          const SizedBox(width: 14, height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: kBlue))
        else
          _statusText(
            _disasterAlerts.isNotEmpty
                ? '${_disasterAlerts.length} 則通報'
                : '近期無重大警報',
            _disasterAlerts.isNotEmpty ? kOrange : kGreen),
        const Spacer(),
        Text('上次同步：$_lastSyncText',
            style: const TextStyle(color: kTextSub, fontSize: 13)),
        const SizedBox(width: 12),
        _pillBtn(vm.isSimulation ? '模擬模式' : '即時監控中',
            vm.isSimulation ? kOrange : kBlue),
      ]),
    );
  }

  Widget _buildStatsRow() {
    final citizenVm   = context.watch<CitizenViewmodel>();
    final supplyVm    = context.watch<AdminSupplyViewModel>();
    final emergencyVm = context.watch<EmergencyViewModel>();
    final isLoading   = citizenVm.isLoading || supplyVm.isLoading || emergencyVm.isLoading;

    if (isLoading) {
      return _card(height: 104,
          child: const Center(child: CircularProgressIndicator(color: kBlue)));
    }

    return Row(children: [
      Expanded(child: _statCard(Icons.people_alt_outlined,
          '${citizenVm.citizens.length}', '用戶總數', kBlue, '查看', () => _go(1))),
      const SizedBox(width: 12),
      Expanded(child: _statCard(Icons.warning_amber_rounded,
          '${emergencyVm.emergencies.length}', '求救事件', kOrange, '處理中', () => _go(3))),
      const SizedBox(width: 12),
      Expanded(child: _statCard(Icons.inventory_2_outlined,
          '${supplyVm.supplies.length}', '物資項目', kGreen, '庫存', () => _go(4))),
      const SizedBox(width: 12),
      Expanded(child: _statCard(Icons.favorite_border,
          '${emergencyVm.emergencies.length}', '健康回報',
          const Color(0xFFE11D48), '今日', () => _go(5))),
    ]);
  }

  Widget _statCard(IconData icon, String value, String label,
      Color color, String badge, VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: _card(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
                color: color.withOpacity(.10), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(value,
                  style: const TextStyle(
                      color: kTextMain, fontSize: 28, fontWeight: FontWeight.w800, height: 1)),
              const SizedBox(height: 6),
              Text(label, style: const TextStyle(color: kTextSub, fontSize: 14)),
            ]),
          ),
          _smallBadge(badge, color),
        ]),
      ),
    );
  }

  static Widget _statusDot(String text, Color color) => Row(children: [
    Container(width: 8, height: 8,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
    const SizedBox(width: 7),
    Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 13)),
  ]);

  static Widget _statusText(String text, Color color) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 10),
    child:   Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13)),
  );

  static Widget _vline() => Container(
      width: 1, height: 20, color: kBorder,
      margin: const EdgeInsets.symmetric(horizontal: 4));

  static Widget _pillBtn(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
        color:        color.withOpacity(.08),
        borderRadius: BorderRadius.circular(20),
        border:       Border.all(color: color.withOpacity(.18))),
    child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12)),
  );

  static Widget _statusChip(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
        color:        color.withOpacity(.08),
        borderRadius: BorderRadius.circular(20),
        border:       Border.all(color: color.withOpacity(.18))),
    child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 13)),
  );
}

// ══════════════════════════════════════════════════════════
//  TACTICAL MAP CARD（不變）
// ══════════════════════════════════════════════════════════
class _TacticalMapCard extends StatefulWidget {
  final List<DisasterAlert>         alerts;
  final bool                        isSimulation;
  final String                      adminArea;
  final ValueChanged<RadarNode>     onNodeTap;
  final ValueChanged<DisasterAlert> onAlertTap;

  const _TacticalMapCard({
    required this.alerts, required this.isSimulation, required this.adminArea,
    required this.onNodeTap, required this.onAlertTap,
  });

  @override
  State<_TacticalMapCard> createState() => _TacticalMapCardState();
}

class _TacticalMapCardState extends State<_TacticalMapCard> with TickerProviderStateMixin {
  late final AnimationController _radarCtrl;
  late final AnimationController _blinkCtrl;
  String? _pressedNodeId;

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
    final areaNodes  = getNodesForArea(widget.adminArea);
    final alertNodes = buildAlertNodes(widget.alerts, widget.adminArea);

    return _card(
      padding: EdgeInsets.zero,
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
          child: Row(children: [
            Container(width: 38, height: 38,
              decoration: BoxDecoration(
                  color: kBlue.withOpacity(.10), borderRadius: BorderRadius.circular(11)),
              child: const Icon(Icons.radar_rounded, color: kBlue)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('轄區防災雷達圖',
                  style: TextStyle(color: kTextMain, fontSize: 16, fontWeight: FontWeight.w800)),
              const SizedBox(height: 3),
              Text('${widget.adminArea}｜防災據點分布',
                  style: const TextStyle(color: kTextSub, fontSize: 12)),
            ])),
            _smallBadge(
              widget.alerts.isEmpty ? '目前無警報' : '${widget.alerts.length} 則警報',
              widget.alerts.isEmpty ? kGreen : kOrange,
            ),
          ]),
        ),
        const Divider(height: 1, color: kBorder),
        Expanded(
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(14)),
            child: LayoutBuilder(builder: (ctx, constraints) {
              final w = constraints.maxWidth;
              final h = constraints.maxHeight;
              return Stack(children: [
                Positioned.fill(
                  child: AnimatedBuilder(
                    animation: _radarCtrl,
                    builder: (_, __) => CustomPaint(
                      painter: _RadarMapPainter(
                        angle:        _radarCtrl.value * Math.pi * 2,
                        hasAlerts:    widget.alerts.isNotEmpty,
                        isSimulation: widget.isSimulation,
                      ),
                    ),
                  ),
                ),
                Center(child: _buildCenterNode(widget.adminArea)),
                for (final node in areaNodes) _buildRadarNodeWidget(node, w, h),
                for (final an in alertNodes) _buildAlertNodeWidget(an, w, h),
                Positioned(left: 18, bottom: 18,
                    child: _RadarLegend(hasAlerts: widget.alerts.isNotEmpty)),
                Positioned(right: 14, bottom: 18,
                    child: Text('點擊節點查看詳情',
                        style: TextStyle(color: kTextSub.withOpacity(.6), fontSize: 11))),
              ]);
            }),
          ),
        ),
      ]),
    );
  }

  Widget _buildCenterNode(String adminArea) {
    final label = adminArea.replaceAll('縣', '').replaceAll('市', '');
    return Container(
      width: 74, height: 74,
      decoration: BoxDecoration(
        color: Colors.white, shape: BoxShape.circle,
        border: Border.all(color: kBlue, width: 2),
        boxShadow: [BoxShadow(color: kBlue.withOpacity(.18), blurRadius: 18, spreadRadius: 2)],
      ),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: kBlue, fontSize: 13, fontWeight: FontWeight.w900)),
        const SizedBox(height: 2),
        const Text('指揮區', style: TextStyle(color: kTextSub, fontSize: 10)),
      ]),
    );
  }

  Widget _buildRadarNodeWidget(RadarNode node, double w, double h) {
    final isPressed = _pressedNodeId == node.id;
    return Positioned(
      left: w * node.relX - 44, top: h * node.relY - 38,
      child: GestureDetector(
        onTapDown:   (_) => setState(() => _pressedNodeId = node.id),
        onTapUp:     (_) { setState(() => _pressedNodeId = null); widget.onNodeTap(node); },
        onTapCancel: () => setState(() => _pressedNodeId = null),
        child: AnimatedScale(
          scale: isPressed ? 0.92 : 1.0, duration: const Duration(milliseconds: 120),
          child: _RadarMarker(label: node.label, color: node.color, isPressed: isPressed),
        ),
      ),
    );
  }

  Widget _buildAlertNodeWidget(AlertRadarNode an, double w, double h) {
    final color = _typeColor(an.alert.type);
    final icon  = _typeIcon(an.alert.type);
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
                decoration: BoxDecoration(
                  color:        color.withOpacity(.15),
                  borderRadius: BorderRadius.circular(6),
                  border:       Border.all(color: color.withOpacity(.6)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(icon, color: color, size: 10),
                  const SizedBox(width: 4),
                  Text(an.alert.title.length > 8
                      ? '${an.alert.title.substring(0, 8)}…'
                      : an.alert.title,
                      style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w800)),
                ]),
              ),
              const SizedBox(height: 4),
              Container(width: 12, height: 12,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: color.withOpacity(.6), blurRadius: 10, spreadRadius: 2)]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _RadarMapPainter extends CustomPainter {
  final double angle;
  final bool   hasAlerts, isSimulation;
  const _RadarMapPainter({required this.angle, required this.hasAlerts, required this.isSimulation});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFFF8FAFC));
    final center    = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.height * .46;
    final axisPaint = Paint()..color = const Color(0xFFE2E8F0)..strokeWidth = 1;
    canvas
      ..drawLine(Offset(center.dx, 0), Offset(center.dx, size.height), axisPaint)
      ..drawLine(Offset(0, center.dy), Offset(size.width, center.dy),  axisPaint)
      ..drawLine(Offset(0, 0), Offset(size.width, size.height), axisPaint)
      ..drawLine(Offset(size.width, 0), Offset(0, size.height), axisPaint);
    final ringColor = (hasAlerts || isSimulation) ? kOrange.withOpacity(.35) : const Color(0xFFBFDBFE).withOpacity(.55);
    final ringPaint = Paint()..color = ringColor..style = PaintingStyle.stroke..strokeWidth = 1;
    for (int i = 1; i <= 4; i++) canvas.drawCircle(center, maxRadius * i / 4, ringPaint);
    final sweepColor = isSimulation ? kOrange.withOpacity(.10) : kBlue.withOpacity(.14);
    final sweep = Path()
      ..moveTo(center.dx, center.dy)
      ..arcTo(Rect.fromCircle(center: center, radius: maxRadius), angle, 0.78, false)
      ..close();
    canvas.drawPath(sweep, Paint()..color = sweepColor..style = PaintingStyle.fill);
    final armColor = isSimulation ? kOrange.withOpacity(.55) : kBlue.withOpacity(.50);
    final end = Offset(center.dx + maxRadius * Math.cos(angle), center.dy + maxRadius * Math.sin(angle));
    canvas.drawLine(center, end, Paint()..color = armColor..strokeWidth = 2.4..strokeCap = StrokeCap.round);
    final glowEnd = Offset(center.dx + maxRadius * .72 * Math.cos(angle), center.dy + maxRadius * .72 * Math.sin(angle));
    canvas.drawCircle(glowEnd, 4, Paint()..color = armColor.withOpacity(.80)..style = PaintingStyle.fill);
    final numStyle = TextStyle(color: kBlue.withOpacity(.35), fontSize: 10, fontWeight: FontWeight.w700);
    void drawNum(String t, Offset o) {
      (TextPainter(text: TextSpan(text: t, style: numStyle), textDirection: TextDirection.ltr)..layout()).paint(canvas, o);
    }
    drawNum('1', Offset(center.dx + maxRadius * .34, center.dy - maxRadius * .34));
    drawNum('2', Offset(center.dx + maxRadius * .62, center.dy - maxRadius * .62));
    drawNum('3', Offset(center.dx - maxRadius * .18, center.dy + maxRadius * .66));
    drawNum('4', Offset(center.dx + maxRadius * .02, center.dy + maxRadius * .92));
  }

  @override
  bool shouldRepaint(covariant _RadarMapPainter old) =>
      old.angle != angle || old.hasAlerts != hasAlerts || old.isSimulation != isSimulation;
}

class _RadarMarker extends StatelessWidget {
  final String label;
  final Color  color;
  final bool   isPressed;
  const _RadarMarker({required this.label, required this.color, this.isPressed = false});

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding:  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color:        isPressed ? color.withOpacity(.22) : color.withOpacity(.10),
          borderRadius: BorderRadius.circular(6),
          border:       Border.all(color: color.withOpacity(isPressed ? .6 : .35)),
          boxShadow: isPressed ? [BoxShadow(color: color.withOpacity(.25), blurRadius: 8, spreadRadius: 1)] : null,
        ),
        child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w800)),
      ),
      const SizedBox(height: 6),
      Container(width: 11, height: 11,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: color.withOpacity(isPressed ? .55 : .35), blurRadius: isPressed ? 14 : 8)]),
      ),
    ]);
  }
}

class _RadarLegend extends StatelessWidget {
  final bool hasAlerts;
  const _RadarLegend({this.hasAlerts = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 130, padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color:        Colors.white.withOpacity(.94),
        borderRadius: BorderRadius.circular(10),
        border:       Border.all(color: kBorder),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(.04), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        const Text('LEGEND', style: TextStyle(color: kTextSub, fontSize: 9, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        const _MiniLegend(color: kGreen,            text: '避難收容'),
        const _MiniLegend(color: kOrange,           text: '政府機關'),
        const _MiniLegend(color: Color(0xFF3B82F6), text: '物資據點'),
        const _MiniLegend(color: Color(0xFF93C5FD), text: '監測站'),
        if (hasAlerts) ...[
          const Divider(height: 10, color: kBorder),
          const _MiniLegend(color: kRed,    text: '地震警報', isAlert: true),
          const _MiniLegend(color: kOrange, text: '颱風警報', isAlert: true),
          const _MiniLegend(color: kBlue,   text: '水災警報', isAlert: true),
        ],
      ]),
    );
  }
}

class _MiniLegend extends StatelessWidget {
  final Color color; final String text; final bool isAlert;
  const _MiniLegend({required this.color, required this.text, this.isAlert = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
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
}

// ══════════════════════════════════════════════════════════
//  RADAR NODE DETAIL DIALOG
// ══════════════════════════════════════════════════════════
class _RadarNodeDetailDialog extends StatelessWidget {
  final RadarNode node; final CitizenViewmodel citizenVm;
  final AdminSupplyViewModel supplyVm; final WeatherViewModel weatherVm;
  const _RadarNodeDetailDialog({required this.node, required this.citizenVm, required this.supplyVm, required this.weatherVm});

  @override
  Widget build(BuildContext context) {
    final color      = node.color;
    final stats      = node.stats;
    final isShelter  = node.id == 'shelter';
    final isSupply   = node.id == 'supply';
    final isGov      = node.id == 'gov';
    final isMonitor  = node.id == 'monitor';
    final isSimulation  = weatherVm.isSimulation;
    final citizenCount  = citizenVm.citizens.length;
    final supplyCount   = supplyVm.supplies.length;
    final shelterCurrentText = isSimulation ? '已收容 128 人' : '已登記 $citizenCount 人';
    final supplyCurrentText  = isSimulation ? '現存 980 箱'   : '共 $supplyCount 項';
    String supplyRatioText;
    if (isSimulation) {
      supplyRatioText = '82%';
    } else if (stats.capacity != '--') {
      final capNum = int.tryParse(stats.capacity.replaceAll(',', '').replaceAll(RegExp(r'[^0-9]'), ''));
      supplyRatioText = (capNum != null && capNum > 0)
          ? '${((supplyCount / capNum) * 100).clamp(0, 100).round()}%'
          : '$supplyCount 項';
    } else { supplyRatioText = '--'; }
    final govCitizenText = isSimulation ? '128 人' : '$citizenCount 人';
    final govSupplyText  = isSimulation ? '980 項' : '$supplyCount 項';
    final monitorStatus  = isSimulation ? '模擬警戒中' : '正常回傳';
    final monitorSource  = isSimulation ? '模擬情境資料' : '氣象署 API';

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 380,
        decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(16),
          border: Border.all(color: kBorder),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(.12), blurRadius: 28, offset: const Offset(0, 8))],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 14, 14),
            child: Row(children: [
              Container(width: 48, height: 48,
                decoration: BoxDecoration(color: color.withOpacity(.12), borderRadius: BorderRadius.circular(14)),
                child: Icon(node.icon, color: color, size: 24)),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(node.label, style: const TextStyle(color: kTextMain, fontSize: 17, fontWeight: FontWeight.w800)),
                const SizedBox(height: 5),
                _NodeStatusBadge(
                  text:  isSimulation ? '警戒模擬模式' : isShelter ? '災民管理即時數據' : isSupply ? '物資管理即時數據' : isMonitor ? '氣象署即時數據' : '應變中心運作中',
                  color: isSimulation ? kOrange : color,
                ),
              ])),
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, color: kTextSub, size: 18)),
            ]),
          ),
          const Divider(height: 1, color: kBorder),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
            child: Row(children: [
              if (isShelter) ...[
                Expanded(child: _StatBox(label: '設施容量', value: stats.capacity, color: color)),
                const SizedBox(width: 10),
                Expanded(child: _StatBox(label: '目前收容', value: shelterCurrentText, color: color)),
              ] else if (isSupply) ...[
                Expanded(child: _StatBox(label: '設施容量', value: stats.capacity, color: color)),
                const SizedBox(width: 10),
                Expanded(child: _StatBox(label: '現有物資', value: supplyCurrentText, color: color)),
                const SizedBox(width: 10),
                Expanded(child: _StatBox(label: '庫存比例', value: supplyRatioText, color: color)),
              ] else if (isGov) ...[
                Expanded(child: _StatBox(label: '應變中心', value: '24h 運作中', color: color)),
                const SizedBox(width: 10),
                Expanded(child: _StatBox(label: '登記災民', value: govCitizenText, color: color)),
                const SizedBox(width: 10),
                Expanded(child: _StatBox(label: '物資項目', value: govSupplyText, color: color)),
              ] else if (isMonitor) ...[
                Expanded(child: _StatBox(label: '監測狀態', value: monitorStatus, color: color)),
                const SizedBox(width: 10),
                Expanded(child: _StatBox(label: '資料來源', value: monitorSource, color: color)),
              ],
            ]),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: double.infinity, padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                    color: color.withOpacity(.06), borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: color.withOpacity(.15))),
                child: Text(node.description,
                    style: const TextStyle(color: kTextMain, fontSize: 13, height: 1.6)),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Icon(isSimulation ? Icons.science_outlined : Icons.check_circle_outline,
                    color: isSimulation ? kOrange : kGreen, size: 13),
                const SizedBox(width: 5),
                Text(isSimulation ? '模擬模式：數據為展示用假資料' : '數據來源：系統即時資料',
                    style: TextStyle(
                        color: isSimulation ? kOrange : kTextSub, fontSize: 12,
                        fontWeight: isSimulation ? FontWeight.w600 : FontWeight.w400)),
              ]),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: color, foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0),
                  child: const Text('關閉', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label, value; final Color color;
  const _StatBox({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
          color: color.withOpacity(.06), borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(.15))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(color: kTextSub, fontSize: 11)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w800),
            maxLines: 1, overflow: TextOverflow.ellipsis),
      ]),
    );
  }
}

class _NodeStatusBadge extends StatelessWidget {
  final String text; final Color color;
  const _NodeStatusBadge({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
          color: color.withOpacity(.10), borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withOpacity(.25))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text(text, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  ALERT DETAIL DIALOG
// ══════════════════════════════════════════════════════════
class _AlertDetailDialog extends StatelessWidget {
  final DisasterAlert alert; final VoidCallback onClose;
  const _AlertDetailDialog({required this.alert, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final color = _typeColor(alert.type);
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 440,
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(14),
            border: Border.all(color: kBorder)),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 12, 14),
            child: Row(children: [
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
            ]),
          ),
          const Divider(height: 1, color: kBorder),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(children: [
              _detailRow(Icons.location_on_outlined, '地點', alert.location),
              const SizedBox(height: 12),
              _detailRow(Icons.description_outlined,  '說明', alert.description),
              const SizedBox(height: 12),
              _detailRow(Icons.access_time,           '時間', _formatTime(alert.time)),
              const SizedBox(height: 16),
              Container(
                width: double.infinity, padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: kCardBg2, borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: kBorder)),
                child: const Text('資料來源：中央氣象署 / 水土保持署開放資料平台',
                    style: TextStyle(color: kTextSub, fontSize: 12)),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  static Widget _detailRow(IconData icon, String label, String value) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, color: kTextSub, size: 18),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(color: kTextSub, fontSize: 12)),
        const SizedBox(height: 3),
        Text(value, style: const TextStyle(color: kTextMain, fontSize: 13, fontWeight: FontWeight.w600)),
      ])),
    ]);
  }
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
  Widget build(BuildContext context) {
    return Dialog(
      alignment: const Alignment(.86, -.80),
      backgroundColor: Colors.transparent,
      child: Container(
        width: 390, constraints: const BoxConstraints(maxHeight: 520),
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(14),
            border: Border.all(color: kBorder)),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 10, 12),
            child: Row(children: [
              const Icon(Icons.notifications_active_outlined, color: kOrange, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text('災害通報 (${alerts.length})',
                  style: const TextStyle(color: kTextMain, fontWeight: FontWeight.w800, fontSize: 15))),
              IconButton(onPressed: onClose, icon: const Icon(Icons.close, color: kTextSub, size: 18)),
            ]),
          ),
          const Divider(height: 1, color: kBorder),
          if (alerts.isEmpty)
            const Padding(padding: EdgeInsets.all(24),
                child: Text('近 30 天內沒有災害通報', style: TextStyle(color: kTextSub)))
          else
            Flexible(
              child: ListView.separated(
                padding: const EdgeInsets.all(12), itemCount: alerts.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) => _EventListCard._alertTile(alerts[i], onAlertTap),
              ),
            ),
        ]),
      ),
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
      borderRadius: BorderRadius.circular(14), onTap: onTap,
      child: _card(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          Container(width: 44, height: 44,
            decoration: BoxDecoration(color: kOrange.withOpacity(.10), borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.apartment_rounded, color: kOrange)),
          const SizedBox(width: 13),
          const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('防空避難設施',
                style: TextStyle(color: kTextMain, fontSize: 16, fontWeight: FontWeight.w800)),
            SizedBox(height: 4),
            Text('查看避難地點', style: TextStyle(color: kTextSub, fontSize: 13)),
          ])),
          const Icon(Icons.chevron_right, color: kTextSub),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  ENVIRONMENT CARD
// ══════════════════════════════════════════════════════════
const Map<String, String> _kRainStationMap = {
  '台北市':'C0A9M0','新北市':'C0A870','桃園市':'C0A9A0','台中市':'C0G650',
  '台南市':'C0R030','高雄市':'C0R170','基隆市':'C0A520','新竹市':'C0A9P0',
  '嘉義市':'C0R010','新竹縣':'C0A9Q0','苗栗縣':'C0F9A0','彰化縣':'C0G510',
  '南投縣':'C0G640','雲林縣':'C0R050','嘉義縣':'C0R020','屏東縣':'C0R200',
  '宜蘭縣':'C0A680','花蓮縣':'C0Z100','台東縣':'C0Z200','澎湖縣':'C0SA00',
  '金門縣':'C0UB00','連江縣':'C0UA00',
};
const Map<String, String> _kWeatherStationMap = {
  '台北市':'C0A770','新北市':'C0AK10','桃園市':'C0C720','台中市':'C0FB70',
  '台南市':'C0N030','高雄市':'C0V890','基隆市':'C0B040','新竹市':'C0D680',
  '嘉義市':'C0N010','新竹縣':'C0D690','苗栗縣':'C0E930','彰化縣':'C0G9B0',
  '南投縣':'C0G9B0','雲林縣':'C0R9B0','嘉義縣':'C0R030','屏東縣':'C0R960',
  '宜蘭縣':'C0UB20','花蓮縣':'C0TA10','台東縣':'C0SB20','澎湖縣':'C0W200',
  '金門縣':'C0W240','連江縣':'C0W220',
};
String _getRainStation(String a)    { final c = AreaDataHelper.toCityName(a); return _kRainStationMap[c]    ?? 'C0G640'; }
String _getWeatherStation(String a) { final c = AreaDataHelper.toCityName(a); return _kWeatherStationMap[c] ?? 'C0G640'; }

class _EnvironmentCard extends StatefulWidget {
  final bool isSimulation; final String adminArea;
  const _EnvironmentCard({required this.isSimulation, required this.adminArea});
  @override State<_EnvironmentCard> createState() => _EnvironmentCardState();
}

class _EnvironmentCardState extends State<_EnvironmentCard> {
  static const String _cwaKey = 'CWA-AFE44442-4E97-4836-A31F-0D743B56732B';
  String _rain='--', _temp='--', _humidity='--', _weather='載入中', _stationName='';
  bool   _isLoading=false, _isOnline=false;

  @override void initState() { super.initState(); _loadEnvData(); }
  @override void didUpdateWidget(_EnvironmentCard old) {
    super.didUpdateWidget(old);
    if (old.adminArea != widget.adminArea) _loadEnvData();
  }

  Future<void> _loadEnvData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _fetchRainfall(_getRainStation(widget.adminArea)),
        _fetchWeather(_getWeatherStation(widget.adminArea)),
      ]);
      if (!mounted) return;
      setState(() {
        _rain = results[0]['rainfall'] ?? '--'; _stationName = results[0]['stationName'] ?? '';
        _temp = results[1]['temp'] ?? '--'; _humidity = results[1]['humidity'] ?? '--';
        _weather = results[1]['weather'] ?? '--'; _isOnline = true;
      });
    } catch (e) {
      debugPrint('[EnvCard ERROR] $e');
      if (mounted) setState(() => _isOnline = false);
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<Map<String, String>> _fetchRainfall(String stationId) async {
    final url = Uri.parse('https://opendata.cwa.gov.tw/api/v1/rest/datastore/O-A0002-001?Authorization=$_cwaKey&StationId=$stationId');
    final res  = await http.get(url).timeout(const Duration(seconds: 10));
    final data = jsonDecode(res.body);
    try {
      final s    = (data['records']['Station'] as List).first;
      final name = s['StationName'] ?? stationId;
      final el   = s['WeatherElement'];
      dynamic rain = el['Now']?['Precipitation'] ?? el['Precipitation'] ?? el['Past1Hour']?['Precipitation'];
      final v = double.tryParse(rain?.toString() ?? '');
      return {'rainfall': (v == null || v < 0) ? '0mm' : '${v}mm', 'stationName': name};
    } catch (_) { return {'rainfall': '0mm', 'stationName': stationId}; }
  }

  Future<Map<String, String>> _fetchWeather(String stationId) async {
    String cleanVal(dynamic v) {
      final str = v?.toString() ?? '--'; final d = double.tryParse(str);
      return (d == null || d <= -99) ? '--' : str;
    }
    try {
      final url = Uri.parse('https://opendata.cwa.gov.tw/api/v1/rest/datastore/O-A0001-001?Authorization=$_cwaKey&StationId=$stationId&WeatherElement=AirTemperature,RelativeHumidity,Weather');
      final res  = await http.get(url).timeout(const Duration(seconds: 10));
      final data = jsonDecode(res.body);
      final stations = data['records']['Station'] as List;
      if (stations.isNotEmpty) {
        final el = stations.first['WeatherElement'];
        final temp = cleanVal(el['AirTemperature']);
        if (temp != '--') return {'temp': temp, 'humidity': cleanVal(el['RelativeHumidity']), 'weather': el['Weather']?.toString() ?? '--'};
      }
    } catch (_) {}
    try {
      final url = Uri.parse('https://opendata.cwa.gov.tw/api/v1/rest/datastore/O-A0002-001?Authorization=$_cwaKey&StationId=$stationId&WeatherElement=AirTemperature,RelativeHumidity');
      final res  = await http.get(url).timeout(const Duration(seconds: 10));
      final data = jsonDecode(res.body);
      final stations = data['records']['Station'] as List;
      if (stations.isNotEmpty) {
        final el = stations.first['WeatherElement'];
        return {'temp': cleanVal(el['AirTemperature']), 'humidity': cleanVal(el['RelativeHumidity']), 'weather': '--'};
      }
    } catch (_) {}
    return {'temp': '--', 'humidity': '--', 'weather': '--'};
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<WeatherViewModel>();
    final isSimulation = vm.isSimulation;
    String rain = _rain, temp = _temp, humidity = _humidity, weather = _weather, station = _stationName;
    String badgeText; Color badgeColor;
    if (isSimulation) {
      rain = '487.3mm'; temp = '38'; humidity = '95'; weather = '雷陣雨'; station = '模擬情境數值';
      badgeText = '模擬'; badgeColor = kOrange;
    } else if (_isLoading) { badgeText = '載入中'; badgeColor = kBlue;
    } else if (_isOnline)  { badgeText = '即時';   badgeColor = kGreen;
    } else                 { badgeText = '無資料'; badgeColor = kMuted; }

    return _card(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.cloud_outlined, color: kBlue, size: 18),
          const SizedBox(width: 8),
          const Text('環境監測', style: TextStyle(color: kTextMain, fontSize: 16, fontWeight: FontWeight.w800)),
          const Spacer(),
          if (_isLoading && !isSimulation)
            const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: kBlue))
          else _smallBadge(badgeText, badgeColor),
          IconButton(visualDensity: VisualDensity.compact, onPressed: _loadEnvData,
              icon: const Icon(Icons.refresh, color: kTextSub, size: 16)),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _envBox(Icons.water_drop_outlined, kBlue,  '累積雨量', rain, '過去1小時')),
          const SizedBox(width: 10),
          Expanded(child: _envBox(Icons.thermostat,          kGreen, '氣溫 °C', temp, weather)),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Icon(isSimulation ? Icons.science_outlined : Icons.location_on_outlined,
              color: isSimulation ? kOrange : kTextSub, size: 14),
          const SizedBox(width: 5),
          Expanded(child: Text(
            station.isNotEmpty ? (isSimulation ? station : '$station 測站') : '資料載入中',
            style: TextStyle(color: isSimulation ? kOrange : kTextSub, fontSize: 12),
            overflow: TextOverflow.ellipsis)),
          Text('濕度：$humidity %', style: const TextStyle(color: kTextSub, fontSize: 12)),
        ]),
      ]),
    );
  }

  static Widget _envBox(IconData icon, Color color, String label, String value, String sub) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: kCardBg2, borderRadius: BorderRadius.circular(10), border: Border.all(color: kBorder)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, color: color, size: 14), const SizedBox(width: 5),
          Expanded(child: Text(label, style: const TextStyle(color: kTextSub, fontSize: 12))),
        ]),
        const SizedBox(height: 8),
        Text(value, style: TextStyle(color: color, fontSize: 25, fontWeight: FontWeight.w800)),
        Text(sub, style: const TextStyle(color: kTextSub, fontSize: 11), overflow: TextOverflow.ellipsis),
      ]),
    );
  }
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
  Widget build(BuildContext context) {
    return _card(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        Row(children: [
          const Icon(Icons.flash_on_rounded, color: kTextMain, size: 18),
          const SizedBox(width: 6),
          const Expanded(child: Text('即時事件動態', style: TextStyle(color: kTextMain, fontSize: 16, fontWeight: FontWeight.w800))),
          _smallBadge('30天｜最多30筆', kBlue),
          IconButton(onPressed: onRefresh, icon: const Icon(Icons.refresh, color: kBlue, size: 18)),
        ]),
        const SizedBox(height: 8),
        if (isLoading)
          const Expanded(child: Center(child: CircularProgressIndicator(color: kBlue)))
        else if (alerts.isEmpty)
          Expanded(child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.check_circle_outline, color: kGreen, size: 36),
            const SizedBox(height: 10),
            const Text('目前轄區平安', style: TextStyle(color: kGreen, fontWeight: FontWeight.w700, fontSize: 15)),
            const SizedBox(height: 4),
            const Text('近 30 天內沒有重大通報', style: TextStyle(color: kTextSub, fontSize: 13)),
          ])))
        else
          Expanded(child: ListView.separated(
            itemCount: alerts.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (ctx, i) => _alertTile(alerts[i], onAlertTap),
          )),
      ]),
    );
  }

  static Widget _alertTile(DisasterAlert alert, ValueChanged<DisasterAlert> onTap) {
    final color = _typeColor(alert.type);
    return InkWell(
      borderRadius: BorderRadius.circular(10), onTap: () => onTap(alert),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: kCardBg2, borderRadius: BorderRadius.circular(10), border: Border.all(color: kBorder)),
        child: Row(children: [
          Container(width: 38, height: 38,
            decoration: BoxDecoration(color: color.withOpacity(.10), borderRadius: BorderRadius.circular(10)),
            child: Icon(_typeIcon(alert.type), color: color, size: 19)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(alert.title, style: const TextStyle(color: kTextMain, fontWeight: FontWeight.w800, fontSize: 14)),
            const SizedBox(height: 4),
            Text('${alert.location} · ${_formatTime(alert.time)}',
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: kTextSub, fontSize: 12)),
          ])),
          _smallBadge(alert.severity, color),
        ]),
      ),
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
  Widget build(BuildContext context) {
    return _card(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        const Row(children: [
          Icon(Icons.timeline_rounded, color: kTextMain, size: 18),
          SizedBox(width: 7),
          Expanded(child: Text('事件時間軸', style: TextStyle(color: kTextMain, fontSize: 16, fontWeight: FontWeight.w800))),
          Text('最近 30 天', style: TextStyle(color: kTextSub, fontSize: 12)),
        ]),
        const SizedBox(height: 14),
        if (events.isEmpty)
          const Expanded(child: Center(child: Text('目前沒有事件紀錄', style: TextStyle(color: kTextSub))))
        else
          Expanded(child: ListView.builder(
            itemCount: events.length,
            itemBuilder: (ctx, i) {
              final e = events[i];
              return InkWell(
                onTap: () {
                  final match = alerts.where((a) => a.id == e.id).toList();
                  if (match.isNotEmpty) onEventTap(match.first);
                },
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Column(children: [
                    Container(width: 10, height: 10, decoration: BoxDecoration(color: e.color, shape: BoxShape.circle)),
                    Container(width: 1, height: 54, color: kBorder),
                  ]),
                  const SizedBox(width: 12),
                  Expanded(child: Padding(
                    padding: const EdgeInsets.only(bottom: 15),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(e.title, style: const TextStyle(color: kTextMain, fontWeight: FontWeight.w800, fontSize: 14)),
                      const SizedBox(height: 4),
                      Text(e.subtitle, style: const TextStyle(color: kTextSub, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Text(_relativeTime(e.time), style: const TextStyle(color: kTextSub, fontSize: 11)),
                    ]),
                  )),
                ]),
              );
            },
          )),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  SHARED HELPERS
// ══════════════════════════════════════════════════════════
Widget _card({required Widget child, EdgeInsetsGeometry padding = const EdgeInsets.all(14), double? height}) {
  return Container(
    height: height, padding: padding,
    decoration: BoxDecoration(
      color: kCardBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: kBorder),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(.035), blurRadius: 12, offset: const Offset(0, 4))],
    ),
    child: child,
  );
}

Widget _smallBadge(String text, Color color) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
        color: color.withOpacity(.08), borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(.16))),
    child: Text(text, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w800)),
  );
}

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

String _formatTime(DateTime t) {
  return '${t.year}/${t.month.toString().padLeft(2,'0')}/${t.day.toString().padLeft(2,'0')} ${t.hour.toString().padLeft(2,'0')}:${t.minute.toString().padLeft(2,'0')}';
}

String _relativeTime(DateTime t) {
  final diff = DateTime.now().difference(t);
  if (diff.inMinutes < 60) return '${diff.inMinutes} 分鐘前';
  if (diff.inHours   < 24) return '${diff.inHours} 小時前';
  return '${diff.inDays} 天前';
}