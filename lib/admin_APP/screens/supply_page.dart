import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:flutter_disaster_app/core/models/supply.dart';
import 'package:flutter_disaster_app/core/models/allocation.dart';
import 'package:flutter_disaster_app/core/models/dispatch.dart';
import 'package:flutter_disaster_app/admin_APP/viewModels/supply_viewmodel.dart';
import 'package:flutter_disaster_app/admin_APP/viewModels/allocation_viewmodel.dart';

// ══════════════════════════════════════════════════════════
//  THEME
// ══════════════════════════════════════════════════════════
const Color _kBg          = Color(0xFFF5F7FA);
const Color _kCardBg      = Color(0xFFFFFFFF);
const Color _kCardBg2     = Color(0xFFF8FAFC);
const Color _kHighlight   = Color(0xFFEFF6FF);
const Color _kBorder      = Color(0xFFE5E7EB);
const Color _kBorderFocus = Color(0xFFBFDBFE);

const Color _kBlue   = Color(0xFF2563EB);
const Color _kGreen  = Color(0xFF16A34A);
const Color _kOrange = Color(0xFFF59E0B);
const Color _kRed    = Color(0xFFDC2626);
const Color _kPurple = Color(0xFF7C3AED);

const Color _kTextMain = Color(0xFF0F172A);
const Color _kTextSub  = Color(0xFF64748B);
const Color _kMuted    = Color(0xFF94A3B8);

enum _Tab { inventory, allocation, dispatch }

// 常見災難物資快速分類（含圖示）
const List<Map<String, dynamic>> _kQuickCategories = [
  {'label': '飲用水',   'icon': Icons.water_drop_outlined,       'color': _kBlue},
  {'label': '食物',     'icon': Icons.fastfood_outlined,          'color': _kOrange},
  {'label': '醫療',     'icon': Icons.medical_services_outlined,  'color': _kRed},
  {'label': '毛毯',     'icon': Icons.king_bed_outlined,          'color': _kPurple},
  {'label': '照明',     'icon': Icons.flashlight_on_outlined,     'color': _kOrange},
  {'label': '通訊',     'icon': Icons.radio_outlined,             'color': _kGreen},
];

// ══════════════════════════════════════════════════════════
//  SUPPLY PAGE
// ══════════════════════════════════════════════════════════
class SupplyPage extends StatefulWidget {
  const SupplyPage({super.key});

  @override
  State<SupplyPage> createState() => _SupplyPageState();
}

