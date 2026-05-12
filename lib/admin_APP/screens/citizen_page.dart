import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_disaster_app/core/models/citizen.dart';
import 'package:flutter_disaster_app/admin_APP/viewModels/citizen_viewmodel.dart';

const Color _kBg       = Color(0xFFF5F7FA);
const Color _kCardBg   = Color(0xFFFFFFFF);
const Color _kCardBg2  = Color(0xFFF8FAFC);
const Color _kBorder   = Color(0xFFE5E7EB);
const Color _kBlue     = Color(0xFF2563EB);
const Color _kGreen    = Color(0xFF16A34A);
const Color _kOrange   = Color(0xFFF59E0B);
const Color _kRed      = Color(0xFFDC2626);
const Color _kTextMain = Color(0xFF0F172A);
const Color _kTextSub  = Color(0xFF64748B);

// ══════════════════════════════════════════════════════════
//  地址快取（OpenStreetMap 反查，避免重複查詢）
// ══════════════════════════════════════════════════════════
final Map<String, String> _addressCache = {};

Future<String> _fetchAddress(double lat, double lng) async {
  final key = '${lat.toStringAsFixed(5)},${lng.toStringAsFixed(5)}';
  if (_addressCache.containsKey(key)) return _addressCache[key]!;

  try {
    final uri = Uri.parse(
      'https://nominatim.openstreetmap.org/reverse'
      '?format=json&lat=$lat&lon=$lng&accept-language=zh-TW',
    );
    final res = await http.get(uri, headers: {
      'User-Agent': 'FlutterDisasterApp/1.0',
    }).timeout(const Duration(seconds: 6));

    if (res.statusCode == 200) {
      final data    = jsonDecode(res.body);
      final address = data['address'] as Map<String, dynamic>?;

      final district = address?['suburb']       ??
                       address?['town']          ??
                       address?['village']       ??
                       address?['city_district'] ?? '';
      final road     = address?['road'] ?? '';
      final result   = [district, road]
          .where((s) => s.isNotEmpty)
          .join('');

      final display = result.isNotEmpty
          ? result
          : (data['display_name'] as String? ?? '').split(',').first;

      _addressCache[key] = display;
      return display;
    }
  } catch (_) {}

  return '${lat.toStringAsFixed(3)}, ${lng.toStringAsFixed(3)}';
}

// ══════════════════════════════════════════════════════════
//  CITIZEN PAGE
// ══════════════════════════════════════════════════════════
class CitizenPage extends StatefulWidget {
  const CitizenPage({super.key});

  @override
  State<CitizenPage> createState() => _CitizenPageState();
}

class _CitizenPageState extends State<CitizenPage> {
  final TextEditingController _searchController = TextEditingController();
  String _filterStatus = '全部';

