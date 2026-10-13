import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:url_launcher/url_launcher.dart';

import 'package:flutter_disaster_app/core/models/supply_request.dart';
import '../viewModels/volunteer_viewmodel.dart';

/// 義工配送頁（手機版 Responsive Web）
/// 只有兩區：
///  ① 待認領任務：S001 的 reserved 任務 →「認領任務」
///  ② 我的配送：V001 的任務
///     claimed   →「取消認領」「確認取貨」
///     dispatched →「配送完成」
/// Demo：固定 V001 / S001（A收容中心）；正式版改成登入或掃 QR Code 帶入
class VolunteerPage extends StatelessWidget {
  final String volunteerId;
  final String stationId;
  final String stationName;

  const VolunteerPage({
    super.key,
    this.volunteerId = 'V001',
    this.stationId = 'S001',
    this.stationName = 'A收容中心',
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => VolunteerViewModel(
        volunteerId: volunteerId,
        stationId: stationId,
        stationName: stationName,
      ),
      child: const _VolunteerView(),
    );
  }
}

// ── 配色（與管理端一致）────────────────────────────────────
const Color _kBg       = Color(0xFFF5F7FA);
const Color _kCardBg   = Color(0xFFFFFFFF);
const Color _kBorder   = Color(0xFFE5E7EB);
const Color _kNavy     = Color(0xFF1E3A5F);
const Color _kNavySub  = Color(0xFFB4CDE6);
const Color _kBlue     = Color(0xFF2563EB);
const Color _kBlueSoft = Color(0xFFEFF4FF);
const Color _kGreen    = Color(0xFF15803D);
const Color _kAmber    = Color(0xFFB45309);
const Color _kRed      = Color(0xFFDC2626);
const Color _kTextMain = Color(0xFF0F172A);
const Color _kTextSub  = Color(0xFF475569);
const Color _kTextMute = Color(0xFF64748B);

// ══════════════════════════════════════════════════════════
//  外框：手機寬度置中，上方深藍列 + 兩個分頁
// ══════════════════════════════════════════════════════════
class _VolunteerView extends StatelessWidget {
  const _VolunteerView();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<VolunteerViewModel>();

    return Scaffold(
      backgroundColor: const Color(0xFFE9EDF3),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Container(
            color: _kBg,
            child: DefaultTabController(
              length: 2,
              // 有進行中的配送時，預設打開「我的配送」
              initialIndex: vm.activeCount > 0 ? 1 : 0,
              child: Column(children: [
                _TopBar(vm: vm),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: _MainTabs(vm: vm),
                ),
                if (vm.errorMessage != null) _errorBanner(vm),
                const Expanded(
                  child: TabBarView(children: [
                    _PendingTab(),
                    _MyTasksTab(),
                  ]),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _errorBanner(VolunteerViewModel vm) => Container(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
        decoration: BoxDecoration(
          color: _kRed.withValues(alpha: .06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _kRed.withValues(alpha: .2)),
        ),
        child: Row(children: [
          const Icon(Icons.wifi_off_rounded, size: 16, color: _kRed),
          const SizedBox(width: 8),
          Expanded(child: Text(vm.errorMessage!, style: const TextStyle(color: _kRed, fontSize: 13))),
          TextButton(onPressed: vm.loadAll, child: const Text('重試')),
        ]),
      );
}

/// 深藍頂部列
class _TopBar extends StatelessWidget {
  final VolunteerViewModel vm;
  const _TopBar({required this.vm});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _kNavy,
      padding: EdgeInsets.fromLTRB(4, MediaQuery.of(context).padding.top + 6, 4, 6),
      child: Row(children: [
        if (Navigator.of(context).canPop())
          IconButton(
            tooltip: '返回',
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          )
        else
          const SizedBox(width: 16),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(vm.stationName,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800)),
            Text('義工 ${vm.volunteerId}・據點 ${vm.stationId}',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: _kNavySub, fontSize: 12)),
          ]),
        ),
        IconButton(
          tooltip: '重新整理',
          onPressed: vm.isLoading ? null : vm.loadAll,
          icon: vm.isLoading
              ? const SizedBox(
                  width: 18, height: 18,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Icon(Icons.refresh_rounded, color: Colors.white),
        ),
      ]),
    );
  }
}

