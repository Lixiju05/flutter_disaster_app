import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_disaster_app/core/models/supply.dart';
import 'package:flutter_disaster_app/core/api_config.dart';
import 'package:flutter_disaster_app/core/offline_demo_data.dart';
import 'package:flutter_disaster_app/admin_APP/widgets/page_header.dart';
import 'package:flutter_disaster_app/admin_APP/widgets/offline_demo_badge.dart';

class SupplyPage extends StatefulWidget {
  const SupplyPage({super.key});

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
  bool _isOfflineDemo = false;
  String _keyword = '';
  String _selectedCategory = '全部';

  static const List<String> _categories = [
    '全部', '食品飲水', '生活用品', '醫療衛生', '衣物',
  ];

  /// 居民物資需求（扁平清單，不分據點）
  List<Map<String, dynamic>> _supplyRequests = [];
  bool _isLoadingRequests = false;
  String _reqFilter = 'pending';
  String _reqKeyword = '';
  final TextEditingController _reqSearchCtrl = TextEditingController();

  /// 異常待審需求（getSupplyRequestReviews）
  List<Map<String, dynamic>> _requestReviews = [];
  bool _isLoadingReviews = false;
  String? _reviewBusyId;

  /// 批次勾選的需求編號
  final Set<String> _selectedRequestIds = {};
  bool _isBatchBusy = false;

