import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_disaster_app/core/models/citizen.dart';
import 'package:flutter_disaster_app/core/models/healthReport.dart';
import 'package:flutter_disaster_app/admin_APP/viewModels/citizen_viewmodel.dart';
import 'package:flutter_disaster_app/admin_APP/viewModels/emergency_viewmodel.dart';
import 'package:flutter_disaster_app/admin_APP/viewModels/supply_viewmodel.dart';
import 'package:flutter_disaster_app/admin_APP/screens/health_report_page.dart';
import 'package:flutter_disaster_app/core/models/emergency_request.dart';

// ── 色系 ────────────────────────────────────────────────────────
const Color _kBg       = Color(0xFFF5F7FA);
const Color _kCardBg   = Color(0xFFFFFFFF);
const Color _kBorder   = Color(0xFFE5E7EB);
const Color _kBlue     = Color(0xFF2563EB);
const Color _kGreen    = Color(0xFF16A34A);
const Color _kOrange   = Color(0xFFF59E0B);
const Color _kRed      = Color(0xFFDC2626);
const Color _kLime     = Color(0xFF4ADE80);   // 輕傷（螢光綠）
const Color _kTextMain = Color(0xFF0F172A);
const Color _kTextSub  = Color(0xFF64748B);

const String _baseUrl =
    'https://delphine-eisteddfodic-afflictively.ngrok-free.dev';

// ── 地址快取 ────────────────────────────────────────────────────
final Map<String, String> _addressCache = {};

Future<String> _fetchAddress(double lat, double lng) async {
  final key = '${lat.toStringAsFixed(5)},${lng.toStringAsFixed(5)}';
  if (_addressCache.containsKey(key)) return _addressCache[key]!;
  try {
    final uri = Uri.parse(
      'https://nominatim.openstreetmap.org/reverse'
      '?format=json&lat=$lat&lon=$lng&accept-language=zh-TW',
    );
    final res = await http.get(uri,
        headers: {'User-Agent': 'FlutterDisasterApp/1.0'}).timeout(
      const Duration(seconds: 6),
    );
    if (res.statusCode == 200) {
      final data    = jsonDecode(res.body);
      final address = data['address'] as Map<String, dynamic>?;
      final district = address?['suburb'] ??
          address?['town'] ??
          address?['village'] ??
          address?['city_district'] ??
          '';
      final road    = address?['road'] ?? '';
      final result  =
          [district, road].where((s) => s.isNotEmpty).join('');
      final display = result.isNotEmpty
          ? result
          : (data['display_name'] as String? ?? '')
              .split(',')
              .first;
      _addressCache[key] = display;
      return display;
    }
  } catch (_) {}
  return '${lat.toStringAsFixed(3)}, ${lng.toStringAsFixed(3)}';
}

// ════════════════════════════════════════════════════════════════
//  CitizenPage
// ════════════════════════════════════════════════════════════════
class CitizenPage extends StatefulWidget {
  const CitizenPage({super.key});
  @override
  State<CitizenPage> createState() => _CitizenPageState();
}

class _CitizenPageState extends State<CitizenPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    Future.microtask(() {
      if (!mounted) return;
      context.read<CitizenViewmodel>().loadCitizens();
      context.read<EmergencyViewModel>().loadEmergencies();
      context.read<AdminSupplyViewModel>().loadSupplies();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _kBg,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 14, 24, 0),
              child: Row(children: [
                Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                  Text('災民管理',
                      style: TextStyle(
                          color: _kTextMain,
                          fontSize: 26,
                          fontWeight: FontWeight.w800)),
                  SizedBox(height: 1),
                  Text('CITIZEN MANAGEMENT CENTER',
                      style: TextStyle(
                          color: _kTextSub,
                          fontSize: 11,
                          letterSpacing: 1.3)),
                ]),
                const SizedBox(width: 12),
                _tag('即時同步', _kGreen),
              ]),
            ),
            const SizedBox(height: 12),
            // ── Tab Bar ─────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                decoration: BoxDecoration(
                  color: _kCardBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _kBorder),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    color: _kBlue.withValues(alpha: .08),
                    borderRadius: BorderRadius.circular(8),
                    border:
                        Border.all(color: _kBlue.withValues(alpha: .25)),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  labelColor: _kBlue,
                  unselectedLabelColor: _kTextSub,
                  labelStyle: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700),
                  unselectedLabelStyle: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w500),
                  tabs: const [
                    Tab(text: '全部'),
                    Tab(text: 'SOS'),
                    Tab(text: '健康回報'),
                    Tab(text: '物資需求'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: const [
                  _TotalTab(),
                  _SosTab(),
                  HealthReportPage(),
                  _SupplyTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _tag(String text, Color color) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
            color: color.withValues(alpha: .08),
            borderRadius: BorderRadius.circular(999),
            border:
                Border.all(color: color.withValues(alpha: .18))),
        child: Text(text,
            style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w700)),
      );
}

