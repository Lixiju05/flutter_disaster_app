import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_disaster_app/admin_APP/widgets/page_header.dart';
import 'package:flutter_disaster_app/admin_APP/widgets/offline_demo_badge.dart';
import 'package:flutter_disaster_app/admin_APP/widgets/map_toggle_button.dart';
import 'package:flutter_disaster_app/admin_APP/widgets/user_avatar.dart';
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
import 'package:flutter_disaster_app/core/api_config.dart';

// ── 色系 ────────────────────────────────────────────────────────
const Color _kBg       = Color(0xFFF5F7FA);
const Color _kCardBg   = Color(0xFFFFFFFF);
const Color _kBorder   = Color(0xFFE5E7EB);
const Color _kBlue     = Color(0xFF2563EB);
const Color _kGreen    = Color(0xFF16A34A);
const Color _kOrange   = Color(0xFFEC6C2D);   // 重傷
const Color _kRed      = Color(0xFFDC2626);
const Color _kYellow   = Color(0xFFD3CA43);   // 輕傷（落日黃）
const Color _kTextMain = Color(0xFF0F172A);
const Color _kTextSub  = Color(0xFF475569);

const String _baseUrl = ApiConfig.baseUrl;

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
            PageHeader(
              title: '救難管理',
              subtitle: 'RESCUE MANAGEMENT CENTER',
              badges: [
                if (context.watch<CitizenViewmodel>().isOfflineDemo)
                  const OfflineDemoBadge(),
              ],
            ),
            // ── 分頁列（與物資管理相同樣式）─────────────────────
            Container(
              decoration: const BoxDecoration(
                color: _kCardBg,
                border: Border(bottom: BorderSide(color: _kBorder)),
              ),
              child: TabBar(
                controller: _tabController,
                labelColor: _kBlue,
                unselectedLabelColor: _kTextSub,
                indicatorColor: _kBlue,
                dividerColor: Colors.transparent,
                labelStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                unselectedLabelStyle: const TextStyle(fontSize: 15),
                tabs: [
                  for (final (icon, text) in const [
                    (Icons.people_alt_outlined, '全部'),
                    (Icons.sos_rounded, 'SOS'),
                    (Icons.favorite_border, '健康回報'),
                    (Icons.inventory_2_outlined, '物資需求'),
                  ])
                    Tab(
                      height: 48,
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(icon, size: 19),
                        const SizedBox(width: 8),
                        Text(text),
                      ]),
                    ),
                ],
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
  List<Map<String, dynamic>> _supplyRequests = [];
  late final MapController _mapCtrl;
  LatLng _mapCenter = const LatLng(23.9575, 120.9275); // 暨大
  double _mapZoom   = 14.0;
  String _filter    = 'all';
  String _keyword   = '';
  final TextEditingController _searchCtrl = TextEditingController();
  bool _mapFullscreen = false;
  void _toggleMapFullscreen() => setState(() => _mapFullscreen = !_mapFullscreen);

  @override
  void initState() {
    super.initState();
    _mapCtrl = MapController();
    _loadHealthReports();
    _loadSupplyRequests();
    _loadAdminArea();
  }

  @override
  void dispose() {
    _mapCtrl.dispose();
    _searchCtrl.dispose();
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

  Future<void> _loadSupplyRequests() async {
    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: jsonEncode({'type': 'getSupplyRequestDetails'}),
      ).timeout(const Duration(seconds: 10));
      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        final loaded = List<Map<String, dynamic>>.from(data['data']);
        // 尚未送達的需求都顯示（待處理、已預留、已出庫）
        const active = {'pending', 'reserved', 'dispatched'};
        if (mounted) setState(() => _supplyRequests = loaded.where((r) => active.contains(r['status'])).toList());
      }
    } catch (_) {}
  }

  // ── 狀態工具 ────────────────────────────────────────────────
  String _normStatus(String s) {
    final st = s.trim().toLowerCase();
    if (st == 'safe'     || st == '安全') return 'safe';
    if (st == 'injured'  || st == 'minor' || st == '輕傷' || st == '轻伤') return 'injured';
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
    // 沒有健康回報、也沒在求救，但有未送達的物資需求
    final hasSupply = _supplyRequests.any((r) => r['userId']?.toString() == c.id);
    if (hasSupply) return 'supply';
    return 'unknown'; // 完全無回報
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'sos':           return _kRed;
      case 'critical':      return _kOrange;
      case 'injured':       return _kYellow;
      case 'safe':          return _kGreen;
      case 'health_report': return const Color(0xFF0891B2);
      case 'supply':        return _kBlue;
      default:              return _kTextSub;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'sos':           return 'SOS';
      case 'critical':      return '重傷';
      case 'injured':       return '輕傷';
      case 'safe':          return '安全';
      case 'health_report': return '健康回報';
      case 'supply':        return '物資需求';
      default:              return '未分類';
    }
  }

  // ── BUILD ──────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final citizenVm = context.watch<CitizenViewmodel>();
    final emVm      = context.watch<EmergencyViewModel>();

    final allCitizens = citizenVm.citizens;
    // 有 SOS、健康回報、物資需求 任一者的 userId 聯集
    final activeIds = <String>{
      // SOS 只算還沒處理完的（已處理的不再列為災民）
      ...emVm.emergencies.where((e) => e.status != 'resolved').map((e) => e.userId),
      ..._healthReports.map((r) => r.reporterId),
      ..._supplyRequests
          .map((r) => r['userId']?.toString() ?? '')
          .where((id) => id.isNotEmpty),
    };
    final citizens = allCitizens
        .where((c) => activeIds.contains(c.id))
        .toList();
    // 每個人只算一次，用和下方列表相同的分組規則，數字才會一致
    final statusOf = {for (final c in citizens) c.id: _citizenStatus(c, emVm)};
    int countOf(String st) => statusOf.values.where((v) => v == st).length;
    final total    = citizens.length;
    final sosCount = countOf('sos');
    final critical = countOf('critical');
    final injured  = countOf('injured');
    final safe     = countOf('safe');
    final supplyNeed = countOf('supply');

    // 放大檢視：地圖佔滿整個分頁內容區，列表／統計卡先讓位
    if (_mapFullscreen) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
        child: _buildMap(citizens, emVm),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
      child: Column(children: [
        // ── 統計卡片 ──────────────────────────────────────────
        _buildStatsRow(total, sosCount, critical, injured, safe, supplyNeed),
        const SizedBox(height: 12),
        // ── 左：地圖　右：災民列表（並排，列表不會被擠到下面）──────
        Expanded(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(flex: 5, child: _buildMap(citizens, emVm)),
            const SizedBox(width: 12),
            Expanded(
              flex: 4,
              child: ListView(
            padding: EdgeInsets.zero,
            children: [
              _buildCitizenList(citizens, citizenVm, emVm),
            ],
              ),
            ),
          ]),
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
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(children: [
        _tapCell(Icons.people_alt_outlined,   '$total',    '總災民',   _kBlue,   'all'),
        _divider(),
        _tapCell(Icons.sos_rounded,           '$sos',      'SOS',     _kRed,    'sos'),
        _divider(),
        _tapCell(Icons.warning_amber_rounded, '$critical', '重傷',    _kOrange, 'critical'),
        _divider(),
        _tapCell(Icons.healing_rounded,       '$injured',  '輕傷',    _kYellow,   'injured'),
        _divider(),
        _tapCell(Icons.verified_user_rounded, '$safe',     '安全',    _kGreen,  'safe'),
        _divider(),
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
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          // 選中：淡底色 + 底部色條
          decoration: BoxDecoration(
            color: sel ? color.withValues(alpha: .06) : Colors.transparent,
            border: Border(bottom: BorderSide(color: sel ? color : Colors.transparent, width: 3)),
          ),
          child: Row(children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(val, style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.w800, height: 1.15)),
                Text(label, style: TextStyle(
                    color: sel ? _kTextMain : _kTextSub, fontSize: 14,
                    fontWeight: sel ? FontWeight.w700 : FontWeight.w500)),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  // ── 地圖 ───────────────────────────────────────────────────
  Widget _buildMap(List<Citizen> citizens, EmergencyViewModel emVm) {
    final markers = <Marker>[];

    // 點圖釘：找到這個人就打開詳情
    void openCitizen(String userId) {
      for (final c in context.read<CitizenViewmodel>().citizens) {
        if (c.id == userId) {
          _showCitizenDetail(c, emVm);
          return;
        }
      }
    }
    String nameOf(String userId) {
      for (final c in context.read<CitizenViewmodel>().citizens) {
        if (c.id == userId) return c.name;
      }
      return '';
    }

    // SOS 人員 userId 集合 — 其健康回報釘只顯示為 SOS 紅釘，不重複顯示
    final sosIds = emVm.emergencies
        .where((e) => e.status != 'resolved')
        .map((e) => e.userId)
        .toSet();

    // 健康狀態標記（重傷/輕傷/安全；有 active SOS 的人略過）
    for (final r in _healthReports) {
      if (r.lat == null || r.lng == null) continue;
      if (sosIds.contains(r.reporterId)) continue;
      final status = _normStatus(r.status);
      if (status != 'critical' && status != 'injured' && status != 'safe') continue;
      final color  = _statusColor(status);
      markers.add(Marker(
        point: LatLng(r.lat!, r.lng!),
        width: 36, height: 44,
        child: _tappablePin(color, () => openCitizen(r.reporterId)),
      ));
    }

    // SOS 標記（紅色圖釘）
    for (final e in emVm.emergencies) {
      if (e.status == 'resolved') continue;
      if (e.lat == 0 && e.lng == 0) continue;
      markers.add(Marker(
        point: LatLng(e.lat, e.lng),
        width: 36, height: 44,
        child: _tappablePin(_kRed, () => openCitizen(e.userId)),
      ));
    }

    // 物資需求 → 藍色圖釘
    for (final req in _supplyRequests) {
      final lat = (req['lat'] as num?)?.toDouble();
      final lng = (req['lng'] as num?)?.toDouble();
      if (lat == null || lng == null) continue;
      if (lat == 0 && lng == 0) continue;
      final uid = req['userId']?.toString() ?? '';
      markers.add(Marker(
        point: LatLng(lat, lng),
        width: 36, height: 44,
        child: _tappablePin(_kBlue,
            () => _showSupplyRequestDetail(context, [req], nameOf(uid), uid)),
      ));
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBorder),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(children: [
          // flutter_map 6 不處理觸控板雙指縮放，這裡自己接；滾輪也一起處理
          Listener(
            onPointerSignal: _onMapPointerSignal,
            onPointerPanZoomStart: (_) => _panZoomStart = _mapCtrl.camera.zoom,
            onPointerPanZoomUpdate: (e) =>
                _zoomMapAt(e.localPosition, _panZoomStart + math.log(e.scale) / math.ln2),
            child: FlutterMap(
            mapController: _mapCtrl,
            options: MapOptions(
              initialCenter: _mapCenter,
              initialZoom: _mapZoom,
              minZoom: 8,
              maxZoom: 18,
              // 拖曳移動、觸控螢幕雙指縮放；不用雙擊放大，滾輪交給上面的 Listener
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.drag | InteractiveFlag.pinchZoom | InteractiveFlag.flingAnimation,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://wmts.nlsc.gov.tw/wmts/EMAP/default/GoogleMapsCompatible/{z}/{y}/{x}',  // 國土測繪中心 台灣通用電子地圖（免費、免金鑰）,
                maxNativeZoom: 16,  // 此區圖資只到第 16 層，超過就放大第 16 層
                userAgentPackageName:
                    'com.example.flutter_disaster_app',
              ),
              MarkerLayer(markers: markers),
            ],
          ),
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
                _legendItem('輕傷',   _kYellow),
                _legendItem('安全',   _kGreen),
                _legendItem('物資需求', _kBlue),
              ]),
            ),
          ),
          // 右側按鈕欄：放大/縮小畫面 + 刷新 + 放大 + 縮小 + 回中心
          Positioned(
            right: 10,
            top: 10,
            child: Column(children: [
              MapToggleButton(fullscreen: _mapFullscreen, onTap: _toggleMapFullscreen),
              const SizedBox(height: 4),
              _mapBtn(Icons.refresh_rounded, _kBlue, () { _loadHealthReports(); _loadSupplyRequests(); }),
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

  double _panZoomStart = 0;

  /// 以游標位置為中心縮放（游標下的地點不動）
  void _zoomMapAt(Offset local, double zoom) {
    final cam = _mapCtrl.camera;
    final z = zoom.clamp(8.0, 18.0);
    if ((z - cam.zoom).abs() < 0.001) return;
    _mapCtrl.move(cam.focusedZoomCenter(math.Point(local.dx, local.dy), z), z);
  }

  void _onMapPointerSignal(PointerSignalEvent event) {
    GestureBinding.instance.pointerSignalResolver.register(event, (e) {
      final zoom = _mapCtrl.camera.zoom;
      if (e is PointerScaleEvent) {
        // 觸控板雙指捏合
        _zoomMapAt(e.localPosition, zoom + math.log(e.scale) / math.ln2);
      } else if (e is PointerScrollEvent) {
        // 滑鼠滾輪 / 觸控板雙指上下滑
        _zoomMapAt(e.localPosition, zoom - e.scrollDelta.dy / 300);
      }
    });
  }

  /// 可點的圖釘：點了開啟資料
  Widget _tappablePin(Color color, VoidCallback onTap) => MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(onTap: onTap, child: _pinMarker(color)),
      );

  Widget _pinMarker(Color color) {
    return Stack(
      alignment: Alignment.topCenter,
      children: [
        Icon(Icons.location_on, color: color, size: 36,
          shadows: [Shadow(color: color.withValues(alpha: 0.4), blurRadius: 6)]),
        Positioned(
          top: 4,
          child: Container(
            width: 14, height: 14,
            decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle),
          ),
        ),
      ],
    );
  }

  Widget _legendItem(String label, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.location_on, color: color, size: 14),
        const SizedBox(width: 5),
        Text(label,
            style: const TextStyle(
                fontSize: 13,
                color: _kTextMain,
                fontWeight: FontWeight.w600)),
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
      ('輕傷', 'injured',  _kYellow,   Icons.healing_rounded),
      ('安全', 'safe',     _kGreen,  Icons.verified_user_rounded),
      ('物資需求', 'supply', _kBlue,  Icons.inventory_2_outlined),
    ];
    final groups = _filter == 'all'
        ? allGroups
        : allGroups.where((g) => g.$2 == _filter).toList();

    // 依姓名 / ID 搜尋
    final kw = _keyword.trim().toLowerCase();
    if (kw.isNotEmpty) {
      citizens = citizens
          .where((c) => c.name.toLowerCase().contains(kw) || c.id.toLowerCase().contains(kw))
          .toList();
    }

    return Container(
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: [
        // 標題列
        Container(
          padding: const EdgeInsets.fromLTRB(20, 10, 14, 10),
          decoration: const BoxDecoration(
            color: Color(0xFFF8FAFC),
            border: Border(bottom: BorderSide(color: _kBorder)),
          ),
          child: Row(children: [
            const Text('災民列表',
                style: TextStyle(color: _kTextMain, fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(width: 16),
            // 搜尋姓名 / ID
            SizedBox(
              width: 280, height: 40,
              child: TextField(
                controller: _searchCtrl,
                onChanged: (v) => setState(() => _keyword = v),
                style: const TextStyle(color: _kTextMain, fontSize: 15),
                decoration: InputDecoration(
                  hintText: '搜尋姓名 / ID',
                  hintStyle: const TextStyle(color: _kTextSub, fontSize: 15),
                  prefixIcon: const Icon(Icons.search_rounded, color: _kTextSub, size: 18),
                  suffixIcon: _keyword.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close_rounded, size: 16, color: _kTextSub),
                          onPressed: () => setState(() { _searchCtrl.clear(); _keyword = ''; }),
                        ),
                  isDense: true,
                  filled: true,
                  fillColor: _kCardBg,
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: _kBorder)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: _kBlue)),
                ),
              ),
            ),
            const Spacer(),
            Text('共 ${citizens.length} 人',
                style: const TextStyle(color: _kTextMain, fontSize: 14, fontWeight: FontWeight.w600)),
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
          Padding(padding: const EdgeInsets.all(16),
              child: Text(kw.isNotEmpty ? '找不到符合「${_keyword.trim()}」的災民' : '暫無資料',
                  style: const TextStyle(color: _kTextSub)))
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
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(9),
                boxShadow: [BoxShadow(color: color.withValues(alpha: .32), blurRadius: 7, offset: const Offset(0, 2))],
              ),
              child: Icon(icon, color: Colors.white, size: 15),
            ),
            const SizedBox(width: 10),
            Text(label, style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: color.withValues(alpha: .12), borderRadius: BorderRadius.circular(99)),
              child: Text('${group.length}', style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w700)),
            ),
          ]),
        ),
        // 人員列表
        if (group.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            child: Text('目前無$label人員', style: const TextStyle(color: _kTextSub, fontSize: 13)),
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
                  Text(group[i].name, style: const TextStyle(color: _kTextMain, fontSize: 15, fontWeight: FontWeight.w600)),
                  Text(group[i].id, style: const TextStyle(color: _kTextSub, fontSize: 13)),
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
    for (final (label, statusKey, color, _) in groups) {
      final group = citizens
          .where((c) => _citizenStatus(c, emVm) == statusKey)
          .toList();

      // 搜尋時只顯示有結果的組
      if (group.isEmpty && _keyword.trim().isNotEmpty) continue;

      // 分組標題
      items.add(Container(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
        color: const Color(0xFFF8FAFC),
        child: Row(children: [
          Container(width: 4, height: 16,
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(color: _kTextMain, fontSize: 15, fontWeight: FontWeight.w800)),
          const SizedBox(width: 8),
          Text('${group.length} 人',
              style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w700)),
        ]),
      ));

      if (group.isEmpty) {
        items.add(Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Text('目前無$label人員',
              style: const TextStyle(color: _kTextSub, fontSize: 14)),
        ));
      } else {
        for (int i = 0; i < group.length; i++) {
          final c      = group[i];
          final isLast = i == group.length - 1;
          items.add(Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: i.isEven ? _kCardBg : const Color(0xFFF8FAFC),
              border: isLast
                  ? null
                  : const Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
            ),
            child: Row(children: [
              UserAvatar(name: c.name, index: i),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(c.name,
                      style: const TextStyle(color: _kTextMain, fontSize: 16, fontWeight: FontWeight.w700)),
                  Text(c.id, style: const TextStyle(color: _kTextSub, fontSize: 14)),
                ]),
              ),
              const SizedBox(width: 8),
              _detailButton(color, () => _showCitizenDetail(c, emVm)),
            ]),
          ));
        }
      }
      items.add(const Divider(height: 1, color: _kBorder));
    }
    return items;
  }

  // ── 市民詳情 Dialog ────────────────────────────────────────
  void _showCitizenDetail(Citizen c, EmergencyViewModel emVm) {
    final report   = _reportFor(c.id);
    final sosList  = emVm.emergencies
        .where((e) => e.userId == c.id && e.status != 'resolved')
        .toList();
    final sos      = sosList.isEmpty ? null : sosList.first;
    final supplies = _supplyRequests
        .where((r) => r['userId']?.toString() == c.id)
        .toList();

    final status = _citizenStatus(c, emVm);
    final color  = _statusColor(status);
    final label  = _statusLabel(status);

    const statusIcons = <String, IconData>{
      'sos':      Icons.sos_rounded,
      'critical': Icons.warning_amber_rounded,
      'injured':  Icons.healing_rounded,
      'safe':     Icons.verified_user_rounded,
    };

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: .35),
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: 480,
          constraints: const BoxConstraints(maxHeight: 580),
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
                    color: color,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [BoxShadow(color: color.withValues(alpha: .32), blurRadius: 9, offset: const Offset(0, 3))],
                  ),
                  child: Icon(
                      statusIcons[status] ?? Icons.person_outline,
                      color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(c.name,
                      style: const TextStyle(
                          color: _kTextMain, fontSize: 17,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 3),
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 3),
                      decoration: BoxDecoration(
                          color: color.withValues(alpha: .08),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                              color: color.withValues(alpha: .2))),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Container(width: 6, height: 6,
                            decoration: BoxDecoration(
                                color: color, shape: BoxShape.circle)),
                        const SizedBox(width: 4),
                        Text(label,
                            style: TextStyle(color: color,
                                fontSize: 13, fontWeight: FontWeight.w700)),
                      ]),
                    ),
                    const SizedBox(width: 8),
                    Text('ID：${c.id}',
                        style: const TextStyle(
                            color: _kTextSub, fontSize: 13)),
                  ]),
                ])),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: _kTextSub, size: 18),
                ),
              ]),
            ),
            const Divider(height: 1, color: _kBorder),
            // 詳情內容
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(18),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  _dialogSectionHeader('基本資料'),
                  _dialogInfoRow('電話', c.phone.isNotEmpty ? c.phone : (report?.phone ?? '')),
                  _dialogInfoRow('地址', c.area),
                  const SizedBox(height: 4),
                  if (report != null) ...[
                    _dialogSectionHeader('健康回報'),
                    _dialogInfoRow('狀態',
                        _translateCitizenStatus(_normStatus(report.status))),
                    _dialogInfoRow('電話',
                        report.phone.isNotEmpty ? report.phone : '未填寫'),
                    _dialogInfoRow('血型',
                        report.bloodType?.isNotEmpty == true
                            ? report.bloodType!
                            : '未填寫'),
                    _dialogInfoRow('回報時間', _fmtDt(report.reportTime)),
                    _dialogInfoRow('地點',
                        report.address?.isNotEmpty == true
                            ? report.address!
                            : (report.lat != null
                                ? '${report.lat!.toStringAsFixed(5)}, '
                                  '${report.lng!.toStringAsFixed(5)}'
                                : '未知')),
                    if (report.description?.trim().isNotEmpty == true)
                      _dialogInfoRow('症狀說明', report.description!),
                    const SizedBox(height: 4),
                  ],
                  if (sos != null) ...[
                    _dialogSectionHeader('SOS 求救'),
                    _dialogInfoRow('狀態', _sosStatusText(sos.status)),
                    _dialogInfoRow('發送時間', _fmtDt(sos.sentAt)),
                    _dialogInfoRow('地址',
                        sos.address?.isNotEmpty == true
                            ? sos.address!
                            : '未提供'),
                    if (sos.lat != 0 && sos.lng != 0)
                      _dialogInfoRow('座標',
                          '${sos.lat.toStringAsFixed(5)}, '
                          '${sos.lng.toStringAsFixed(5)}'),
                    const SizedBox(height: 4),
                  ],
                  if (supplies.isNotEmpty) ...[
                    _dialogSectionHeader('物資需求'),
                    for (final s in supplies)
                      _dialogInfoRow(
                          s['itemName']?.toString() ?? '物資',
                          [
                            '${s['qty']} ${s['unit'] ?? ''}',
                            switch (s['status']?.toString()) {
                              'pending'    => '待處理',
                              'reserved'   => '已預留',
                              'dispatched' => '已出庫',
                              'completed'  => '已完成',
                              _            => s['status']?.toString() ?? '',
                            },
                            if ((s['address']?.toString() ?? '').isNotEmpty) '送往 ${s['address']}',
                          ].join('・')),
                    const SizedBox(height: 4),
                  ],
                  if (report == null && sos == null && supplies.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Center(
                        child: Text('此用戶尚無詳細資料',
                            style: TextStyle(
                                color: _kTextSub, fontSize: 14)),
                      ),
                    ),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  String _translateCitizenStatus(String s) {
    switch (s) {
      case 'safe':     return '安全';
      case 'injured':  return '輕傷';
      case 'critical': return '重傷';
      default:         return s;
    }
  }

  String _sosStatusText(String s) {
    switch (s) {
      case 'active':     return '待處理';
      case 'processing': return '處理中';
      case 'resolved':   return '已完成';
      default:           return s;
    }
  }

  static String _fmtDt(DateTime t) =>
      '${t.year}/${t.month.toString().padLeft(2, '0')}/'
      '${t.day.toString().padLeft(2, '0')} '
      '${t.hour.toString().padLeft(2, '0')}:'
      '${t.minute.toString().padLeft(2, '0')}';
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
                color: _kTextSub, fontSize: 15)),
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
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: sel ? color.withValues(alpha: .06) : Colors.transparent,
          ),
          child: Row(children: [
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [BoxShadow(color: color.withValues(alpha: .32), blurRadius: 6, offset: const Offset(0, 2))],
              ),
              child: Icon(icon, color: Colors.white, size: 16),
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
                  style: const TextStyle(color: _kTextSub, fontSize: 13)),
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
                    fontSize: 15,
                    fontWeight: FontWeight.w700)),
            const Spacer(),
            Text('共 ${filtered.length} 筆',
                style: const TextStyle(
                    color: _kTextSub, fontSize: 13)),
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
            color: color,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [BoxShadow(color: color.withValues(alpha: .32), blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: Icon(
              isHandled
                  ? Icons.check_circle_outline_rounded
                  : Icons.warning_amber_rounded,
              color: Colors.white,
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
                      fontSize: 15,
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
                          fontSize: 12,
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
                        color: _kTextSub, fontSize: 13)),
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
                      fontSize: 13,
                      fontWeight: isOverdue
                          ? FontWeight.w600
                          : FontWeight.w400)),
              const SizedBox(width: 6),
              Text('（${_relativeTime(e.sentAt)}）',
                  style: const TextStyle(
                      color: _kTextSub, fontSize: 13)),
            ]),
            const SizedBox(height: 5),
            Row(children: [
              const Icon(Icons.location_on_outlined, color: _kTextSub, size: 13),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  e.address?.isNotEmpty == true ? e.address! : '位置未提供',
                  style: const TextStyle(color: _kTextSub, fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (e.lat != 0 && e.lng != 0) ...[
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: () => _openMap(e.lat, e.lng),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: _kBlue.withValues(alpha: .06),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: _kBlue.withValues(alpha: .18)),
                    ),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.map_outlined, color: _kBlue, size: 11),
                      SizedBox(width: 3),
                      Text('地圖', style: TextStyle(color: _kBlue, fontSize: 12, fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ),
              ],
            ]),
          ]),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            _detailButton(_kBlue, () => _showSosDetail(e)),
            if (!isHandled) ...[
              const SizedBox(height: 6),
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
                            fontSize: 13,
                            fontWeight: FontWeight.w700)),
                  ]),
                ),
              ),
            ],
          ],
        ),
      ]),
    );
  }

  // ── SOS 詳情 Dialog ────────────────────────────────────────
  void _showSosDetail(EmergencyRequest e) {
    final isHandled  = e.status == 'resolved';
    final color      = isHandled ? _kGreen : _kOrange;
    final statusText = e.status == 'active'
        ? '待處理'
        : e.status == 'processing'
            ? '處理中'
            : '已完成';

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: .35),
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: 480,
          constraints: const BoxConstraints(maxHeight: 540),
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
                    color: color,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [BoxShadow(color: color.withValues(alpha: .32), blurRadius: 9, offset: const Offset(0, 3))],
                  ),
                  child: Icon(
                      isHandled
                          ? Icons.check_circle_outline_rounded
                          : Icons.sos_rounded,
                      color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(
                      e.userName.isNotEmpty ? e.userName : '用戶 ${e.userId}',
                      style: const TextStyle(
                          color: _kTextMain, fontSize: 17,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 3),
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 3),
                      decoration: BoxDecoration(
                          color: color.withValues(alpha: .08),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                              color: color.withValues(alpha: .2))),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Container(width: 6, height: 6,
                            decoration: BoxDecoration(
                                color: color, shape: BoxShape.circle)),
                        const SizedBox(width: 4),
                        Text(statusText,
                            style: TextStyle(color: color,
                                fontSize: 13, fontWeight: FontWeight.w700)),
                      ]),
                    ),
                    const SizedBox(width: 8),
                    Text('ID：${e.userId}',
                        style: const TextStyle(
                            color: _kTextSub, fontSize: 13)),
                  ]),
                ])),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: _kTextSub, size: 18),
                ),
              ]),
            ),
            const Divider(height: 1, color: _kBorder),
            // 詳情內容
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(18),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  _dialogSectionHeader('基本資訊'),
                  _dialogInfoRow('用戶 ID', e.userId),
                  _dialogInfoRow('姓名',
                      e.userName.isNotEmpty ? e.userName : '未填寫'),
                  _dialogInfoRow('電話',
                      e.phone.isNotEmpty ? e.phone : '未填寫'),
                  _dialogInfoRow('SOS 編號', e.emergencyId),
                  const SizedBox(height: 4),
                  _dialogSectionHeader('事件資訊'),
                  _dialogInfoRow('狀態', statusText),
                  _dialogInfoRow('跳點數', '${e.hopCount}'),
                  _dialogInfoRow('發送時間', _fullTime(e.sentAt)),
                  if (e.receivedAt != null)
                    _dialogInfoRow('接收時間', _fullTime(e.receivedAt!)),
                  const SizedBox(height: 4),
                  _dialogSectionHeader('位置資訊'),
                  _dialogInfoRow('地址',
                      e.address?.isNotEmpty == true
                          ? e.address!
                          : '未提供'),
                  if (e.lat != 0 && e.lng != 0)
                    _dialogInfoRow('座標',
                        '${e.lat.toStringAsFixed(5)}, '
                        '${e.lng.toStringAsFixed(5)}'),
                  if (e.lat != 0 && e.lng != 0) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: GestureDetector(
                        onTap: () {
                          Navigator.pop(context);
                          _openMap(e.lat, e.lng);
                        },
                        child: Container(
                          padding:
                              const EdgeInsets.symmetric(vertical: 11),
                          decoration: BoxDecoration(
                            color: _kBlue.withValues(alpha: .06),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: _kBlue.withValues(alpha: .2)),
                          ),
                          child: const Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.center,
                              children: [
                            Icon(Icons.map_outlined,
                                color: _kBlue, size: 16),
                            SizedBox(width: 6),
                            Text('打開地圖',
                                style: TextStyle(
                                    color: _kBlue,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600)),
                          ]),
                        ),
                      ),
                    ),
                  ],
                ]),
              ),
            ),
          ]),
        ),
      ),
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
              fontSize: 13,
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
        // 與「全部」分頁的統計一致：尚未送達的需求都列出
        const active = {'pending', 'reserved', 'dispatched'};
        setState(() => _requests = all.where((r) => active.contains(r['status'])).toList());
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
    // 只列出申請人真的存在的需求（後端有幾筆 userId 對不到人）
    final ids = context.watch<CitizenViewmodel>().citizens.map((c) => c.id).toSet();
    final list = ids.isEmpty
        ? _requests
        : _requests.where((r) => ids.contains(r['userId']?.toString())).toList();
    final people = list.map((r) => r['userId']?.toString()).toSet().length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
      child: Column(children: [
        Row(children: [
          const Text('物資需求',
              style: TextStyle(color: _kTextMain, fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(width: 8),
          Text('共 ${list.length} 筆・$people 人',
              style: const TextStyle(color: _kTextSub, fontSize: 14, fontWeight: FontWeight.w600)),
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
        else if (list.isEmpty)
          const Expanded(child: Center(child: Text('目前沒有物資需求', style: TextStyle(color: _kTextSub, fontSize: 15))))
        else
          Expanded(
            child: ListView.builder(
              itemCount: list.length,
              itemBuilder: (_, i) => _requestCard(list[i], index: i),
            ),
          ),
      ]),
    );
  }

  Widget _requestCard(Map<String, dynamic> req, {required int index}) {
    final reqId    = req['requestId']?.toString() ?? req['id']?.toString() ?? '?';
    final itemName = req['itemName']?.toString() ?? '物資 #${req['itemId']}';
    final qty      = (req['qty'] as num?)?.toInt() ?? 0;
    final unit     = req['unit']?.toString() ?? '';
    final userId   = req['userId']?.toString() ?? '';
    // 申請人：用災民資料找姓名，找不到就顯示 ID
    String userName = req['userName']?.toString() ?? '';
    if (userName.isEmpty) {
      for (final c in context.read<CitizenViewmodel>().citizens) {
        if (c.id == userId) { userName = c.name; break; }
      }
    }
    final address  = req['address']?.toString() ?? '';
    final (label, color) = switch (req['status']?.toString()) {
      'pending'    => ('待處理', _kTextSub),
      'reserved'   => ('已預留', _kBlue),
      'dispatched' => ('已出庫', _kOrange),
      'completed'  => ('已完成', _kGreen),
      _            => (req['status']?.toString() ?? '', _kTextSub),
    };

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _showSupplyRequestDetail(context, [req], userName, userId),
      child: Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: index.isEven ? _kCardBg : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kBorder),
      ),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('$itemName × $qty $unit',
                style: const TextStyle(color: _kTextMain, fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(
                [
                  '申請人：${userName.isNotEmpty ? '$userName（$userId）' : (userId.isEmpty ? '—' : userId)}',
                  if (address.isNotEmpty) '地點：$address',
                ].join('　'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: _kTextSub, fontSize: 14)),
            const SizedBox(height: 2),
            Text(reqId, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
          ]),
        ),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: color.withValues(alpha: .08),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: color.withValues(alpha: .25)),
          ),
          child: Text(label, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w700)),
        ),
        const SizedBox(width: 8),
        const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
      ]),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  物資需求詳情（一人可能有多筆需求）