  Color get _blue   => const Color(0xFF2563EB);
  Color get _green  => const Color(0xFF16A34A);
  Color get _orange => const Color(0xFFF59E0B);
  Color get _red    => const Color(0xFFDC2626);
  Color get _bg     => const Color(0xFFF5F7FA);
  Color get _card   => Colors.white;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) return;
      if (_tabController.index == 1) loadSupplyRequests();
    });
    loadSupplies();
    loadSupplyRequests();
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
        setState(() {
          _supplies = list.map((e) => SupplyItem.fromJson(e)).toList();
          _isOfflineDemo = false;
        });
      } else {
        setState(() => _suppliesError = data['message']?.toString() ?? '載入失敗');
      }
    } catch (e) {
      // 連不上後端時，先用示範資料讓畫面可以照常顯示、方便改 UI
      setState(() {
        _supplies = demoSupplies();
        _suppliesError = null;
        _isOfflineDemo = true;
      });
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

  // ── 居民物資需求 API ──────────────────────────────────────

  /// 需求處理流程：pending → reserved → dispatched → completed
  static const _reqStatusOrder = {'pending': 0, 'reserved': 1, 'dispatched': 2, 'completed': 3};

  Future<void> loadSupplyRequests({bool silent = false}) async {
    if (!silent) setState(() => _isLoadingRequests = true);
    try {
      final data = await _post({'type': 'getSupplyRequestDetails'});
      if (data['success'] == true) {
        final all = List<Map<String, dynamic>>.from(data['data']);
        if (!mounted) return;
        setState(() {
          _supplyRequests = all
              .where((r) => _reqStatusOrder.containsKey(r['status']))
              .toList()
            ..sort((a, b) =>
                _reqStatusOrder[a['status']]!.compareTo(_reqStatusOrder[b['status']]!));
          _isOfflineDemo = false;
        });
      }
      await _loadRequestReviews(silent: silent);
    } catch (_) {
      // 連不上後端時，先用示範資料讓畫面可以照常顯示、方便改 UI
      if (mounted) {
        setState(() {
          _supplyRequests = demoSupplyRequestMaps();
          _requestReviews = demoSupplyRequestReviews();
          _isOfflineDemo = true;
        });
      }
    } finally {
      if (mounted) setState(() => _isLoadingRequests = false);
    }
  }

  /// 異常待審需求（庫存不足／疑似重複／超過上限／必填資料異常）
  Future<void> _loadRequestReviews({bool silent = false}) async {
    if (!silent) setState(() => _isLoadingReviews = true);
    try {
      final data = await _post({'type': 'getSupplyRequestReviews'});
      if (data['success'] == true && mounted) {
        setState(() => _requestReviews = List<Map<String, dynamic>>.from(data['data'] ?? []));
      }
    } catch (_) {
      // 外層 loadSupplyRequests 的 catch 已處理離線示範資料
    } finally {
      if (mounted) setState(() => _isLoadingReviews = false);
    }
  }

  /// 取得後端存取權杖（登入時取得）
  Future<String> _authToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('adminToken') ?? '';
  }

  /// 批次處理：批次預留／批次出庫／批次完成（需帶管理員 Token）
  Future<void> _runBatch(String type, String actionLabel) async {
    final ids = _selectedRequestIds.toList();
    if (ids.isEmpty) return;
    setState(() => _isBatchBusy = true);
    try {
      final token = await _authToken();
      final response = await http
          .post(
            Uri.parse(_baseUrl),
            headers: {
              'Content-Type': 'application/json',
              if (token.isNotEmpty) 'Authorization': 'Bearer $token',
            },
            body: jsonEncode({'type': type, 'requestIds': ids}),
          )
          .timeout(const Duration(seconds: 15));
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (!mounted) return;
      setState(() => _selectedRequestIds.clear());
      await loadSupplyRequests();
      if (!mounted) return;
      _showBatchResultDialog(data, actionLabel);
    } catch (e) {
      if (_isOfflineDemo) {
        // 離線示範：連不到後端時，直接在本機模擬狀態轉換，方便測試 UI
        final nextStatus = switch (type) {
          'batchReserveSupplyRequests' => 'reserved',
          'batchDispatchSupplyRequests' => 'dispatched',
          'batchCompleteSupplyRequests' => 'completed',
          _ => null,
        };
        if (nextStatus != null && mounted) {
          setState(() {
            for (final r in _supplyRequests) {
              if (ids.contains(r['requestId']?.toString())) r['status'] = nextStatus;
            }
            _selectedRequestIds.clear();
          });
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(backgroundColor: _red, content: Text('$actionLabel失敗，連線錯誤：$e')));
      }
    } finally {
      if (mounted) setState(() => _isBatchBusy = false);
    }
  }

  /// 批次結果：即使 HTTP 200 也可能部分失敗，所以要讀每一筆結果
  void _showBatchResultDialog(Map<String, dynamic> data, String actionLabel) {
    final total = (data['total'] as num?)?.toInt() ?? 0;
    final succeeded = (data['succeeded'] as num?)?.toInt() ?? 0;
    final failed = (data['failed'] as num?)?.toInt() ?? 0;
    final results = (data['results'] as List?) ?? [];
    final failedItems = results.whereType<Map>().where((e) => e['success'] != true).toList();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(children: [
          Expanded(child: Text('$actionLabel結果')),
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
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('共 $total 筆・成功 $succeeded 筆・失敗 $failed 筆',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              if (failedItems.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text('失敗項目：', style: TextStyle(fontWeight: FontWeight.w600, color: _red)),
                const SizedBox(height: 6),
                ...failedItems.map((e) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                          '・${e['requestId'] ?? '—'}：${e['message'] ?? e['reason'] ?? '處理失敗'}',
                          style: TextStyle(fontSize: 13, color: _red)),
                    )),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// 異常需求審核：核准（approve）或暫緩（defer）
  Future<void> _reviewDecision(Map<String, dynamic> r, String decision, String note) async {
    final requestId = r['requestId']?.toString() ?? '';
    if (requestId.isEmpty) return;
    setState(() => _reviewBusyId = requestId);
    try {
      final token = await _authToken();
      final response = await http
          .post(
            Uri.parse(_baseUrl),
            headers: {
              'Content-Type': 'application/json',
              if (token.isNotEmpty) 'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'type': 'reviewSupplyRequest',
              'requestId': requestId,
              'decision': decision,
              'note': note,
            }),
          )
          .timeout(const Duration(seconds: 10));
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (!mounted) return;
      if (data['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(decision == 'approve' ? '已核准，物資已預留' : '已暫緩處理')));
        await loadSupplyRequests();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            backgroundColor: _red, content: Text(data['message']?.toString() ?? '審核失敗')));
      }
    } catch (e) {
      if (_isOfflineDemo) {
        // 離線示範：直接在本機模擬審核結果
        setState(() {
          _requestReviews.removeWhere((x) => x['requestId']?.toString() == requestId);
          if (decision == 'approve') {
            final idx = _supplyRequests.indexWhere((x) => x['requestId']?.toString() == requestId);
            if (idx != -1) _supplyRequests[idx]['status'] = 'reserved';
          }
        });
      } else if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(backgroundColor: _red, content: Text('連線失敗：$e')));
      }
    } finally {
      if (mounted) setState(() => _reviewBusyId = null);
    }
  }

  /// 開一個小對話框讓管理員填審核備註，再送出核准／暫緩
  void _showReviewNoteDialog(Map<String, dynamic> r, String decision) {
    final noteCtrl = TextEditingController();
    final isApprove = decision == 'approve';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isApprove ? '核准異常需求' : '暫緩此需求'),
        content: SizedBox(
          width: 360,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${r['itemName'] ?? '物資'} × ${r['qty'] ?? 0} ${r['unit'] ?? ''}',
                style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            TextField(
              controller: noteCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: '審核備註（選填）',
                border: OutlineInputBorder(),
              ),
            ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: isApprove ? _green : _orange, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctx);
              _reviewDecision(r, decision, noteCtrl.text.trim());
            },
            child: Text(isApprove ? '核准' : '暫緩'),
          ),
        ],
      ),
    );
  }

  /// 依 itemId 找庫存資料（找不到回傳 null）
  SupplyItem? _supplyById(int? itemId) {
    for (final s in _supplies) {
      if (s.itemId == itemId) return s;
    }
    return null;
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
          badges: [if (_isOfflineDemo) const OfflineDemoBadge()],
          actions: [
            PageHeaderButton(
              icon: Icons.refresh_rounded,
              tooltip: '重新整理',
              onPressed: () {
                if (_tabController.index == 0) {
                  loadSupplies();
                } else {
                  loadSupplyRequests();
                }
              },
            ),
          ],
        ),
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
                (Icons.assignment_outlined, '物資需求'),
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
              _requestsTab(),
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
      clipBehavior: Clip.antiAlias,
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
            return _supplyRow(entry.value, index: entry.key, isLast: entry.key == items.length - 1);
          }),
        ],
      ),
    );
  }

  /// 3 顆 32px 按鈕 + 2 個 6px 間距
  static const double _actionColWidth = 3 * 32 + 2 * 6;

  Widget _th(String label, {int flex = 1}) {
    return Expanded(
      flex: flex,
      child: Text(label,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
    );
  }

  Widget _supplyRow(SupplyItem item, {required int index, bool isLast = false}) {
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
        color: index.isEven ? _card : const Color(0xFFF8FAFC),
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
            color: color,
            borderRadius: BorderRadius.circular(9),
            boxShadow: [
              BoxShadow(color: color.withValues(alpha: 0.32), blurRadius: 8, offset: const Offset(0, 2)),
            ],
          ),
          child: Icon(icon, size: 16, color: Colors.white),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  // Tab 1：物資需求（居民提出的物資需求，扁平清單，不分據點）
  // 流程：pending（待處理）→ reserved（已預留）→ dispatched（已出庫）→ completed（已完成）
  // 異常需求維持 pending，另外列在「異常待審」，需人工核准／暫緩
  // ══════════════════════════════════════════════════════════

  /// 物資需求狀態 → 中文 + 顏色
  ({String label, Color color}) _reqStyle(String status) => switch (status) {
        'pending'    => (label: '待處理', color: const Color(0xFF64748B)),
        'reserved'   => (label: '已預留', color: _blue),
        'dispatched' => (label: '已出庫', color: _orange),
        'completed'  => (label: '已完成', color: _green),
        _            => (label: status, color: const Color(0xFF64748B)),
      };

  /// 需求編號 → 異常原因（來自 getSupplyRequestReviews）
  Map<String, String> get _reviewReasonMap => {
        for (final r in _requestReviews)
          if ((r['requestId']?.toString() ?? '').isNotEmpty)
            r['requestId'].toString(): (r['reason'] ?? '異常需求').toString(),
      };

  /// 篩選分組：待處理需求若被標記異常，歸到「異常待審」
  String _reqGroup(Map<String, dynamic> r) {
    final id = r['requestId']?.toString() ?? '';
    final status = r['status']?.toString() ?? '';
    if (status == 'pending' && _reviewReasonMap.containsKey(id)) return 'review';
    return status;
  }

  int _groupCount(String group) => _supplyRequests.where((r) => _reqGroup(r) == group).length;

  List<Map<String, dynamic>> get _filteredRequests {
    final kw = _reqKeyword.trim().toLowerCase();
    return _supplyRequests.where((r) {
      if (_reqFilter != 'all' && _reqGroup(r) != _reqFilter) return false;
      if (kw.isEmpty) return true;
      return [r['requestId'], r['itemName'], r['address']]
          .any((v) => (v?.toString() ?? '').toLowerCase().contains(kw));
    }).toList();
  }

  /// 目前篩選狀態對應的批次動作（只有篩選到單一狀態時才能批次處理）
  ({String type, String label})? get _batchAction => switch (_reqFilter) {
        'pending'    => (type: 'batchReserveSupplyRequests', label: '批次預留'),
        'reserved'   => (type: 'batchDispatchSupplyRequests', label: '批次出庫'),
        'dispatched' => (type: 'batchCompleteSupplyRequests', label: '批次完成'),
        _            => null,
      };

  Widget _requestsTab() {
    if (_isLoadingRequests && _supplyRequests.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    final rows = _filteredRequests;
    final batchAction = _batchAction;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
          _reqFilterChip('待處理 ${_groupCount('pending')}', 'pending'),
          _reqFilterChip('異常待審 ${_requestReviews.length}', 'review'),
          _reqFilterChip('已預留 ${_groupCount('reserved')}', 'reserved'),
          _reqFilterChip('已出庫 ${_groupCount('dispatched')}', 'dispatched'),
          _reqFilterChip('已完成 ${_groupCount('completed')}', 'completed'),
          _reqFilterChip('全部 ${_supplyRequests.length}', 'all'),
          SizedBox(
            width: 260, height: 40,
            child: TextField(
              controller: _reqSearchCtrl,
              onChanged: (v) => setState(() => _reqKeyword = v),
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                hintText: '搜尋 地點 / 物資 / 編號',
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
        if (batchAction != null) ...[
          const SizedBox(height: 10),
          _batchBar(rows, batchAction),
        ],
        const SizedBox(height: 10),
        Expanded(
          child: _reqFilter == 'review'
              ? _reviewList()
              : _reqTable(rows, showCheckbox: batchAction != null),
        ),
      ]),
    );
  }

  Widget _batchBar(List<Map<String, dynamic>> rows, ({String type, String label}) action) {
    final selectableIds =
        rows.map((r) => r['requestId']?.toString() ?? '').where((id) => id.isNotEmpty).toSet();
    final selectedCount = _selectedRequestIds.intersection(selectableIds).length;
    final allSelected = selectableIds.isNotEmpty && selectableIds.every(_selectedRequestIds.contains);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _blue.withValues(alpha: .06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _blue.withValues(alpha: .20)),
      ),
      child: Row(children: [
        Checkbox(
          value: allSelected,
          onChanged: selectableIds.isEmpty ? null : (v) {
            setState(() {
              if (v == true) {
                _selectedRequestIds.addAll(selectableIds);
              } else {
                _selectedRequestIds.removeAll(selectableIds);
              }
            });
          },
        ),
        Text('全選本頁（已選 $selectedCount 筆）',
            style: const TextStyle(fontSize: 13, color: Color(0xFF475569))),
        const Spacer(),
        ElevatedButton.icon(
          onPressed: (selectedCount == 0 || _isBatchBusy)
              ? null
              : () => _runBatch(action.type, action.label),
          icon: _isBatchBusy
              ? const SizedBox(width: 14, height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.playlist_add_check_rounded, size: 18),
          label: Text('${action.label}（$selectedCount）'),
          style: ElevatedButton.styleFrom(backgroundColor: _blue, foregroundColor: Colors.white),
        ),
      ]),
    );
  }

  Widget _reqFilterChip(String label, String value) {
    final selected = _reqFilter == value;
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: () => setState(() { _reqFilter = value; _selectedRequestIds.clear(); }),
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

  // 欄位：需求地點 / 物資 / 數量 / 需求編號 / 狀態 / 時間
  static const _reqColFlex = [5, 3, 2, 3, 2, 3];

  Widget _reqCell(String text, int col, {Color? color, bool bold = false}) => Expanded(
        flex: _reqColFlex[col],
        child: Text(text,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: 14,
                color: color ?? const Color(0xFF0F172A),
                fontWeight: bold ? FontWeight.w700 : FontWeight.w400)),
      );

  Widget _reqTable(List<Map<String, dynamic>> rows, {required bool showCheckbox}) {
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
                  if (showCheckbox) const SizedBox(width: 40),
                  for (final (i, h) in const ['需求地點', '物資', '數量', '需求編號', '狀態', '時間'].indexed)
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
                          itemBuilder: (_, i) => _reqRow(rows[i], index: i, showCheckbox: showCheckbox),
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

  Widget _reqRow(Map<String, dynamic> r, {required int index, required bool showCheckbox}) {
    final id = r['requestId']?.toString() ?? '';
    final status = r['status']?.toString() ?? '';
    final st = _reqStyle(status);
    final done = status == 'completed';
    final textColor = done ? const Color(0xFF64748B) : null;
    final selected = _selectedRequestIds.contains(id);
    final createdAt = r['createdAt']?.toString() ?? '';

    return InkWell(
      onTap: () => _showRequestDetail(r),
      child: Container(
        color: index.isEven ? _card : const Color(0xFFF8FAFC),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(children: [
          if (showCheckbox)
            SizedBox(
              width: 40,
              child: Checkbox(
                value: selected,
                onChanged: id.isEmpty ? null : (v) {
                  setState(() {
                    if (v == true) {
                      _selectedRequestIds.add(id);
                    } else {
                      _selectedRequestIds.remove(id);
                    }
                  });
                },
              ),
            ),
          _reqCell(_reqLocation(r), 0, bold: true, color: textColor),
          _reqCell(r['itemName']?.toString() ?? '物資 #${r['itemId']}', 1, color: textColor),
          _reqCell('${r['qty'] ?? 0} ${r['unit'] ?? ''}', 2, color: textColor),
          _reqCell(id.isEmpty ? '—' : id, 3, color: const Color(0xFF475569)),
          Expanded(
            flex: _reqColFlex[4],
            child: Align(alignment: Alignment.centerLeft, child: _statusBadge(st.label, st.color)),
          ),
          _reqCell(createdAt.isEmpty ? '—' : _formatDate(createdAt), 5, color: const Color(0xFF475569)),
        ]),
      ),
    );
  }

  /// 異常待審清單（卡片樣式，逐筆核准／暫緩）
  Widget _reviewList() {
    if (_isLoadingReviews && _requestReviews.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_requestReviews.isEmpty) return _emptyBox('目前沒有異常待審的需求', '');
    return ListView.separated(
      itemCount: _requestReviews.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _reviewCard(_requestReviews[i]),
    );
  }

  Widget _reviewCard(Map<String, dynamic> r) {
    final id = r['requestId']?.toString() ?? '';
    final reason = r['reason']?.toString() ?? '異常需求';
    final busy = _reviewBusyId == id;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFCA5A5)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text('${r['itemName'] ?? '物資'} × ${r['qty'] ?? 0} ${r['unit'] ?? ''}',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          ),
          _statusBadge('異常待審', _red),
        ]),
        const SizedBox(height: 6),
        Text('需求編號 ${id.isEmpty ? '—' : id} ・ ${_reqLocation(r)}',
            style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(8)),
          child: Row(children: [
            Icon(Icons.warning_amber_rounded, size: 16, color: _red),
            const SizedBox(width: 6),
            Expanded(child: Text(reason, style: TextStyle(fontSize: 13, color: _red))),
          ]),
        ),
        const SizedBox(height: 10),
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          TextButton(
            onPressed: busy ? null : () => _showReviewNoteDialog(r, 'defer'),
            child: const Text('暫緩'),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: busy ? null : () => _showReviewNoteDialog(r, 'approve'),
            style: ElevatedButton.styleFrom(backgroundColor: _green, foregroundColor: Colors.white),
            child: busy
                ? const SizedBox(width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('核准'),
          ),
        ]),
      ]),
    );
  }

  /// 點一列：顯示詳細資料
  void _showRequestDetail(Map<String, dynamic> r) {
    final id = r['requestId']?.toString() ?? '';
    final status = r['status']?.toString() ?? '';
    final st = _reqStyle(status);
    final qty = (r['qty'] as num?)?.toInt() ?? 0;
    final unit = r['unit']?.toString() ?? '';
    final lat = (r['lat'] as num?)?.toDouble();
    final lng = (r['lng'] as num?)?.toDouble();
    final stock = _supplyById((r['itemId'] as num?)?.toInt());
    final reason = _reviewReasonMap[id];
    final progress = switch (status) {
      'pending'    => reason != null ? '異常待審，需人工確認' : '等待預留物資',
      'reserved'   => '物資已預留，等待出庫',
      'dispatched' => '已出庫，等待配送完成登記',
      'completed'  => '已完成配送',
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
          _statusBadge(reason != null ? '異常待審' : st.label, reason != null ? _red : st.color),
          const SizedBox(width: 4),
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
          width: 420,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (progress.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(progress,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
                        color: reason != null ? _red : st.color)),
              ),
            if (reason != null) line('異常原因', reason, color: _red),
            line('需求編號', id.isEmpty ? '—' : id),
            line('需求者', r['userId']?.toString() ?? '—'),
            line('需求地點', _reqLocation(r)),
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
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  // Dialogs
  // ══════════════════════════════════════════════════════════

  SupplyItem? _findSupplyByName(String text) {
    final t = text.trim().toLowerCase();
    if (t.isEmpty) return null;
    for (final s in _supplies) {
      if (s.name.toLowerCase() == t) return s;
    }
    return null;
  }

  void _showAddSupplyDialog() {
    final nameCtrl   = TextEditingController();
    final unitCtrl   = TextEditingController();
    final stockCtrl  = TextEditingController();
    String selectedCat = _categories[1];
    SupplyItem? matched;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          final typed = nameCtrl.text.trim();
          final suggestions = (typed.isEmpty || matched != null)
              ? const <SupplyItem>[]
              : _supplies
                  .where((s) => s.name.toLowerCase().contains(typed.toLowerCase()))
                  .take(5)
                  .toList();

          return AlertDialog(
            title: const Text('新增物資'),
            content: SizedBox(
              width: 320,
              child: SingleChildScrollView(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                    labelText: '物資名稱',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onChanged: (v) => setDlgState(() => matched = _findSupplyByName(v)),
                ),
                if (suggestions.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 4, bottom: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final s in suggestions)
                          InkWell(
                            onTap: () => setDlgState(() {
                              nameCtrl.text = s.name;
                              matched = s;
                            }),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              child: Row(children: [
                                Expanded(child: Text(s.name)),
                                Text('庫存 ${s.stockQty} ${s.unit}',
                                    style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                              ]),
                            ),
                          ),
                      ],
                    ),
                  ),
                if (matched != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: _blue.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                        '目前庫存 ${matched!.stockQty} ${matched!.unit}，將直接補貨',
                        style: TextStyle(color: _blue, fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                if (matched == null) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: DropdownButtonFormField<String>(
                      value: selectedCat,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      items: _categories.skip(1)
                          .map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                      onChanged: (v) => setDlgState(() => selectedCat = v ?? selectedCat),
                    ),
                  ),
                  _input('單位', unitCtrl),
                ],
                _qtyInput(matched != null ? '補貨數量' : '新增數量', stockCtrl),
              ]),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
              ElevatedButton(
                onPressed: () async {
                  final qty = int.tryParse(stockCtrl.text.trim()) ?? 0;
                  final dup = matched;
                  Navigator.pop(context);
                  if (dup != null) {
                    final ok = await updateStock(itemId: dup.itemId, additionalQty: qty);
                    _snack(ok ? '已補貨至現有品項' : '補貨失敗', ok);
                    return;
                  }
                  final ok = await addSupply(
                    name: nameCtrl.text.trim(), category: selectedCat,
                    unit: unitCtrl.text.trim(), stockQty: qty,
                    neededQty: 0,
                  );
                  _snack(ok ? '新增成功' : '新增失敗', ok);
                },
                child: Text(matched != null ? '確認補貨' : '確認新增'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showUpdateStockDialog(SupplyItem item) {
    final qtyCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('補貨：${item.name}'),
        content: _qtyInput('補貨數量', qtyCtrl),
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
        content: _qtyInput('新需求量', neededCtrl),
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
            color: color,
            borderRadius: BorderRadius.circular(11),
            boxShadow: [
              BoxShadow(color: color.withValues(alpha: 0.32), blurRadius: 9, offset: const Offset(0, 3)),
            ],
          ),
          child: Icon(icon, color: Colors.white, size: 20),
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

  /// 數量輸入框：中間可手動輸入，左右各一顆加減按鈕
  Widget _qtyInput(String label, TextEditingController controller, {int step = 1, int min = 0}) {
    void bump(int delta) {
      final next = (int.tryParse(controller.text.trim()) ?? 0) + delta;
      controller.text = (next < min ? min : next).toString();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(children: [
        _qtyStepBtn(Icons.remove, () => bump(-step)),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              labelText: label,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(width: 8),
        _qtyStepBtn(Icons.add, () => bump(step)),
      ]),
    );
  }

  Widget _qtyStepBtn(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 44, height: 44,
        decoration: BoxDecoration(
          color: _blue.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, size: 20, color: _blue),
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