// ════════════════════════════════════════════════════════════════
//  全部 Tab
// ════════════════════════════════════════════════════════════════
class _TotalTab extends StatefulWidget {
  const _TotalTab();
  @override
  State<_TotalTab> createState() => _TotalTabState();
}

class _TotalTabState extends State<_TotalTab> {
  List<HealthReport> _healthReports = [];
  late final MapController _mapCtrl;
  LatLng _mapCenter = const LatLng(23.9575, 120.9275); // 暨大
  double _mapZoom   = 14.0;
  String _filter    = 'all';

  @override
  void initState() {
    super.initState();
    _mapCtrl = MapController();
    _loadHealthReports();
    _loadAdminArea();
  }

  @override
  void dispose() {
    _mapCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAdminArea() async {
    final prefs = await SharedPreferences.getInstance();
    final area  = prefs.getString('adminArea') ?? '';
    final center = _centerForArea(area);
    final zoom   = _zoomForArea(area);
    if (!mounted) return;
    setState(() { _mapCenter = center; _mapZoom = zoom; });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _mapCtrl.move(center, zoom);
    });
  }

  LatLng _centerForArea(String area) {
    if (area.contains('暨大') || area.contains('暨南')) return const LatLng(23.9575, 120.9275);
    if (area.contains('南村'))  return const LatLng(23.9600, 120.9675);
    if (area.contains('埔里'))  return const LatLng(23.9750, 120.9650);
    if (area.contains('南投'))  return const LatLng(23.8500, 120.9750);
    return const LatLng(23.9577, 120.9308);
  }

  double _zoomForArea(String area) {
    if (area.contains('暨大') || area.contains('暨南')) return 14.0;
    if (area.contains('南村'))  return 13.0;
    if (area.contains('埔里'))  return 12.0;
    if (area.contains('南投'))  return 10.0;
    return 13.0;
  }

  Future<void> _loadHealthReports() async {
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
        if (mounted) setState(() => _healthReports = loaded);
      }
    } catch (_) {}
  }

  // ── 狀態工具 ────────────────────────────────────────────────
  String _normStatus(String s) {
    final st = s.trim().toLowerCase();
    if (st == 'safe'     || st == '安全') return 'safe';
    if (st == 'injured'  || st == '輕傷' || st == '轻伤') return 'injured';
    if (st == 'critical' || st == '重傷' || st == '重伤') return 'critical';
    return st;
  }

  HealthReport? _reportFor(String citizenId) {
    try {
      return _healthReports
          .firstWhere((r) => r.reporterId == citizenId);
    } catch (_) {
      return null;
    }
  }

  String _citizenStatus(Citizen c, EmergencyViewModel emVm) {
    final hasSos = emVm.emergencies
        .any((e) => e.userId == c.id && e.status != 'resolved');
    if (hasSos) return 'sos';
    final report = _reportFor(c.id);
    if (report != null) {
      final s = _normStatus(report.status);
      if (s == 'critical' || s == 'injured' || s == 'safe') return s;
      return 'health_report'; // 有回報但狀態不明確
    }
    return 'unknown'; // 完全無回報
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'sos':           return _kRed;
      case 'critical':      return _kOrange;
      case 'injured':       return _kLime;
      case 'safe':          return _kGreen;
      case 'health_report': return const Color(0xFF0891B2);
      default:              return _kBlue;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'sos':           return 'SOS';
      case 'critical':      return '重傷';
      case 'injured':       return '輕傷';
      case 'safe':          return '安全';
      case 'health_report': return '健康回報';
      default:              return '物資需求';
    }
  }

  // ── BUILD ──────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final citizenVm = context.watch<CitizenViewmodel>();
    final emVm      = context.watch<EmergencyViewModel>();
    final supplyVm  = context.watch<AdminSupplyViewModel>();

    final citizens    = citizenVm.citizens;
    final total       = citizens.length;
    final sosCount    = emVm.emergencies
        .where((e) => e.status != 'resolved')
        .length;
    final critical = _healthReports
        .where((r) => _normStatus(r.status) == 'critical')
        .length;
    final injured = _healthReports
        .where((r) => _normStatus(r.status) == 'injured')
        .length;
    final safe = _healthReports
        .where((r) => _normStatus(r.status) == 'safe')
        .length;
    final supplyNeed = supplyVm.supplies
        .where((s) => s.neededQty > s.stockQty)
        .length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
      child: Column(children: [
        // ── 統計卡片 ──────────────────────────────────────────
        _buildStatsRow(total, sosCount, critical, injured, safe, supplyNeed),
        const SizedBox(height: 12),
        // ── 地圖 ──────────────────────────────────────────────
        _buildMap(citizens, emVm),
        const SizedBox(height: 12),
        // ── 災民列表 + 健康回報 + 物資需求 ───────────────────────
        Expanded(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              if (_filter != 'supply') ...[
                _buildCitizenList(citizens, citizenVm, emVm),
              ],
              if (_filter == 'all') ...[
                const SizedBox(height: 12),
                _buildExtraSection('健康回報', 'health_report',
                    const Color(0xFF0891B2), Icons.favorite_border_rounded, citizens, emVm),
                const SizedBox(height: 12),
                _buildExtraSection('物資需求', 'unknown',
                    _kBlue, Icons.inventory_2_outlined, citizens, emVm),
              ],
              if (_filter == 'supply') ...[
                _buildExtraSection('物資需求', 'unknown',
                    _kBlue, Icons.inventory_2_outlined, citizens, emVm),
              ],
            ],
          ),
        ),
      ]),
    );
  }

  // ── 統計卡片列 ─────────────────────────────────────────────
  Widget _buildStatsRow(int total, int sos, int critical,
      int injured, int safe, int supply) {
    return Container(
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kBorder),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: .028),
              blurRadius: 6,
              offset: const Offset(0, 2))
        ],
      ),
      child: Row(children: [
        _tapCell(Icons.people_alt_outlined,   '$total',    '總災民',   _kBlue,   'all'),
        _divider(),
        _tapCell(Icons.sos_rounded,           '$sos',      'SOS',     _kRed,    'sos'),
        _divider(),
        _tapCell(Icons.warning_amber_rounded, '$critical', '重傷',    _kOrange, 'critical'),
        _divider(),
        _tapCell(Icons.healing_rounded,       '$injured',  '輕傷',    _kLime,   'injured'),
        _divider(),
        _tapCell(Icons.verified_user_rounded, '$safe',     '安全',    _kGreen,  'safe'),
        _divider(),
        _tapCell(Icons.inventory_2_outlined,  '$supply',   '物資需求', _kBlue,   'supply'),
      ]),
    );
  }

  Widget _tapCell(IconData icon, String val, String label, Color color, String filter) {
    final sel = _filter == filter;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _filter = filter),
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
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 16),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(val, style: TextStyle(color: sel ? color : _kTextMain, fontSize: 20, fontWeight: FontWeight.w800, height: 1.1)),
                Text(label, style: const TextStyle(color: _kTextSub, fontSize: 11)),
              ]),
            ),
            if (sel) Icon(Icons.check_circle_rounded, color: color, size: 14),
          ]),
        ),
      ),
    );
  }

  // ── 地圖 ───────────────────────────────────────────────────
  Widget _buildMap(List<Citizen> citizens, EmergencyViewModel emVm) {
    final markers = <Marker>[];

    // 健康狀態標記（只顯示 重傷/輕傷/安全，不含健康回報）
    for (final r in _healthReports) {
      if (r.lat == null || r.lng == null) continue;
      final status = _normStatus(r.status);
      if (status != 'critical' && status != 'injured' && status != 'safe') continue;
      final color  = _statusColor(status);
      markers.add(_buildMarker(
        LatLng(r.lat!, r.lng!),
        r.name,
        color,
        status == 'critical'
            ? Icons.warning_amber_rounded
            : status == 'safe'
                ? Icons.verified_user_rounded
                : Icons.healing_rounded,
      ));
    }

    // SOS 標記（紅色）
    for (final e in emVm.emergencies) {
      if (e.status == 'resolved') continue;
      if (e.lat == 0 && e.lng == 0) continue;
      markers.add(Marker(
        point: LatLng(e.lat, e.lng),
        width: 36, height: 36,
        child: Container(
          decoration: BoxDecoration(
            color: _kRed.withValues(alpha: .15),
            shape: BoxShape.circle,
            border: Border.all(color: _kRed, width: 2),
          ),
          child: const Icon(Icons.sos_rounded,
              color: _kRed, size: 18),
        ),
      ));
    }

    // 未有健康回報的災民 → 藍色
    final reportedIds =
        _healthReports.map((r) => r.reporterId).toSet();
    for (final c in citizens) {
      if (reportedIds.contains(c.id)) continue;
      if (c.latitude == 0 && c.longitude == 0) continue;
      markers.add(_buildMarker(
          LatLng(c.latitude, c.longitude), c.name, _kBlue, null));
    }

    return Container(
      height: 220,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBorder),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: .05),
              blurRadius: 10,
              offset: const Offset(0, 3))
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(children: [
          FlutterMap(
            mapController: _mapCtrl,
            options: MapOptions(
              initialCenter: _mapCenter,
              initialZoom: _mapZoom,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://a.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
                userAgentPackageName:
                    'com.example.flutter_disaster_app',
              ),
              MarkerLayer(markers: markers),
            ],
          ),
          // 圖例
          Positioned(
            left: 10,
            bottom: 10,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .92),
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: _kBorder),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: .06),
                      blurRadius: 6)
                ],
              ),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                _legendItem('SOS',    _kRed),
                _legendItem('重傷',   _kOrange),
                _legendItem('輕傷',   _kLime),
                _legendItem('安全',   _kGreen),
                _legendItem('物資需求', _kBlue),
              ]),
            ),
          ),
          // 右側按鈕欄：刷新 + 放大 + 縮小 + 回中心
          Positioned(
            right: 10,
            top: 10,
            child: Column(children: [
              _mapBtn(Icons.refresh_rounded, _kBlue, _loadHealthReports),
              const SizedBox(height: 4),
              _mapBtn(Icons.add, _kTextMain,
                  () => _mapCtrl.move(_mapCtrl.camera.center, _mapCtrl.camera.zoom + 1)),
              const SizedBox(height: 4),
              _mapBtn(Icons.remove, _kTextMain,
                  () => _mapCtrl.move(_mapCtrl.camera.center, _mapCtrl.camera.zoom - 1)),
              const SizedBox(height: 4),
              _mapBtn(Icons.my_location_rounded, _kBlue,
                  () => _mapCtrl.move(_mapCenter, _mapZoom)),
            ]),
          ),
        ]),
      ),
    );
  }

  Marker _buildMarker(
      LatLng point, String name, Color color, IconData? icon) {
    return Marker(
      point: point,
      width: 32, height: 32,
      child: Container(
        decoration: BoxDecoration(
          color: color.withValues(alpha: .15),
          shape: BoxShape.circle,
          border: Border.all(color: color, width: 1.8),
        ),
        child: icon != null
            ? Icon(icon, color: color, size: 14)
            : Center(
                child: Text(
                  name.isNotEmpty ? name[0] : '?',
                  style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.w800),
                ),
              ),
      ),
    );
  }

  Widget _legendItem(String label, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 8,
            height: 8,
            decoration:
                BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text(label,
            style: const TextStyle(
                fontSize: 10,
                color: _kTextMain,
                fontWeight: FontWeight.w500)),
      ]),
    );
  }

  Widget _mapBtn(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30, height: 30,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .94),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: _kBorder),
        ),
        child: Icon(icon, size: 16, color: color),
      ),
    );
  }

  // ── 災民列表（分組顯示）────────────────────────────────────
  Widget _buildCitizenList(List<Citizen> citizens,
      CitizenViewmodel vm, EmergencyViewModel emVm) {

    const allGroups = [
      ('SOS',  'sos',      _kRed,    Icons.sos_rounded),
      ('重傷', 'critical', _kOrange, Icons.warning_amber_rounded),
      ('輕傷', 'injured',  _kLime,   Icons.healing_rounded),
      ('安全', 'safe',     _kGreen,  Icons.verified_user_rounded),
    ];
    final groups = _filter == 'all'
        ? allGroups
        : allGroups.where((g) => g.$2 == _filter).toList();

    return Container(
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBorder),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: .03),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(children: [
        // 標題列
        Container(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
          decoration: const BoxDecoration(
            color: Color(0xFFF8FAFC),
            borderRadius: BorderRadius.vertical(top: Radius.circular(13)),
            border: Border(bottom: BorderSide(color: _kBorder)),
          ),
          child: Row(children: [
            const Icon(Icons.people_alt_outlined, color: _kTextMain, size: 16),
            const SizedBox(width: 6),
            const Text('災民列表',
                style: TextStyle(color: _kTextMain, fontSize: 14, fontWeight: FontWeight.w700)),
            const Spacer(),
            Text('共 ${citizens.length} 人',
                style: const TextStyle(color: _kTextSub, fontSize: 11)),
            const SizedBox(width: 10),
            _iconBtn(Icons.refresh_rounded, _kBlue, vm.loadCitizens),
          ]),
        ),
        // 分組內容（在 ListView 裡，不用 Expanded）
        if (vm.isLoading)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator(color: _kBlue, strokeWidth: 2.5)),
          )
        else if (vm.errorMessage != null)
          Padding(padding: const EdgeInsets.all(16), child: Text(vm.errorMessage!, style: const TextStyle(color: _kRed)))
        else if (citizens.isEmpty)
          const Padding(padding: EdgeInsets.all(16), child: Text('暫無資料', style: TextStyle(color: _kTextSub)))
        else
          Column(children: _buildGroupedItems(citizens, emVm, groups)),
      ]),
    );
  }

  // ── 健康回報 / 物資需求 獨立區塊 ────────────────────────────
  Widget _buildExtraSection(
    String label, String statusKey, Color color, IconData icon,
    List<Citizen> citizens, EmergencyViewModel emVm,
  ) {
    final group = citizens
        .where((c) => _citizenStatus(c, emVm) == statusKey)
        .toList();

    return Container(
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBorder),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .03), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // 標題
        Container(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: .05),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
            border: const Border(bottom: BorderSide(color: _kBorder)),
          ),
          child: Row(children: [
            Container(
              width: 30, height: 30,
              decoration: BoxDecoration(color: color.withValues(alpha: .12), borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, color: color, size: 15),
            ),
            const SizedBox(width: 10),
            Text(label, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w700)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: color.withValues(alpha: .12), borderRadius: BorderRadius.circular(99)),
              child: Text('${group.length}', style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
            ),
          ]),
        ),
        // 人員列表
        if (group.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            child: Text('目前無$label人員', style: const TextStyle(color: _kTextSub, fontSize: 12)),
          )
        else
          for (int i = 0; i < group.length; i++) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                border: i == group.length - 1
                    ? null
                    : Border(bottom: BorderSide(color: _kBorder.withValues(alpha: .5), width: .8)),
              ),
              child: Row(children: [
                Container(
                  width: 3, height: 36,
                  decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(99)),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(color: color.withValues(alpha: .10), borderRadius: BorderRadius.circular(10)),
                  child: Center(child: Text(
                    group[i].name.isNotEmpty ? group[i].name[0] : '?',
                    style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.w700),
                  )),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(group[i].name, style: const TextStyle(color: _kTextMain, fontSize: 14, fontWeight: FontWeight.w600)),
                  Text(group[i].id, style: const TextStyle(color: _kTextSub, fontSize: 11)),
                ])),
              ]),
            ),
          ],
      ]),
    );
  }

  List<Widget> _buildGroupedItems(
    List<Citizen> citizens,
    EmergencyViewModel emVm,
    List<(String, String, Color, IconData)> groups,
  ) {
    final items = <Widget>[];
    for (final (label, statusKey, color, icon) in groups) {
      final group = citizens
          .where((c) => _citizenStatus(c, emVm) == statusKey)
          .toList();

      // 分組標題
      items.add(Container(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 6),
        color: color.withValues(alpha: .04),
        child: Row(children: [
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 14),
          ),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w700)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(99),
            ),
            child: Text('${group.length}',
                style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
          ),
        ]),
      ));

      if (group.isEmpty) {
        items.add(Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          child: Text('目前無$label人員',
              style: const TextStyle(color: _kTextSub, fontSize: 12)),
        ));
      } else {
        for (int i = 0; i < group.length; i++) {
          final c      = group[i];
          final isLast = i == group.length - 1;
          items.add(Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            decoration: BoxDecoration(
              border: isLast
                  ? null
                  : Border(bottom: BorderSide(color: _kBorder.withValues(alpha: .5), width: .8)),
            ),
            child: Row(children: [
              Container(
                width: 3, height: 36,
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(99)),
              ),
              const SizedBox(width: 12),
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    c.name.isNotEmpty ? c.name[0] : '?',
                    style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(c.name,
                      style: const TextStyle(color: _kTextMain, fontSize: 14, fontWeight: FontWeight.w600)),
                  Text(c.id, style: const TextStyle(color: _kTextSub, fontSize: 11)),
                ]),
              ),
            ]),
          ));
        }
      }
      items.add(const Divider(height: 1, color: _kBorder));
    }
    return items;
  }
}