// ════════════════════════════════════════════════════════════════
void _showSupplyRequestDetail(
    BuildContext context, List<Map<String, dynamic>> reqs, String userName, String userId) {
  (String, Color) statusOf(String? st) => switch (st) {
        'pending'    => ('待處理', _kTextSub),
        'reserved'   => ('已預留', _kBlue),
        'dispatched' => ('已出庫', _kOrange),
        'completed'  => ('已完成', _kGreen),
        _            => (st ?? '', _kTextSub),
      };

  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: Row(children: [
        Expanded(
          child: Text(
            '物資需求・${userName.isNotEmpty ? '$userName（$userId）' : userId}',
            style: const TextStyle(color: _kTextMain, fontSize: 18, fontWeight: FontWeight.w800),
          ),
        ),
        InkWell(
          onTap: () => Navigator.pop(ctx),
          borderRadius: BorderRadius.circular(16),
          child: const Padding(
            padding: EdgeInsets.all(4),
            child: Icon(Icons.close, size: 20, color: Color(0xFF94A3B8)),
          ),
        ),
      ]),
      content: SizedBox(
        width: 460,
        child: ListView(shrinkWrap: true, children: [
          for (final r in reqs) ...[
            Builder(builder: (_) {
              final (label, color) = statusOf(r['status']?.toString());
              final lat = (r['lat'] as num?)?.toDouble();
              final lng = (r['lng'] as num?)?.toDouble();
              final hasLoc = lat != null && lng != null && !(lat == 0 && lng == 0);
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _kBorder),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(
                      child: Text('${r['itemName'] ?? '物資'} × ${r['qty'] ?? 0} ${r['unit'] ?? ''}',
                          style: const TextStyle(color: _kTextMain, fontSize: 16, fontWeight: FontWeight.w800)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: .08),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: color.withValues(alpha: .25)),
                      ),
                      child: Text(label, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w700)),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  _dialogInfoRow('需求編號', r['requestId']?.toString() ?? ''),
                  _dialogInfoRow('需求地點', r['address']?.toString() ?? ''),
                  _dialogInfoRow('建立時間', r['createdAt']?.toString() ?? ''),
                  if (hasLoc)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () => launchUrl(
                            Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng'),
                            mode: LaunchMode.externalApplication),
                        icon: const Icon(Icons.map_outlined, size: 18),
                        label: const Text('在地圖上查看'),
                      ),
                    ),
                ]),
              );
            }),
          ],
        ]),
      ),
    ),
  );
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