/// 兩個分頁：待認領任務 / 我的配送
class _MainTabs extends StatelessWidget {
  final VolunteerViewModel vm;
  const _MainTabs({required this.vm});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFE8EDF5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TabBar(
        indicator: BoxDecoration(
          color: _kCardBg,
          borderRadius: BorderRadius.circular(9),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: .06), blurRadius: 6, offset: const Offset(0, 2)),
          ],
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: _kBlue,
        unselectedLabelColor: _kTextSub,
        labelPadding: EdgeInsets.zero,
        labelStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        unselectedLabelStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
        tabs: [
          Tab(text: '待認領任務 ${vm.pending.length}'),
          Tab(text: '我的配送 ${vm.activeCount}'),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  ① 待認領任務
// ══════════════════════════════════════════════════════════
class _PendingTab extends StatelessWidget {
  const _PendingTab();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<VolunteerViewModel>();
    final list = vm.pending;

    if (vm.isLoading && list.isEmpty && vm.myTasks.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: _kBlue));
    }

    return RefreshIndicator(
      color: _kBlue,
      onRefresh: vm.loadAll,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          if (list.isEmpty)
            const _EmptyBox(
              icon: Icons.inventory_2_outlined,
              title: '目前沒有待認領的任務',
              text: '系統分配到本收容中心並預留庫存後，任務會出現在這裡',
            )
          else ...[
            _hint('系統已預留物資，按「認領任務」由你負責配送'),
            for (final r in list) _PendingCard(request: r),
          ],
        ],
      ),
    );
  }
}

class _PendingCard extends StatelessWidget {
  final SupplyRequest request;
  const _PendingCard({required this.request});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<VolunteerViewModel>();
    final r = request;
    final busy = vm.busyId == r.requestId;

    return _card(
      child: Row(children: [
        Expanded(child: _requestInfo(context, r)),
        const SizedBox(width: 10),
        SizedBox(
          height: 44,
          child: ElevatedButton(
            onPressed: vm.busyId != null ? null : () => _confirmClaim(context, vm, r),
            style: _btnStyle(_kBlue),
            child: busy
                ? _spinner()
                : const Text('認領任務', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          ),
        ),
      ]),
    );
  }

  Future<void> _confirmClaim(BuildContext context, VolunteerViewModel vm, SupplyRequest r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _kCardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('認領這筆任務？',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _kTextMain)),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${r.itemName} × ${r.qty} ${r.unit}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _kTextMain)),
          const SizedBox(height: 4),
          Text('送往 ${_addressOf(r)}', style: const TextStyle(fontSize: 13, color: _kTextSub)),
          if (r.hasLocation) ...[
            const SizedBox(height: 10),
            SizedBox(width: double.maxFinite, child: _RequestMap(request: r, height: 140)),
          ],
          const SizedBox(height: 10),
          const Text('認領後請到本收容中心物資區取貨，再送到需求者手上。',
              style: TextStyle(fontSize: 14, color: _kTextMain)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('返回', style: TextStyle(color: _kTextSub))),
          ElevatedButton(
            style: _btnStyle(_kBlue),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('認領任務'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    final res = await vm.claim(r);
    if (!context.mounted) return;
    _snack(context, res.success,
        res.success ? '認領成功，已加入「我的配送」' : '⚠️ 無法認領${res.message.isNotEmpty ? '（${res.message}）' : ''}');
    // 認領成功後切到「我的配送」
    if (res.success) DefaultTabController.of(context).animateTo(1);
  }
}

// ══════════════════════════════════════════════════════════
//  ② 我的配送
// ══════════════════════════════════════════════════════════
class _MyTasksTab extends StatelessWidget {
  const _MyTasksTab();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<VolunteerViewModel>();
    final active = vm.myTasks.where((r) => r.isClaimed || r.isDelivering).toList();
    final done = vm.myTasks.where((r) => r.isDone).toList();

    return RefreshIndicator(
      color: _kBlue,
      onRefresh: vm.loadAll,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          if (active.isEmpty)
            const _EmptyBox(
              icon: Icons.local_shipping_outlined,
              title: '目前沒有進行中的配送',
              text: '在「待認領任務」按下認領後會出現在這裡',
            )
          else
            for (final r in active) _MyTaskCard(request: r),
          if (done.isNotEmpty) ...[
            const SizedBox(height: 14),
            _hint('已完成（${done.length}）'),
            for (final r in done) _MyTaskCard(request: r),
          ],
        ],
      ),
    );
  }
}

class _MyTaskCard extends StatelessWidget {
  final SupplyRequest request;
  const _MyTaskCard({required this.request});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<VolunteerViewModel>();
    final r = request;
    final busy = vm.busyId == r.requestId;
    final locked = vm.busyId != null;

    final (label, color) = switch (r.status) {
      'claimed'    => ('已認領・待取貨', _kGreen),
      'dispatched' => ('配送中', _kAmber),
      'completed'  => ('已完成', _kTextMute),
      _            => (r.statusLabel, _kTextMute),
    };