// ════════════════════════════════════════════════════════════════
//  SOS Tab
// ════════════════════════════════════════════════════════════════
class _SosTab extends StatefulWidget {
  const _SosTab();
  @override
  State<_SosTab> createState() => _SosTabState();
}

class _SosTabState extends State<_SosTab> {
  String _filter = '全部';

  Future<void> _openMap(double lat, double lng) async {
    final uri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _confirmHandle(
      EmergencyRequest e, EmergencyViewModel vm) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: .35),
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
        title: const Text('確認標記已處理',
            style: TextStyle(
                color: _kTextMain,
                fontSize: 15,
                fontWeight: FontWeight.w700)),
        content: Text(
            '確定將「${e.userName.isNotEmpty ? e.userName : e.userId}」的求救事件標記為已處理？',
            style: const TextStyle(
                color: _kTextSub, fontSize: 14)),
        actionsPadding:
            const EdgeInsets.fromLTRB(12, 0, 12, 12),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消',
                  style: TextStyle(color: _kTextSub))),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _kGreen,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(
                  horizontal: 18, vertical: 10),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('標記已處理'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) vm.markHandled(e);
  }

  @override
  Widget build(BuildContext context) {
    final vm         = context.watch<EmergencyViewModel>();
    final all        = vm.emergencies;
    final pending    = all.where((e) => e.status == 'active').length;
    final processing =
        all.where((e) => e.status == 'processing').length;
    final resolved =
        all.where((e) => e.status == 'resolved').length;

    final filtered = all.where((e) {
      if (_filter == '待處理') return e.status == 'active';
      if (_filter == '處理中') return e.status == 'processing';
      if (_filter == '已完成') return e.status == 'resolved';
      return true;
    }).toList()
      ..sort((a, b) {
        if (a.status != 'resolved' && b.status == 'resolved') {
          return -1;
        }
        if (a.status == 'resolved' && b.status != 'resolved') {
          return 1;
        }
        return b.sentAt.compareTo(a.sentAt);
      });

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
      child: Column(children: [
        Container(
          decoration: BoxDecoration(
            color: _kCardBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _kBorder),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: .028),
                  blurRadius: 6,
                  offset: const Offset(0, 2))
            ],
          ),
          child: Row(children: [
            _tapStatCell('${all.length}', '全部',   Icons.list_alt_rounded,      _kBlue,   '全部'),
            _divider(),
            _tapStatCell('$pending',    '待處理', Icons.warning_amber_rounded,  _kOrange, '待處理'),
            _divider(),
            _tapStatCell('$processing', '處理中', Icons.sync_rounded,           _kBlue,   '處理中'),
            _divider(),
            _tapStatCell('$resolved',   '已完成', Icons.check_circle_outline,   _kGreen,  '已完成'),
            _divider(),
            SizedBox(
              width: 44,
              child: IconButton(
                onPressed: vm.loadEmergencies,
                icon: const Icon(Icons.refresh_rounded, color: _kBlue, size: 17),
                padding: EdgeInsets.zero,
              ),
            ),
          ]),
        ),
        const SizedBox(height: 10),
        Expanded(child: _buildList(vm, filtered)),
      ]),
    );
  }

  Widget _tapStatCell(String val, String label, IconData icon, Color color, String filter) {
    final sel = _filter == filter;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _filter = filter),
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
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(val,
                  style: TextStyle(
                      color: sel ? color : _kTextMain,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      height: 1.1)),
              Text(label,
                  style: const TextStyle(color: _kTextSub, fontSize: 11)),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _buildList(
      EmergencyViewModel vm, List<EmergencyRequest> filtered) {
    if (vm.isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: _kBlue));
    }
    if (filtered.isEmpty) {
      return const Center(
          child: Text('暫無資料',
              style: TextStyle(color: _kTextSub)));
    }

    return Container(
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kBorder),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: .028),
              blurRadius: 6,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
          decoration: const BoxDecoration(
            color: Color(0xFFF8FAFC),
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(12)),
            border:
                Border(bottom: BorderSide(color: _kBorder)),
          ),
          child: Row(children: [
            const Icon(Icons.bolt_rounded,
                color: _kTextMain, size: 16),
            const SizedBox(width: 6),
            const Text('SOS 列表',
                style: TextStyle(
                    color: _kTextMain,
                    fontSize: 14,
                    fontWeight: FontWeight.w700)),
            const Spacer(),
            Text('共 ${filtered.length} 筆',
                style: const TextStyle(
                    color: _kTextSub, fontSize: 11)),
          ]),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(10),
            itemCount: filtered.length,
            itemBuilder: (_, i) =>
                _buildCard(filtered[i], vm),
          ),
        ),
      ]),
    );
  }

  Widget _buildCard(EmergencyRequest e, EmergencyViewModel vm) {
    final isHandled   = e.status == 'resolved';
    final color       = isHandled ? _kGreen : _kOrange;
    final minutesAgo  =
        DateTime.now().difference(e.sentAt).inMinutes;
    final isOverdue   = !isHandled && minutesAgo >= 30;
    final displayName =
        e.userName.isNotEmpty ? e.userName : '用戶 ${e.userId}';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isOverdue
            ? _kRed.withValues(alpha: .04)
            : (!isHandled
                ? _kOrange.withValues(alpha: .025)
                : Colors.white),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: isOverdue
                ? _kRed.withValues(alpha: .22)
                : (!isHandled
                    ? _kOrange.withValues(alpha: .18)
                    : _kBorder)),
      ),
      child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
              color: color.withValues(alpha: .10),
              borderRadius: BorderRadius.circular(9)),
          child: Icon(
              isHandled
                  ? Icons.check_circle_outline_rounded
                  : Icons.warning_amber_rounded,
              color: color,
              size: 19),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Row(children: [
              Text(displayName,
                  style: const TextStyle(
                      color: _kTextMain,
                      fontSize: 14,
                      fontWeight: FontWeight.w700)),
              const SizedBox(width: 8),
              _statusDot(isHandled),
              if (isOverdue) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                      color: _kRed.withValues(alpha: .10),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                          color:
                              _kRed.withValues(alpha: .25))),
                  child: const Text('逾時未處理',
                      style: TextStyle(
                          color: _kRed,
                          fontSize: 10,
                          fontWeight: FontWeight.w700)),
                ),
              ],
            ]),
            const SizedBox(height: 5),
            if (e.phone.isNotEmpty)
              Row(children: [
                const Icon(Icons.phone_outlined,
                    color: _kTextSub, size: 13),
                const SizedBox(width: 4),
                Text(e.phone,
                    style: const TextStyle(
                        color: _kTextSub, fontSize: 12)),
              ]),
            const SizedBox(height: 5),
            Row(children: [
              Icon(Icons.access_time_rounded,
                  color: isOverdue ? _kRed : _kTextSub,
                  size: 13),
              const SizedBox(width: 4),
              Text(_fullTime(e.sentAt),
                  style: TextStyle(
                      color: isOverdue ? _kRed : _kTextSub,
                      fontSize: 12,
                      fontWeight: isOverdue
                          ? FontWeight.w600
                          : FontWeight.w400)),
              const SizedBox(width: 6),
              Text('（${_relativeTime(e.sentAt)}）',
                  style: const TextStyle(
                      color: _kTextSub, fontSize: 11)),
            ]),
            const SizedBox(height: 5),
            _AddressWidget(
                lat: e.lat,
                lng: e.lng,
                onMapTap: () => _openMap(e.lat, e.lng)),
          ]),
        ),
        if (!isHandled) ...[
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () => _confirmHandle(e, vm),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 13, vertical: 9),
              decoration: BoxDecoration(
                color: isOverdue
                    ? _kRed.withValues(alpha: .10)
                    : _kGreen.withValues(alpha: .10),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: isOverdue
                        ? _kRed.withValues(alpha: .35)
                        : _kGreen.withValues(alpha: .35)),
              ),
              child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                Icon(Icons.check_rounded,
                    color: isOverdue ? _kRed : _kGreen,
                    size: 14),
                const SizedBox(width: 5),
                Text('標記已處理',
                    style: TextStyle(
                        color: isOverdue ? _kRed : _kGreen,
                        fontSize: 12,
                        fontWeight: FontWeight.w700)),
              ]),
            ),
          ),
        ],
      ]),
    );
  }

  static Widget _statusDot(bool handled) {
    final color = handled ? _kGreen : _kOrange;
    final text  = handled ? '已處理' : '待處理';
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
          width: 5,
          height: 5,
          decoration: BoxDecoration(
              color: color, shape: BoxShape.circle)),
      const SizedBox(width: 4),
      Text(text,
          style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600)),
    ]);
  }

  static String _fullTime(DateTime t) =>
      '${t.year}/${t.month.toString().padLeft(2, '0')}/${t.day.toString().padLeft(2, '0')} '
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  static String _relativeTime(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 1)  return '剛剛';
    if (diff.inMinutes < 60) return '${diff.inMinutes} 分鐘前';
    if (diff.inHours   < 24) return '${diff.inHours} 小時前';
    return '${diff.inDays} 天前';
  }
}

