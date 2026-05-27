import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_disaster_app/core/models/emergency_request.dart';
import 'package:flutter_disaster_app/admin_APP/viewModels/emergency_viewmodel.dart';

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
//  地址快取
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
      final road   = address?['road'] ?? '';
      final result = [district, road].where((s) => s.isNotEmpty).join('');

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
//  EMERGENCY PAGE
// ══════════════════════════════════════════════════════════
class EmergencyPage extends StatefulWidget {
  const EmergencyPage({super.key});

  @override
  State<EmergencyPage> createState() => _EmergencyPageState();
}

class _EmergencyPageState extends State<EmergencyPage> {
  String _filter      = '全部';
  String _searchQuery = '';
  final  TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    Future.microtask(
        () => context.read<EmergencyViewModel>().loadEmergencies());
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _openMap(double lat, double lng) async {
    final uri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _confirmHandle(EmergencyRequest e, EmergencyViewModel vm) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withOpacity(.35),
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        titlePadding:   const EdgeInsets.fromLTRB(20, 20, 20, 8),
        contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        title: const Text('確認標記已處理',
            style: TextStyle(color: _kTextMain, fontSize: 15, fontWeight: FontWeight.w700)),
        content: Text(
          '確定將「${e.userName.isNotEmpty ? e.userName : e.userId}」的求救事件標記為已處理？此操作無法還原。',
          style: const TextStyle(color: _kTextSub, fontSize: 14),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消', style: TextStyle(color: _kTextSub)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _kGreen,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
    final pending    = all.where((e) => e.status != 'resolved' && e.status != 'processing').length;
    final processing = all.where((e) => e.status == 'processing').length;
    final resolved   = all.where((e) => e.status == 'resolved').length;
    final q = _searchQuery.trim().toLowerCase();
    final filtered = all.where((e) {
      if (_filter == '待處理') { if (e.status == 'resolved' || e.status == 'processing') return false; }
      else if (_filter == '處理中') { if (e.status != 'processing') return false; }
      else if (_filter == '已完成') { if (e.status != 'resolved') return false; }
      if (q.isEmpty) return true;
      return e.userName.toLowerCase().contains(q) ||
             e.userId.toLowerCase().contains(q)   ||
             e.phone.toLowerCase().contains(q);
    }).toList()..sort((a, b) => b.sentAt.compareTo(a.sentAt));

    return Container(
      color: _kBg,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 14, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(vm, pending),
                  const SizedBox(height: 12),
                  _buildStatsBar(all.length, pending, processing, resolved),
                  const SizedBox(height: 10),
                  _buildSearchBar(),
                  const SizedBox(height: 10),
                  _buildToolbar(filtered.length),
                  const SizedBox(height: 10),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                child: _buildList(vm, filtered),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(EmergencyViewModel vm, int pending) {
    return Row(children: [
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('緊急事件',
            style: TextStyle(color: _kTextMain, fontSize: 26, fontWeight: FontWeight.w800)),
        const SizedBox(height: 1),
        const Text('EMERGENCY MANAGEMENT',
            style: TextStyle(color: _kTextSub, fontSize: 11, letterSpacing: 1.3)),
      ]),
      const SizedBox(width: 12),
      if (pending > 0) _tag('待處理 $pending 件', _kOrange),
      const Spacer(),
      _iconBtn(Icons.refresh_rounded, _kBlue, vm.loadEmergencies),
    ]);
  }

  Widget _buildStatsBar(int total, int pending, int processing, int resolved) {
    return Container(
      decoration: BoxDecoration(
        color:        _kCardBg,
        borderRadius: BorderRadius.circular(10),
        border:       Border.all(color: _kBorder),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: .028), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(children: [
        _tapStatCell(Icons.apps_rounded,           '$total',      '全部',   _kBlue,   '全部'),
        _divider(),
        _tapStatCell(Icons.warning_amber_rounded,  '$pending',    '待處理', _kOrange, '待處理'),
        _divider(),
        _tapStatCell(Icons.sync_rounded,           '$processing', '處理中', _kBlue,   '處理中'),
        _divider(),
        _tapStatCell(Icons.check_circle_outline,   '$resolved',   '已完成', _kGreen,  '已完成'),
      ]),
    );
  }

  Widget _tapStatCell(IconData icon, String val, String label, Color color, String filter) {
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
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(val, style: TextStyle(color: sel ? color : _kTextMain, fontSize: 20, fontWeight: FontWeight.w800, height: 1.1)),
              Text(label, style: const TextStyle(color: _kTextSub, fontSize: 11)),
            ]),
            if (sel) ...[const Spacer(), Icon(Icons.check_circle_rounded, color: color, size: 14)],
          ]),
        ),
      ),
    );
  }

  Widget _divider() => Container(width: 1, height: 28, color: _kBorder);

  Widget _buildSearchBar() {
    return Container(
      height: 38,
      decoration: BoxDecoration(
        color:        _kCardBg,
        borderRadius: BorderRadius.circular(8),
        border:       Border.all(color: _kBorder),
      ),
      child: TextField(
        controller: _searchCtrl,
        style: const TextStyle(color: _kTextMain, fontSize: 13),
        decoration: InputDecoration(
          hintText:        '搜尋姓名、ID 或電話…',
          hintStyle:       const TextStyle(color: _kTextSub, fontSize: 13),
          prefixIcon:      const Icon(Icons.search_rounded, color: _kTextSub, size: 18),
          suffixIcon: _searchQuery.isNotEmpty
              ? GestureDetector(
                  onTap: () => setState(() {
                    _searchCtrl.clear();
                    _searchQuery = '';
                  }),
                  child: const Icon(Icons.close_rounded, color: _kTextSub, size: 16),
                )
              : null,
          border:          InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
        ),
        onChanged: (v) => setState(() => _searchQuery = v),
      ),
    );
  }

  Widget _buildToolbar(int shown) {
    return Row(children: [
      _filterBtn('全部',   _kBlue),
      const SizedBox(width: 4),
      _filterBtn('待處理', _kOrange),
      const SizedBox(width: 4),
      _filterBtn('處理中', _kBlue),
      const SizedBox(width: 4),
      _filterBtn('已完成', _kGreen),
      const Spacer(),
      Text('共 $shown 筆', style: const TextStyle(color: _kTextSub, fontSize: 12)),
    ]);
  }

  Widget _filterBtn(String label, Color color) {
    final sel = _filter == label;
    return GestureDetector(
      onTap: () => setState(() => _filter = label),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 130),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color:        sel ? color.withValues(alpha: .08) : _kCardBg,
          borderRadius: BorderRadius.circular(8),
          border:       Border.all(color: sel ? color.withValues(alpha: .35) : _kBorder),
        ),
        child: Text(label,
            style: TextStyle(
                color:      sel ? color : _kTextSub,
                fontSize:   12,
                fontWeight: sel ? FontWeight.w700 : FontWeight.w500)),
      ),
    );
  }

  Widget _buildList(EmergencyViewModel vm, List<EmergencyRequest> filtered) {
    if (vm.isLoading) {
      return const Center(child: CircularProgressIndicator(color: _kBlue, strokeWidth: 2.5));
    }
    if (vm.errorMessage != null) {
      return _placeholder(
        icon: Icons.cloud_off_outlined, iconColor: _kRed,
        title: '資料載入失敗',
        subtitle: vm.errorMessage,
        action: GestureDetector(
          onTap: vm.loadEmergencies,
          child: Container(
            margin: const EdgeInsets.only(top: 10),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color:        _kRed.withOpacity(.06),
              borderRadius: BorderRadius.circular(7),
              border:       Border.all(color: _kRed.withOpacity(.2)),
            ),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.refresh_rounded, color: _kRed, size: 14),
              SizedBox(width: 5),
              Text('重新載入', style: TextStyle(color: _kRed, fontSize: 12, fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
      );
    }
    if (vm.emergencies.isEmpty) return _placeholder(icon: Icons.inbox_outlined, iconColor: _kTextSub, title: '暫無緊急事件');
    if (filtered.isEmpty) {
      return _placeholder(icon: Icons.inbox_outlined, iconColor: _kTextSub, title: '沒有「$_filter」的事件');
    }

    return Container(
      decoration: BoxDecoration(
        color:        _kCardBg,
        borderRadius: BorderRadius.circular(12),
        border:       Border.all(color: _kBorder),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(.028), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
          decoration: const BoxDecoration(
            color:        Color(0xFFF8FAFC),
            borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            border:       Border(bottom: BorderSide(color: _kBorder)),
          ),
          child: Row(children: [
            const Icon(Icons.bolt_rounded, color: _kTextMain, size: 16),
            const SizedBox(width: 6),
            const Text('求救事件列表',
                style: TextStyle(color: _kTextMain, fontSize: 14, fontWeight: FontWeight.w700)),
            const Spacer(),
            Text('共 ${filtered.length} 筆', style: const TextStyle(color: _kTextSub, fontSize: 11)),
          ]),
        ),
        Expanded(
          child: ListView.builder(
            padding:   const EdgeInsets.all(10),
            itemCount: filtered.length,
            itemBuilder: (_, i) => _buildCard(filtered[i], vm),
          ),
        ),
      ]),
    );
  }

  // ══════════════════════════════════════════════════════════
  //  事件卡片（加上姓名、ID、完整發送時間）
  // ══════════════════════════════════════════════════════════
  Widget _buildCard(EmergencyRequest e, EmergencyViewModel vm) {
    final isResolved   = e.status == 'resolved';
    final isProcessing = e.status == 'processing';
    final color = isResolved ? _kGreen : (isProcessing ? _kBlue : _kOrange);
    final statusLabel = isResolved ? '已完成' : (isProcessing ? '處理中' : '待處理');
    final displayName = e.userName.isNotEmpty ? e.userName : '用戶 ${e.userId}';

    return Container(
      margin:  const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:        isResolved ? Colors.white : color.withValues(alpha: .025),
        borderRadius: BorderRadius.circular(10),
        border:       Border.all(color: isResolved ? _kBorder : color.withValues(alpha: .20)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        // 左側圖示
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(color: color.withValues(alpha: .10), borderRadius: BorderRadius.circular(9)),
          child: Icon(
            isResolved ? Icons.check_circle_outline_rounded
                : isProcessing ? Icons.sync_rounded
                : Icons.warning_amber_rounded,
            color: color, size: 19,
          ),
        ),
        const SizedBox(width: 12),

        // 主要內容：姓名+ID、電話、位置
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // 姓名 + ID + 狀態
            Row(children: [
              const Icon(Icons.person_outline_rounded, color: _kTextSub, size: 13),
              const SizedBox(width: 4),
              Flexible(child: Text(displayName,
                  style: const TextStyle(color: _kTextMain, fontSize: 13, fontWeight: FontWeight.w700),
                  overflow: TextOverflow.ellipsis, maxLines: 1)),
              const SizedBox(width: 6),
              Flexible(child: Text('ID：${e.userId}', style: const TextStyle(color: _kTextSub, fontSize: 12),
                  overflow: TextOverflow.ellipsis, maxLines: 1)),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .10),
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(color: color.withValues(alpha: .25)),
                ),
                child: Text(statusLabel,
                    style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700)),
              ),
            ]),
            const SizedBox(height: 5),
            // 電話
            if (e.phone.isNotEmpty) ...[
              Row(children: [
                const Icon(Icons.phone_outlined, color: _kTextSub, size: 13),
                const SizedBox(width: 4),
                Text(e.phone, style: const TextStyle(color: _kTextSub, fontSize: 12)),
              ]),
              const SizedBox(height: 5),
            ],
            // 位置
            _AddressWidget(lat: e.lat, lng: e.lng, onMapTap: () => _openMap(e.lat, e.lng)),
          ]),
        ),

        // 右側按鈕
        if (!isResolved) ...[
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () => _confirmHandle(e, vm),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
              decoration: BoxDecoration(
                color:        _kGreen.withValues(alpha: .10),
                borderRadius: BorderRadius.circular(8),
                border:       Border.all(color: _kGreen.withValues(alpha: .35)),
              ),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.check_rounded, color: _kGreen, size: 14),
                SizedBox(width: 5),
                Text('標記完成', style: TextStyle(color: _kGreen, fontSize: 12, fontWeight: FontWeight.w700)),
              ]),
            ),
          ),
        ],
      ]),
    );
  }

  // ── 共用小元件 ────────────────────────────────────────
  Widget _placeholder({
    IconData? icon, Color? iconColor,
    String? title, String? subtitle, Widget? action,
  }) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
              color: (iconColor ?? _kBlue).withOpacity(.08), shape: BoxShape.circle),
          child: Icon(icon, color: iconColor ?? _kBlue, size: 20),
        ),
        const SizedBox(height: 10),
        Text(title ?? '',
            style: const TextStyle(color: _kTextMain, fontSize: 13, fontWeight: FontWeight.w600)),
        if (subtitle != null) ...[
          const SizedBox(height: 3),
          Text(subtitle, style: const TextStyle(color: _kTextSub, fontSize: 12)),
        ],
        if (action != null) action,
      ]),
    );
  }

  static Widget _tag(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
        color:        color.withOpacity(.08),
        borderRadius: BorderRadius.circular(999),
        border:       Border.all(color: color.withOpacity(.18))),
    child: Text(text, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700)),
  );

  static Widget _iconBtn(IconData icon, Color color, VoidCallback onTap) =>
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
//  地址顯示元件
// ══════════════════════════════════════════════════════════
class _AddressWidget extends StatefulWidget {
  final double       lat;
  final double       lng;
  final VoidCallback onMapTap;