    return _card(
      faded: r.isDone,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: _requestInfo(context, r)),
          const SizedBox(width: 8),
          _tag(label, color),
        ]),
        // claimed：取消認領 / 確認取貨
        if (r.isClaimed) ...[
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: SizedBox(
                height: 44,
                child: OutlinedButton(
                  onPressed: locked
                      ? null
                      : () => _confirmAction(
                            context,
                            title: '取消認領',
                            message: '取消「${r.itemName} × ${r.qty} ${r.unit}」？\n取消後任務會回到「待認領任務」。',
                            confirmText: '確認取消',
                            color: _kRed,
                            action: () => vm.cancelClaim(r),
                            successText: '已取消認領',
                          ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _kRed,
                    side: BorderSide(color: _kRed.withValues(alpha: .4)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('取消認領', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SizedBox(
                height: 44,
                child: ElevatedButton(
                  onPressed: locked
                      ? null
                      : () => _confirmAction(
                            context,
                            title: '確認取貨',
                            message: '確認已在物資區拿到「${r.itemName} × ${r.qty} ${r.unit}」？\n確認後會從庫存扣除。',
                            confirmText: '確認取貨',
                            color: _kGreen,
                            action: () => vm.pickup(r),
                            successText: '已取貨，請出發配送',
                          ),
                  style: _btnStyle(_kGreen),
                  child: busy
                      ? _spinner()
                      : const Text('確認取貨', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                ),
              ),
            ),
          ]),
        ],
        // dispatched：導航 / 配送完成
        if (r.isDelivering) ...[
          const SizedBox(height: 12),
          Row(children: [
            if (r.hasLocation) ...[
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: OutlinedButton.icon(
                    onPressed: () => _openNavigation(r),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _kBlue,
                      side: BorderSide(color: _kBlue.withValues(alpha: .4)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.navigation_rounded, size: 16),
                    label: const Text('導航', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: SizedBox(
                height: 44,
                child: ElevatedButton(
                  onPressed: locked
                      ? null
                      : () => _confirmAction(
                            context,
                            title: '配送完成',
                            message: '確認已將「${r.itemName} × ${r.qty} ${r.unit}」交到需求者手上？',
                            confirmText: '確認完成',
                            color: _kAmber,
                            action: () => vm.complete(r),
                            successText: '配送完成，辛苦了！',
                          ),
                  style: _btnStyle(_kAmber),
                  child: busy
                      ? _spinner()
                      : const Text('配送完成', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                ),
              ),
            ),
          ]),
        ],
      ]),
    );
  }
}

// ── 卡片共用 ─────────────────────────────────────────────
Widget _card({required Widget child, bool faded = false}) => Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      decoration: BoxDecoration(
        color: faded ? const Color(0xFFF8FAFC) : _kCardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBorder),
      ),
      child: child,
    );

/// 物資名稱、送往地點（可點開地圖）、單號
Widget _requestInfo(BuildContext context, SupplyRequest r) =>
    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('${r.itemName} × ${r.qty} ${r.unit}',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _kTextMain)),
      const SizedBox(height: 3),
      InkWell(
        onTap: r.hasLocation ? () => _showMapSheet(context, r) : null,
        child: Row(children: [
          const Icon(Icons.location_on_outlined, size: 15, color: _kTextSub),
          const SizedBox(width: 3),
          Flexible(
            child: Text('送往 ${_addressOf(r)}',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, color: _kTextSub)),
          ),
          if (r.hasLocation)
            const Text('  地圖 ›', style: TextStyle(fontSize: 13, color: _kBlue, fontWeight: FontWeight.w700)),
        ]),
      ),
      const SizedBox(height: 2),
      Text(
          r.claimedAt != null
              ? '${r.requestId}・${_ago(r.claimedAt!)}認領'
              : r.createdAt != null
                  ? '${r.requestId}・${_ago(r.createdAt!)}建立'
                  : r.requestId,
          style: const TextStyle(fontSize: 12, color: _kTextMute)),
    ]);

Widget _hint(String text) => Padding(
      padding: const EdgeInsets.only(bottom: 10, left: 2, top: 4),
      child: Text(text, style: const TextStyle(fontSize: 13, color: _kTextSub)),
    );

ButtonStyle _btnStyle(Color color) => ElevatedButton.styleFrom(
      elevation: 0,
      backgroundColor: color,
      foregroundColor: Colors.white,
      disabledBackgroundColor: color.withValues(alpha: .35),
      disabledForegroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );

Widget _spinner() => const SizedBox(
    width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2));

// ══════════════════════════════════════════════════════════
//  需求位置地圖（國土測繪中心圖資，紅色地標）
// ══════════════════════════════════════════════════════════
class _RequestMap extends StatelessWidget {
  final SupplyRequest request;
  final double height;
  final bool interactive;
  const _RequestMap({required this.request, this.height = 150, this.interactive = false});

