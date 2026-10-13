import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import 'package:flutter_disaster_app/core/models/supply.dart';
import 'package:flutter_disaster_app/core/models/allocation.dart';
import 'package:flutter_disaster_app/core/api_config.dart';
import 'package:flutter_disaster_app/admin_APP/widgets/page_header.dart';

class SupplyPage extends StatefulWidget {
  /// 一進來顯示哪個分頁：0 庫存管理 / 1 據點管理 / 2 出貨紀錄
  final int initialTab;
  const SupplyPage({super.key, this.initialTab = 0});

  @override
  State<SupplyPage> createState() => _SupplyPageState();
}

class _SupplyPageState extends State<SupplyPage>
    with SingleTickerProviderStateMixin {
  static const String _baseUrl = ApiConfig.baseUrl;

  late final TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  List<SupplyItem> _supplies = [];
  bool _isLoadingSupplies = false;
  String? _suppliesError;
  String _keyword = '';
  String _selectedCategory = '全部';

  static const List<String> _categories = [
    '全部', '食品飲水', '生活用品', '醫療衛生', '衣物',
  ];

  List<AllocationItem> _allocations = [];
  bool _isLoadingAllocations = false;
  String? _allocationsError;

  List<AllocationItem> _dispatches = [];
  bool _isLoadingDispatches = false;
  String? _dispatchesError;

  List<Map<String, dynamic>> _supplyRequests = [];
  // 災民配送分頁：篩選（all / active / 單一狀態）與搜尋
  String _reqFilter = 'waiting';
  String _reqKeyword = '';
  final TextEditingController _reqSearchCtrl = TextEditingController();
  bool _isLoadingRequests = false;
  String? _requestsError;

  /// 收容中心據點（對應後端 stations 表；後端目前沒有取得據點清單的 API）
  static const Map<String, String> _stations = {'S001': 'A收容中心', 'S002': 'B收容中心'};
  static const String _unassigned = '未標示據點';
  String _selectedStation = 'A收容中心';
  /// 目前打開的據點（null = 顯示據點卡片清單）
  String? _openStation;

  /// 各據點物資庫存（據點名稱 → 後端 getStationInventory 回傳的清單）
  final Map<String, List<Map<String, dynamic>>> _stationStock = {};
  final Set<String> _stationStockLoading = {};

  /// requestId → 據點名稱（逐據點呼叫 getPendingSupplyRequests 查得）
  Map<String, String> _requestStation = {};

  Color get _blue   => const Color(0xFF2563EB);
  Color get _green  => const Color(0xFF16A34A);
  Color get _orange => const Color(0xFFF59E0B);
  Color get _red    => const Color(0xFFDC2626);
  Color get _bg     => const Color(0xFFF5F7FA);
  Color get _card   => Colors.white;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this, initialIndex: widget.initialTab.clamp(0, 2));
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) return;
      if (_tabController.index == 1) { loadAllocations(); loadSupplyRequests(); }
      if (_tabController.index == 2) loadDispatches();
    });
    loadSupplies();
    loadSupplyRequests();
    loadAllocations();
    loadDispatches();
    _autoRefresh = Timer.periodic(const Duration(seconds: 10), (_) {
      if (!mounted) return;
      loadSupplies(silent: true);
      loadSupplyRequests(silent: true);
    });
  }

  Timer? _autoRefresh;

  @override
  void dispose() {
    _autoRefresh?.cancel();
    _tabController.dispose();
    _searchController.dispose();
    _reqSearchCtrl.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> _post(Map<String, dynamic> body) async {
    final response = await http
        .post(
          Uri.parse(_baseUrl),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 10),
            onTimeout: () => throw Exception('連線逾時'));
    debugPrint('REQUEST => $body');
    debugPrint('STATUS  => ${response.statusCode}');
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  // ── 庫存 API ──────────────────────────────────────────────

  /// silent = 背景自動更新，不顯示轉圈圈
  Future<void> loadSupplies({bool silent = false}) async {
    if (!silent) setState(() { _isLoadingSupplies = true; _suppliesError = null; });
    try {
      final data = await _post({'type': 'getInventory'});
      if (data['success'] == true) {
        final list = data['data'] as List;
        setState(() => _supplies = list.map((e) => SupplyItem.fromJson(e)).toList());
      } else {
        setState(() => _suppliesError = data['message']?.toString() ?? '載入失敗');
      }
    } catch (e) {
      setState(() => _suppliesError = 'API 連線失敗：$e');
    } finally {
      setState(() => _isLoadingSupplies = false);
    }
  }

  Future<bool> addSupply({
    required String name, required String category,
    required String unit, required int stockQty, required int neededQty,
  }) async {
    try {
      final data = await _post({
        'type': 'addInventory', 'name': name, 'category': category,
        'unit': unit, 'stockQty': stockQty, 'neededQty': neededQty,
      });
      if (data['success'] == true) { await loadSupplies(); return true; }
      return false;
    } catch (e) { return false; }
  }

  Future<bool> updateStock({required int itemId, required int additionalQty}) async {
    try {
      final data = await _post({'type': 'updateStock', 'itemId': itemId, 'qty': additionalQty});
      if (data['success'] == true) { await loadSupplies(); return true; }
      return false;
    } catch (e) { return false; }
  }

  Future<bool> updateNeeded({required int itemId, required int neededQty}) async {
    try {
      final data = await _post({'type': 'updateNeeded', 'itemId': itemId, 'neededQty': neededQty});
      if (data['success'] == true) { await loadSupplies(); return true; }
      return false;
    } catch (e) { return false; }
  }

  /// 刪除物資：回傳後端訊息（使用中的物資後端會拒絕刪除）
  Future<({bool success, String message})> deleteSupply(int itemId) async {
    try {
      final data = await _post({'type': 'deleteInventory', 'itemId': itemId});
      final ok = data['success'] == true;
      if (ok) await loadSupplies();
      return (success: ok, message: data['message']?.toString() ?? '');
    } catch (e) {
      return (success: false, message: 'API 連線失敗：$e');
    }
  }

  // ── 分配 API ──────────────────────────────────────────────

  Future<void> loadAllocations() async {
    setState(() { _isLoadingAllocations = true; _allocationsError = null; });
    try {
      final data = await _post({'type': 'getAllocations'});
      if (data['success'] == true) {
        final list = data['data'] as List;
        if (list.isNotEmpty) debugPrint('DEBUG first allocation raw: ${list.first}');
        setState(() => _allocations = list
            .map((e) => AllocationItem.fromJson(e))
            .where((a) => a.status == 'reserved')
            .toList());
      } else {
        setState(() => _allocationsError = data['message']?.toString() ?? '載入失敗');
      }
    } catch (e) {
      setState(() => _allocationsError = 'API 連線失敗：$e');
    } finally {
      setState(() => _isLoadingAllocations = false);
    }
  }

  Future<({bool ok, String reason})> allocate({required int itemId, required String zoneId, required int qty}) async {
    try {
      final data = await _post({'type': 'allocate', 'itemId': itemId, 'zoneId': zoneId, 'qty': qty});
      if (data['success'] == true) {
        // 分配後直接出貨：後端 allocate 不回傳 allocationId，
        // 重新讀取後找出剛建立的那筆（同物資、同據點、同數量、編號最大）再呼叫 dispatch
        await loadAllocations();
        final created = _allocations
            .where((a) => a.itemId == itemId && a.zoneId.trim() == zoneId.trim() && a.qty == qty)
            .toList()
          ..sort((a, b) => b.allocationId.compareTo(a.allocationId));
        if (created.isEmpty) {
          await loadSupplies();
          return (ok: false, reason: '已分配，但找不到這筆分配可出貨，請重新整理');
        }
        return dispatch(created.first.allocationId);
      }
      return (ok: false, reason: _failReason(data, '可用庫存不足或資料有誤'));
    } catch (e) { return (ok: false, reason: '連線失敗'); }
  }

  Future<bool> cancelAllocation(int allocationId) async {
    try {
      final data = await _post({'type': 'cancelAllocation', 'allocationId': allocationId});
      if (data['success'] == true) {
        await Future.wait([loadSupplies(), loadAllocations()]);
        return true;
      }
      return false;
    } catch (e) { return false; }
  }

  // ── 出貨 API ──────────────────────────────────────────────

  Future<void> loadDispatches() async {
    setState(() { _isLoadingDispatches = true; _dispatchesError = null; });
    try {
      final data = await _post({'type': 'getDispatches'});
      if (data['success'] == true) {
        final list = data['data'] as List;
        setState(() => _dispatches = list.map((e) => AllocationItem.fromJson(e)).toList());
      } else {
        setState(() => _dispatchesError = data['message']?.toString() ?? '載入失敗');
      }
    } catch (e) {
      setState(() => _dispatchesError = 'API 連線失敗：$e');
    } finally {
      setState(() => _isLoadingDispatches = false);
    }
  }

  Future<({bool ok, String reason})> dispatch(int allocationId) async {
    try {
      final data = await _post({'type': 'dispatch', 'allocationId': allocationId});
      if (data['success'] == true) {
        await Future.wait([loadSupplies(), loadAllocations(), loadDispatches()]);
        return (ok: true, reason: '');
      }
      return (ok: false, reason: _failReason(data, '出貨失敗，請重新整理後再試'));
    } catch (e) { return (ok: false, reason: '連線失敗'); }
  }

  // ── 需求配送 API ──────────────────────────────────────────

  Future<void> loadSupplyRequests({bool silent = false}) async {
    if (!silent) setState(() { _isLoadingRequests = true; _requestsError = null; });
    try {
      final data = await _post({'type': 'getSupplyRequestDetails'});
      if (data['success'] == true) {
        final all = List<Map<String, dynamic>>.from(data['data']);
        // 待認領 → 已認領（義工）→ 已配送，依流程順序排列
        // reserved（已預留庫存）也視為待認領
        const order = {'pending': 0, 'reserved': 0, 'claimed': 1, 'dispatched': 2, 'completed': 2};

        // 明細沒有 stationId，用各據點的待認領清單補上「哪一筆屬於哪個據點」
        final stationMap = Map<String, String>.from(_requestStation);
        await Future.wait(_stations.entries.map((st) async {
          try {
            final res = await _post({'type': 'getPendingSupplyRequests', 'stationId': st.key});
            if (res['success'] == true) {
              for (final r in (res['data'] ?? res['requests'] ?? []) as List) {
                final id = r['requestId']?.toString();
                if (id != null) stationMap[id] = st.value;
              }
            }
          } catch (_) {}
        }));

        if (!mounted) return;
        setState(() {
          _requestStation = stationMap;
          _supplyRequests = all
              .where((r) => order.containsKey(r['status']))
              .toList()
            ..sort((a, b) => order[a['status']]!.compareTo(order[b['status']]!));
        });
      } else {
        setState(() => _requestsError = '載入失敗');
      }
    } catch (e) {
      setState(() => _requestsError = 'API 連線失敗：$e');
    } finally {
      setState(() => _isLoadingRequests = false);
    }
  }

  Future<({bool ok, String reason})> dispatchRequest(Map<String, dynamic> req) async {
    try {
      final requestId = req['id']?.toString() ?? req['requestId']?.toString() ?? '';
      final data = await _post({'type': 'dispatchSupplyRequest', 'requestId': requestId});
      if (data['success'] == true) {
        await Future.wait([loadSupplies(), loadAllocations(), loadDispatches(), loadSupplyRequests()]);
        return (ok: true, reason: '');
      }
      return (ok: false, reason: _failReason(data, '配送失敗'));
    } catch (e) { return (ok: false, reason: '連線失敗'); }
  }

  /// 依 itemId 找庫存資料（找不到回傳 null）
  SupplyItem? _supplyById(int? itemId) {
    for (final s in _supplies) {
      if (s.itemId == itemId) return s;
    }
    return null;
  }

  /// 後端失敗訊息轉成管理員看得懂的文字
  String _failReason(Map<String, dynamic> data, String fallback) {
    final msg = data['message']?.toString() ?? '';
    if (msg.isEmpty || msg == 'Invalid request') return fallback;
    if (msg.contains('Not enough stock')) return '庫存不足';
    return msg.replaceFirst('Exception: ', '');
  }

  // ── Build ─────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      floatingActionButton: AnimatedBuilder(
        animation: _tabController,
        builder: (_, __) {
          if (_tabController.index != 0) return const SizedBox.shrink();
          return FloatingActionButton.extended(
            backgroundColor: _green,
            foregroundColor: Colors.white,
            onPressed: _showAddSupplyDialog,
            icon: const Icon(Icons.add),
            label: const Text('新增物資'),
          );
        },
      ),
      body: Column(children: [
        PageHeader(
          title: '物資管理',
          subtitle: 'SUPPLY MANAGEMENT',
          actions: [
            PageHeaderButton(
              icon: Icons.refresh_rounded,
              tooltip: '重新整理',
              onPressed: () {
                if (_tabController.index == 0) {
                  loadSupplies();
                } else if (_tabController.index == 1) {
                  loadAllocations();
                  loadSupplyRequests();
                  if (_openStation != null) _loadStationStock(_openStation!);
                } else if (_tabController.index == 2) {
                  loadDispatches();
                }
              },
            ),
          ],
        ),
        // 分頁列：圖示與文字橫排，高度較矮
        Container(
          decoration: BoxDecoration(
            color: _card,
            border: const Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
          ),
          child: TabBar(
            controller: _tabController,
            labelColor: _blue,
            unselectedLabelColor: const Color(0xFF475569),
            indicatorColor: _blue,
            dividerColor: Colors.transparent,
            labelStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            unselectedLabelStyle: const TextStyle(fontSize: 15),
            tabs: [
              for (final (icon, text) in const [
                (Icons.warehouse_outlined, '庫存管理'),
                (Icons.assignment_outlined, '據點管理'),
                (Icons.local_shipping_outlined, '出貨紀錄'),
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
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _inventoryTab(),
              _stationTab(),
              _dispatchTab(),
            ],
          ),
        ),
      ]),
    );
  }

  // ══════════════════════════════════════════════════════════
  // Tab 0：庫存管理
  // ══════════════════════════════════════════════════════════

  Widget _inventoryTab() {
    if (_isLoadingSupplies) return const Center(child: CircularProgressIndicator());
    if (_suppliesError != null) return _errorBox(_suppliesError!, loadSupplies);

    final categoryFiltered = _selectedCategory == '全部'
        ? _supplies
        : _supplies.where((item) => item.category == _selectedCategory).toList();

    final filtered = categoryFiltered.where((item) {
      final key = _keyword.trim().toLowerCase();
      if (key.isEmpty) return true;
      return item.name.toLowerCase().contains(key) ||
          item.category.toLowerCase().contains(key);
    }).toList();

    final totalAvailable = _supplies.fold<int>(0, (s, i) => s + i.availableQty);
    final lowStockCount  = _supplies.where((i) => i.isLowStock).length;

    // 上方（統計、搜尋、分類）固定，只有下方物資表格可以滑動
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Column(children: [
          Row(children: [
            Expanded(child: _statCard('物資種類', '${_supplies.length}', Icons.category, _blue)),
            const SizedBox(width: 10),
            Expanded(child: _statCard('可用庫存', '$totalAvailable', Icons.warehouse, _green)),
            const SizedBox(width: 10),
            Expanded(child: _statCard('庫存不足', '$lowStockCount', Icons.warning_amber_rounded, _orange)),
          ]),
          const SizedBox(height: 10),
          TextField(
            controller: _searchController,
            onChanged: (v) => setState(() => _keyword = v),
            decoration: InputDecoration(
              hintText: '搜尋物資名稱 / 分類...',
              prefixIcon: const Icon(Icons.search, size: 20),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final cat = _categories[i];
                final sel = _selectedCategory == cat;
                return GestureDetector(
                  onTap: () => setState(() => _selectedCategory = cat),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: sel ? _blue : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: sel ? _blue : const Color(0xFFE5E7EB)),
                    ),
                    child: Text(cat,
                      style: TextStyle(
                        color: sel ? Colors.white : const Color(0xFF475569),
                        fontSize: 14,
                        fontWeight: sel ? FontWeight.w600 : FontWeight.normal,
                      )),
                  ),
                );
              },
            ),
          ),
        ]),
      ),
      Expanded(
        child: RefreshIndicator(
          onRefresh: loadSupplies,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              if (filtered.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: _emptyBox('沒有符合條件的物資', '後端開啟後資料將自動載入'),
                )
              else
                _groupedSupplyTable(filtered),
              // 留空間給右下角「新增物資」按鈕
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    ]);
  }

  Widget _groupedSupplyTable(List<SupplyItem> items) {
    final Map<String, List<SupplyItem>> grouped = {};
    for (final item in items) {
      grouped.putIfAbsent(item.category, () => []).add(item);
    }

    const order = ['食品飲水', '生活用品', '醫療衛生', '衣物'];
    final sortedKeys = [
      ...order.where((c) => grouped.containsKey(c)),
      ...grouped.keys.where((c) => !order.contains(c)),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: sortedKeys.map((category) {
        final categoryItems = grouped[category]!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 6),
              child: Row(children: [
                Container(
                  width: 4, height: 16,
                  decoration: BoxDecoration(
                    color: _blue,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Text(category,
                  style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
                const SizedBox(width: 8),
                Text('${categoryItems.length} 項',
                  style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
              ]),
            ),
            _supplyTable(categoryItems),
          ],
        );
      }).toList(),
    );
  }

  Widget _supplyTable(List<SupplyItem> items) {
    return Container(
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
            ),
            child: Row(children: [
              _th('名稱', flex: 3),
              _th('單位', flex: 1),
              _th('可用', flex: 1),
              _th('預留', flex: 1),
              _th('尚缺', flex: 1),
              _th('狀態', flex: 2),
              // 操作欄固定寬度＝4 顆按鈕，右邊不會空一大塊
              const SizedBox(
                width: _actionColWidth,
                child: Text('操作',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
              ),
            ]),
          ),
          ...items.asMap().entries.map((entry) {
            return _supplyRow(entry.value, isLast: entry.key == items.length - 1);
          }),
        ],
      ),
    );
  }

  /// 4 顆 32px 按鈕 + 3 個 6px 間距
  static const double _actionColWidth = 4 * 32 + 3 * 6;

  Widget _th(String label, {int flex = 1}) {
    return Expanded(
      flex: flex,
      child: Text(label,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
    );
  }

  Widget _supplyRow(SupplyItem item, {bool isLast = false}) {
    final isLow    = item.isLowStock;
    final shortage = item.shortageQty;

    String statusLabel;
    Color  statusColor;
    if (item.availableQty == 0) {
      statusLabel = '缺貨'; statusColor = _red;
    } else if (isLow) {
      statusLabel = '庫存不足'; statusColor = _orange;
    } else {
      statusLabel = '庫存正常'; statusColor = _green;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        border: isLast ? null : const Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(flex: 3, child: Text(item.name,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)))),
          Expanded(flex: 1, child: Text(item.unit,
            style: const TextStyle(fontSize: 14, color: Color(0xFF475569)))),
          Expanded(flex: 1, child: Text('${item.availableQty}',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: isLow ? _orange : _green))),
          // 預留為負數代表後端資料異常，顯示 0 並以紅字提醒
          Expanded(flex: 1, child: Tooltip(
            message: item.hasReservedError ? '後端預留資料異常（${item.reservedQty}），已以 0 計算' : '',
            child: Text(item.hasReservedError ? '0 ⚠' : '${item.reservedQty}',
              style: TextStyle(fontSize: 14,
                  color: item.hasReservedError ? _red : const Color(0xFF64748B))))),
          Expanded(flex: 1, child: Text(isLow ? '$shortage' : '—',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600,
              color: isLow ? _red : const Color(0xFF64748B)))),
          Expanded(flex: 2, child: Align(
            alignment: Alignment.centerLeft,
            child: _statusBadge(statusLabel, statusColor))),
          SizedBox(
            width: _actionColWidth,
            child: Row(children: [
              _rowIconBtn(icon: Icons.add, color: _green, tooltip: '補貨',
                onTap: () => _showUpdateStockDialog(item)),
              const SizedBox(width: 6),
              _rowIconBtn(icon: Icons.edit_outlined, color: _orange, tooltip: '修改需求',
                onTap: () => _showUpdateNeededDialog(item)),
              const SizedBox(width: 6),
              _rowIconBtn(
                icon: Icons.assignment_turned_in_outlined,
                color: item.availableQty > 0 ? _blue : const Color(0xFFCBD5E1),
                tooltip: '分配',
                onTap: item.availableQty > 0 ? () => _showAllocateDialog(item) : null,
              ),
              const SizedBox(width: 6),
              _rowIconBtn(icon: Icons.delete_outline, color: _red, tooltip: '刪除',
                onTap: () => _confirmDeleteSupply(item)),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _rowIconBtn({
    required IconData icon, required Color color,
    required String tooltip, VoidCallback? onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  // Tab 1：據點管理（選據點 → 篩選 → 需求明細；上方顯示該據點待出貨的分配）
  // ══════════════════════════════════════════════════════════

  /// 物資需求狀態 → 中文 + 顏色（依後端流程）
  ({String label, Color color}) _reqStyle(String status) => switch (status) {
        'pending'    => (label: '待處理', color: const Color(0xFF64748B)),
        'reserved'   => (label: '待認領', color: _blue),
        'claimed'    => (label: '已認領', color: _green),
        'dispatched' => (label: '配送中', color: const Color(0xFFD97706)),
        'completed'  => (label: '已完成', color: const Color(0xFF475569)),
        _            => (label: status, color: const Color(0xFF64748B)),
      };

  /// 三組：waiting 待認領（pending / reserved）、delivering 配送中（claimed / dispatched）、done 已完成
  static String _reqGroup(String status) => switch (status) {
        'pending' || 'reserved'    => 'waiting',
        'claimed' || 'dispatched'  => 'delivering',
        'completed'                => 'done',
        _                          => 'other',
      };

  int _groupCount(List<Map<String, dynamic>> list, String group) =>
      list.where((r) => _reqGroup(r['status']?.toString() ?? '') == group).length;

  /// 這筆需求屬於哪個據點：後端有給就用後端的，否則用待認領清單查到的；都沒有 → 未標示
  String _stationOf(Map<String, dynamic> r) {
    final name = r['stationName']?.toString() ?? '';
    if (name.isNotEmpty) return name;
    final id = r['stationId']?.toString() ?? '';
    if (_stations.containsKey(id)) return _stations[id]!;
    return _requestStation[r['requestId']?.toString()] ?? _unassigned;
  }

  /// 據點清單：後端的收容中心 + 分配 / 出貨用過的據點；有未標示的需求才多一個「未標示據點」
  List<String> get _stationNames {
    final names = <String>[..._stations.values];
    for (final z in _knownZones) {
      if (!names.contains(z)) names.add(z);
    }
    if (_supplyRequests.any((r) => _stationOf(r) == _unassigned)) names.add(_unassigned);
    return names;
  }

  List<Map<String, dynamic>> get _stationRequests =>
      _supplyRequests.where((r) => _stationOf(r) == _selectedStation).toList();

  List<Map<String, dynamic>> get _filteredRequests {
    final kw = _reqKeyword.trim().toLowerCase();
    return _stationRequests.where((r) {
      final st = r['status']?.toString() ?? '';
      if (_reqFilter != 'all' && _reqGroup(st) != _reqFilter) return false;
      if (kw.isEmpty) return true;
      return [r['requestId'], r['itemName'], r['volunteerId'], r['address']]
          .any((v) => (v?.toString() ?? '').toLowerCase().contains(kw));
    }).toList();
  }

  /// 據點管理：沒選據點 → 據點卡片清單；點了某據點 → 該據點的訂單
  Widget _stationTab() {
    if (_isLoadingRequests && _supplyRequests.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    final open = _openStation;
    if (open == null || !_stationNames.contains(open)) return _stationList();
    _selectedStation = open;
    return _stationDetail();
  }

  // ── 第一層：據點卡片（A、B、…）──────────────────────────
  Widget _stationList() {
    final stations = _stationNames;
    return RefreshIndicator(
      onRefresh: () async => Future.wait([loadSupplyRequests(), loadAllocations()]),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        itemCount: stations.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, i) => _stationCard(stations[i]),
      ),
    );
  }

  Widget _stationCard(String name) {
    final reqs = _supplyRequests.where((r) => _stationOf(r) == name).toList();
    final waiting = _groupCount(reqs, 'waiting');
    final delivering = _groupCount(reqs, 'delivering');
    final done = _groupCount(reqs, 'done');
    final unassigned = name == _unassigned;

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => setState(() {
        _openStation = name;
        _reqFilter = 'stock';
        _loadStationStock(name);
        _reqSearchCtrl.clear();
        _reqKeyword = '';
      }),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Row(children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
              color: (unassigned ? const Color(0xFF64748B) : const Color(0xFF1E3A5F)).withValues(alpha: .08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(unassigned ? Icons.help_outline_rounded : Icons.home_work_outlined,
                color: unassigned ? const Color(0xFF64748B) : const Color(0xFF1E3A5F), size: 26),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 3,
            child: Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
          ),
          // 待 / 配 / 完
          Expanded(
            flex: 4,
            child: Row(children: [
              _miniCount('待認領', waiting, _blue),
              _miniCount('配送中', delivering, const Color(0xFFD97706)),
              _miniCount('已完成', done, const Color(0xFF475569)),
            ]),
          ),
          const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
        ]),
      ),
    );
  }

  Widget _miniCount(String label, int n, Color color) => Expanded(
        child: Column(children: [
          Text('$n', style: TextStyle(
              fontSize: 22, fontWeight: FontWeight.w800,
              color: n > 0 ? color : const Color(0xFFCBD5E1))),
          Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
        ]),
      );

  // ── 第二層：某據點的訂單（待 / 配 / 完 → 明細）────────────
  Widget _stationDetail() {
    final stationReqs = _stationRequests;
    final rows = _filteredRequests;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // 返回 + 據點名稱
        Row(children: [
          IconButton(
            tooltip: '返回據點列表',
            onPressed: () => setState(() => _openStation = null),
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          const Icon(Icons.home_work_outlined, color: Color(0xFF1E3A5F), size: 22),
          const SizedBox(width: 8),
          Text(_selectedStation,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
        ]),
        const SizedBox(height: 8),
        // 待 / 配 / 完 + 搜尋
        Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
          _reqFilterChip('物資庫存', 'stock'),
          _reqFilterChip('待認領 ${_groupCount(stationReqs, 'waiting')}', 'waiting'),
          _reqFilterChip('配送中 ${_groupCount(stationReqs, 'delivering')}', 'delivering'),
          _reqFilterChip('已完成 ${_groupCount(stationReqs, 'done')}', 'done'),
          _reqFilterChip('全部 ${stationReqs.length}', 'all'),
          SizedBox(
            width: 280, height: 40,
            child: TextField(
              controller: _reqSearchCtrl,
              onChanged: (v) => setState(() => _reqKeyword = v),
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                hintText: '搜尋 地點 / 物資 / 編號 / 義工',
                hintStyle: const TextStyle(fontSize: 14, color: Color(0xFF64748B)),
                prefixIcon: const Icon(Icons.search, size: 18),
                suffixIcon: _reqKeyword.isEmpty ? null : IconButton(
                  icon: const Icon(Icons.close, size: 16),
                  onPressed: () => setState(() { _reqSearchCtrl.clear(); _reqKeyword = ''; }),
                ),
                isDense: true,
                filled: true,
                fillColor: _card,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: _blue)),
              ),
            ),
          ),
        ]),
        const SizedBox(height: 10),
        // 訂單明細
        Expanded(child: _reqFilter == 'stock' ? _stockTable() : _reqTable(rows)),
      ]),
    );
  }

  // ── 據點物資庫存 ─────────────────────────────────────────

  /// 讀取某據點的物資庫存（後端 getStationInventory，依 stationId）
  Future<void> _loadStationStock(String stationName) async {
    final stationId = _stations.entries
        .firstWhere((e) => e.value == stationName, orElse: () => const MapEntry('', ''))
        .key;
    if (stationId.isEmpty) {
      setState(() => _stationStock[stationName] = []);
      return;
    }
    setState(() => _stationStockLoading.add(stationName));
    List<Map<String, dynamic>> list = [];
    try {
      final data = await _post({'type': 'getStationInventory', 'stationId': stationId});
      if (data['success'] == true) {
        list = List<Map<String, dynamic>>.from(data['data'] ?? data['inventory'] ?? []);
      }
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _stationStock[stationName] = list;
      _stationStockLoading.remove(stationName);
    });
  }

  /// 此據點還沒送完的需求，依物資加總數量（itemId → qty）
  Map<int, int> _stationDemand() {
    final demand = <int, int>{};
    for (final r in _stationRequests) {
      final g = _reqGroup(r['status']?.toString() ?? '');
      if (g != 'waiting' && g != 'delivering') continue;
      final id = (r['itemId'] as num?)?.toInt();
      if (id == null) continue;
      demand[id] = (demand[id] ?? 0) + ((r['qty'] as num?)?.toInt() ?? 0);
    }
    return demand;
  }

  // 欄位：物資 / 單位 / 庫存 / 已預留 / 可用 / 需求量 / 狀態
  static const _stockColFlex = [3, 1, 1, 1, 1, 1, 2];

  Widget _stockTable() {
    if (_stationStockLoading.contains(_selectedStation) && !_stationStock.containsKey(_selectedStation)) {
      return const Center(child: CircularProgressIndicator());
    }
    final kw = _reqKeyword.trim().toLowerCase();
    final demand = _stationDemand();
    final rows = (_stationStock[_selectedStation] ?? []).where((s) {
      if (kw.isEmpty) return true;
      final name = (s['itemName'] ?? s['name'] ?? '').toString().toLowerCase();
      return name.contains(kw);
    }).toList();

    Widget cell(String text, int col, {Color? color, bool bold = false}) => Expanded(
          flex: _stockColFlex[col],
          child: Text(text,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 14,
                  color: color ?? const Color(0xFF0F172A),
                  fontWeight: bold ? FontWeight.w700 : FontWeight.w400)),
        );

    return Container(
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: const Color(0xFFF8FAFC),
          child: Row(children: [
            for (final (i, h) in const ['物資', '單位', '庫存', '已預留', '可用', '需求量', '狀態'].indexed)
              cell(h, i, color: const Color(0xFF475569), bold: true),
          ]),
        ),
        const Divider(height: 1, color: Color(0xFFE5E7EB)),
        Expanded(
          child: rows.isEmpty
              ? Center(child: Text(
                  kw.isNotEmpty ? '找不到符合「${_reqKeyword.trim()}」的物資' : '目前沒有庫存資料',
                  style: const TextStyle(color: Color(0xFF64748B), fontSize: 14)))
              : RefreshIndicator(
                  onRefresh: () => _loadStationStock(_selectedStation),
                  child: ListView.separated(
                    itemCount: rows.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                    itemBuilder: (_, i) {
                      final s = rows[i];
                      final itemId = (s['itemId'] as num?)?.toInt();
                      final stock = (s['stockQty'] as num?)?.toInt() ?? 0;
                      final reservedRaw = (s['reservedQty'] as num?)?.toInt() ?? 0;
                      final reserved = reservedRaw < 0 ? 0 : reservedRaw;
                      // 可用量以後端 availableQty 為準；沒給才自己算（實際庫存 − 預留量）
                      final availableRaw = (s['availableQty'] as num?)?.toInt() ?? (stock - reserved);
                      final available = availableRaw < 0 ? 0 : availableRaw;
                      final need = demand[itemId] ?? 0;
                      final shortage = need - available;

                      final (label, color) = stock <= 0
                          ? ('缺貨', _red)
                          : shortage > 0
                              ? ('不足 $shortage', _orange)
                              : ('充足', _green);

                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(children: [
                          cell((s['itemName'] ?? s['name'] ?? _itemNameById(itemId ?? -1, '')).toString(), 0, bold: true),
                          cell((s['unit'] ?? _supplyById(itemId)?.unit ?? '').toString(), 1,
                              color: const Color(0xFF475569)),
                          cell('$stock', 2),
                          cell('$reserved', 3, color: const Color(0xFF64748B)),
                          cell('$available', 4, bold: true, color: available > 0 ? _green : _red),
                          cell(need > 0 ? '$need' : '—', 5,
                              color: need > 0 ? const Color(0xFF0F172A) : const Color(0xFF94A3B8)),
                          Expanded(
                            flex: _stockColFlex[6],
                            child: Align(alignment: Alignment.centerLeft, child: _statusBadge(label, color)),
                          ),
                        ]),
                      );
                    },
                  ),
                ),
        ),
      ]),
    );
  }

  Widget _reqFilterChip(String label, String value) {
    final selected = _reqFilter == value;
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: () => setState(() => _reqFilter = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? _blue : _card,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: selected ? _blue : const Color(0xFFE5E7EB)),
        ),
        child: Text(label, style: TextStyle(
            fontSize: 14,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? Colors.white : const Color(0xFF475569))),
      ),
    );
  }

  // 欄位：需求地點 / 物資 / 數量 / 需求編號 / 義工 / 狀態 / 認領時間
  static const _reqColFlex = [5, 3, 2, 3, 2, 2, 3];

  Widget _reqCell(String text, int col, {Color? color, bool bold = false}) => Expanded(
        flex: _reqColFlex[col],
        child: Text(text,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: 14,
                color: color ?? const Color(0xFF0F172A),
                fontWeight: bold ? FontWeight.w700 : FontWeight.w400)),
      );

  Widget _reqTable(List<Map<String, dynamic>> rows) {
    return Container(
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(builder: (context, c) {
        final width = c.maxWidth < 860 ? 860.0 : c.maxWidth;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: width,
            child: Column(children: [
              // 表頭
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                color: const Color(0xFFF8FAFC),
                child: Row(children: [
                  for (final (i, h) in const ['需求地點', '物資', '數量', '需求編號', '義工', '狀態', '認領時間'].indexed)
                    _reqCell(h, i, color: const Color(0xFF475569), bold: true),
                ]),
              ),
              const Divider(height: 1, color: Color(0xFFE5E7EB)),
              Expanded(
                child: rows.isEmpty
                    ? Center(child: Text(
                        _reqKeyword.trim().isNotEmpty ? '找不到符合「${_reqKeyword.trim()}」的需求' : '目前沒有符合條件的需求',
                        style: const TextStyle(color: Color(0xFF64748B), fontSize: 14)))
                    : RefreshIndicator(
                        onRefresh: loadSupplyRequests,
                        child: ListView.separated(
                          itemCount: rows.length,
                          separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                          itemBuilder: (_, i) => _reqRow(rows[i]),
                        ),
                      ),
              ),
            ]),
          ),
        );
      }),
    );
  }

  String _reqLocation(Map<String, dynamic> r) {
    final address = r['address']?.toString() ?? '';
    if (address.isNotEmpty) return address;
    final lat = (r['lat'] as num?)?.toDouble();
    final lng = (r['lng'] as num?)?.toDouble();
    if (lat == null || lng == null) return '未提供';
    return '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}';
  }

  Widget _reqRow(Map<String, dynamic> r) {
    final status = r['status']?.toString() ?? '';
    final st = _reqStyle(status);
    final volunteer = r['volunteerId']?.toString() ?? '';
    // 已認領 / 配送中 卻沒有義工 → 資料異常
    final missingVolunteer = volunteer.isEmpty && (status == 'claimed' || status == 'dispatched');
    final claimedAt = r['claimedAt']?.toString() ?? '';
    final done = status == 'completed';
    final textColor = done ? const Color(0xFF64748B) : null;

    return InkWell(
      onTap: () => _showRequestDetail(r),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(children: [
          _reqCell(_reqLocation(r), 0, bold: true, color: textColor),
          _reqCell(r['itemName']?.toString() ?? '物資 #${r['itemId']}', 1, color: textColor),
          _reqCell('${r['qty'] ?? 0} ${r['unit'] ?? ''}', 2, color: textColor),
          _reqCell(r['requestId']?.toString() ?? '—', 3, color: const Color(0xFF475569)),
          _reqCell(missingVolunteer ? '— 異常' : (volunteer.isEmpty ? '—' : volunteer), 4,
              color: missingVolunteer ? _red : textColor),
          Expanded(
            flex: _reqColFlex[5],
            child: Align(alignment: Alignment.centerLeft, child: _statusBadge(st.label, st.color)),
          ),
          _reqCell(claimedAt.isEmpty ? '—' : _formatDate(claimedAt), 6, color: const Color(0xFF475569)),
        ]),
      ),
    );
  }

  /// 點一列：顯示詳細資料
  void _showRequestDetail(Map<String, dynamic> r) {
    final status = r['status']?.toString() ?? '';
    final st = _reqStyle(status);
    final qty = (r['qty'] as num?)?.toInt() ?? 0;
    final unit = r['unit']?.toString() ?? '';
    final lat = (r['lat'] as num?)?.toDouble();
    final lng = (r['lng'] as num?)?.toDouble();
    final stock = _supplyById((r['itemId'] as num?)?.toInt());
    final progress = switch (status) {
      'pending'    => '等待預留物資',
      'reserved'   => '物資已預留，等待義工認領',
      'claimed'    => '義工已認領，等待到據點取貨',
      'dispatched' => '義工已取貨，正在送往災民',
      'completed'  => '已送到災民手上',
      _            => '',
    };

    Widget line(String label, String value, {Color? color}) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: 84, child: Text(label, style: const TextStyle(fontSize: 14, color: Color(0xFF475569)))),
            Expanded(child: Text(value, style: TextStyle(fontSize: 14, color: color ?? const Color(0xFF0F172A)))),
          ]),
        );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(children: [
          Expanded(child: Text('${r['itemName'] ?? '物資'} × $qty $unit')),
          _statusBadge(st.label, st.color),
        ]),
        content: SizedBox(
          width: 420,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (progress.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(progress, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: st.color)),
              ),
            line('需求編號', r['requestId']?.toString() ?? '—'),
            line('需求者', r['userId']?.toString() ?? '—'),
            line('需求地點', _reqLocation(r)),
            line('負責據點', _stationOf(r)),
            line('認領義工', (r['volunteerId']?.toString() ?? '').isEmpty ? '—' : r['volunteerId'].toString()),
            line('認領時間', (r['claimedAt']?.toString() ?? '').isEmpty ? '—' : _formatDate(r['claimedAt'].toString())),
            line('建立時間', (r['createdAt']?.toString() ?? '').isEmpty ? '—' : _formatDate(r['createdAt'].toString())),
            // 尚未預留時，提示目前可用庫存夠不夠
            if (status == 'pending' && stock != null)
              line('可用庫存', '${stock.availableQty} ${stock.unit}（需要 $qty）',
                  color: stock.availableQty >= qty ? _green : _red),
          ]),
        ),
        actions: [
          if (lat != null && lng != null && !(lat == 0 && lng == 0))
            TextButton.icon(
              onPressed: () => launchUrl(
                  Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng'),
                  mode: LaunchMode.externalApplication),
              icon: const Icon(Icons.map_outlined, size: 18),
              label: const Text('在地圖上查看'),
            ),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('關閉')),
        ],
      ),
    );
  }

  String _itemNameById(int itemId, String fallback) {
    try {
      return _supplies.firstWhere((s) => s.itemId == itemId).name;
    } catch (_) {
      return fallback.isNotEmpty ? fallback : '未知物資';
    }
  }

  Widget _allocationCard(AllocationItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _blue.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text('單號：#${item.allocationId}', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _green)),
            const Spacer(),
            _statusBadge('待出貨', _blue),
          ]),
          const SizedBox(height: 4),
          Text('物資名稱：${_itemNameById(item.itemId, item.itemName)}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
          const SizedBox(height: 10),
          Row(children: [
            CircleAvatar(
              backgroundColor: _blue.withValues(alpha: 0.1),
              child: Icon(Icons.assignment_outlined, color: _blue),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text('分配區域：${item.zoneId}・數量：${item.qty} ${item.unit}',
                  style: const TextStyle(fontSize: 13, color: Color(0xFF475569))),
              ],
            )),
          ]),
          const SizedBox(height: 8),
          Text('建立時間：${_formatDate(item.createdAt)}',
            style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _confirmDispatch(item),
                style: ElevatedButton.styleFrom(backgroundColor: _green, foregroundColor: Colors.white),
                icon: const Icon(Icons.local_shipping, size: 16),
                label: const Text('確認出貨'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _confirmCancelAllocation(item),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _red,
                  side: BorderSide(color: _red.withValues(alpha: 0.4)),
                ),
                icon: const Icon(Icons.cancel_outlined, size: 16),
                label: const Text('取消分配'),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  // Tab 2：出貨紀錄
  // ══════════════════════════════════════════════════════════

  Widget _dispatchTab() {
    if (_isLoadingDispatches) return const Center(child: CircularProgressIndicator());
    if (_dispatchesError != null) return _errorBox(_dispatchesError!, loadDispatches);

    return RefreshIndicator(
      onRefresh: loadDispatches,
      child: _dispatches.isEmpty
          ? ListView(children: [
              const SizedBox(height: 60),
              _emptyBox('目前沒有出貨紀錄', '出貨後的紀錄會顯示在這裡'),
            ])
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _dispatches.length,
              itemBuilder: (_, i) => _dispatchCard(_dispatches[i]),
            ),
    );
  }

  Widget _dispatchCard(AllocationItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text('單號：#${item.allocationId}', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _green)),
            const Spacer(),
            _statusBadge('已出貨', _green),
          ]),
          const SizedBox(height: 4),
          Text('物資名稱：${_itemNameById(item.itemId, item.itemName)}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
          const SizedBox(height: 10),
          Row(children: [
            CircleAvatar(
              backgroundColor: _green.withValues(alpha: 0.1),
              child: Icon(Icons.check_circle_outline, color: _green),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text('區域：${item.zoneId}・數量：${item.qty} ${item.unit}',
                  style: const TextStyle(fontSize: 13, color: Color(0xFF475569))),
                const SizedBox(height: 2),
                Text('出貨時間：${_formatDate(item.createdAt)}',
                  style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
              ],
            )),
          ]),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  // Dialogs
  // ══════════════════════════════════════════════════════════

  void _showAddSupplyDialog() {
    final nameCtrl   = TextEditingController();
    final unitCtrl   = TextEditingController();
    final stockCtrl  = TextEditingController();
    final neededCtrl = TextEditingController();
    String selectedCat = _categories[1];

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: const Text('新增物資'),
          content: SingleChildScrollView(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _input('物資名稱', nameCtrl),
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: DropdownButtonFormField<String>(
                  value: selectedCat,
                  decoration: InputDecoration(
                    labelText: '分類',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: _categories.skip(1)
                      .map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                  onChanged: (v) => setDlgState(() => selectedCat = v ?? selectedCat),
                ),
              ),
              _input('單位', unitCtrl),
              _input('初始庫存', stockCtrl, isNumber: true),
              _input('需求量', neededCtrl, isNumber: true),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
            ElevatedButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                final qty  = int.tryParse(stockCtrl.text.trim()) ?? 0;
                final existing = _supplies
                    .where((s) => s.name.toLowerCase() == name.toLowerCase()).toList();

                if (existing.isNotEmpty && context.mounted) {
                  Navigator.pop(context);
                  final dup = existing.first;
                  showDialog(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text('已存在同名物資'),
                      content: Text(
                        '「$name」已存在（目前庫存 ${dup.stockQty} ${dup.unit}）。\n\n'
                        '要將 $qty 件加入現有庫存，還是建立新條目？'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
                        OutlinedButton(
                          onPressed: () async {
                            Navigator.pop(context);
                            final ok = await addSupply(
                              name: name, category: selectedCat,
                              unit: unitCtrl.text.trim(), stockQty: qty,
                              neededQty: int.tryParse(neededCtrl.text.trim()) ?? 0,
                            );
                            _snack(ok ? '新條目建立成功' : '建立失敗', ok);
                          },
                          child: const Text('建立新條目'),
                        ),
                        ElevatedButton(
                          onPressed: () async {
                            Navigator.pop(context);
                            final ok = await updateStock(itemId: dup.itemId, additionalQty: qty);
                            _snack(ok ? '已補貨至現有品項' : '補貨失敗', ok);
                          },
                          child: const Text('加入現有庫存'),
                        ),
                      ],
                    ),
                  );
                  return;
                }

                Navigator.pop(context);
                final ok = await addSupply(
                  name: name, category: selectedCat,
                  unit: unitCtrl.text.trim(), stockQty: qty,
                  neededQty: int.tryParse(neededCtrl.text.trim()) ?? 0,
                );
                _snack(ok ? '新增成功' : '新增失敗', ok);
              },
              child: const Text('確認新增'),
            ),
          ],
        ),
      ),
    );
  }

  void _showUpdateStockDialog(SupplyItem item) {
    final qtyCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('補貨：${item.name}'),
        content: _input('補貨數量', qtyCtrl, isNumber: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final ok = await updateStock(
                itemId: item.itemId,
                additionalQty: int.tryParse(qtyCtrl.text.trim()) ?? 0,
              );
              _snack(ok ? '補貨成功' : '補貨失敗', ok);
            },
            child: const Text('確認補貨'),
          ),
        ],
      ),
    );
  }

  void _showUpdateNeededDialog(SupplyItem item) {
    final neededCtrl = TextEditingController(text: item.neededQty.toString());
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('修改需求量：${item.name}'),
        content: _input('新需求量', neededCtrl, isNumber: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final ok = await updateNeeded(
                itemId: item.itemId,
                neededQty: int.tryParse(neededCtrl.text.trim()) ?? item.neededQty,
              );
              _snack(ok ? '修改成功' : '修改失敗', ok);
            },
            child: const Text('確認修改'),
          ),
        ],
      ),
    );
  }

  /// 曾經用過的據點名稱（來自後端的分配 / 出貨紀錄），預設據點排第一
  List<String> get _knownZones {
    const defaultZone = 'A收容中心';
    final zones = <String>{defaultZone};
    for (final a in [..._allocations, ..._dispatches]) {
      final z = a.zoneId.trim();
      if (z.isNotEmpty) zones.add(z);
    }
    return zones.toList();
  }

  void _showAllocateDialog(SupplyItem item) {
    final zoneCtrl = TextEditingController(text: 'A收容中心');
    final qtyCtrl  = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('分配物資：${item.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _green.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(children: [
                Icon(Icons.inventory_2_outlined, color: _green, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '可用庫存：${item.availableQty} ${item.unit}（預留 ${item.safeReservedQty}）',
                    style: TextStyle(color: _green, fontWeight: FontWeight.w600, fontSize: 14)),
                ),
              ]),
            ),
            if (item.hasReservedError) ...[
              const SizedBox(height: 6),
              Text('⚠️ 預留資料異常（後端為 ${item.reservedQty}），已以 0 計算，請通知後端',
                  style: TextStyle(color: _red, fontSize: 13, fontWeight: FontWeight.w600)),
            ],
            const SizedBox(height: 16),
            _input('分配到哪個據點', zoneCtrl),
            // 點選既有據點，避免打錯字導致義工端對不上
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final z in _knownZones)
                ActionChip(
                  label: Text(z, style: const TextStyle(fontSize: 13)),
                  avatar: const Icon(Icons.home_work_outlined, size: 16),
                  onPressed: () => zoneCtrl.text = z,
                ),
            ]),
            const SizedBox(height: 6),
            const Text('出貨後，該據點的義工會在「據點到貨」看到這批物資',
                style: TextStyle(fontSize: 13, color: Color(0xFF475569))),
            const SizedBox(height: 12),
            _input('分配數量', qtyCtrl, isNumber: true),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          ElevatedButton(
            onPressed: () async {
              final qty = int.tryParse(qtyCtrl.text.trim()) ?? 0;
              if (qty <= 0)                     { _snack('請輸入有效數量', false); return; }
              if (zoneCtrl.text.trim().isEmpty) { _snack('請輸入分配區域', false); return; }
              if (qty > item.availableQty) {
                _snack('超過可用庫存：可用 ${item.availableQty} ${item.unit}，請先補貨或減少數量', false);
                return;
              }
              Navigator.pop(context);
              final r = await allocate(
                itemId: item.itemId, zoneId: zoneCtrl.text.trim(), qty: qty);
              _snack(r.ok ? '已分配並出貨到 ${zoneCtrl.text.trim()}' : '分配失敗：${r.reason}', r.ok);
              // 直接出貨了，帶到「出貨紀錄」看結果
              if (r.ok) _tabController.animateTo(2);
            },
            child: const Text('確認分配'),
          ),
        ],
      ),
    );
  }

  void _confirmDispatch(AllocationItem item) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('確認出貨'),
        content: Text('確定要將「${item.itemName}」${item.qty} ${item.unit} 出貨至 ${item.zoneId}？\n出貨後無法撤銷。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _green),
            onPressed: () async {
              Navigator.pop(context);
              final r = await dispatch(item.allocationId);
              // 出貨後留在目前頁面，不自動跳到「出貨紀錄」
              _snack(r.ok ? '出貨成功，可在「出貨紀錄」查看' : '出貨失敗：${r.reason}', r.ok);
            },
            child: const Text('確認出貨', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _confirmCancelAllocation(AllocationItem item) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('取消分配'),
        content: Text('確定要取消「${item.itemName}」${item.qty} ${item.unit} 的分配單？\n庫存將會恢復。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('返回')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _red),
            onPressed: () async {
              Navigator.pop(context);
              final ok = await cancelAllocation(item.allocationId);
              _snack(ok ? '已取消分配' : '取消失敗', ok);
            },
            child: const Text('確認取消', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  // 共用元件
  // ══════════════════════════════════════════════════════════

  Widget _statCard(String title, String value, IconData icon, Color color) {
    // 橫向排列：左邊圖示、右邊數字，高度較矮
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(value,
                style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.w800, height: 1.15)),
            Text(title,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Color(0xFF475569), fontSize: 13)),
          ]),
        ),
      ]),
    );
  }

  Widget _statusBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(text,
        style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.bold)),
    );
  }

  Widget _emptyBox(String title, String subtitle) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(16)),
      child: Column(children: [
        const Icon(Icons.inbox_outlined, size: 46, color: Color(0xFF64748B)),
        const SizedBox(height: 12),
        Text(title, style: const TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.bold)),
        if (subtitle.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(color: Color(0xFF64748B), fontSize: 13)),
        ],
      ]),
    );
  }

  Widget _errorBox(String message, VoidCallback onRetry) {
    return Center(child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(message, style: TextStyle(color: _red)),
        const SizedBox(height: 12),
        ElevatedButton(onPressed: onRetry, child: const Text('重新載入')),
      ],
    ));
  }

  Widget _input(String label, TextEditingController controller, {bool isNumber = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  void _confirmDeleteSupply(SupplyItem item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('刪除物資'),
        content: Text('確定要刪除「${item.name}」嗎？\n刪除後會從後端資料庫移除，無法復原。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _red, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              final result = await deleteSupply(item.itemId);
              _snack(result.success
                  ? '已刪除「${item.name}」'
                  : '刪除失敗：${result.message}', result.success);
            },
            child: const Text('刪除'),
          ),
        ],
      ),
    );
  }

  void _snack(String message, bool success) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(backgroundColor: success ? _green : _red, content: Text(message)));
  }

  String _formatDate(String raw) {
    try {
      final dt = DateTime.parse(raw).toLocal();
      return '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')} '
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return raw;
    }
  }
}