// ════════════════════════════════════════════════════════════════
//  物資需求 Tab
// ════════════════════════════════════════════════════════════════
class _SupplyTab extends StatefulWidget {
  const _SupplyTab();
  @override
  State<_SupplyTab> createState() => _SupplyTabState();
}

class _SupplyTabState extends State<_SupplyTab> {
  List<Map<String, dynamic>> _requests = [];
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'type': 'getSupplyRequestDetails'}),
      ).timeout(const Duration(seconds: 10));
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data['success'] == true) {
        final all = List<Map<String, dynamic>>.from(data['data']);
        setState(() => _requests = all.where((r) => r['status'] == 'pending').toList());
      } else {
        setState(() => _error = '載入失敗');
      }
    } catch (e) {
      setState(() => _error = 'API 連線失敗：$e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
      child: Column(children: [
        Row(children: [
          const Text('物資需求',
              style: TextStyle(color: _kTextMain, fontSize: 16, fontWeight: FontWeight.w700)),
          const Spacer(),
          _iconBtn(Icons.refresh_rounded, _kBlue, _load),
        ]),
        const SizedBox(height: 10),
        if (_isLoading)
          const Expanded(child: Center(child: CircularProgressIndicator(color: _kBlue)))
        else if (_error != null)
          Expanded(child: Center(child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, style: const TextStyle(color: _kRed)),
              const SizedBox(height: 12),
              ElevatedButton(onPressed: _load, child: const Text('重新載入')),
            ],
          )))
        else if (_requests.isEmpty)
          const Expanded(child: Center(child: Text('目前無待處理的物資需求', style: TextStyle(color: _kTextSub))))
        else
          Expanded(
            child: ListView.builder(
              itemCount: _requests.length,
              itemBuilder: (_, i) => _requestCard(_requests[i]),
            ),
          ),
      ]),
    );
  }

  Widget _requestCard(Map<String, dynamic> req) {
    final reqId    = req['id']?.toString() ?? req['requestId']?.toString() ?? '?';
    final itemName = req['itemName']?.toString() ?? '物資 #${req['itemId']}';
    final qty      = (req['qty'] as num?)?.toInt() ?? 0;
    final unit     = req['unit']?.toString() ?? '';
    final userName = req['userName']?.toString() ?? req['userId']?.toString() ?? '—';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kOrange.withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
            color: _kOrange.withValues(alpha: .10),
            borderRadius: BorderRadius.circular(9),
          ),
          child: const Icon(Icons.inbox_outlined, color: _kOrange, size: 19),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(itemName,
                style: const TextStyle(color: _kTextMain, fontSize: 14, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text('申請人：$userName・數量：$qty $unit',
                style: const TextStyle(color: _kTextSub, fontSize: 12)),
          ]),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: _kOrange.withValues(alpha: .08),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: _kOrange.withValues(alpha: .2)),
          ),
          child: Text('#$reqId', style: const TextStyle(color: _kOrange, fontSize: 11, fontWeight: FontWeight.w700)),
        ),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  共用小元件