// ── Dialog 共用元件 ────────────────────────────────────────────
Widget _dialogInfoRow(String label, String value) {
  return Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
    decoration: BoxDecoration(
      color: const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: _kBorder),
    ),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(
        width: 78,
        child: Text(label,
            style: const TextStyle(color: _kTextSub, fontSize: 13, fontWeight: FontWeight.w500)),
      ),
      Expanded(
        child: Text(value.isEmpty ? '未填寫' : value,
            style: const TextStyle(color: _kTextMain, fontSize: 14, fontWeight: FontWeight.w600)),
      ),
    ]),
  );
}

Widget _dialogSectionHeader(String label) {
  return Padding(
    padding: const EdgeInsets.only(top: 4, bottom: 8),
    child: Row(children: [
      Container(
          width: 3, height: 14,
          decoration: BoxDecoration(
              color: _kBlue, borderRadius: BorderRadius.circular(99))),
      const SizedBox(width: 7),
      Text(label,
          style: const TextStyle(
              color: _kTextMain, fontSize: 14, fontWeight: FontWeight.w700)),
    ]),
  );
}

/// 「詳情」按鈕：各頁統一白底藍框（color 參數保留給呼叫端，不再改變按鈕顏色）
Widget _detailButton(Color color, VoidCallback onTap) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _kBlue.withValues(alpha: .4)),
      ),
      child: const Text('詳情',
          style: TextStyle(color: _kBlue, fontSize: 14, fontWeight: FontWeight.w700)),
    ),
  );
}

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
                fontSize: 13),
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
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ]),
        ),
      ),
    ]);
  }
}
