import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:flutter_disaster_app/core/models/supply_request.dart';
import '../viewModels/volunteer_viewmodel.dart';

/// 義工配送任務頁（手機版 Responsive Web，樣式沿用管理端模板）
/// Demo：固定 V001 / A收容中心
/// 正式版：掃收容中心 QR Code → 帶 stationId 進來
class VolunteerPage extends StatelessWidget {
  final String volunteerId;
  final String stationName;

  const VolunteerPage({
    super.key,
    this.volunteerId = 'V001',
    this.stationName = 'A收容中心',
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => VolunteerViewModel(
        volunteerId: volunteerId,
        stationName: stationName,
      ),
      child: const _VolunteerView(),
    );
  }
}

// ── 與管理端相同的配色 ──────────────────────────────────────
const Color _kBg       = Color(0xFFF5F7FA);
const Color _kCardBg   = Color(0xFFFFFFFF);
const Color _kBorder   = Color(0xFFE5E7EB);
const Color _kBlue     = Color(0xFF2563EB);
const Color _kGreen    = Color(0xFF16A34A);
const Color _kOrange   = Color(0xFFF59E0B);
const Color _kRed      = Color(0xFFDC2626);
const Color _kTextMain = Color(0xFF0F172A);
const Color _kTextSub  = Color(0xFF475569);
const Color _kSidebarBg      = Color(0xFF1E3A5F);
const Color _kSidebarTextSub = Color(0xFFB4CDE6);

class _VolunteerView extends StatelessWidget {
  const _VolunteerView();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<VolunteerViewModel>();

    return Scaffold(
      backgroundColor: const Color(0xFFE9EDF3),
      body: Center(
        // 電腦瀏覽器上維持手機寬度並置中
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Container(
            color: _kBg,
            child: SafeArea(
              child: DefaultTabController(
                length: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _brandBar(context, vm),
                    _header(context, vm),
                    const SizedBox(height: 12),
                    _infoBar(vm),
                    const SizedBox(height: 12),
                    _tabBar(vm),
                    const SizedBox(height: 12),
                    Expanded(
                      child: TabBarView(children: [
                        _TaskList(
                          requests: vm.requests,
                          emptyText: '目前沒有待認領的物資需求',
                        ),
                        _TaskList(
                          requests: vm.myClaimed,
                          emptyText: '尚未認領任何任務',
                        ),
                      ]),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Header：標題 + 英文副標 + 標籤（同管理端）────────────────
  // ── 深藍 Logo 列（同指揮中心側邊欄）────────────────────────
  Widget _brandBar(BuildContext context, VolunteerViewModel vm) {
    return Container(
      color: _kSidebarBg,
      padding: const EdgeInsets.fromLTRB(4, 10, 10, 10),
      child: Row(children: [
        if (Navigator.of(context).canPop())
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                size: 18, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          )
        else
          const SizedBox(width: 12),
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .15),
              borderRadius: BorderRadius.circular(10)),
          child: const Icon(Icons.shield_outlined,
              color: Colors.white, size: 19),
        ),
        const SizedBox(width: 10),
        const Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('災難管理系統',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800)),
            Text('VOLUNTEER',
                style: TextStyle(
                    color: _kSidebarTextSub,
                    fontSize: 12,
                    letterSpacing: 1.1)),
          ]),
        ),
        IconButton(
          tooltip: '重新整理',
          icon: const Icon(Icons.refresh_rounded, color: Colors.white),
          onPressed: vm.isLoading ? null : vm.loadPendingRequests,
        ),
      ]),
    );
  }

  // ── 頁面標題（同指揮中心：中文大標 + 英文副標）──────────────
  Widget _header(BuildContext context, VolunteerViewModel vm) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${vm.stationName}－義工配送任務',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: _kTextMain,
                    fontSize: 20,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Row(children: [
              const Text('VOLUNTEER DELIVERY TASKS',
                  style: TextStyle(
                      color: _kTextSub, fontSize: 12, letterSpacing: 1.3)),
              const SizedBox(width: 8),
              _tag('即時同步', _kGreen),
            ]),
          ]),
        ),
      ]),
    );
  }

  // ── 據點 / 義工資訊 + 統計 ───────────────────────────────────
  Widget _infoBar(VolunteerViewModel vm) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: _kCardBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _kBorder),
        ),
        child: Row(children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _kBlue.withValues(alpha: .08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.home_work_outlined,
                color: _kBlue, size: 19),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(vm.stationName,
                      style: const TextStyle(
                          color: _kTextMain,
                          fontSize: 15,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text('義工 ${vm.volunteerId}',
                      style: const TextStyle(
                          color: _kTextSub, fontSize: 13)),
                ]),
          ),
          _stat('${vm.requests.length}', '待認領', _kOrange),
          Container(
              width: 1,
              height: 28,
              color: _kBorder,
              margin: const EdgeInsets.symmetric(horizontal: 12)),
          _stat('${vm.myClaimed.length}', '已認領', _kGreen),
        ]),
      ),
    );
  }

  Widget _stat(String value, String label, Color color) {
    return Column(children: [
      Text(value,
          style: TextStyle(
              color: color, fontSize: 18, fontWeight: FontWeight.w800)),
      Text(label, style: const TextStyle(color: _kTextSub, fontSize: 12)),
    ]);
  }

  // ── Tab Bar（同管理端）──────────────────────────────────────
  Widget _tabBar(VolunteerViewModel vm) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color: _kCardBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _kBorder),
        ),
        child: TabBar(
          indicator: BoxDecoration(
            color: _kBlue.withValues(alpha: .08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _kBlue.withValues(alpha: .25)),
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: Colors.transparent,
          labelColor: _kBlue,
          unselectedLabelColor: _kTextSub,
          labelStyle:
              const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          unselectedLabelStyle:
              const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          tabs: [
            Tab(text: '待認領 (${vm.requests.length})'),
            Tab(text: '我已認領 (${vm.myClaimed.length})'),
          ],
        ),
      ),
    );
  }
}

