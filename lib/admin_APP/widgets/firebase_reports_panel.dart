import 'dashboard_firestore_sos.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../core/models/firebase_report.dart';
import '../../core/repositories/firebase_reports_repository.dart';
import '../services/firebase_reports_client.dart';
import '../viewModels/firebase_reports_view_model.dart';
import '../screens/full_map_page.dart';
import 'page_header.dart';

/// Explicit source selection. Legacy widgets are mounted only on user choice.
class ReportSourcePage extends StatefulWidget {
  final bool initialFirestore;
  final bool sosOnly;
  final WidgetBuilder sqliteBuilder;
  final FirebaseReportsRepository Function()? repositoryFactory;
  const ReportSourcePage(
      {super.key,
      required this.sosOnly,
      required this.sqliteBuilder,
      this.initialFirestore = true,
      this.repositoryFactory});
  @override
  State<ReportSourcePage> createState() => _ReportSourcePageState();
}

class _ReportSourcePageState extends State<ReportSourcePage> {
  late bool _firestore = widget.initialFirestore;
  @override
  Widget build(BuildContext context) => Column(children: [
        Container(
            color: const Color(0xFFEFF6FF),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Wrap(
                spacing: 16,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Text('回報來源',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  DropdownButton<bool>(
                      value: _firestore,
                      items: const [
                        DropdownMenuItem(
                            value: true, child: Text('Firestore 居民回報（唯讀）')),
                        DropdownMenuItem(
                            value: false, child: Text('SQLite 原有回報')),
                      ],
                      onChanged: (value) {
                        if (value != null) setState(() => _firestore = value);
                      }),
                  const Text('指揮中心支援來源切換；災民總地圖仍使用 SQLite',
                      style: TextStyle(fontSize: 12)),
                ])),
        Expanded(
            child: _firestore
                ? FirebaseReportsPanel(
                    key: ValueKey('firestore-${widget.sosOnly}'),
                    sosOnly: widget.sosOnly,
                    repositoryFactory: widget.repositoryFactory)
                : KeyedSubtree(
                    key: const ValueKey('sqlite'),
                    child: widget.sqliteBuilder(context))),
      ]);
}

class FirebaseReportsPanel extends StatefulWidget {
  final bool sosOnly;
  final FirebaseReportsRepository Function()? repositoryFactory;
  final Duration refreshInterval;
  const FirebaseReportsPanel(
      {super.key,
      required this.sosOnly,
      this.repositoryFactory,
      this.refreshInterval = const Duration(seconds: 30)});
  @override
  State<FirebaseReportsPanel> createState() => _FirebaseReportsPanelState();
}