  @override
  Widget build(BuildContext context) {
    final point = ll.LatLng(request.lat!, request.lng!);
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: height,
        decoration: BoxDecoration(
          border: Border.all(color: _kBorder),
          borderRadius: BorderRadius.circular(12),
        ),
        child: FlutterMap(
          options: MapOptions(
            initialCenter: point,
            initialZoom: 16,
            minZoom: 12,
            maxZoom: 18,
            interactionOptions: InteractionOptions(
              flags: interactive ? InteractiveFlag.all & ~InteractiveFlag.rotate : InteractiveFlag.none,
            ),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://wmts.nlsc.gov.tw/wmts/EMAP/default/GoogleMapsCompatible/{z}/{y}/{x}',
              userAgentPackageName: 'com.example.flutter_disaster_app',
              maxNativeZoom: 16,
              maxZoom: 18,
            ),
            MarkerLayer(markers: [
              Marker(
                point: point,
                width: 44, height: 44,
                alignment: Alignment.topCenter,
                child: const Icon(Icons.location_on_rounded, color: _kRed, size: 44),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  共用
// ══════════════════════════════════════════════════════════

/// 需求地址：有文字地址用地址，否則用座標
String _addressOf(SupplyRequest r) {
  if (r.address.isNotEmpty) return r.address;
  if (r.hasLocation) return '${r.lat!.toStringAsFixed(4)}, ${r.lng!.toStringAsFixed(4)}';
  return '需求地點（未提供）';
}

String _ago(DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return '剛剛';
  if (d.inMinutes < 60) return '${d.inMinutes} 分鐘前';
  if (d.inHours < 24) return '${d.inHours} 小時前';
  return '${d.inDays} 天前';
}

/// 開啟 Google 地圖導航到需求位置
Future<void> _openNavigation(SupplyRequest r) async {
  final uri = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${r.lat},${r.lng}');
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

/// 底部彈出地圖：顯示需求位置
void _showMapSheet(BuildContext context, SupplyRequest r) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: _kCardBg,
    constraints: const BoxConstraints(maxWidth: 480),
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: _kBorder, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 12),
          Row(children: [
            const Icon(Icons.location_on_rounded, color: _kRed, size: 22),
            const SizedBox(width: 6),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${r.itemName} × ${r.qty} ${r.unit}',
                    style: const TextStyle(color: _kTextMain, fontSize: 17, fontWeight: FontWeight.w800)),
                Text(_addressOf(r), style: const TextStyle(color: _kTextSub, fontSize: 14)),
              ]),
            ),
          ]),
          const SizedBox(height: 12),
          _RequestMap(request: r, height: 300, interactive: true),
        ]),
      ),
    ),
  );
}

/// 空狀態（含最後更新時間：實際向後端取得資料的時間）
class _EmptyBox extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;
  const _EmptyBox({required this.icon, required this.title, required this.text});

  @override
  Widget build(BuildContext context) {
    final t = context.watch<VolunteerViewModel>().lastUpdated;
    String? updated;
    if (t != null) {
      final d = DateTime.now().difference(t);
      updated = d.inSeconds < 5
          ? '剛剛更新'
          : d.inMinutes < 1
              ? '${d.inSeconds} 秒前更新'
              : '${d.inMinutes} 分鐘前更新';
    }
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kBorder),
      ),
      child: Column(children: [
        Container(
          width: 64, height: 64,
          decoration: const BoxDecoration(color: _kBlueSoft, shape: BoxShape.circle),
          child: Icon(icon, color: _kBlue, size: 30),
        ),
        const SizedBox(height: 12),
        Text(title,
            textAlign: TextAlign.center,
            style: const TextStyle(color: _kTextMain, fontSize: 16, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(text, textAlign: TextAlign.center, style: const TextStyle(color: _kTextSub, fontSize: 13)),
        if (updated != null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(999)),
            child: Text('$updated・每 15 秒自動更新', style: const TextStyle(color: _kTextMute, fontSize: 12)),
          ),
        ],
      ]),
    );
  }
}

/// 共用確認視窗 → 執行動作 → 顯示後端結果
Future<void> _confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmText,
  required Color color,
  required Future<({bool success, String message})> Function() action,
  required String successText,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: _kCardBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _kTextMain)),
      content: Text(message, style: const TextStyle(fontSize: 14, color: _kTextMain)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('返回', style: TextStyle(color: _kTextSub))),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
              elevation: 0, backgroundColor: color, foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmText),
        ),
      ],
    ),
  );
  if (ok != true) return;

  final result = await action();
  if (!context.mounted) return;
  _snack(context, result.success,
      result.success ? successText : '⚠️ 操作失敗${result.message.isNotEmpty ? '：${result.message}' : ''}');
}

void _snack(BuildContext context, bool success, String text) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    behavior: SnackBarBehavior.floating,
    backgroundColor: success ? _kGreen : _kRed,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    content: Text(text, style: const TextStyle(fontWeight: FontWeight.w600)),
  ));
}

Widget _tag(String text, Color color) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
          color: color.withValues(alpha: .08),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: .18))),
      child: Text(text, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
    );