  @override
  void initState() {
    super.initState();
    Future.microtask(
        () => context.read<CitizenViewmodel>().loadCitizens());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Citizen> _filtered(List<Citizen> all) {
    final kw = _searchController.text.trim().toLowerCase();

    var result = all.where((c) {
      final matchKw = kw.isEmpty ||
          c.name.toLowerCase().contains(kw) ||
          c.id.toLowerCase().contains(kw);
      final matchStatus = _filterStatus == '全部' ||
          (_filterStatus == '待救援' && c.needsRescue) ||
          (_filterStatus == '安全' && !c.needsRescue);
      return matchKw && matchStatus;
    }).toList();

    // ★ 待救援排前面
    result.sort((a, b) {
      if (a.needsRescue && !b.needsRescue) return -1;
      if (!a.needsRescue && b.needsRescue) return 1;
      return 0;
    });

    return result;
  }

  Future<void> _openMap(double lat, double lng) async {
    final uri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _confirmToggle(Citizen c) async {
    final toRescue = !c.needsRescue;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withOpacity(.35),
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
        titlePadding:   const EdgeInsets.fromLTRB(20, 20, 20, 8),
        contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        title: Text(
          toRescue ? '標記為待救援' : '標記為安全',
          style: const TextStyle(
              color:      _kTextMain,
              fontSize:   15,
              fontWeight: FontWeight.w700),
        ),
        content: Text(
          '確定將「${c.name}」${toRescue ? '設為待救援' : '設為安全'}？',
          style: const TextStyle(color: _kTextSub, fontSize: 14),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消',
                style: TextStyle(color: _kTextSub)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: toRescue ? _kOrange : _kGreen,
              foregroundColor: Colors.white,
              elevation:       0,
              padding: const EdgeInsets.symmetric(
                  horizontal: 18, vertical: 10),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(toRescue ? '標記求援' : '標記安全'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      context.read<CitizenViewmodel>().updateNeedsRescue(c, toRescue);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm     = context.watch<CitizenViewmodel>();
    final all    = vm.citizens;
    final rows   = _filtered(all);
    final total  = all.length;
    final rescue = all.where((c) => c.needsRescue).length;
    final safe   = total - rescue;

    return Container(
      color: _kBg,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 固定頂部 ──────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 14, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(vm),
                  const SizedBox(height: 12),
                  _buildStatsBar(total, rescue, safe),
                  const SizedBox(height: 10),
                  _buildToolbar(),
                  const SizedBox(height: 10),
                ],
              ),
            ),
            // ── 可捲動表格 ────────────────────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                child: _buildTable(vm, rows),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 標題列（移除 USER APP DATA ONLY）────────────────────
  Widget _buildHeader(CitizenViewmodel vm) {
    return Row(children: [
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('災民管理',
            style: TextStyle(
                color:      _kTextMain,
                fontSize:   26,
                fontWeight: FontWeight.w800)),
        const SizedBox(height: 1),
        const Text('CITIZEN MANAGEMENT CENTER',
            style: TextStyle(
                color:         _kTextSub,
                fontSize:      11,
                letterSpacing: 1.3)),
      ]),
      const SizedBox(width: 12),
      _tag('即時同步', _kGreen),
      const Spacer(),
      _iconBtn(Icons.refresh_rounded, _kBlue, vm.loadCitizens),
    ]);
  }

  // ── 統計橫條 ──────────────────────────────────────────
  Widget _buildStatsBar(int total, int rescue, int safe) {
    return Container(
      decoration: BoxDecoration(
        color:        _kCardBg,
        borderRadius: BorderRadius.circular(10),
        border:       Border.all(color: _kBorder),
        boxShadow: [
          BoxShadow(
              color:      Colors.black.withOpacity(.028),
              blurRadius: 6,
              offset:     const Offset(0, 2)),
        ],
      ),
      child: Row(children: [
        _statCell(Icons.people_alt_outlined,   '$total',  '總災民', _kBlue),
        _divider(),
        _statCell(Icons.warning_amber_rounded, '$rescue', '待救援', _kOrange),
        _divider(),
        _statCell(Icons.check_circle_outline,  '$safe',   '安全',   _kGreen),
      ]),
    );
  }

  Widget _statCell(IconData icon, String val, String label, Color color) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
                color:        color.withOpacity(.10),
                borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(val,
                style: TextStyle(
                    color:      color,
                    fontSize:   20,
                    fontWeight: FontWeight.w800,
                    height:     1.1)),
            Text(label,
                style: const TextStyle(
                    color: _kTextSub, fontSize: 11)),
          ]),
        ]),
      ),
    );
  }

  Widget _divider() =>
      Container(width: 1, height: 28, color: _kBorder);

  // ── 搜尋 + 篩選 Tab（數字拿掉）────────────────────────
  Widget _buildToolbar() {
    return Row(children: [
      Expanded(
        child: Container(
          height: 38,
          decoration: BoxDecoration(
            color:        _kCardBg,
            borderRadius: BorderRadius.circular(8),
            border:       Border.all(color: _kBorder),
          ),
          child: TextField(
            controller: _searchController,
            onChanged:  (_) => setState(() {}),
            style: const TextStyle(color: _kTextMain, fontSize: 13),
            decoration: const InputDecoration(
              hintText:       '搜尋姓名或 ID...',
              hintStyle:      TextStyle(color: _kTextSub, fontSize: 13),
              prefixIcon:     Icon(Icons.search, color: _kTextSub, size: 16),
              border:         InputBorder.none,
              contentPadding: EdgeInsets.symmetric(vertical: 10),
            ),
          ),
        ),
      ),
      const SizedBox(width: 8),
      // ★ Tab 不顯示數字
      _filterBtn('全部',   _kBlue),
      const SizedBox(width: 4),
      _filterBtn('待救援', _kOrange),
      const SizedBox(width: 4),
      _filterBtn('安全',   _kGreen),
    ]);
  }

  Widget _filterBtn(String label, Color color) {
    final sel = _filterStatus == label;
    return GestureDetector(
      onTap: () => setState(() => _filterStatus = label),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 130),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color:        sel ? color.withOpacity(.08) : _kCardBg,
          borderRadius: BorderRadius.circular(8),
          border:       Border.all(
              color: sel ? color.withOpacity(.35) : _kBorder),
        ),
        child: Text(label,
            style: TextStyle(
                color:      sel ? color : _kTextSub,
                fontSize:   12,
                fontWeight: sel ? FontWeight.w700 : FontWeight.w500)),
      ),
    );
  }

  // ── 表格 ──────────────────────────────────────────────
  Widget _buildTable(CitizenViewmodel vm, List<Citizen> rows) {
    return Container(
      decoration: BoxDecoration(
        color:        _kCardBg,
        borderRadius: BorderRadius.circular(12),
        border:       Border.all(color: _kBorder),
        boxShadow: [
          BoxShadow(
              color:      Colors.black.withOpacity(.028),
              blurRadius: 6,
              offset:     const Offset(0, 2)),
        ],
      ),
      child: Column(children: [
        // 表頭
        Container(
          height:  40,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: const BoxDecoration(
            color:        Color(0xFFF8FAFC),
            borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            border:       Border(bottom: BorderSide(color: _kBorder)),
          ),
          child: Row(children: [
            _th('姓名',    flex: 2),
            _th('ID',      flex: 2),
            _th('位置',    flex: 3),
            _th('救援狀態', flex: 2),
            _th('操作',    flex: 2),
          ]),
        ),

        // 狀態
        if (vm.isLoading)
          _placeholder(
              child: const SizedBox(
                  width: 24, height: 24,
                  child: CircularProgressIndicator(
                      color: _kBlue, strokeWidth: 2.5)))
        else if (vm.errorMessage != null)
          _errorState(vm)
        else if (rows.isEmpty && vm.citizens.isEmpty)
          _emptyState()
        else if (rows.isEmpty)
          _noResultState()
        else
          Expanded(
            child: ListView.builder(
              itemCount:   rows.length,
              itemBuilder: (_, i) => _buildRow(rows[i], i),
            ),
          ),
      ]),
    );
  }

  Widget _th(String text, {int flex = 1}) => Expanded(
    flex: flex,
    child: Text(text,
        style: const TextStyle(
            color:         _kTextSub,
            fontSize:      11,
            fontWeight:    FontWeight.w600,
            letterSpacing: .4)),
  );

  Widget _buildRow(Citizen c, int i) {
    // ★ 待救援的行加上淡橘色背景
    final isRescue = c.needsRescue;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: isRescue
            ? _kOrange.withOpacity(.03)
            : (i % 2 == 0 ? Colors.transparent : _kCardBg2),
        border: Border(
            bottom: BorderSide(
                color: isRescue
                    ? _kOrange.withOpacity(.12)
                    : _kBorder,
                width: .5)),
      ),
      child: Row(children: [
        // 姓名
        Expanded(
          flex: 2,
          child: Row(children: [
            CircleAvatar(
              radius:          13,
              backgroundColor: isRescue
                  ? _kOrange.withOpacity(.15)
                  : _kBlue.withOpacity(.10),
              child: Text(
                c.name.isNotEmpty ? c.name[0] : '?',
                style: TextStyle(
                    color:      isRescue ? _kOrange : _kBlue,
                    fontSize:   11,
                    fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(c.name,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color:      _kTextMain,
                      fontSize:   13,
                      fontWeight: FontWeight.w600)),
            ),
          ]),
        ),

        // ID
        Expanded(
          flex: 2,
          child: Text(c.id,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: _kTextSub, fontSize: 12)),
        ),

        // ★ 位置（OpenStreetMap 反查地址）
        Expanded(
          flex: 3,
          child: _AddressCell(
            lat:       c.latitude,
            lng:       c.longitude,
            onMapTap:  () => _openMap(c.latitude, c.longitude),
          ),
        ),

        // 救援狀態
        Expanded(
          flex: 2,
          child: _statusBadge(c.needsRescue),
        ),

        // 操作
        Expanded(
          flex: 2,
          child: _actionBtn(c),
        ),
      ]),
    );
  }

  Widget _statusBadge(bool needsRescue) {
    final color = needsRescue ? _kRed : _kGreen;
    final text  = needsRescue ? '待救援' : '安全';
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
          width: 6, height: 6,
          decoration:
              BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 6),
      Text(text,
          style: TextStyle(
              color:      color,
              fontSize:   12,
              fontWeight: FontWeight.w600)),
    ]);
  }

  Widget _actionBtn(Citizen c) {
    final isRescue = c.needsRescue;
    final color    = isRescue ? _kGreen : _kOrange;
    final label    = isRescue ? '標記安全' : '標記求援';
    final icon     = isRescue
        ? Icons.check_rounded
        : Icons.warning_amber_rounded;
    return GestureDetector(
      onTap: () => _confirmToggle(c),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color:        color.withOpacity(.07),
          borderRadius: BorderRadius.circular(6),
          border:       Border.all(color: color.withOpacity(.25)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  color:      color,
                  fontSize:   12,
                  fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }

  // ── 空狀態（加流程說明）──────────────────────────────
  Widget _emptyState() {
    return Expanded(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                  color:  _kBlue.withOpacity(.08),
                  shape:  BoxShape.circle),
              child: const Icon(Icons.cloud_sync_outlined,
                  color: _kBlue, size: 24),
            ),
            const SizedBox(height: 14),
            const Text('等待用戶端同步',
                style: TextStyle(
                    color:      _kTextMain,
                    fontSize:   15,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            const Text('資料由使用者 APP 自動上傳',
                style: TextStyle(color: _kTextSub, fontSize: 13)),
            const SizedBox(height: 28),

            // ★ 流程說明
            Container(
              width:   480,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color:        _kCardBg2,
                borderRadius: BorderRadius.circular(12),
                border:       Border.all(color: _kBorder),
              ),
              child: Column(children: [
                const Text('資料來源說明',
                    style: TextStyle(
                        color:      _kTextMain,
                        fontSize:   13,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _flowStep(
                      icon:     Icons.smartphone_outlined,
                      color:    _kBlue,
                      label:    '用戶 APP',
                      sublabel: '災民自行回報位置',
                    ),
                    _flowArrow(),
                    _flowStep(
                      icon:     Icons.cloud_upload_outlined,
                      color:    _kGreen,
                      label:    '自動上傳',
                      sublabel: '即時同步至後端',
                    ),
                    _flowArrow(),
                    _flowStep(
                      icon:     Icons.admin_panel_settings_outlined,
                      color:    _kOrange,
                      label:    '管理端',
                      sublabel: '查看並標記救援狀態',
                    ),
                  ],
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _flowStep({
    required IconData icon,
    required Color    color,
    required String   label,
    required String   sublabel,
  }) {
    return Column(children: [
      Container(
        width: 44, height: 44,
        decoration: BoxDecoration(
            color:        color.withOpacity(.10),
            shape:        BoxShape.circle,
            border:       Border.all(color: color.withOpacity(.22))),
        child: Icon(icon, color: color, size: 20),
      ),
      const SizedBox(height: 8),
      Text(label,
          style: const TextStyle(
              color:      _kTextMain,
              fontSize:   12,
              fontWeight: FontWeight.w700)),
      const SizedBox(height: 3),
      SizedBox(
        width: 80,
        child: Text(sublabel,
            textAlign: TextAlign.center,
            style: const TextStyle(
                color:    _kTextSub,
                fontSize: 10,
                height:   1.4)),
      ),
    ]);
  }

  Widget _flowArrow() => const Padding(
    padding: EdgeInsets.only(bottom: 20, left: 8, right: 8),
    child: Icon(Icons.chevron_right_rounded,
        color: _kBorder, size: 22),
  );

  Widget _noResultState() => _placeholder(
    icon:     Icons.search_off_rounded,
    iconColor: _kTextSub,
    title:    '找不到符合條件的結果',
    subtitle: '請調整搜尋關鍵字或篩選條件',
  );

  Widget _errorState(CitizenViewmodel vm) => _placeholder(
    icon:     Icons.cloud_off_outlined,
    iconColor: _kRed,
    title:    '資料載入失敗',
    subtitle: vm.errorMessage ?? '發生未知錯誤',
    action: GestureDetector(
      onTap: vm.loadCitizens,
      child: Container(
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color:        _kRed.withOpacity(.06),
          borderRadius: BorderRadius.circular(7),
          border:       Border.all(color: _kRed.withOpacity(.2)),
        ),
        child: const Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.refresh_rounded, color: _kRed, size: 14),
          SizedBox(width: 5),
          Text('重新載入',
              style: TextStyle(
                  color:      _kRed,
                  fontSize:   12,
                  fontWeight: FontWeight.w600)),
        ]),
      ),
    ),
  );

  Widget _placeholder({
    Widget?   child,
    IconData? icon,
    Color?    iconColor,
    String?   title,
    String?   subtitle,
    Widget?   action,
  }) {
    return Expanded(
      child: Center(
        child: child ??
            Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                    color:  (iconColor ?? _kBlue).withOpacity(.08),
                    shape:  BoxShape.circle),
                child: Icon(icon,
                    color: iconColor ?? _kBlue, size: 20),
              ),
              const SizedBox(height: 10),
              Text(title ?? '',
                  style: const TextStyle(
                      color:      _kTextMain,
                      fontSize:   13,
                      fontWeight: FontWeight.w600)),
              if (subtitle != null) ...[
                const SizedBox(height: 3),
                Text(subtitle,
                    style: const TextStyle(
                        color: _kTextSub, fontSize: 12)),
              ],
              if (action != null) action,
            ]),
      ),
    );
  }

  // ── 共用小元件 ────────────────────────────────────────
  static Widget _tag(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
        color:        color.withOpacity(.08),
        borderRadius: BorderRadius.circular(999),
        border:       Border.all(color: color.withOpacity(.18))),
    child: Text(text,
        style: TextStyle(
            color:      color,
            fontSize:   10,
            fontWeight: FontWeight.w700)),
  );

  static Widget _iconBtn(
      IconData icon, Color color, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          width: 34, height: 34,
          decoration: BoxDecoration(
              color:        _kCardBg,
              borderRadius: BorderRadius.circular(8),
              border:       Border.all(color: _kBorder)),
          child: Icon(icon, color: color, size: 16),
        ),
      );
}