// ── 任務列表：白色卡片內的精簡列 ─────────────────────────────
class _TaskList extends StatelessWidget {
  final List<SupplyRequest> requests;
  final String emptyText;
  const _TaskList({required this.requests, required this.emptyText});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<VolunteerViewModel>();

    if (vm.isLoading && requests.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: vm.loadPendingRequests,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          if (vm.errorMessage != null)
            _errorBanner(vm.errorMessage!, vm.loadPendingRequests),
          Container(
            decoration: BoxDecoration(
              color: _kCardBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _kBorder),
            ),
            clipBehavior: Clip.antiAlias,
            child: requests.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 36),
                    child: Center(
                      child: Text(emptyText,
                          style: const TextStyle(
                              color: _kTextSub, fontSize: 14)),
                    ),
                  )
                : Column(children: [
                    for (var i = 0; i < requests.length; i++) ...[
                      if (i > 0)
                        const Divider(height: 1, color: _kBorder),
                      _TaskRow(request: requests[i]),
                    ],
                  ]),
          ),
        ],
      ),
    );
  }

  Widget _errorBanner(String msg, VoidCallback onRetry) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      decoration: BoxDecoration(
        color: _kRed.withValues(alpha: .06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kRed.withValues(alpha: .2)),
      ),
      child: Row(children: [
        const Icon(Icons.wifi_off_rounded, size: 16, color: _kRed),
        const SizedBox(width: 8),
        Expanded(
            child: Text(msg,
                style: const TextStyle(color: _kRed, fontSize: 13))),
        TextButton(onPressed: onRetry, child: const Text('重試')),
      ]),
    );
  }
}

class _TaskRow extends StatelessWidget {
  final SupplyRequest request;
  const _TaskRow({required this.request});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<VolunteerViewModel>();
    final claimed = request.isClaimed;
    final color = claimed ? _kGreen : _kOrange;
    final isClaiming = vm.claimingId == request.requestId;
    final location = request.address.isNotEmpty
        ? request.address
        : (request.lat != null
            ? '${request.lat!.toStringAsFixed(4)}, ${request.lng!.toStringAsFixed(4)}'
            : '未提供地址');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: color.withValues(alpha: .08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
              claimed
                  ? Icons.local_shipping_outlined
                  : Icons.inventory_2_outlined,
              color: color,
              size: 19),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Flexible(
                  child: Text(
                    '${request.itemName} × ${request.qty} ${request.unit}',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: _kTextMain,
                        fontSize: 15,
                        fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 6),
                _tag(request.statusLabel, color),
              ]),
              const SizedBox(height: 3),
              Row(children: [
                Text(request.requestId,
                    style: const TextStyle(
                        color: _kTextSub,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 5),
                  child: Text('·',
                      style: TextStyle(color: _kTextSub, fontSize: 13)),
                ),
                const Icon(Icons.location_on_outlined,
                    size: 12, color: _kTextSub),
                const SizedBox(width: 2),
                Expanded(
                  child: Text(location,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: _kTextSub, fontSize: 13)),
                ),
              ]),
            ],
          ),
        ),
        const SizedBox(width: 8),
        if (claimed)
          const Icon(Icons.check_circle_rounded, color: _kGreen, size: 22)
        else
          SizedBox(
            height: 34,
            child: ElevatedButton(
              onPressed: vm.claimingId != null
                  ? null
                  : () => _confirmClaim(context, vm),
              style: ElevatedButton.styleFrom(
                elevation: 0,
                backgroundColor: _kBlue,
                foregroundColor: Colors.white,
                disabledBackgroundColor: _kBlue.withValues(alpha: .35),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: isClaiming
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Text('認領配送',
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700)),
            ),
          ),
      ]),
    );
  }

  Future<void> _confirmClaim(
      BuildContext context, VolunteerViewModel vm) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _kCardBg,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('確認認領配送',
            style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: _kTextMain)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${request.itemName} × ${request.qty} ${request.unit}',
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: _kTextMain)),
            const SizedBox(height: 6),
            Text('${request.requestId}　${request.address}',
                style: const TextStyle(fontSize: 13, color: _kTextSub)),
            const SizedBox(height: 12),
            const Text('認領後請負責將物資送達需求地點。',
                style: TextStyle(fontSize: 14, color: _kTextMain)),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消',
                  style: TextStyle(color: _kTextSub))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                elevation: 0,
                backgroundColor: _kBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8))),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('確認認領'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    final result = await vm.claim(request);
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: result.success ? _kGreen : _kRed,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      content: Text(
        result.success
            ? '認領成功：${request.requestId}，可在「我已認領」查看'
            : '⚠️ 此需求已被認領或無法認領'
                '${result.message.isNotEmpty ? '（${result.message}）' : ''}',
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ));
  }
}

// ── 共用小元件（同管理端 _tag 樣式）──────────────────────────
Widget _tag(String text, Color color) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
          color: color.withValues(alpha: .08),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: .18))),
      child: Text(text,
          style: TextStyle(
              color: color, fontSize: 12, fontWeight: FontWeight.w700)),
    );
