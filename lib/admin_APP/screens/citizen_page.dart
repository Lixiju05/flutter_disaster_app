import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_disaster_app/core/models/citizen.dart';
import 'package:flutter_disaster_app/admin_APP/viewModels/citizen_viewmodel.dart';

const Color _kBg = Color(0xFF07131F);
const Color _kCardBg = Color(0xFF0A1826);
const Color _kCardBg2 = Color(0xFF0D2133);
const Color _kCyan = Color(0xFF00C8FF);
const Color _kGreen = Color(0xFF00D09C);
const Color _kMuted = Color(0xFF5C7896);
const Color _kBorder = Color(0xFF123047);
const Color _kAmber = Color(0xFFFFC107);
const Color _kRed = Color(0xFFFF4C4C);

class CitizenPage extends StatefulWidget {
  const CitizenPage({super.key});

  @override
  State<CitizenPage> createState() => _CitizenPageState();
}

class _CitizenPageState extends State<CitizenPage> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      context.read<CitizenViewmodel>().loadCitizens();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Citizen> _filterCitizens(List<Citizen> citizens) {
    final keyword = _searchController.text.trim().toLowerCase();
    if (keyword.isEmpty) return citizens;

    return citizens.where((c) {
      return c.name.toLowerCase().contains(keyword) ||
          c.id.toLowerCase().contains(keyword);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<CitizenViewmodel>();
    final all = vm.citizens;
    final filtered = _filterCitizens(all);

    final total = all.length;
    final needRescue = all.where((c) => c.needsRescue).length;
    final safe = all.where((c) => !c.needsRescue).length;

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
              _buildSummaryCards(total, needRescue, safe),
              const SizedBox(height: 18),
              _buildSearchBar(),
              const SizedBox(height: 18),
              Expanded(
                child: _buildTable(vm, filtered),
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
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              '災民管理',
              style: TextStyle(
                color: Colors.white,
                fontSize: 30,
                fontWeight: FontWeight.bold,
                letterSpacing: .5,
              ),
            ),
            SizedBox(height: 5),
            Text(
              'CITIZEN MANAGEMENT CENTER',
              style: TextStyle(
                color: _kMuted,
                fontSize: 11,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
        const SizedBox(width: 14),
        _chip('● 即時同步', _kCyan),
        const Spacer(),
        _chip('USER APP DATA ONLY', _kMuted),
      ],
    );
  }

  Widget _buildSummaryCards(int total, int needRescue, int safe) {
    return Row(
      children: [
        Expanded(
          child: _summaryCard(
            title: '總災民數',
            value: '$total',
            icon: Icons.people_alt_outlined,
            color: _kCyan,
            bg: const Color(0xFF07304A),
            tag: '即時',
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _summaryCard(
            title: '待救援',
            value: '$needRescue',
            icon: Icons.warning_amber_rounded,
            color: _kAmber,
            bg: const Color(0xFF3A2A05),
            tag: '警戒',
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _summaryCard(
            title: '安全',
            value: '$safe',
            icon: Icons.check_circle_outline,
            color: _kGreen,
            bg: const Color(0xFF062B23),
            tag: '穩定',
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

  Widget _buildSearchBar() {
    return Container(
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
          hintText: '搜尋姓名或 ID...',
          hintStyle: TextStyle(color: _kMuted, fontSize: 15),
          prefixIcon: Icon(Icons.search, color: _kMuted, size: 20),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }

  Widget _buildTable(CitizenViewmodel vm, List<Citizen> citizens) {
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
              border: Border(
                bottom: BorderSide(color: _kBorder),
              ),
            ),
            child: Row(
              children: [
                _headerCell('姓名', flex: 2),
                _headerCell('ID', flex: 2),
                _headerCell('座標', flex: 3),
                _headerCell('救援狀態', flex: 2),
                _headerCell('操作', flex: 2),
              ],
            ),
          ),
          Expanded(
            child: citizens.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    itemCount: citizens.length,
                    itemBuilder: (context, i) {
                      return _buildRow(citizens[i], i);
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
              Icons.cloud_sync_outlined,
              color: _kCyan.withOpacity(.75),
              size: 44,
            ),
            const SizedBox(height: 14),
            const Text(
              '等待用户端同步災民資料',
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '資料會由使用者 APP 自動上傳，管理端不提供手動新增。',
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

  Widget _buildRow(Citizen c, int index) {
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
            flex: 2,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: _kCyan.withOpacity(.13),
                  child: Text(
                    c.name.isNotEmpty ? c.name[0] : '?',
                    style: const TextStyle(
                      color: _kCyan,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    c.name,
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
              c.id,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: _kMuted, fontSize: 13),
            ),
          ),
          Expanded(
            flex: 3,
            child: Row(
              children: [
                Icon(
                  Icons.location_on,
                  color: _kCyan.withOpacity(.65),
                  size: 15,
                ),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    '${c.latitude.toStringAsFixed(4)}, ${c.longitude.toStringAsFixed(4)}',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: _kMuted, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: _buildStatusBadge(c.needsRescue),
          ),
          Expanded(
            flex: 2,
            child: _buildActionButton(c),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(Citizen c) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () {
        context.read<CitizenViewmodel>().updateNeedsRescue(
              c,
              !c.needsRescue,
            );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: c.needsRescue
              ? _kGreen.withOpacity(.12)
              : _kAmber.withOpacity(.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: c.needsRescue
                ? _kGreen.withOpacity(.35)
                : _kAmber.withOpacity(.35),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              c.needsRescue
                  ? Icons.check_circle_outline
                  : Icons.warning_amber_rounded,
              color: c.needsRescue ? _kGreen : _kAmber,
              size: 15,
            ),
            const SizedBox(width: 6),
            Text(
              c.needsRescue ? '標記安全' : '標記求援',
              style: TextStyle(
                color: c.needsRescue ? _kGreen : _kAmber,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(bool needsRescue) {
    final color = needsRescue ? _kRed : _kGreen;
    final text = needsRescue ? '待救援' : '安全';

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
                BoxShadow(
                  color: color.withOpacity(.45),
                  blurRadius: 8,
                ),
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