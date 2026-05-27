import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'package:flutter_disaster_app/core/models/supply.dart';
import 'package:flutter_disaster_app/core/models/allocation.dart';

class SupplyPage extends StatefulWidget {
  const SupplyPage({super.key});

  @override
  State<SupplyPage> createState() => _SupplyPageState();
}

class _SupplyPageState extends State<SupplyPage>
    with SingleTickerProviderStateMixin {
  static const String _baseUrl =
      'https://delphine-eisteddfodic-afflictively.ngrok-free.dev';

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
  bool _isLoadingRequests = false;
  String? _requestsError;

  Color get _blue   => const Color(0xFF2563EB);
  Color get _green  => const Color(0xFF16A34A);
  Color get _orange => const Color(0xFFF59E0B);
  Color get _red    => const Color(0xFFDC2626);
  Color get _bg     => const Color(0xFFF5F7FA);
  Color get _card   => Colors.white;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) return;
      if (_tabController.index == 1) { loadAllocations(); loadSupplyRequests(); }
      if (_tabController.index == 2) loadDispatches();
    });
    loadSupplies();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
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

  Future<void> loadSupplies() async {
    setState(() { _isLoadingSupplies = true; _suppliesError = null; });
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
      final data = await _post({'type': 'updateStock', 'itemId': itemId, 'additionalQty': additionalQty});
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

  Future<bool> allocate({required int itemId, required String zoneId, required int qty}) async {
    try {
      final data = await _post({'type': 'allocate', 'itemId': itemId, 'zoneId': zoneId, 'qty': qty});
      if (data['success'] == true) {
        await Future.wait([loadSupplies(), loadAllocations()]);
        return true;
      }
      return false;
    } catch (e) { return false; }
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

  Future<bool> dispatch(int allocationId) async {
    try {
      final data = await _post({'type': 'dispatch', 'allocationId': allocationId});
      if (data['success'] == true) {
        await Future.wait([loadSupplies(), loadAllocations(), loadDispatches()]);
        return true;
      }
      return false;
    } catch (e) { return false; }
  }

  // ── 需求配送 API ──────────────────────────────────────────

  Future<void> loadSupplyRequests() async {
    setState(() { _isLoadingRequests = true; _requestsError = null; });
    try {
      final data = await _post({'type': 'getSupplyRequestDetails'});
      if (data['success'] == true) {
        final all = List<Map<String, dynamic>>.from(data['data']);
        setState(() => _supplyRequests = all.where((r) => r['status'] == 'pending').toList());
      } else {
        setState(() => _requestsError = '載入失敗');
      }
    } catch (e) {
      setState(() => _requestsError = 'API 連線失敗：$e');
    } finally {
      setState(() => _isLoadingRequests = false);
    }
  }

  Future<bool> dispatchRequest(Map<String, dynamic> req) async {
    try {
      final requestId = req['id']?.toString() ?? req['requestId']?.toString() ?? '';
      final data = await _post({'type': 'dispatchSupplyRequest', 'requestId': requestId});
      if (data['success'] == true) {
        await Future.wait([loadSupplies(), loadAllocations(), loadDispatches(), loadSupplyRequests()]);
        return true;
      }
      return false;
    } catch (e) { return false; }
  }

  // ── Build ─────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _card,
        elevation: 0,
        title: const Text('物資管理中心',
            style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            onPressed: () {
              if (_tabController.index == 0) loadSupplies();
              else if (_tabController.index == 1) { loadAllocations(); loadSupplyRequests(); }
              else if (_tabController.index == 2) loadDispatches();
            },
            icon: const Icon(Icons.refresh),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: _blue,
          unselectedLabelColor: const Color(0xFF64748B),
          indicatorColor: _blue,
          tabs: const [
            Tab(icon: Icon(Icons.warehouse_outlined),      text: '庫存管理'),
            Tab(icon: Icon(Icons.assignment_outlined),     text: '物資分配'),
            Tab(icon: Icon(Icons.local_shipping_outlined), text: '出貨紀錄'),
          ],
        ),
      ),
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
      body: TabBarView(
        controller: _tabController,
        children: [
          _inventoryTab(),
          _allocationTab(),
          _dispatchTab(),
        ],
      ),
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

    return RefreshIndicator(
      onRefresh: loadSupplies,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(children: [
            Expanded(child: _statCard('物資種類', '${_supplies.length}', Icons.category, _blue)),
            const SizedBox(width: 10),
            Expanded(child: _statCard('可用庫存', '$totalAvailable', Icons.warehouse, _green)),
            const SizedBox(width: 10),
            Expanded(child: _statCard('庫存不足', '$lowStockCount', Icons.warning_amber_rounded, _orange)),
          ]),
          const SizedBox(height: 16),
          TextField(
            controller: _searchController,
            onChanged: (v) => setState(() => _keyword = v),
            decoration: InputDecoration(
              hintText: '搜尋物資名稱 / 分類...',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
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
                        color: sel ? Colors.white : const Color(0xFF64748B),
                        fontSize: 13,
                        fontWeight: sel ? FontWeight.w600 : FontWeight.normal,
                      )),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          if (filtered.isEmpty)
            _emptyBox('沒有符合條件的物資', '後端開啟後資料將自動載入')
          else
            _groupedSupplyTable(filtered),
          const SizedBox(height: 80),
        ],
      ),
    );
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
              padding: const EdgeInsets.only(top: 16, bottom: 8),
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
                    fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
                const SizedBox(width: 8),
                Text('${categoryItems.length} 項',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
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
              _th('操作', flex: 2),
            ]),
          ),
          ...items.asMap().entries.map((entry) {
            return _supplyRow(entry.value, isLast: entry.key == items.length - 1);
          }),
        ],
      ),
    );
  }

  Widget _th(String label, {int flex = 1}) {
    return Expanded(
      flex: flex,
      child: Text(label,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
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
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)))),
          Expanded(flex: 1, child: Text(item.unit,
            style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)))),
          Expanded(flex: 1, child: Text('${item.availableQty}',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isLow ? _orange : _green))),
          Expanded(flex: 1, child: Text('${item.reservedQty}',
            style: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)))),
          Expanded(flex: 1, child: Text(isLow ? '$shortage' : '—',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
              color: isLow ? _red : const Color(0xFF94A3B8)))),
          Expanded(flex: 2, child: _statusBadge(statusLabel, statusColor)),
          Expanded(
            flex: 2,
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
  // Tab 1：物資分配
  // ══════════════════════════════════════════════════════════

  Widget _allocationTab() {
    if (_isLoadingAllocations || _isLoadingRequests) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_allocationsError != null) return _errorBox(_allocationsError!, () { loadAllocations(); loadSupplyRequests(); });

    final hasReqs  = _supplyRequests.isNotEmpty;
    final hasAlloc = _allocations.isNotEmpty;

    Future<void> refreshAll() => Future.wait([loadAllocations(), loadSupplyRequests()]);

    if (!hasReqs && !hasAlloc) {
      return RefreshIndicator(
        onRefresh: refreshAll,
        child: ListView(children: [
          const SizedBox(height: 60),
          _emptyBox('目前沒有待配送需求', '市民送出需求或在庫存頁分配後會顯示在這裡'),
        ]),
      );
    }

    return RefreshIndicator(
      onRefresh: refreshAll,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (hasReqs) ...[
            const Text('待配送需求',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
            const SizedBox(height: 10),
            ..._supplyRequests.map((r) => _requestCard(r)),
            const SizedBox(height: 20),
          ],
          if (hasAlloc) ...[
            const Text('已分配待出貨',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
            const SizedBox(height: 10),
            ..._allocations.map((a) => _allocationCard(a)),
          ],
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _requestCard(Map<String, dynamic> req) {
    final reqId    = req['id']?.toString() ?? req['requestId']?.toString() ?? '?';
    final itemName = req['itemName']?.toString() ?? '物資 #${req['itemId']}';
    final qty      = (req['qty'] as num?)?.toInt() ?? 0;
    final unit     = req['unit']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _orange.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            CircleAvatar(
              backgroundColor: _orange.withValues(alpha: 0.1),
              child: Icon(Icons.inbox_outlined, color: _orange),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(itemName,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                const SizedBox(height: 4),
                Text('需求 #$reqId・$qty $unit',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              ],
            )),
            _statusBadge('待配送', _orange),
          ]),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _confirmDispatchRequest(req),
              style: ElevatedButton.styleFrom(backgroundColor: _blue, foregroundColor: Colors.white),
              icon: const Icon(Icons.local_shipping, size: 16),
              label: const Text('配送'),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDispatchRequest(Map<String, dynamic> req) {
    final reqId    = req['id']?.toString() ?? req['requestId']?.toString() ?? '?';
    final itemName = req['itemName']?.toString() ?? '物資';
    final qty      = (req['qty'] as num?)?.toInt() ?? 0;
    final unit     = req['unit']?.toString() ?? '';
    final zoneId   = req['zoneId']?.toString() ?? req['gridId']?.toString() ?? '—';

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('確認配送'),
        content: Text('需求 #$reqId\n「$itemName」$qty $unit\n配送地點：$zoneId'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _blue),
            onPressed: () async {
              Navigator.pop(context);
              final ok = await dispatchRequest(req);
              _snack(ok ? '配送成功' : '配送失敗（庫存可能不足）', ok);
            },
            child: const Text('確認配送', style: TextStyle(color: Colors.white)),
          ),
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
          Text('物資名稱：${_itemNameById(item.itemId, item.itemName)}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
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
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              ],
            )),
          ]),
          const SizedBox(height: 8),
          Text('建立時間：${_formatDate(item.createdAt)}',
            style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
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
          Text('物資名稱：${_itemNameById(item.itemId, item.itemName)}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
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
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                const SizedBox(height: 2),
                Text('出貨時間：${_formatDate(item.createdAt)}',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
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

  void _showAllocateDialog(SupplyItem item) {
    final zoneCtrl = TextEditingController();
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
                    '可用庫存：${item.availableQty} ${item.unit}（預留 ${item.reservedQty}）',
                    style: TextStyle(color: _green, fontWeight: FontWeight.w600, fontSize: 13)),
                ),
              ]),
            ),
            const SizedBox(height: 16),
            _input('分配區域（如 A區避難所）', zoneCtrl),
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
              Navigator.pop(context);
              final ok = await allocate(
                itemId: item.itemId, zoneId: zoneCtrl.text.trim(), qty: qty);
              _snack(ok ? '分配成功' : '分配失敗（庫存可能不足）', ok);
              if (ok) _tabController.animateTo(1);
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
              final ok = await dispatch(item.allocationId);
              _snack(ok ? '出貨成功' : '出貨失敗', ok);
              if (ok) _tabController.animateTo(2);
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
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(children: [
        Icon(icon, color: color),
        const SizedBox(height: 8),
        Text(value, style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.w900)),
        const SizedBox(height: 4),
        Text(title, style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
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
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }

  Widget _emptyBox(String title, String subtitle) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(16)),
      child: Column(children: [
        const Icon(Icons.inbox_outlined, size: 46, color: Color(0xFF94A3B8)),
        const SizedBox(height: 12),
        Text(title, style: const TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
        if (subtitle.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
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