class _FirebaseReportsPanelState extends State<FirebaseReportsPanel>
    with WidgetsBindingObserver {
  late final FirebaseReportsViewModel _vm;
  Timer? _timer;
  bool _ownsModel = true;
  bool _foreground = true;
  String _search = '';
  String _status = '全部';
  int _page = 0;
  final _searchController = TextEditingController();
  static const _blue = Color(0xFF2563EB);
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _foreground = WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    final shared = widget.sosOnly
        ? context.getInheritedWidgetOfExactType<FirebaseSosScope>()?.model
        : null;
    _ownsModel = shared == null;
    _vm = shared ??
        FirebaseReportsViewModel(
            widget.repositoryFactory?.call() ??
                FirebaseReportsRepository(FirebaseReportsClient(http.Client())),
            sosOnly: widget.sosOnly);
    _vm.addListener(_changed);
    if (!_vm.hasLoaded && !_vm.loading) unawaited(_vm.refresh());
    if (_ownsModel && widget.refreshInterval > Duration.zero) {
      _timer = Timer.periodic(widget.refreshInterval, (_) {
        if (mounted && _foreground) {
          unawaited(_vm.refresh());
        }
      });
    }
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _vm.removeListener(_changed);
    if (_ownsModel) _vm.dispose();
    _searchController.dispose();
    super.dispose();
  }

  String _time(DateTime? time) =>
      time == null ? '回報時間未知' : time.toLocal().toString().split('.').first;
  String _short(String id) => id.length <= 12
      ? id
      : '${id.substring(0, 6)}…${id.substring(id.length - 4)}';
  Color _color(String? status) => switch (status) {
        '重傷' => Colors.red.shade700,
        '輕傷' => Colors.orange.shade800,
        '安全' => Colors.green.shade700,
        _ => _blue
      };

  @override
  Widget build(BuildContext context) {
    final q = _search.trim().toLowerCase();
    final filtered = _vm.reports
        .where((r) =>
            (_status == '全部' || r.status == _status) &&
            (q.isEmpty ||
                (r.name ?? '').toLowerCase().contains(q) ||
                r.uid.toLowerCase().contains(q)))
        .toList();
    final pageCount = math.max(1, (filtered.length / 10).ceil());
    final index = math.min(_page, pageCount - 1);
    final visible = filtered.skip(index * 10).take(10).toList();
    return ColoredBox(
        color: const Color(0xFFF5F7FA),
        child: Column(children: [
          PageHeader(
              title: widget.sosOnly ? 'SOS 緊急回報' : '健康回報',
              subtitle: 'Firestore 居民最新狀態 · 唯讀',
              actions: [
                PageHeaderButton(
                    icon: Icons.refresh,
                    tooltip: '重新整理 Firestore 回報',
                    onPressed:
                        _vm.loading ? null : () => unawaited(_vm.refresh())),
              ]),
          if (_vm.loading) const LinearProgressIndicator(minHeight: 2),
          Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(spacing: 16, runSpacing: 8, children: [
                      Text(
                          '${widget.sosOnly ? 'SOS' : '健康回報'} ${_vm.hasLoaded ? '${_vm.reports.length} 筆' : '尚未取得資料'}',
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.w800)),
                      Text(_vm.updatedAt == null
                          ? '尚未完成讀取'
                          : '最近更新 ${_time(_vm.updatedAt)}'),
                      const Text('開啟本頁時每 30 秒更新，也可手動重新整理'),
                    ]),
                    const SizedBox(height: 12),
                    TextField(
                        controller: _searchController,
                        decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.search),
                            hintText: '搜尋姓名或 Firebase UID',
                            border: OutlineInputBorder(),
                            isDense: true),
                        onChanged: (value) => setState(() {
                              _search = value;
                              _page = 0;
                            })),
                    const SizedBox(height: 8),
                    Wrap(spacing: 8, children: [
                      for (final status in ['全部', '安全', '輕傷', '重傷', '未宣告'])
                        ChoiceChip(
                            label: Text(status),
                            selected: _status == status,
                            onSelected: (_) => setState(() {
                                  _status = status;
                                  _page = 0;
                                }))
                    ]),
                    if (_vm.error != null)
                      Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Row(children: [
                            Expanded(
                                child: Text(
                                    '${_vm.error}${_vm.hasLoaded ? '；以下保留上次成功資料' : ''}',
                                    style:
                                        TextStyle(color: Colors.red.shade700))),
                            TextButton(
                                onPressed: _vm.loading
                                    ? null
                                    : () => unawaited(_vm.refresh()),
                                child: const Text('重試')),
                          ])),
                  ])),
          Expanded(
              child: !_vm.hasLoaded && _vm.loading
                  ? const Center(child: CircularProgressIndicator())
                  : !_vm.hasLoaded && _vm.error != null
                      ? const Center(
                          child: Text('尚未取得 Firestore 回報，請確認登入、權限與後端設定'))
                      : filtered.isEmpty
                          ? Center(
                              child: Text(q.isNotEmpty || _status != '全部'
                                  ? '沒有符合條件的回報'
                                  : widget.sosOnly
                                      ? '目前沒有 sos=true 的回報'
                                      : '目前沒有 Firestore 健康回報'))
                          : ListView.builder(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 24),
                              itemCount: visible.length,
                              itemBuilder: (context, i) => _card(visible[i]))),
          if (_vm.hasLoaded)
            Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Row(children: [
                  Expanded(
                      child: Text(
                          '第 ${index + 1} / $pageCount 頁 · 篩選後 ${filtered.length} 筆')),
                  IconButton(
                      tooltip: '上一頁',
                      onPressed: index == 0
                          ? null
                          : () => setState(() => _page = index - 1),
                      icon: const Icon(Icons.chevron_left)),
                  IconButton(
                      tooltip: '下一頁',
                      onPressed: index + 1 >= pageCount
                          ? null
                          : () => setState(() => _page = index + 1),
                      icon: const Icon(Icons.chevron_right)),
                ])),
        ]));
  }

  Widget _card(FirebaseReport report) => Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFFE5E7EB))),
      child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          leading: Icon(
              report.sos == true ? Icons.sos : Icons.health_and_safety_outlined,
              color: report.sos == true
                  ? Colors.red.shade700
                  : _color(report.status)),
          title: Text(
              report.name?.trim().isNotEmpty == true ? report.name! : '姓名未提供',
              style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
                'Firebase UID ${_short(report.uid)} · ${report.status ?? '狀況未知'}${report.sos == true ? ' · SOS' : ''}'),
            Text(_time(report.reportTime)),
            if (report.dataQuality.isNotEmpty)
              const Text('部分資料待確認', style: TextStyle(color: Colors.orange)),
          ]),
          trailing: TextButton(
              onPressed: () => _details(report), child: const Text('詳細資料'))));

  Future<void> _details(FirebaseReport report) async {
    await showDialog<void>(
        context: context,
        builder: (dialogContext) => AnimatedBuilder(
            animation: _vm,
            builder: (_, __) {
              final current = _vm.reports.where((r) => r.uid == report.uid);
              if (current.isEmpty) {
                return AlertDialog(
                    title: const Text('回報狀態已更新'),
                    content: const Text('此回報已不在目前清單，請返回檢視最新結果'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          child: const Text('關閉'))
                    ]);
              }
              return _detailsDialog(current.first, dialogContext);
            }));
  }

  Widget _detailsDialog(FirebaseReport report, BuildContext dialogContext) =>
      AlertDialog(
        title: Text(widget.sosOnly ? 'SOS 回報詳細資料' : '健康回報詳細資料'),
        content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                  if (_vm.error != null) const Text('更新失敗，顯示上次成功資料'),
                  Text('資料來源：Firestore health_reports（最新狀態）'),
                  Text('姓名：${report.name ?? '未提供'}'),
                  Text('Firebase UID：${_short(report.uid)}'),
                  Text(
                      '來源事件：${report.eventId == null ? '未提供' : _short(report.eventId!)}'),
                  Text('健康狀況：${report.status ?? '未知'}'),
                  Text(
                      'SOS：${report.sos == true ? '是' : report.sos == false ? '否' : '未知'}'),
                  Text('回報時間：${_time(report.reportTime)}'),
                  if (report.description?.isNotEmpty == true)
                    Text('傷勢摘要：${report.description}'),
                  const SizedBox(height: 12),
                  Text(report.hasCoordinates
                      ? 'GPS：${report.latitude}, ${report.longitude}'
                      : '未提供有效 GPS'),
                  const Text('位置由 App 回報，精度與擷取時間未知，可能是舊位置。回報時間不等於定位時間。'),
                  if (report.dataQuality.isNotEmpty)
                    const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text('來源部分欄位缺漏或不一致，請人工確認。')),
                ]))),
        actions: [
          if (report.hasCoordinates)
            TextButton(
                onPressed: () async {
                  Navigator.pop(dialogContext);
                  await _map(report);
                },
                child: const Text('查看地圖')),
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('關閉')),
        ],
      );

  Future<void> _map(FirebaseReport report) async {
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
                title: const Text('開啟回報位置'),
                content: const Text(
                    '此座標可能是舊位置，精度未知。開啟地圖將向圖資服務載入此區域圖磚；導航也會傳送目的座標。是否繼續？'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(c, false),
                      child: const Text('取消')),
                  TextButton(
                      onPressed: () => Navigator.pop(c, true),
                      child: const Text('開啟地圖'))
                ]));
    if (!mounted || confirmed != true) return;
    await Navigator.push<void>(
        context,
        MaterialPageRoute(
            builder: (_) => FullMapPage(
                lat: report.latitude!,
                lng: report.longitude!,
                title: 'Firestore 回報位置',
                subtitle: '位置時間與精度未知',
                showReferenceCircle: false)));
  }
}
