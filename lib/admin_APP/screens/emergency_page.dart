import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_disaster_app/core/models/emergency_request.dart';
import 'package:flutter_disaster_app/admin_APP/viewModels/emergency_viewmodel.dart';

const Color _kBg = Color(0xFF07131F);
const Color _kCardBg = Color(0xFF0A1826);
const Color _kCardBg2 = Color(0xFF0D2133);
const Color _kCyan = Color(0xFF00C8FF);
const Color _kGreen = Color(0xFF00D09C);
const Color _kMuted = Color(0xFF5C7896);
const Color _kBorder = Color(0xFF123047);
const Color _kAmber = Color(0xFFFFC107);
const Color _kRed = Color(0xFFFF4C4C);
const Color _kPurple = Color(0xFFB45CFF);

class EmergencyPage extends StatefulWidget {
  const EmergencyPage({super.key});

  @override
  State<EmergencyPage> createState() => _EmergencyPageState();
}

class _EmergencyPageState extends State<EmergencyPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      context.read<EmergencyViewModel>().loadEmergencies();
    });
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<EmergencyViewModel>();

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
              _buildSummaryCards(vm),
              const SizedBox(height: 18),
              Expanded(child: _buildEmergencyList(vm)),
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
              '緊急事件',
              style: TextStyle(
                color: Colors.white,
                fontSize: 30,
                fontWeight: FontWeight.bold,
                letterSpacing: .5,
              ),
            ),
            SizedBox(height: 5),
            Text(
              'EMERGENCY REQUEST CENTER',
              style: TextStyle(
                color: _kMuted,
                fontSize: 11,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
        const SizedBox(width: 14),
        _chip('● 即時求救', _kRed),
        const Spacer(),
        _chip('USER APP REPORTS', _kMuted),
      ],
    );
  }

  Widget _buildHeaderBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kRed.withOpacity(.25)),
        gradient: const LinearGradient(
          colors: [
            Color(0xFF3A1030),
            Color(0xFF5A183A),
            Color(0xFF7A223F),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: _kRed.withOpacity(.08),
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
              Icons.emergency_rounded,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(width: 18),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '即時緊急求救事件',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 27,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  '以下為民眾從使用者 APP 回報的緊急求救事件，管理端負責查看與標記處理狀態。',
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

  Widget _buildSummaryCards(EmergencyViewModel vm) {
    final total = vm.emergencies.length;
    final handled = vm.emergencies.where((e) => e.handled).length;
    final pending = total - handled;

    return Row(
      children: [
        Expanded(
          child: _summaryCard(
            title: '總事件數',
            value: total.toString(),
            icon: Icons.list_alt_rounded,
            color: _kPurple,
            bg: const Color(0xFF2A1640),
            tag: '總計',
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _summaryCard(
            title: '待處理',
            value: pending.toString(),
            icon: Icons.warning_amber_rounded,
            color: _kAmber,
            bg: const Color(0xFF3A2A05),
            tag: '警戒',
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _summaryCard(
            title: '已處理',
            value: handled.toString(),
            icon: Icons.check_circle_rounded,
            color: _kGreen,
            bg: const Color(0xFF062B23),
            tag: '完成',
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
                style: const TextStyle(color: _kMuted, fontSize: 14),
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

  Widget _buildEmergencyList(EmergencyViewModel vm) {
    if (vm.isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: _kRed),
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

    if (vm.emergencies.isEmpty) {
      return _buildEmptyState();
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
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: vm.emergencies.length,
        itemBuilder: (context, index) {
          final emergency = vm.emergencies[index];
          return _buildEmergencyCard(emergency, vm, index);
        },
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
          border: Border.all(color: _kRed.withOpacity(.18)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.verified_user_outlined,
              color: _kGreen.withOpacity(.75),
              size: 46,
            ),
            const SizedBox(height: 14),
            const Text(
              '目前沒有緊急事件',
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '使用者 APP 若送出求救回報，事件會自動同步到這裡。',
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

  Widget _buildEmergencyCard(
    EmergencyRequest emergency,
    EmergencyViewModel vm,
    int index,
  ) {
    final color = emergency.handled ? _kGreen : _kAmber;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: index.isEven ? _kCardBg2 : const Color(0xFF091625),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: emergency.handled
              ? _kGreen.withOpacity(.25)
              : _kAmber.withOpacity(.28),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: color.withOpacity(.13),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              emergency.handled
                  ? Icons.check_circle_rounded
                  : Icons.warning_amber_rounded,
              color: color,
              size: 26,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '求救類型：${emergency.type}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.location_on, color: _kCyan.withOpacity(.7), size: 14),
                    const SizedBox(width: 5),
                    Text(
                      '${emergency.latitude.toStringAsFixed(4)}, ${emergency.longitude.toStringAsFixed(4)}',
                      style: const TextStyle(color: _kMuted, fontSize: 13),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.access_time, color: _kMuted.withOpacity(.8), size: 14),
                    const SizedBox(width: 5),
                    Text(
                      emergency.createdAt.toString().substring(0, 16),
                      style: const TextStyle(color: _kMuted, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
          _statusBadge(emergency.handled),
          const SizedBox(width: 12),
          if (!emergency.handled)
            ElevatedButton.icon(
              onPressed: () {
                vm.markHandled(emergency);
              },
              icon: const Icon(Icons.check_circle_outline, size: 17),
              label: const Text('標記已處理'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _kGreen,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: _kGreen.withOpacity(.12),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: _kGreen.withOpacity(.35)),
              ),
              child: const Text(
                '已完成',
                style: TextStyle(
                  color: _kGreen,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _statusBadge(bool handled) {
    final color = handled ? _kGreen : _kAmber;
    final text = handled ? '已處理' : '待處理';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: color.withOpacity(.45), blurRadius: 8),
              ],
            ),
          ),
          const SizedBox(width: 7),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
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