class _SupplyPageState extends State<SupplyPage>
    with SingleTickerProviderStateMixin {
  _Tab   _tab              = _Tab.inventory;
  late   TabController _tabCtrl;
  final  TextEditingController _searchCtrl = TextEditingController();
  String _keyword          = '';
  String _selectedCategory = '全部';
  bool   _showOnlyLow      = false; // ★ 低庫存快速篩選

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _tabCtrl.addListener(() {
      if (!_tabCtrl.indexIsChanging) return;
      setState(() => _tab = _Tab.values[_tabCtrl.index]);
    });
    Future.microtask(() {
      if (!mounted) return;
      context.read<AdminSupplyViewModel>().loadSupplies();
      context.read<AllocationViewModel>().loadAll();
    });
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: Column(children: [
          _buildHeader(),
          Expanded(child: _buildBody()),
        ]),
      ),
    );
  }

  // ──────────────────────────────────────────────────────
  //  HEADER（標題 + 右上角新增按鈕）
  // ──────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      decoration: const BoxDecoration(
        color:  _kCardBg,
        border: Border(bottom: BorderSide(color: _kBorder)),
      ),
      child: Column(children: [
        // 標題列
        Row(children: [
          Container(
            width: 46, height: 46,
            decoration: BoxDecoration(
              color:        _kGreen.withOpacity(.10),
              borderRadius: BorderRadius.circular(13),
              border:       Border.all(color: _kGreen.withOpacity(.18)),
            ),
            child: const Icon(Icons.inventory_2_rounded,
                color: _kGreen, size: 22),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('物資管理中心',
                      style: TextStyle(
                          color:      _kTextMain,
                          fontSize:   22,
                          fontWeight: FontWeight.w800)),
                  SizedBox(height: 2),
                  Text('SUPPLY MANAGEMENT CENTER',
                      style: TextStyle(
                          color:         _kTextSub,
                          fontSize:      11,
                          letterSpacing: 1.4)),
                ]),
          ),
          // ★ 已同步狀態
          Consumer<AdminSupplyViewModel>(
            builder: (_, vm, __) => _statusChip(
              vm.isLoading ? '同步中' : '已同步',
              vm.isLoading ? _kOrange : _kGreen,
            ),
          ),
          const SizedBox(width: 8),
          // ★ 新增物資按鈕（右上角，小巧）
          Consumer<AdminSupplyViewModel>(
            builder: (_, vm, __) => _addSupplyBtn(vm),
          ),
          const SizedBox(width: 8),
          _iconBtn(Icons.refresh_rounded, _kTextSub, () {
            context.read<AdminSupplyViewModel>().loadSupplies();
            context.read<AllocationViewModel>().loadAll();
          }),
        ]),
        const SizedBox(height: 14),
        // ★ Tab Bar 放在 Header 底部（跟內容區貼近）
        TabBar(
          controller:           _tabCtrl,
          indicatorColor:       _kBlue,
          indicatorWeight:      2.5,
          indicatorSize:        TabBarIndicatorSize.label,
          labelColor:           _kBlue,
          unselectedLabelColor: _kTextSub,
          dividerColor:         Colors.transparent,
          labelStyle: const TextStyle(
              fontSize: 13, fontWeight: FontWeight.w700),
          unselectedLabelStyle:
              const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          tabs: const [
            Tab(icon: Icon(Icons.inventory_2_outlined,   size: 15), text: '庫存管理'),
            Tab(icon: Icon(Icons.share_outlined,          size: 15), text: '物資分配'),
            Tab(icon: Icon(Icons.local_shipping_outlined, size: 15), text: '出貨紀錄'),
          ],
        ),
      ]),
    );
  }

  // ★ 右上角新增物資按鈕（小巧不搶眼）
  Widget _addSupplyBtn(AdminSupplyViewModel vm) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => _showAddSupplyDialog(vm),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color:        _kGreen.withOpacity(.08),
          borderRadius: BorderRadius.circular(8),
          border:       Border.all(color: _kGreen.withOpacity(.22)),
        ),
        child: const Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.add_rounded, color: _kGreen, size: 16),
          SizedBox(width: 5),
          Text('新增物資',
              style: TextStyle(
                  color:      _kGreen,
                  fontSize:   12,
                  fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }

  // ──────────────────────────────────────────────────────
  //  BODY
  // ──────────────────────────────────────────────────────
  Widget _buildBody() {
    switch (_tab) {
      case _Tab.inventory:  return _buildInventoryTab();
      case _Tab.allocation: return _buildAllocationTab();
      case _Tab.dispatch:   return _buildDispatchTab();
    }
  }

  // ══════════════════════════════════════════════════════
  //  TAB 1 — 庫存管理
  // ══════════════════════════════════════════════════════
  Widget _buildInventoryTab() {
    return Consumer<AdminSupplyViewModel>(
      builder: (_, vm, __) {
        if (vm.isLoading)
          return const Center(
              child: CircularProgressIndicator(color: _kBlue));
        if (vm.errorMessage != null)
          return _buildError(vm.errorMessage!, () => vm.loadSupplies());

        final categories = [
          '全部',
          ...vm.supplies.map((e) => e.category).toSet().toList()..sort(),
        ];

        final filtered = vm.supplies.where((item) {
          final matchCat = _selectedCategory == '全部' ||
              item.category == _selectedCategory;
          final key      = _keyword.trim().toLowerCase();
          final matchKey = key.isEmpty ||
              item.name.toLowerCase().contains(key) ||
              item.category.toLowerCase().contains(key);
          final matchLow = !_showOnlyLow || item.stockQty < item.neededQty;
          return matchCat && matchKey && matchLow;
        }).toList();

        // 低庫存排前面
        filtered.sort((a, b) {
          final aLow = a.stockQty < a.neededQty ? 0 : 1;
          final bLow = b.stockQty < b.neededQty ? 0 : 1;
          return aLow.compareTo(bLow);
        });

        final totalStock =
            vm.supplies.fold(0, (s, e) => s + e.stockQty);
        final lowCount =
            vm.supplies.where((e) => e.stockQty < e.neededQty).length;

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ★ 統計卡（低庫存可點擊篩選）
                _buildStatsRow(vm.supplies.length, totalStock, lowCount),
                const SizedBox(height: 18),

                // ★ 快速分類（災難常用物資）
                if (vm.supplies.isNotEmpty) ...[
                  _buildQuickCategoryRow(vm),
                  const SizedBox(height: 16),
                ],

                // 搜尋列
                _buildSearchBar(),
                const SizedBox(height: 12),

                // 分類 chips
                _buildCategoryChips(categories),
                const SizedBox(height: 14),

                // 低庫存篩選提示
                if (_showOnlyLow)
                  _buildLowStockBanner(lowCount),
                if (_showOnlyLow) const SizedBox(height: 10),

                // 物資列表
                if (filtered.isEmpty)
                  _buildEmptyState(
                    vm.supplies.isEmpty
                        ? '沒有符合條件的物資'
                        : '目前沒有低庫存物資',
                  )
                else
                  ...filtered.map((item) => _buildInventoryCard(item, vm)),
              ]),
        );
      },
    );
  }

  // ★ 統計卡（低庫存卡片可點擊）
  Widget _buildStatsRow(int kinds, int total, int low) {
    return Row(children: [
      Expanded(child: _statCard('物資種類',   '$kinds',
          Icons.category_rounded,      _kBlue,   '項目',
          onTap: null)),
      const SizedBox(width: 12),
      Expanded(child: _statCard('總庫存量',   '$total',
          Icons.warehouse_rounded,     _kGreen,  '單位',
          onTap: null)),
      const SizedBox(width: 12),
      // ★ 低庫存卡點擊直接篩選
      Expanded(child: _statCard('低庫存警示', '$low',
          Icons.warning_amber_rounded, _kOrange, '項目',
          onTap: low > 0 ? () {
            setState(() {
              _showOnlyLow      = !_showOnlyLow;
              _selectedCategory = '全部';
              _keyword          = '';
              _searchCtrl.clear();
            });
          } : null,
          isActive: _showOnlyLow)),
    ]);
  }

  Widget _statCard(String title, String value, IconData icon,
      Color color, String unit,
      {VoidCallback? onTap, bool isActive = false}) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color:        isActive ? color.withOpacity(.06) : _kCardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: isActive ? color.withOpacity(.35) : _kBorder,
              width: isActive ? 1.5 : 1),
          boxShadow: [
            BoxShadow(
                color:      Colors.black.withOpacity(.035),
                blurRadius: 10,
                offset:     const Offset(0, 3)),
          ],
        ),
        child: Row(children: [
          Container(
              width: 3, height: 54,
              decoration: BoxDecoration(
                  color:        color,
                  borderRadius: BorderRadius.circular(4))),
          const SizedBox(width: 13),
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
                color:        color.withOpacity(.10),
                borderRadius: BorderRadius.circular(11)),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value,
                      style: TextStyle(
                          color:      color,
                          fontSize:   26,
                          fontWeight: FontWeight.w900,
                          height:     1)),
                  const SizedBox(height: 4),
                  Text(title,
                      style: const TextStyle(
                          color: _kTextSub, fontSize: 12)),
                ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            _badge(unit, color),
            if (onTap != null) ...[
              const SizedBox(height: 4),
              Text(
                isActive ? '取消篩選' : '點擊篩選',
                style: TextStyle(
                    color:    color.withOpacity(.6),
                    fontSize: 9),
              ),
            ],
          ]),
        ]),
      ),
    );
  }

  // ★ 快速分類列（常見災難物資）
  Widget _buildQuickCategoryRow(AdminSupplyViewModel vm) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('快速分類',
          style: TextStyle(
              color:      _kTextSub,
              fontSize:   12,
              fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _kQuickCategories.map((cat) {
            final label = cat['label'] as String;
            final icon  = cat['icon']  as IconData;
            final color = cat['color'] as Color;
            final count = vm.supplies
                .where((s) => s.category.contains(label))
                .length;
            final sel   = _selectedCategory == label;

            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => setState(() =>
                    _selectedCategory = sel ? '全部' : label),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 140),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: sel
                        ? color.withOpacity(.10)
                        : _kCardBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: sel
                            ? color.withOpacity(.35)
                            : _kBorder),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min,
                      children: [
                    Icon(icon, color: color, size: 15),
                    const SizedBox(width: 6),
                    Text(label,
                        style: TextStyle(
                            color:      sel ? color : _kTextSub,
                            fontSize:   12,
                            fontWeight: sel
                                ? FontWeight.w700
                                : FontWeight.w500)),
                    if (count > 0) ...[
                      const SizedBox(width: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                            color:        color.withOpacity(.12),
                            borderRadius: BorderRadius.circular(4)),
                        child: Text('$count',
                            style: TextStyle(
                                color:      color,
                                fontSize:   9,
                                fontWeight: FontWeight.w800)),
                      ),
                    ],
                  ]),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    ]);
  }

  // ★ 低庫存篩選提示橫幅
  Widget _buildLowStockBanner(int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color:        _kOrange.withOpacity(.06),
        borderRadius: BorderRadius.circular(8),
        border:       Border.all(color: _kOrange.withOpacity(.22)),
      ),
      child: Row(children: [
        const Icon(Icons.warning_amber_rounded,
            color: _kOrange, size: 15),
        const SizedBox(width: 8),
        Text('顯示 $count 項低庫存物資',
            style: const TextStyle(
                color:      _kOrange,
                fontSize:   12,
                fontWeight: FontWeight.w600)),
        const Spacer(),
        GestureDetector(
          onTap: () => setState(() => _showOnlyLow = false),
          child: const Text('清除篩選',
              style: TextStyle(
                  color:      _kOrange,
                  fontSize:   11,
                  fontWeight: FontWeight.w700)),
        ),
      ]),
    );
  }

  // ── 搜尋列 ────────────────────────────────────────────
  Widget _buildSearchBar() {
    return Container(
      height: 44,
      decoration: BoxDecoration(
          color:        _kCardBg,
          borderRadius: BorderRadius.circular(10),
          border:       Border.all(color: _kBorder)),
      child: TextField(
        controller: _searchCtrl,
        onChanged:  (v) => setState(() => _keyword = v),
        style: const TextStyle(color: _kTextMain, fontSize: 13),
        decoration: InputDecoration(
          hintText:  '搜尋物資名稱 / 分類...',
          hintStyle: const TextStyle(color: _kMuted, fontSize: 13),
          prefixIcon: const Icon(Icons.search_rounded,
              color: _kMuted, size: 18),
          suffixIcon: _keyword.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close_rounded,
                      color: _kMuted, size: 16),
                  onPressed: () {
                    _searchCtrl.clear();
                    setState(() => _keyword = '');
                  })
              : null,
          border:         InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 11),
        ),
      ),
    );
  }

  // ── 分類 chips ────────────────────────────────────────
  Widget _buildCategoryChips(List<String> categories) {
    return Wrap(
      spacing: 6, runSpacing: 6,
      children: categories.map((cat) {
        final sel = _selectedCategory == cat;
        return InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => setState(() {
            _selectedCategory = cat;
            _showOnlyLow      = false;
          }),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            padding:  const EdgeInsets.symmetric(
                horizontal: 13, vertical: 6),
            decoration: BoxDecoration(
              color: sel ? _kHighlight : _kCardBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: sel ? _kBorderFocus : _kBorder),
            ),
            child: Text(cat,
                style: TextStyle(
                    color:      sel ? _kBlue : _kTextSub,
                    fontSize:   12,
                    fontWeight: sel
                        ? FontWeight.w700
                        : FontWeight.w500)),
          ),
        );
      }).toList(),
    );
  }

  // ── 物資卡片 ──────────────────────────────────────────
  Widget _buildInventoryCard(
      SupplyItem item, AdminSupplyViewModel vm) {
    final isLow = item.stockQty < item.neededQty;
    final color = isLow ? _kOrange : _kGreen;
    final pct   = item.neededQty > 0
        ? (item.stockQty / item.neededQty).clamp(0.0, 1.0)
        : 1.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color:        _kCardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: isLow
                ? _kOrange.withOpacity(.22)
                : _kBorder),
        boxShadow: [
          BoxShadow(
              color:      Colors.black.withOpacity(.04),
              blurRadius: 10,
              offset:     const Offset(0, 3)),
        ],
      ),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 46, height: 46,
                  decoration: BoxDecoration(
                      color:        color.withOpacity(.10),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: color.withOpacity(.16))),
                  child: Icon(
                    isLow
                        ? Icons.warning_amber_rounded
                        : Icons.inventory_2_outlined,
                    color: color, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Expanded(
                            child: Text(item.name,
                                style: const TextStyle(
                                    color:      _kTextMain,
                                    fontSize:   15,
                                    fontWeight: FontWeight.w800)),
                          ),
                          _statusBadge(
                              isLow ? '庫存不足' : '庫存充足', color),
                        ]),
                        const SizedBox(height: 6),
                        Wrap(spacing: 5, runSpacing: 4, children: [
                          _miniTag(item.category,       _kBlue),
                          _miniTag('單位：${item.unit}', _kTextSub),
                          _miniTag('ID ${item.itemId}',  _kMuted),
                        ]),
                        const SizedBox(height: 12),
                        Row(children: [
                          _quantityBox('庫存',
                              '${item.stockQty}',  _kGreen),
                          const SizedBox(width: 8),
                          _quantityBox('需求',
                              '${item.neededQty}', _kOrange),
                          if (isLow) ...[
                            const SizedBox(width: 8),
                            _quantityBox(
                                '缺口',
                                '${item.neededQty - item.stockQty}',
                                _kRed),
                          ],
                        ]),
                      ]),
                ),
                const SizedBox(width: 10),
                Column(children: [
                  _actionBtn('補貨', Icons.add_circle_outline,
                      _kBlue,
                      () => _showUpdateStockDialog(item, vm)),
                  const SizedBox(height: 6),
                  _actionBtn('需求', Icons.edit_outlined,
                      _kPurple,
                      () => _showUpdateNeededDialog(item, vm)),
                ]),
              ]),
        ),
        ClipRRect(
          borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(14)),
          child: LinearProgressIndicator(
            value:           pct,
            minHeight:       4,
            backgroundColor: _kBorder,
            valueColor: AlwaysStoppedAnimation<Color>(
                isLow ? _kOrange : _kGreen),
          ),
        ),
      ]),
    );
  }

  Widget _quantityBox(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
          color:        color.withOpacity(.08),
          borderRadius: BorderRadius.circular(8),
          border:       Border.all(color: color.withOpacity(.16))),
      child: Column(children: [
        Text(value,
            style: TextStyle(
                color:      color,
                fontSize:   16,
                fontWeight: FontWeight.w900)),
        const SizedBox(height: 1),
        Text(label,
            style: const TextStyle(
                color: _kTextSub, fontSize: 10)),
      ]),
    );
  }

  Widget _miniTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
          color:        color.withOpacity(.08),
          borderRadius: BorderRadius.circular(5),
          border:       Border.all(color: color.withOpacity(.14))),
      child: Text(text,
          style: TextStyle(
              color:      color,
              fontSize:   10,
              fontWeight: FontWeight.w600)),
    );
  }

  // ══════════════════════════════════════════════════════
  //  TAB 2 — 物資分配
  // ══════════════════════════════════════════════════════
  Widget _buildAllocationTab() {
    return Consumer<AllocationViewModel>(
      builder: (_, vm, __) {
        if (vm.isLoading)
          return const Center(
              child: CircularProgressIndicator(color: _kBlue));
        if (vm.errorMessage != null)
          return _buildError(vm.errorMessage!, () => vm.loadAll());

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildAllocateButton(vm),
                const SizedBox(height: 20),
                if (vm.allocations.isEmpty)
                  _buildEmptyState('尚無分配紀錄')
                else ...[
                  _sectionLabel(Icons.list_alt_rounded,
                      '分配紀錄（${vm.allocations.length} 筆）'),
                  const SizedBox(height: 10),
                  ...vm.allocations
                      .map((a) => _buildAllocationCard(a, vm)),
                ],
              ]),
        );
      },
    );
  }

  Widget _buildAllocateButton(AllocationViewModel vm) {
    final enabled = vm.supplies.isNotEmpty;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: enabled ? () => _showAllocateDialog(vm) : null,
      child: Container(
        width: double.infinity, height: 44,
        decoration: BoxDecoration(
          color:        _kBlue.withOpacity(enabled ? .06 : .03),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: _kBlue.withOpacity(enabled ? .20 : .08)),
        ),
        child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.share_outlined,
                  color: enabled ? _kBlue : _kMuted, size: 17),
              const SizedBox(width: 8),
              Text('新增物資分配',
                  style: TextStyle(
                      color:      enabled ? _kBlue : _kMuted,
                      fontSize:   13,
                      fontWeight: FontWeight.w700)),
            ]),
      ),
    );
  }

  Widget _buildAllocationCard(
      AllocationItem a, AllocationViewModel vm) {
    final dispatched = a.dispatched;
    final color      = dispatched ? _kMuted : _kBlue;

    return _card(
      padding: const EdgeInsets.all(14),
      child: Row(children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
              color:        color.withOpacity(.10),
              borderRadius: BorderRadius.circular(10),
              border:       Border.all(color: color.withOpacity(.16))),
          child: Icon(
              dispatched
                  ? Icons.check_circle_outline
                  : Icons.share_outlined,
              color: color, size: 19),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text('分配 #${a.allocationId}',
                      style: const TextStyle(
                          color:      _kTextMain,
                          fontWeight: FontWeight.w700,
                          fontSize:   14)),
                  const SizedBox(width: 8),
                  _statusBadge(
                      dispatched ? '已出貨' : '待出貨', color),
                ]),
                const SizedBox(height: 6),
                Wrap(spacing: 5, runSpacing: 4, children: [
                  _miniTag('物資 #${a.itemId}', _kBlue),
                  _miniTag('區域 ${a.zoneId}',  _kPurple),
                  _miniTag('數量 ${a.qty}',      _kGreen),
                ]),
              ]),
        ),
        if (!dispatched) ...[
          const SizedBox(width: 10),
          _actionBtn('出貨', Icons.local_shipping_outlined,
              _kGreen,
              () => _confirmDispatch(a.allocationId, vm)),
        ],
      ]),
    );
  }

  // ══════════════════════════════════════════════════════
  //  TAB 3 — 出貨紀錄
  // ══════════════════════════════════════════════════════
  Widget _buildDispatchTab() {
    return Consumer<AllocationViewModel>(
      builder: (_, vm, __) {
        if (vm.isLoading)
          return const Center(
              child: CircularProgressIndicator(color: _kBlue));
        if (vm.errorMessage != null)
          return _buildError(vm.errorMessage!, () => vm.loadAll());

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (vm.dispatches.isEmpty)
                  _buildEmptyState('尚無出貨紀錄')
                else ...[
                  _sectionLabel(Icons.local_shipping_outlined,
                      '出貨紀錄（${vm.dispatches.length} 筆）'),
                  const SizedBox(height: 10),
                  ...vm.dispatches.map(_buildDispatchCard),
                ],
              ]),
        );
      },
    );
  }

  Widget _buildDispatchCard(DispatchItem d) {
    return _card(
      padding: const EdgeInsets.all(14),
      child: Row(children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
              color:        _kGreen.withOpacity(.10),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _kGreen.withOpacity(.16))),
          child: const Icon(Icons.local_shipping_outlined,
              color: _kGreen, size: 19),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text('出貨 #${d.dispatchId}',
                      style: const TextStyle(
                          color:      _kTextMain,
                          fontWeight: FontWeight.w700,
                          fontSize:   14)),
                  const SizedBox(width: 8),
                  _statusBadge('已完成', _kGreen),
                ]),
                const SizedBox(height: 6),
                Wrap(spacing: 5, runSpacing: 4, children: [
                  _miniTag('分配 #${d.allocationId}', _kBlue),
                  if (d.dispatchedAt.isNotEmpty)
                    _miniTag(d.dispatchedAt, _kTextSub),
                ]),
              ]),
        ),
      ]),
    );
  }

  // ══════════════════════════════════════════════════════
  //  DIALOGS
  // ══════════════════════════════════════════════════════
  void _showAddSupplyDialog(AdminSupplyViewModel vm) {
    final nameCtrl     = TextEditingController();
    final categoryCtrl = TextEditingController();
    final unitCtrl     = TextEditingController();
    final stockCtrl    = TextEditingController();
    final neededCtrl   = TextEditingController();
    _showFormDialog(
      title:  '新增物資',
      icon:   Icons.add_rounded,
      color:  _kGreen,
      fields: [
        _FormField('物資名稱',        nameCtrl),
        _FormField('分類',            categoryCtrl),
        _FormField('單位',            unitCtrl),
        _FormField('初始庫存（數字）', stockCtrl,  isNumber: true),
        _FormField('需求量（數字）',  neededCtrl, isNumber: true),
      ],
      onConfirm: () async {
        final ok = await vm.addSupply(
          name:      nameCtrl.text.trim(),
          category:  categoryCtrl.text.trim(),
          unit:      unitCtrl.text.trim(),
          stockQty:  int.tryParse(stockCtrl.text.trim())  ?? 0,
          neededQty: int.tryParse(neededCtrl.text.trim()) ?? 0,
        );
        _showResultSnack(ok, '新增成功', '新增失敗');
      },
    );
  }

  void _showUpdateStockDialog(
      SupplyItem item, AdminSupplyViewModel vm) {
    final ctrl = TextEditingController();
    _showFormDialog(
      title:  '補貨 — ${item.name}',
      icon:   Icons.add_circle_outline,
      color:  _kBlue,
      fields: [_FormField('補充數量（正整數）', ctrl, isNumber: true)],
      onConfirm: () async {
        final ok = await vm.updateStock(
            itemId: item.itemId,
            qty:    int.tryParse(ctrl.text.trim()) ?? 0);
        _showResultSnack(ok, '補貨成功', '補貨失敗');
      },
    );
  }

  void _showUpdateNeededDialog(
      SupplyItem item, AdminSupplyViewModel vm) {
    final ctrl =
        TextEditingController(text: '${item.neededQty}');
    _showFormDialog(
      title:  '修改需求量 — ${item.name}',
      icon:   Icons.edit_outlined,
      color:  _kPurple,
      fields: [_FormField('新需求量', ctrl, isNumber: true)],
      onConfirm: () async {
        final ok = await vm.updateNeeded(
            itemId:    item.itemId,
            neededQty: int.tryParse(ctrl.text.trim()) ??
                item.neededQty);
        _showResultSnack(ok, '更新成功', '更新失敗');
      },
    );
  }

  void _showAllocateDialog(AllocationViewModel vm) {
    SupplyItem? sel =
        vm.supplies.isNotEmpty ? vm.supplies.first : null;
    final zoneCtrl = TextEditingController();
    final qtyCtrl  = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => _dialogShell(
          title: '新增物資分配',
          icon:  Icons.share_outlined,
          color: _kBlue,
          child: Column(children: [
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 2),
              decoration: BoxDecoration(
                  color:        _kCardBg2,
                  borderRadius: BorderRadius.circular(10),
                  border:       Border.all(color: _kBorder)),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<SupplyItem>(
                  isExpanded:    true,
                  dropdownColor: _kCardBg,
                  value:         sel,
                  style: const TextStyle(
                      color: _kTextMain, fontSize: 13),
                  icon: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: _kTextSub, size: 18),
                  items: vm.supplies
                      .map((s) => DropdownMenuItem(
                            value: s,
                            child: Text(
                                '${s.name}（庫存 ${s.stockQty} ${s.unit}）'),
                          ))
                      .toList(),
                  onChanged: (v) => setS(() => sel = v),
                ),
              ),
            ),
            const SizedBox(height: 12),
            _inputField('目標區域（例：A區）', zoneCtrl),
            const SizedBox(height: 12),
            _inputField('分配數量', qtyCtrl, isNumber: true),
            const SizedBox(height: 20),
            _confirmButton('確認分配', _kBlue, () async {
              if (sel == null) return;
              Navigator.pop(context);
              final ok = await vm.allocate(
                  itemId: sel!.itemId,
                  zoneId: zoneCtrl.text.trim(),
                  qty: int.tryParse(qtyCtrl.text.trim()) ?? 0);
              _showResultSnack(ok, '分配成功', '分配失敗');
            }),
          ]),
        ),
      ),
    );
  }

  Future<void> _confirmDispatch(
      int allocationId, AllocationViewModel vm) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _kCardBg,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14)),
        title: const Row(children: [
          Icon(Icons.local_shipping_outlined,
              color: _kGreen, size: 20),
          SizedBox(width: 10),
          Text('確認出貨？',
              style: TextStyle(
                  color:      _kTextMain,
                  fontSize:   17,
                  fontWeight: FontWeight.w800)),
        ]),
        content: Text(
            '分配 #$allocationId 將標記為已出貨，並扣除對應庫存。',
            style: const TextStyle(
                color: _kTextSub, fontSize: 13)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消',
                  style: TextStyle(color: _kTextSub))),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon:  const Icon(Icons.check_rounded, size: 15),
            label: const Text('確認出貨'),
            style: ElevatedButton.styleFrom(
                backgroundColor: _kGreen,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8))),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      final ok = await vm.dispatch(allocationId);
      _showResultSnack(ok, '出貨成功', '出貨失敗');
    }
  }

  // ── 表單對話框通用 ────────────────────────────────────
  void _showFormDialog({
    required String              title,
    required IconData            icon,
    required Color               color,
    required List<_FormField>    fields,
    required Future<void> Function() onConfirm,
  }) {
    showDialog(
      context: context,
      builder: (_) => _dialogShell(
        title: title, icon: icon, color: color,
        child: Column(children: [
          ...fields.map((f) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child:   _inputField(f.label, f.controller,
                    isNumber: f.isNumber),
              )),
          const SizedBox(height: 8),
          _confirmButton('確認送出', color, () async {
            Navigator.pop(context);
            await onConfirm();
          }),
        ]),
      ),
    );
  }

  Widget _dialogShell({
    required String   title,
    required IconData icon,
    required Color    color,
    required Widget   child,
  }) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width:   460,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color:        _kCardBg,
          borderRadius: BorderRadius.circular(16),
          border:       Border.all(color: _kBorder),
          boxShadow: [
            BoxShadow(
                color:      Colors.black.withOpacity(.10),
                blurRadius: 24,
                offset:     const Offset(0, 8)),
          ],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                  color:        color.withOpacity(.10),
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(
                      color: color.withOpacity(.20))),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(title,
                  style: const TextStyle(
                      color:      _kTextMain,
                      fontSize:   16,
                      fontWeight: FontWeight.w800)),
            ),
            IconButton(
              onPressed:   () => Navigator.pop(context),
              icon: const Icon(Icons.close,
                  color: _kTextSub, size: 17),
              padding:     EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ]),
          const SizedBox(height: 6),
          const Divider(color: _kBorder),
          const SizedBox(height: 14),
          child,
        ]),
      ),
    );
  }

  Widget _inputField(String hint, TextEditingController ctrl,
      {bool isNumber = false}) {
    return Container(
      decoration: BoxDecoration(
          color:        _kCardBg2,
          borderRadius: BorderRadius.circular(10),
          border:       Border.all(color: _kBorder)),
      child: TextField(
        controller:   ctrl,
        keyboardType: isNumber
            ? TextInputType.number
            : TextInputType.text,
        style: const TextStyle(color: _kTextMain, fontSize: 13),
        decoration: InputDecoration(
          hintText:  hint,
          hintStyle: const TextStyle(color: _kMuted, fontSize: 12),
          border:    InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 13),
        ),
      ),
    );
  }

  Widget _confirmButton(
      String label, Color color, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity, height: 46,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
        ),
        child: Text(label,
            style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize:   14)),
      ),
    );
  }

  // ── 共用 Widgets ──────────────────────────────────────
  Widget _buildError(String msg, VoidCallback onRetry) {
    return Center(
      child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                color:  _kRed.withOpacity(.08),
                shape:  BoxShape.circle,
                border: Border.all(color: _kRed.withOpacity(.18)),
              ),
              child: const Icon(Icons.error_outline,
                  color: _kRed, size: 26),
            ),
            const SizedBox(height: 14),
            Text(msg,
                style: const TextStyle(color: _kRed, fontSize: 13)),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon:  const Icon(Icons.refresh, size: 15),
              label: const Text('重試'),
              style: OutlinedButton.styleFrom(
                  foregroundColor: _kBlue,
                  side: BorderSide(color: _kBlue.withOpacity(.28))),
            ),
          ]),
    );
  }

  Widget _buildEmptyState(String text) {
    return _card(
      padding: const EdgeInsets.all(40),
      child: Column(children: [
        Container(
          width: 58, height: 58,
          decoration: BoxDecoration(
              color:  _kCardBg2,
              shape:  BoxShape.circle,
              border: Border.all(color: _kBorder)),
          child: const Icon(Icons.inventory_2_outlined,
              size: 26, color: _kMuted),
        ),
        const SizedBox(height: 14),
        Text(text,
            style: const TextStyle(
                color:      _kTextSub,
                fontSize:   14,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 5),
        const Text('後端開啟後資料將自動載入',
            style: TextStyle(color: _kMuted, fontSize: 12)),
      ]),
    );
  }

  static Widget _statusBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
          color:        color.withOpacity(.08),
          borderRadius: BorderRadius.circular(999),
          border:       Border.all(color: color.withOpacity(.18))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width:  6, height: 6,
            decoration: BoxDecoration(
                color: color, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text(text,
            style: TextStyle(
                color:      color,
                fontSize:   10,
                fontWeight: FontWeight.w700)),
      ]),
    );
  }

  Widget _actionBtn(String label, IconData icon,
      Color color, VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
            color:        color.withOpacity(.07),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withOpacity(.16))),
        child: Column(children: [
          Icon(icon, color: color, size: 15),
          const SizedBox(height: 3),
          Text(label,
              style: TextStyle(
                  color:      color,
                  fontSize:   10,
                  fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }

  void _showResultSnack(bool success, String ok, String fail) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: success ? _kGreen : _kRed,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8)),
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      duration: const Duration(seconds: 2),
      content: Row(children: [
        Icon(
          success
              ? Icons.check_circle_outline
              : Icons.error_outline,
          color: Colors.white, size: 17),
        const SizedBox(width: 8),
        Text(success ? ok : fail,
            style: const TextStyle(
                color:      Colors.white,
                fontWeight: FontWeight.w700)),
      ]),
    ));
  }
}