  const _AddressWidget({
    required this.lat,
    required this.lng,
    required this.onMapTap,
  });

  @override
  State<_AddressWidget> createState() => _AddressWidgetState();
}

class _AddressWidgetState extends State<_AddressWidget> {
  String _address = '查詢中…';
  bool   _loaded  = false;

  @override
  void initState() { super.initState(); _load(); }

  @override
  void didUpdateWidget(_AddressWidget old) {
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
      Icon(Icons.location_on_outlined,
          color: _loaded ? _kTextSub : _kBlue.withOpacity(.4), size: 13),
      const SizedBox(width: 4),
      Expanded(
        child: Text(_address,
            style: TextStyle(
                color:    _loaded ? _kTextSub : _kBlue.withOpacity(.5),
                fontSize: 12),
            maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      const SizedBox(width: 6),
      GestureDetector(
        onTap: widget.onMapTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color:        _kBlue.withOpacity(.06),
            borderRadius: BorderRadius.circular(4),
            border:       Border.all(color: _kBlue.withOpacity(.18)),
          ),
          child: const Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.map_outlined, color: _kBlue, size: 11),
            SizedBox(width: 3),
            Text('地圖', style: TextStyle(color: _kBlue, fontSize: 10, fontWeight: FontWeight.w600)),
          ]),
        ),
      ),
    ]);
  }
}

