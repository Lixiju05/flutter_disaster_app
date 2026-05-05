import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_disaster_app/core/models/supply.dart';
import 'package:flutter_disaster_app/admin_APP/viewModels/supply_viewmodel.dart';

const Color _kBg = Color(0xFF07131F);
const Color _kCardBg = Color(0xFF0A1826);
const Color _kCardBg2 = Color(0xFF0D2133);
const Color _kCyan = Color(0xFF00C8FF);
const Color _kGreen = Color(0xFF00D09C);
const Color _kMuted = Color(0xFF5C7896);
const Color _kBorder = Color(0xFF123047);
const Color _kAmber = Color(0xFFFFC107);
const Color _kRed = Color(0xFFFF4C4C);
const Color _kPurple = Color(0xFF7D5CFF);

class SupplyPage extends StatefulWidget {
  const SupplyPage({super.key});

  @override
  State<SupplyPage> createState() => _SupplyPageState();
}

class _SupplyPageState extends State<SupplyPage> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedCategory = '全部';

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      context.read<AdminSupplyViewModel>().loadSupplies();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<String> _categories(List<SupplyItem> supplies) {
    final names = supplies
        .map((e) => e.category)
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();
    names.sort();
    return ['全部', ...names];
  }

  List<SupplyItem> _filteredItems(List<SupplyItem> supplies) {
    final keyword = _searchController.text.trim().toLowerCase();

    return supplies.where((item) {
      final matchKeyword = item.name.toLowerCase().contains(keyword) ||
          item.category.toLowerCase().contains(keyword);

      final matchCategory =
          _selectedCategory == '全部' || item.category == _selectedCategory;

      return matchKeyword && matchCategory;
    }).toList();
  }

  int _totalQuantity(List<SupplyItem> supplies) {
    return supplies.fold(0, (sum, item) => sum + item.stockQty);
  }

  int _lowStockCount(List<SupplyItem> supplies) {
    return supplies.where((item) => item.isLowStock).length;
  }

  Future<void> _showAddDialog() async {
    final nameController = TextEditingController();
    final categoryController = TextEditingController();
    final unitController = TextEditingController(text: '個');
    final stockController = TextEditingController();
    final neededController = TextEditingController();
    final vm = context.read<AdminSupplyViewModel>();

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: _kCardBg,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Text(
            '新增物資',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _dialogInput(nameController, '物資名稱'),
                const SizedBox(height: 12),
                _dialogInput(categoryController, '分類，例如：食品 / 醫療 / 生活用品'),
                const SizedBox(height: 12),
                _dialogInput(unitController, '單位，例如：瓶 / 包 / 個'),
                const SizedBox(height: 12),
                _dialogInput(stockController, '目前庫存', number: true),
                const SizedBox(height: 12),
                _dialogInput(neededController, '需求量', number: true),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('取消', style: TextStyle(color: _kMuted)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _kCyan,
                foregroundColor: Colors.black,
              ),
              onPressed: () async {
                final name = nameController.text.trim();
                final category = categoryController.text.trim();
                final unit = unitController.text.trim();
                final stockQty =
                    int.tryParse(stockController.text.trim()) ?? 0;
                final neededQty =
                    int.tryParse(neededController.text.trim()) ?? 0;

                if (name.isEmpty || category.isEmpty || unit.isEmpty) return;

                final success = await vm.addSupply(
                  name: name,
                  category: category,
                  unit: unit,
                  stockQty: stockQty,
                  neededQty: neededQty,
                );

                if (!mounted) return;

                if (success) {
                  Navigator.pop(dialogContext);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('新增物資成功')),
                  );
                }
              },
              child: const Text('新增'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showStockDialog(SupplyItem item) async {
    final qtyController = TextEditingController();
    final vm = context.read<AdminSupplyViewModel>();

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: _kCardBg,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Text(
            '補貨：${item.name}',
            style: const TextStyle(color: Colors.white),
          ),
          content: _dialogInput(qtyController, '補貨數量', number: true),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('取消', style: TextStyle(color: _kMuted)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _kGreen,
                foregroundColor: Colors.black,
              ),
              onPressed: () async {
                final qty = int.tryParse(qtyController.text.trim()) ?? 0;
                if (qty <= 0) return;

                final success =
                    await vm.updateStock(itemId: item.itemId, qty: qty);

                if (!mounted) return;

                if (success) {
                  Navigator.pop(dialogContext);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('補貨成功')),
                  );
                }
              },
              child: const Text('確認補貨'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showNeededDialog(SupplyItem item) async {
    final neededController =
        TextEditingController(text: item.neededQty.toString());
    final vm = context.read<AdminSupplyViewModel>();

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: _kCardBg,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Text(
            '修改需求量：${item.name}',
            style: const TextStyle(color: Colors.white),
          ),
          content: _dialogInput(neededController, '新的需求量', number: true),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('取消', style: TextStyle(color: _kMuted)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _kCyan,
                foregroundColor: Colors.black,
              ),
              onPressed: () async {
                final neededQty =
                    int.tryParse(neededController.text.trim()) ?? 0;

                final success = await vm.updateNeeded(
                  itemId: item.itemId,
                  neededQty: neededQty,
                );

                if (!mounted) return;

                if (success) {
                  Navigator.pop(dialogContext);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('需求量已更新')),
                  );
                }
              },
              child: const Text('儲存'),
            ),
          ],
        );
      },
    );
  }

  Widget _dialogInput(
    TextEditingController controller,
    String label, {
    bool number = false,
  }) {
    return TextField(
      controller: controller,
      keyboardType: number ? TextInputType.number : TextInputType.text,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: _kMuted),
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: _kBorder),
          borderRadius: BorderRadius.circular(12),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: _kCyan),
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AdminSupplyViewModel>();
    final allSupplies = vm.supplies;
    final filteredSupplies = _filteredItems(allSupplies);
    final categories = _categories(allSupplies);

    return Container(
      color: _kBg,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTopBar(),
              const SizedBox(height: 18),
              _buildHeaderBanner(),
              const SizedBox(height: 18),
              _buildSummaryCards(allSupplies),
              const SizedBox(height: 18),
              _buildSearchAndActionBar(),
              const SizedBox(height: 14),
              _buildCategoryChips(categories),
              const SizedBox(height: 18),
              Expanded(
                child: _buildSupplyTableCard(
                  vm: vm,
                  supplies: filteredSupplies,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Row(
      children: [
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '物資管理',
              style: TextStyle(
                color: Colors.white,
                fontSize: 30,
                fontWeight: FontWeight.bold,
                letterSpacing: .5,
              ),
            ),
            SizedBox(height: 5),
            Text(
              'SUPPLY INVENTORY CONTROL CENTER',
              style: TextStyle(
                color: _kMuted,
                fontSize: 11,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
        const SizedBox(width: 14),
        _chip('● 即時庫存', _kCyan),
        const Spacer(),
        _chip('API DATABASE', _kMuted),
      ],
    );
  }

  Widget _buildHeaderBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kCyan.withOpacity(.25)),
        gradient: const LinearGradient(
          colors: [
            Color(0xFF07304A),
            Color(0xFF095A64),
            Color(0xFF0B7C7C),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: _kCyan.withOpacity(.08),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.local_shipping_rounded,
              color: Colors.white,
              size: 30,
            ),
          ),
          const SizedBox(width: 18),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '即時掌握物資庫存',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 27,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  '物資資料由後端 API 與真實資料庫提供，管理端負責顯示、補貨與修改需求量。',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards(List<SupplyItem> supplies) {
    return Row(
      children: [
        Expanded(
          child: _summaryCard(
            title: '物資種類',
            value: supplies.length.toString(),
            icon: Icons.category_rounded,
            color: _kCyan,
            bg: const Color(0xFF07304A),
            tag: '分類',
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _summaryCard(
            title: '總庫存量',
            value: _totalQuantity(supplies).toString(),
            icon: Icons.warehouse_rounded,
            color: _kGreen,
            bg: const Color(0xFF062B23),
            tag: '充足',
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _summaryCard(
            title: '低庫存項目',
            value: _lowStockCount(supplies).toString(),
            icon: Icons.warning_amber_rounded,
            color: _kAmber,
            bg: const Color(0xFF3A2A05),
            tag: '警戒',
          ),
        ),
      ],
    );
  }

  Widget _summaryCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required Color bg,
    required String tag,
  }) {
    return Container(
      height: 102,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(.35)),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(.08),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: color.withOpacity(.13),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  color: color,
                  fontSize: 34,
                  fontWeight: FontWeight.bold,
                  height: 1,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(
                  color: _kMuted,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: color.withOpacity(.12),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(
              tag,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndActionBar() {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 54,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: _kCardBg2,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _kCyan.withOpacity(.18)),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              style: const TextStyle(color: Colors.white, fontSize: 15),
              decoration: const InputDecoration(
                hintText: '請輸入物資名稱或分類搜尋',
                hintStyle: TextStyle(color: _kMuted, fontSize: 15),
                prefixIcon: Icon(Icons.search_rounded, color: _kMuted),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),
        SizedBox(
          height: 54,
          child: ElevatedButton.icon(
            onPressed: _showAddDialog,
            icon: const Icon(Icons.add_box_rounded, size: 18),
            label: const Text('新增物資'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _kCyan,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 22),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryChips(List<String> categories) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: categories.map((category) {
        final isSelected = _selectedCategory == category;

        return InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: () {
            setState(() {
              _selectedCategory = category;
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            decoration: BoxDecoration(
              color: isSelected ? _kCyan.withOpacity(.15) : _kCardBg2,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: isSelected ? _kCyan : _kBorder,
              ),
            ),
            child: Text(
              category,
              style: TextStyle(
                color: isSelected ? _kCyan : _kMuted,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSupplyTableCard({
    required AdminSupplyViewModel vm,
    required List<SupplyItem> supplies,
  }) {
    if (vm.isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: _kCyan),
      );
    }

    if (vm.errorMessage != null) {
      return Center(
        child: Text(
          vm.errorMessage!,
          style: const TextStyle(color: _kRed),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.28),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            height: 54,
            padding: const EdgeInsets.symmetric(horizontal: 22),
            decoration: const BoxDecoration(
              color: Color(0xFF0C2235),
              borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
              border: Border(bottom: BorderSide(color: _kBorder)),
            ),
            child: Row(
              children: [
                _headerCell('物資名稱', flex: 3),
                _headerCell('分類', flex: 2),
                _headerCell('庫存', flex: 2),
                _headerCell('需求量', flex: 2),
                _headerCell('狀態', flex: 2),
                _headerCell('操作', flex: 3),
              ],
            ),
          ),
          Expanded(
            child: supplies.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    itemCount: supplies.length,
                    itemBuilder: (context, index) {
                      return _buildSupplyRow(supplies[index], index);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(26),
        decoration: BoxDecoration(
          color: const Color(0xFF081C2B),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _kCyan.withOpacity(.16)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.inventory_2_outlined,
              color: _kCyan.withOpacity(.75),
              size: 44,
            ),
            const SizedBox(height: 14),
            const Text(
              '目前沒有物資資料',
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '請新增物資，或確認後端 API 是否已提供庫存資料。',
              style: TextStyle(
                color: _kMuted,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _headerCell(String text, {int flex = 1}) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF7FA6C6),
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: .8,
        ),
      ),
    );
  }

  Widget _buildSupplyRow(SupplyItem item, int index) {
    final isEven = index % 2 == 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
      decoration: BoxDecoration(
        color: isEven ? Colors.transparent : Colors.white.withOpacity(.025),
        border: Border(
          bottom: BorderSide(color: _kBorder.withOpacity(.55)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: _kPurple.withOpacity(.14),
                  child: const Icon(
                    Icons.inventory_2_rounded,
                    color: _kPurple,
                    size: 15,
                  ),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    item.name,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              item.category,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: _kMuted, fontSize: 13),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              '${item.stockQty} ${item.unit}',
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              '${item.neededQty} ${item.unit}',
              style: const TextStyle(color: _kMuted, fontSize: 13),
            ),
          ),
          Expanded(
            flex: 2,
            child: _buildStockChip(item),
          ),
          Expanded(
            flex: 3,
            child: Row(
              children: [
                _buildActionButton(
                  label: '補貨',
                  color: _kGreen,
                  bgColor: _kGreen.withOpacity(.12),
                  onTap: () => _showStockDialog(item),
                ),
                const SizedBox(width: 8),
                _buildActionButton(
                  label: '需求量',
                  color: _kCyan,
                  bgColor: _kCyan.withOpacity(.12),
                  onTap: () => _showNeededDialog(item),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStockChip(SupplyItem item) {
    final color = item.isLowStock ? _kRed : _kGreen;
    final label = item.isLowStock ? '庫存不足' : '正常';

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(.12),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withOpacity(.35)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required Color color,
    required Color bgColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(.35)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  static Widget _chip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(.10),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(.28)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 11,
        ),
      ),
    );
  }
}