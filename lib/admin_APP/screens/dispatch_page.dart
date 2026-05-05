import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_disaster_app/admin_APP/viewModels/allocation_viewmodel.dart';
import 'package:flutter_disaster_app/core/models/dispatch.dart';

class DispatchPage extends StatefulWidget {
  const DispatchPage({super.key});

  @override
  State<DispatchPage> createState() => _DispatchPageState();
}

class _DispatchPageState extends State<DispatchPage> {
  static const Color pageBg     = Color(0xFFF4F7FB);
  static const Color cardBg     = Colors.white;
  static const Color titleColor = Color(0xFF183153);
  static const Color textSoft   = Color(0xFF6B7A90);
  static const Color borderColor = Color(0xFFE6ECF3);

  @override
  void initState() {
    super.initState();
    Future.microtask(() => context.read<AllocationViewModel>().loadAll());
  }

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

              if (vm.isLoading)
                const Center(child: CircularProgressIndicator())
              else if (vm.errorMessage != null)
                Center(
                    child: Text(vm.errorMessage!,
                        style: const TextStyle(color: Colors.redAccent)))
              else
                _buildDispatchList(vm.dispatches),
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
                Text('出貨紀錄',
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: titleColor)),
                SizedBox(height: 4),
                Text('Dispatch History',
                    style: TextStyle(fontSize: 13, color: textSoft)),
              ],
            ),
          ),
          CircleAvatar(
            radius: 20,
            backgroundColor: Color(0xFFEAF7EC),
            child: Icon(Icons.check_circle_rounded,
                color: Color(0xFF2E7D32)),
          ),
        ],
      ),
    );
  }

  Widget _buildDispatchList(List<DispatchItem> dispatches) {
    if (dispatches.isEmpty) {
      return const Center(
          child: Padding(
        padding: EdgeInsets.all(32),
        child: Text('目前無出貨紀錄',
            style: TextStyle(color: textSoft, fontSize: 16)),
      ));
    }

    return Column(
      children: dispatches.map((item) => _buildDispatchCard(item)).toList(),
    );
  }

  Widget _buildDispatchCard(DispatchItem item) {
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
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFEAF7EC),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.check_circle_rounded,
                color: Color(0xFF2E7D32)),
          ),
          const SizedBox(width: 16),
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
                if (item.dispatchedAt.isNotEmpty)
                  Text('出貨時間：${item.dispatchedAt}',
                      style:
                          const TextStyle(color: textSoft, fontSize: 12)),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFEAF7EC),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Text('已出貨',
                style: TextStyle(
                    color: Color(0xFF2E7D32),
                    fontWeight: FontWeight.bold,
                    fontSize: 13)),
          ),
        ],
      ),
    );
  }
}