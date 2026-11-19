import 'package:flutter/material.dart';
import 'package:flutter_disaster_app/admin_APP/widgets/page_header.dart';
import 'package:flutter_disaster_app/admin_APP/widgets/firebase_reports_panel.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_disaster_app/core/models/emergency_request.dart';
import 'package:flutter_disaster_app/admin_APP/viewModels/emergency_viewmodel.dart';

const Color _kBg       = Color(0xFFF5F7FA);
const Color _kCardBg   = Color(0xFFFFFFFF);
const Color _kBorder   = Color(0xFFE5E7EB);
const Color _kBlue     = Color(0xFF2563EB);
const Color _kGreen    = Color(0xFF16A34A);
const Color _kOrange   = Color(0xFFF59E0B);
const Color _kRed      = Color(0xFFDC2626);
const Color _kTextMain = Color(0xFF0F172A);
const Color _kTextSub  = Color(0xFF475569);

// ══════════════════════════════════════════════════════════
//  EMERGENCY PAGE
// ══════════════════════════════════════════════════════════
class EmergencyPage extends StatelessWidget {
  final bool initialFirestore;
  const EmergencyPage({super.key, this.initialFirestore = true});
  @override
  Widget build(BuildContext context) => ReportSourcePage(sosOnly: true, initialFirestore: initialFirestore,
      sqliteBuilder: (_) => const SqliteEmergencyPage());
}

class SqliteEmergencyPage extends StatefulWidget {
  const SqliteEmergencyPage({super.key});

  @override
  State<SqliteEmergencyPage> createState() => _EmergencyPageState();
}

class _EmergencyPageState extends State<SqliteEmergencyPage> {
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