// ════════════════════════════════════════════════════════════════
Widget _divider() =>
    Container(width: 1, height: 28, color: _kBorder);

Widget _iconBtn(
        IconData icon, Color color, VoidCallback onTap) =>
    GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34, height: 34,
        decoration: BoxDecoration(
            color: _kCardBg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _kBorder)),
        child: Icon(icon, color: color, size: 16),
      ),
    );

// ════════════════════════════════════════════════════════════════
//  地址顯示元件
// ════════════════════════════════════════════════════════════════
class _AddressWidget extends StatefulWidget {
  final double lat, lng;
  final VoidCallback onMapTap;
  const _AddressWidget(
      {required this.lat,
      required this.lng,
      required this.onMapTap});
  @override
  State<_AddressWidget> createState() => _AddressWidgetState();
}

class _AddressWidgetState extends State<_AddressWidget> {
  String _address = '查詢中…';
  bool   _loaded  = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(_AddressWidget old) {
    super.didUpdateWidget(old);
    if (old.lat != widget.lat || old.lng != widget.lng) _load();
  }

  Future<void> _load() async {
    final result =
        await _fetchAddress(widget.lat, widget.lng);
    if (mounted) {
      setState(() {
        _address = result;
        _loaded  = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(Icons.location_on_outlined,
          color: _loaded
              ? _kTextSub
              : _kBlue.withValues(alpha: .4),
          size: 13),
      const SizedBox(width: 4),
      Expanded(
        child: Text(_address,
            style: TextStyle(
                color: _loaded
                    ? _kTextSub
                    : _kBlue.withValues(alpha: .5),
                fontSize: 12),
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
      ),
      const SizedBox(width: 6),
      GestureDetector(
        onTap: widget.onMapTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: _kBlue.withValues(alpha: .06),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
                color: _kBlue.withValues(alpha: .18)),
          ),
          child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
            Icon(Icons.map_outlined,
                color: _kBlue, size: 11),
            SizedBox(width: 3),
            Text('地圖',
                style: TextStyle(
                    color: _kBlue,
                    fontSize: 10,
                    fontWeight: FontWeight.w600)),
          ]),
        ),
      ),
    ]);
  }
}