// ══════════════════════════════════════════════════════════
//  地址顯示元件（非同步查詢 OpenStreetMap）
// ══════════════════════════════════════════════════════════
class _AddressCell extends StatefulWidget {
  final double       lat;
  final double       lng;
  final VoidCallback onMapTap;

  const _AddressCell({
    required this.lat,
    required this.lng,
    required this.onMapTap,
  });

  @override
  State<_AddressCell> createState() => _AddressCellState();
}

class _AddressCellState extends State<_AddressCell> {
  String _address = '查詢中…';
  bool   _loaded  = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(_AddressCell old) {
    super.didUpdateWidget(old);
    if (old.lat != widget.lat || old.lng != widget.lng) _load();
  }

  Future<void> _load() async {
    final result = await _fetchAddress(widget.lat, widget.lng);
    if (mounted) setState(() { _address = result; _loaded = true; });
  }

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(
        Icons.location_on_outlined,
        color: _loaded
            ? const Color(0xFF64748B)
            : const Color(0xFF2563EB).withOpacity(.4),
        size: 12,
      ),
      const SizedBox(width: 4),
      Flexible(
        child: Text(
          _address,
          overflow:  TextOverflow.ellipsis,
          style: TextStyle(
              color:    _loaded
                  ? const Color(0xFF64748B)
                  : const Color(0xFF2563EB).withOpacity(.5),
              fontSize: 12),
        ),
      ),
      const SizedBox(width: 5),
      GestureDetector(
        onTap: widget.onMapTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color:        const Color(0xFF2563EB).withOpacity(.06),
            borderRadius: BorderRadius.circular(5),
            border:       Border.all(
                color: const Color(0xFF2563EB).withOpacity(.18)),
          ),
          child: const Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.map_outlined,
                color: Color(0xFF2563EB), size: 11),
            SizedBox(width: 3),
            Text('地圖',
                style: TextStyle(
                    color:      Color(0xFF2563EB),
                    fontSize:   10,
                    fontWeight: FontWeight.w600)),
          ]),
        ),
      ),
    ]);
  }
}