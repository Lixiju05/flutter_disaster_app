import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_disaster_app/core/models/allocation.dart';
import 'package:flutter_disaster_app/core/models/supply.dart';
import 'package:flutter_disaster_app/admin_APP/viewModels/allocation_viewmodel.dart';

class AllocationPage extends StatefulWidget {
  const AllocationPage({super.key});

  @override
  State<AllocationPage> createState() => _AllocationPageState();
}

class _AllocationPageState extends State<AllocationPage> {
  static const Color pageBg    = Color(0xFFF4F7FB);
  static const Color cardBg    = Colors.white;
  static const Color titleColor = Color(0xFF183153);
  static const Color textSoft  = Color(0xFF6B7A90);
  static const Color borderColor = Color(0xFFE6ECF3);
  static const Color accentTeal = Color(0xFF1C7C8C);

  @override
  void initState() {
    super.initState();
    Future.microtask(() => context.read<AllocationViewModel>().loadAll());
  }

  // ────────────────── 分配 Dialog ──────────────────
  Future<void> _showAllocateDialog(List<SupplyItem> supplies) async {
    SupplyItem? selectedItem = supplies.isNotEmpty ? supplies.first : null;
    final zoneController = TextEditingController();
    final qtyController  = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18)),
              title: const Text('新增物資分配'),
              content: SizedBox(
                width: 380,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 選物資
                    DropdownButtonFormField<SupplyItem>(
                      value: selectedItem,
                      decoration: const InputDecoration(
                        labelText: '選擇物資',
                        border: OutlineInputBorder(),
                      ),
                      items: supplies
                          .map((s) => DropdownMenuItem(
                                value: s,
                                child: Text('${s.name}（庫存 ${s.stockQty} ${s.unit}）'),
                              ))
                          .toList(),
                      onChanged: (v) => setDialogState(() => selectedItem = v),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: zoneController,
                      decoration: const InputDecoration(
                        labelText: '目標區域，例如：A區 / 北區',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: qtyController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: '分配數量',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('取消')),
                ElevatedButton(
                  onPressed: () async {
                    if (selectedItem == null) return;
                    final zone = zoneController.text.trim();
                    final qty  = int.tryParse(qtyController.text.trim()) ?? 0;
                    if (zone.isEmpty || qty <= 0) return;

                    final success =
                        await context.read<AllocationViewModel>().allocate(
                              itemId: selectedItem!.itemId,
                              zoneId: zone,
                              qty: qty,
                            );

                    if (!mounted) return;
                    if (success) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('分配成功')));
                    }
                  },
                  child: const Text('確認分配'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ────────────────── Build ──────────────────
  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AllocationViewModel>();

    return Container(
      color: pageBg,
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTopBar(),
              const SizedBox(height: 22),
              _buildActionBar(vm),
              const SizedBox(height: 20),

              // 載入中 / 錯誤
              if (vm.isLoading)
                const Center(child: CircularProgressIndicator())
              else if (vm.errorMessage != null)
                Center(
                    child: Text(vm.errorMessage!,
                        style: const TextStyle(color: Colors.redAccent)))
              else ...[
                _buildSectionTitle('待出貨分配'),
                const SizedBox(height: 12),
                _buildAllocationList(vm),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: borderColor),
      ),
      child: const Row(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('物資分配',
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: titleColor)),
                SizedBox(height: 4),
                Text('Allocation Management',
                    style: TextStyle(fontSize: 13, color: textSoft)),
              ],
            ),
          ),
          CircleAvatar(
            radius: 20,
            backgroundColor: Color(0xFFEAF2FF),
            child: Icon(Icons.alt_route_rounded, color: Color(0xFF4A90E2)),
          ),
        ],
      ),
    );
  }

  Widget _buildActionBar(AllocationViewModel vm) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text('分配紀錄',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: titleColor)),
        ElevatedButton.icon(
          onPressed: () => _showAllocateDialog(vm.supplies),
          icon: const Icon(Icons.add_box_rounded),
          label: const Text('新增分配'),
          style: ElevatedButton.styleFrom(
            backgroundColor: accentTeal,
            foregroundColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(title,
        style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: titleColor));
  }

  Widget _buildAllocationList(AllocationViewModel vm) {
    // 只顯示「尚未出貨」的
    final pending =
        vm.allocations.where((a) => !a.dispatched).toList();

    if (pending.isEmpty) {
      return const Center(
          child: Padding(
        padding: EdgeInsets.all(32),
        child: Text('目前無待出貨分配',
            style: TextStyle(color: textSoft, fontSize: 16)),
      ));
    }

    return Column(
      children: pending
          .map((item) => _buildAllocationCard(item, vm))
          .toList(),
    );
  }

  Widget _buildAllocationCard(AllocationItem item, AllocationViewModel vm) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          // 圖示
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFEAF2FF),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.local_shipping_rounded,
                color: Color(0xFF4A90E2)),
          ),
          const SizedBox(width: 16),
          // 資訊
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.itemName,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: titleColor)),
                const SizedBox(height: 4),
                Text(
                    '目標：${item.zoneId}　數量：${item.qty} ${item.unit}',
                    style:
                        const TextStyle(color: textSoft, fontSize: 13)),
                if (item.createdAt.isNotEmpty)
                  Text('建立時間：${item.createdAt}',
                      style:
                          const TextStyle(color: textSoft, fontSize: 12)),
              ],
            ),
          ),
          // 出貨按鈕
          ElevatedButton(
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('確認出貨？'),
                  content: Text(
                      '確定將「${item.itemName}」${item.qty}${item.unit} 出貨至 ${item.zoneId}？'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('取消')),
                    ElevatedButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('確認')),
                  ],
                ),
              );

              if (confirm == true) {
                final success =
                    await vm.dispatch(item.allocationId);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content:
                        Text(success ? '出貨成功！' : '出貨失敗，請重試')));
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2E7D32),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            child: const Text('確認出貨'),
          ),
        ],
      ),
    );
  }
}