// ══════════════════════════════════════════════════════════
//  FILE-LEVEL HELPERS
// ══════════════════════════════════════════════════════════
Widget _card({
  required Widget child,
  EdgeInsetsGeometry padding = const EdgeInsets.all(14),
  double? height,
}) {
  return Container(
    height:     height,
    padding:    padding,
    decoration: BoxDecoration(
      color:        _kCardBg,
      borderRadius: BorderRadius.circular(14),
      border:       Border.all(color: _kBorder),
      boxShadow: [
        BoxShadow(
            color:      Colors.black.withOpacity(.035),
            blurRadius: 10,
            offset:     const Offset(0, 3)),
      ],
    ),
    child: child,
  );
}

Widget _badge(String text, Color color) {
  return Container(
    padding: const EdgeInsets.symmetric(
        horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
        color:        color.withOpacity(.10),
        borderRadius: BorderRadius.circular(6)),
    child: Text(text,
        style: TextStyle(
            color:      color,
            fontSize:   10,
            fontWeight: FontWeight.w700)),
  );
}

Widget _statusChip(String text, Color color) {
  return Container(
    padding: const EdgeInsets.symmetric(
        horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
        color:        color.withOpacity(.08),
        borderRadius: BorderRadius.circular(20),
        border:       Border.all(color: color.withOpacity(.18))),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
          width:  6, height: 6,
          decoration: BoxDecoration(
              color: color, shape: BoxShape.circle)),
      const SizedBox(width: 6),
      Text(text,
          style: TextStyle(
              color:      color,
              fontSize:   11,
              fontWeight: FontWeight.w700)),
    ]),
  );
}

Widget _iconBtn(IconData icon, Color color, VoidCallback onTap) {
  return InkWell(
    borderRadius: BorderRadius.circular(8),
    onTap: onTap,
    child: Container(
      width: 36, height: 36,
      decoration: BoxDecoration(
          color:        _kCardBg2,
          borderRadius: BorderRadius.circular(8),
          border:       Border.all(color: _kBorder)),
      child: Icon(icon, color: color, size: 17),
    ),
  );
}

Widget _sectionLabel(IconData icon, String text) {
  return Row(children: [
    Icon(icon, color: _kMuted, size: 14),
    const SizedBox(width: 6),
    Text(text,
        style: const TextStyle(
            color:      _kTextSub,
            fontSize:   13,
            fontWeight: FontWeight.w600)),
  ]);
}

// ══════════════════════════════════════════════════════════
//  FORM FIELD DATA CLASS
// ══════════════════════════════════════════════════════════
class _FormField {
  final String                label;
  final TextEditingController controller;
  final bool                  isNumber;
  const _FormField(this.label, this.controller,
      {this.isNumber = false});
}