  /// 確認後改狀態，並提示成功 / 失敗
  Future<void> _confirmStatus(
    EmergencyRequest e,
    EmergencyViewModel vm, {
    required String title,
    required String message,
    required String confirmText,
    required Color color,
    required Future<bool> Function() action,
    required String successText,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: .35),
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(title,
            style: const TextStyle(color: _kTextMain, fontSize: 17, fontWeight: FontWeight.w800)),
        content: Text(message, style: const TextStyle(color: _kTextMain, fontSize: 15)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消', style: TextStyle(color: _kTextSub, fontSize: 15)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(confirmText, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final ok = await action();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: ok ? _kGreen : _kRed,
      content: Text(ok ? successText : '更新失敗，請確認後端連線後再試一次',
          style: const TextStyle(fontWeight: FontWeight.w600)),
    ));
  }

  String _nameOf(EmergencyRequest e) => e.userName.isNotEmpty ? e.userName : e.userId;

  Future<void> _confirmProcessing(EmergencyRequest e, EmergencyViewModel vm) => _confirmStatus(
        e, vm,
        title: '開始處理',
        message: '將「${_nameOf(e)}」的求救事件改為「處理中」？',
        confirmText: '開始處理',
        color: _kBlue,
        action: () => vm.markProcessing(e),
        successText: '已改為處理中',
      );

  Future<void> _confirmHandle(EmergencyRequest e, EmergencyViewModel vm) => _confirmStatus(
        e, vm,
        title: '標記完成',
        message: '確定將「${_nameOf(e)}」的求救事件標記為已完成？此操作無法還原。',
        confirmText: '標記完成',
        color: _kGreen,
        action: () => vm.markHandled(e),
        successText: '已標記完成',
      );

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
    }).toList()
      // 未完成的排前面，同狀態依時間新到舊
      ..sort((a, b) {
        final ra = a.status == 'resolved' ? 1 : 0;
        final rb = b.status == 'resolved' ? 1 : 0;
        if (ra != rb) return ra.compareTo(rb);
        return b.sentAt.compareTo(a.sentAt);
      });

    return Container(
      color: _kBg,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(vm, pending),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 統計格同時是篩選（點一下就只看該狀態）
                  _buildStatsBar(all.length, pending, processing, resolved),
                  const SizedBox(height: 12),
                  _buildSearchBar(),
                  const SizedBox(height: 12),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                child: _buildList(vm, filtered),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(EmergencyViewModel vm, int pending) {
    return PageHeader(
      title: '緊急事件',
      subtitle: 'EMERGENCY MANAGEMENT',
      badges: [if (pending > 0) _tag('待處理 $pending 件', _kOrange)],
      actions: [
        PageHeaderButton(
            icon: Icons.refresh_rounded, tooltip: '重新整理', onPressed: vm.loadEmergencies),
      ],
    );
  }

  Widget _buildStatsBar(int total, int pending, int processing, int resolved) {
    return Container(
      decoration: BoxDecoration(
        color:        _kCardBg,
        borderRadius: BorderRadius.circular(12),
        border:       Border.all(color: _kBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(children: [
        _tapStatCell(Icons.list_alt_rounded,       '$total',      '全部',   _kBlue,   '全部'),
        _divider(),
        _tapStatCell(Icons.warning_amber_rounded,  '$pending',    '待處理', _kOrange, '待處理'),
        _divider(),
        _tapStatCell(Icons.sync_rounded,           '$processing', '處理中', _kBlue,   '處理中'),
        _divider(),
        _tapStatCell(Icons.check_circle_outline,   '$resolved',   '已完成', _kGreen,  '已完成'),
      ]),
    );
  }

  /// 統計格：選中時淡底色 + 底部色條（同災民管理）
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
            border: Border(bottom: BorderSide(color: sel ? color : Colors.transparent, width: 3)),
          ),
          child: Row(children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 10),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(val, style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.w800, height: 1.15)),
              Text(label, style: TextStyle(
                  color: sel ? _kTextMain : _kTextSub, fontSize: 14,
                  fontWeight: sel ? FontWeight.w700 : FontWeight.w500)),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _divider() => Container(width: 1, height: 32, color: _kBorder);

  Widget _buildSearchBar() {
    return Container(
      height: 46,
      decoration: BoxDecoration(
        color:        _kCardBg,
        borderRadius: BorderRadius.circular(12),
        border:       Border.all(color: _kBorder),
      ),
      child: TextField(
        controller: _searchCtrl,
        style: const TextStyle(color: _kTextMain, fontSize: 16),
        decoration: InputDecoration(
          hintText:        '搜尋姓名、ID 或電話…',
          hintStyle:       const TextStyle(color: _kTextSub, fontSize: 15),
          prefixIcon:      const Icon(Icons.search_rounded, color: _kTextSub, size: 20),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close_rounded, color: _kTextSub, size: 18),
                  onPressed: () => setState(() {
                    _searchCtrl.clear();
                    _searchQuery = '';
                  }),
                )
              : null,
          border:          InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 13),
        ),
        onChanged: (v) => setState(() => _searchQuery = v),
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
        action: Padding(
          padding: const EdgeInsets.only(top: 10),
          child: OutlinedButton.icon(
            onPressed: vm.loadEmergencies,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('重新載入'),
          ),
        ),
      );
    }
    if (vm.emergencies.isEmpty) return _placeholder(icon: Icons.inbox_outlined, iconColor: _kTextSub, title: '暫無緊急事件');

    return Container(
      decoration: BoxDecoration(
        color:        _kCardBg,
        borderRadius: BorderRadius.circular(14),
        border:       Border.all(color: _kBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: [
        Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          decoration: const BoxDecoration(
            color:  Color(0xFFF8FAFC),
            border: Border(bottom: BorderSide(color: _kBorder)),
          ),
          child: Row(children: [
            Text(_filter == '全部' ? '求救事件' : '求救事件・$_filter',
                style: const TextStyle(color: _kTextMain, fontSize: 16, fontWeight: FontWeight.w800)),
            const Spacer(),
            Text('共 ${filtered.length} 筆',
                style: const TextStyle(color: _kTextMain, fontSize: 14, fontWeight: FontWeight.w600)),
          ]),
        ),
        Expanded(
          child: filtered.isEmpty
              ? Center(child: Text(
                  _searchQuery.trim().isNotEmpty ? '找不到符合「${_searchQuery.trim()}」的事件' : '沒有「$_filter」的事件',
                  style: const TextStyle(color: _kTextSub, fontSize: 15)))
              : ListView.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  itemBuilder: (_, i) => _buildCard(filtered[i], vm),
                ),
        ),
      ]),
    );
  }

  // ══════════════════════════════════════════════════════════
  //  事件列（白底、狀態標籤、右側操作按鈕）
  // ══════════════════════════════════════════════════════════
  Widget _buildCard(EmergencyRequest e, EmergencyViewModel vm) {
    final isResolved   = e.status == 'resolved';
    final isProcessing = e.status == 'processing';
    final color = isResolved ? _kGreen : (isProcessing ? _kBlue : _kOrange);
    final statusLabel = isResolved ? '已完成' : (isProcessing ? '處理中' : '待處理');
    final displayName = e.userName.isNotEmpty ? e.userName : '用戶 ${e.userId}';
    final hasLocation = !(e.lat == 0 && e.lng == 0);
    final address = e.address?.isNotEmpty == true ? e.address! : '位置未提供';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(color: const Color(0xFFEFF4FF), borderRadius: BorderRadius.circular(10)),
          child: Center(child: Text(
            displayName.isNotEmpty ? displayName[0] : '?',
            style: const TextStyle(color: Color(0xFF1E3A5F), fontSize: 16, fontWeight: FontWeight.w700),
          )),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(child: Text(displayName,
                  style: TextStyle(
                      color: isResolved ? _kTextSub : _kTextMain,
                      fontSize: 16, fontWeight: FontWeight.w700),
                  overflow: TextOverflow.ellipsis, maxLines: 1)),
              const SizedBox(width: 8),
              Text(e.userId, style: const TextStyle(color: _kTextSub, fontSize: 14)),
              const SizedBox(width: 8),
              _tag(statusLabel, color),
              const SizedBox(width: 8),
              Text(_ago(e.sentAt), style: const TextStyle(color: _kTextSub, fontSize: 13)),
            ]),
            const SizedBox(height: 4),
            Text(
              [if (e.phone.isNotEmpty) e.phone, address].join('　'),
              style: const TextStyle(color: _kTextSub, fontSize: 14),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ]),
        ),
        const SizedBox(width: 12),
        // 操作：地圖 / 詳情 / 開始處理 / 標記完成
        if (hasLocation) ...[
          _outlineBtn('地圖', _kBlue, () => _openMap(e.lat, e.lng)),
          const SizedBox(width: 8),
        ],
        _outlineBtn('詳情', _kBlue, () => _showEmergencyDetail(e)),
        if (!isResolved && !isProcessing) ...[
          const SizedBox(width: 8),
          _outlineBtn('開始處理', _kBlue, () => _confirmProcessing(e, vm)),
        ],
        if (!isResolved) ...[
          const SizedBox(width: 8),
          _filledBtn('標記完成', _kGreen, () => _confirmHandle(e, vm)),
        ],
      ]),
    );
  }

  static String _ago(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return '剛剛';
    if (d.inMinutes < 60) return '${d.inMinutes} 分鐘前';
    if (d.inHours < 24) return '${d.inHours} 小時前';
    return '${d.inDays} 天前';
  }

  /// 白底外框按鈕（同用戶管理的「詳情」）
  static Widget _outlineBtn(String text, Color color, VoidCallback onTap) => InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: _kCardBg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: .4)),
          ),
          child: Text(text, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w700)),
        ),
      );

  /// 實心按鈕（主要動作）
  static Widget _filledBtn(String text, Color color, VoidCallback onTap) => InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
          child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
        ),
      );

  // ── 詳情 Dialog ─────────────────────────────────────────────
  void _showEmergencyDetail(EmergencyRequest e) {
    final isResolved   = e.status == 'resolved';
    final isProcessing = e.status == 'processing';
    final color       = isResolved ? _kGreen : (isProcessing ? _kBlue : _kOrange);
    final statusLabel = isResolved ? '已完成' : (isProcessing ? '處理中' : '待處理');

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: .35),
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: 480,
          constraints: const BoxConstraints(maxHeight: 540),
          decoration: BoxDecoration(
            color:        _kCardBg,
            borderRadius: BorderRadius.circular(16),
            border:       Border.all(color: _kBorder),
            boxShadow: [
              BoxShadow(
                color:      Colors.black.withValues(alpha: .10),
                blurRadius: 24,
                offset:     const Offset(0, 8),
              ),
            ],
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // ── 標題列 ──────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 12, 14),
              child: Row(children: [
                Container(
                  width: 42, height: 42,
                  decoration: BoxDecoration(
                      color:        color.withValues(alpha: .10),
                      borderRadius: BorderRadius.circular(11)),
                  child: Icon(
                      isResolved
                          ? Icons.check_circle_outline_rounded
                          : isProcessing
                              ? Icons.sync_rounded
                              : Icons.sos_rounded,
                      color: color, size: 22),
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
                        Text(statusLabel,
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
            // ── 詳情內容 ─────────────────────────────────
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(18),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  _emSection('基本資訊'),
                  _emRow('用戶 ID',  e.userId),
                  _emRow('姓名',
                      e.userName.isNotEmpty ? e.userName : '未填寫'),
                  _emRow('電話',
                      e.phone.isNotEmpty ? e.phone : '未填寫'),
                  _emRow('SOS 編號', e.emergencyId),
                  const SizedBox(height: 4),
                  _emSection('事件資訊'),
                  _emRow('狀態',   statusLabel),
                  _emRow('跳點數', '${e.hopCount}'),
                  _emRow('發送時間', _fmtTime(e.sentAt)),
                  if (e.receivedAt != null)
                    _emRow('接收時間', _fmtTime(e.receivedAt!)),
                  const SizedBox(height: 4),
                  _emSection('位置資訊'),
                  _emRow('地址',
                      e.address?.isNotEmpty == true
                          ? e.address!
                          : '未提供'),
                  if (e.lat != 0 && e.lng != 0)
                    _emRow('座標',
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
                            color:        _kBlue.withValues(alpha: .06),
                            borderRadius: BorderRadius.circular(8),
                            border:       Border.all(
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

  static Widget _emRow(String label, String value) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color:        const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border:       Border.all(color: _kBorder),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: 78,
          child: Text(label,
              style: const TextStyle(
                  color: _kTextSub, fontSize: 13, fontWeight: FontWeight.w500)),
        ),
        Expanded(
          child: Text(value.isEmpty ? '未填寫' : value,
              style: const TextStyle(
                  color: _kTextMain, fontSize: 14, fontWeight: FontWeight.w600)),
        ),
      ]),
    );
  }

  static Widget _emSection(String label) {
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
                color: _kTextMain,
                fontSize: 14,
                fontWeight: FontWeight.w700)),
      ]),
    );
  }

  static String _fmtTime(DateTime t) =>
      '${t.year}/${t.month.toString().padLeft(2, '0')}/'
      '${t.day.toString().padLeft(2, '0')} '
      '${t.hour.toString().padLeft(2, '0')}:'
      '${t.minute.toString().padLeft(2, '0')}';

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
              color: (iconColor ?? _kBlue).withValues(alpha:.08), shape: BoxShape.circle),
          child: Icon(icon, color: iconColor ?? _kBlue, size: 20),
        ),
        const SizedBox(height: 10),
        Text(title ?? '',
            style: const TextStyle(color: _kTextMain, fontSize: 14, fontWeight: FontWeight.w600)),
        if (subtitle != null) ...[
          const SizedBox(height: 3),
          Text(subtitle, style: const TextStyle(color: _kTextSub, fontSize: 13)),
        ],
        if (action != null) action,
      ]),
    );
  }

  static Widget _tag(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
        color:        color.withValues(alpha:.08),
        borderRadius: BorderRadius.circular(999),
        border:       Border.all(color: color.withValues(alpha:.18))),
    child: Text(text, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
  );
}
