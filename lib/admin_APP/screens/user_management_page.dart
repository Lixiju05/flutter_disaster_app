import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

// ── 色系（與 dashboard 統一）────────────────────────────
const Color _kBg = Color(0xFFF5F7FA);
const Color _kCardBg = Color(0xFFFFFFFF);
const Color _kCardBg2 = Color(0xFFF8FAFC);
const Color _kBorder = Color(0xFFE5E7EB);
const Color _kBlue = Color(0xFF2563EB);
const Color _kGreen = Color(0xFF16A34A);
const Color _kOrange = Color(0xFFF59E0B);
const Color _kPurple = Color(0xFF7C3AED);
const Color _kTextMain = Color(0xFF0F172A);
const Color _kTextSub = Color(0xFF64748B);
const Color _kRed = Color(0xFFDC2626);

const String _umBaseUrl =
    'https://delphine-eisteddfodic-afflictively.ngrok-free.dev';

class UserManagementPage extends StatefulWidget {
  const UserManagementPage({super.key});

  @override
  State<UserManagementPage> createState() => _UserManagementPageState();
}

class _UserManagementPageState extends State<UserManagementPage> {
  final TextEditingController _searchController = TextEditingController();

  Timer? _debounce;
  Timer? _refreshTimer;

  List<Map<String, dynamic>> _allUsers = [];
  List<Map<String, dynamic>> _users = [];

  bool _isLoading = true;
  String _errorMessage = '';
  String _searchKeyword = '';
  String _selectedArea = 'all';

  @override
  void initState() {
    super.initState();
    _loadUsers();

    _refreshTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _loadUsers(showLoading: false),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  // ── API ──────────────────────────────────────────────
  Future<void> _loadUsers({bool showLoading = true}) async {
    if (showLoading && mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });
    }

    try {
      final response = await http
          .post(
            Uri.parse(_umBaseUrl),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'ngrok-skip-browser-warning': 'true',
            },
            body: jsonEncode({'type': 'getAllUsers'}),
          )
          .timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        final users = List<Map<String, dynamic>>.from(data['data']);

        if (!mounted) return;

        setState(() {
          _allUsers = users;
          _isLoading = false;
          _errorMessage = '';
        });

        _applyFilters();
      } else {
        if (!mounted) return;

        setState(() {
          _errorMessage = data['message'] ?? '取得用戶資料失敗';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _errorMessage = '連線錯誤：$e';
        _isLoading = false;
      });
    }
  }

  // ── 篩選 ─────────────────────────────────────────────
  void _applyFilters() {
    List<Map<String, dynamic>> result = List.from(_allUsers);

    if (_selectedArea != 'all') {
      result = result
          .where(
            (u) =>
                (u['area'] ?? '').toString().toLowerCase() ==
                _selectedArea.toLowerCase(),
          )
          .toList();
    }

    if (_searchKeyword.isNotEmpty) {
      result = result.where((u) {
        final name = (u['name'] ?? '').toString().toLowerCase();
        final phone = (u['phone'] ?? '').toString().toLowerCase();
        final area = (u['area'] ?? '').toString().toLowerCase();

        return name.contains(_searchKeyword) ||
            phone.contains(_searchKeyword) ||
            area.contains(_searchKeyword);
      }).toList();
    }

    if (mounted) {
      setState(() => _users = result);
    }
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();

    _debounce = Timer(const Duration(milliseconds: 280), () {
      setState(() => _searchKeyword = value.trim().toLowerCase());
      _applyFilters();
    });
  }

  List<String> get _areas {
    final list = _allUsers
        .map((u) => (u['area'] ?? '').toString())
        .where((a) => a.isNotEmpty)
        .toSet()
        .toList()
      ..sort();

    return ['all', ...list];
  }

  int _countByArea(String area) {
    return _allUsers.where((u) => (u['area'] ?? '') == area).length;
  }

  String _userStatusText(Map<String, dynamic> user) {
    final status = (user['status'] ?? '').toString().trim();

    if (status == 'verified' || status == '已驗證') return '已驗證';
    if (status == 'pending' || status == '待審核') return '待審核';
    if (status == 'disabled' || status == '停用') return '停用';

    return '已登記';
  }

  Color _userStatusColor(String status) {
    switch (status) {
      case '已驗證':
        return _kGreen;
      case '待審核':
        return _kOrange;
      case '停用':
        return _kRed;
      default:
        return _kBlue;
    }
  }

  int get _verifiedCount {
    return _allUsers.where((u) {
      final status = _userStatusText(u);
      return status == '已驗證' || status == '已登記';
    }).length;
  }

  // ════════════════════════════════════════════════════
  // BUILD
  // ════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Container(
      color: _kBg,
      child: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: _kBlue),
      );
    }

    if (_errorMessage.isNotEmpty) {
      return _buildError();
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatsRow(),
          const SizedBox(height: 18),
          _buildSearchAndFilter(),
          const SizedBox(height: 18),
          if (_allUsers.isEmpty)
            _buildEmpty('目前沒有用戶資料')
          else if (_users.isEmpty)
            _buildEmpty('沒有符合條件的用戶資料')
          else
            ..._users.map(
              (user) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _buildUserCard(user),
              ),
            ),
        ],
      ),
    );
  }

  // ── Header ──────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 16),
      decoration: const BoxDecoration(
        color: _kCardBg,
        border: Border(
          bottom: BorderSide(color: _kBorder),
        ),
      ),
      child: Row(
        children: [
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '用戶管理',
                style: TextStyle(
                  color: _kTextMain,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'CITIZEN INFORMATION CENTER',
                style: TextStyle(
                  color: _kTextSub,
                  fontSize: 12,
                  letterSpacing: 1.4,
                ),
              ),
            ],
          ),
          const SizedBox(width: 14),
          _pill('系統運作正常', _kGreen),
          const Spacer(),
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => _loadUsers(),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: _kCardBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _kBorder),
              ),
              child: const Icon(
                Icons.refresh_rounded,
                color: _kBlue,
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── 統計卡片 ─────────────────────────────────────────
  Widget _buildStatsRow() {
    return Row(
      children: [
        Expanded(
          child: _statCard(
            '用戶總數',
            '${_allUsers.length}',
            Icons.groups_rounded,
            _kBlue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _statCard(
            '已登記',
            '$_verifiedCount',
            Icons.verified_user_outlined,
            _kGreen,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _statCard(
            '管理員',
            '1',
            Icons.admin_panel_settings_outlined,
            _kPurple,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _statCard(
            '區域數',
            '${_areas.length - 1}',
            Icons.apartment_outlined,
            _kOrange,
          ),
        ),
      ],
    );
  }

  Widget _statCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.035),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withOpacity(.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: color,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  color: _kTextMain,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(
                  color: _kTextSub,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── 搜尋 + 區域篩選 ───────────────────────────────────
  Widget _buildSearchAndFilter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 46,
          decoration: BoxDecoration(
            color: _kCardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _kBorder),
          ),
          child: TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            style: const TextStyle(
              color: _kTextMain,
              fontSize: 14,
            ),
            decoration: InputDecoration(
              hintText: '搜尋姓名 / 電話 / 區域...',
              hintStyle: const TextStyle(
                color: _kTextSub,
                fontSize: 14,
              ),
              prefixIcon: const Icon(
                Icons.search,
                color: _kTextSub,
                size: 18,
              ),
              suffixIcon: _searchKeyword.isNotEmpty
                  ? IconButton(
                      icon: const Icon(
                        Icons.close_rounded,
                        color: _kTextSub,
                        size: 18,
                      ),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchKeyword = '');
                        _applyFilters();
                      },
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 13,
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        _buildAreaSelector(),
      ],
    );
  }

  Widget _buildAreaSelector() {
    return SizedBox(
      height: 92,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _areas.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final area = _areas[index];
          final selected = _selectedArea == area;

          final label = area == 'all' ? '全部區域' : area;
          final count = area == 'all' ? _allUsers.length : _countByArea(area);

          return InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () {
              setState(() => _selectedArea = area);
              _applyFilters();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              width: 158,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: selected ? _kBlue : _kCardBg,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: selected ? _kBlue : _kBorder,
                ),
                boxShadow: [
                  BoxShadow(
                    color: selected
                        ? _kBlue.withOpacity(.18)
                        : Colors.black.withOpacity(.03),
                    blurRadius: selected ? 18 : 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: selected
                              ? Colors.white.withOpacity(.18)
                              : _kBlue.withOpacity(.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          area == 'all'
                              ? Icons.public_rounded
                              : Icons.location_on_rounded,
                          color: selected ? Colors.white : _kBlue,
                          size: 17,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: selected ? Colors.white : _kGreen,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selected ? Colors.white : _kTextMain,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$count 位居民',
                    style: TextStyle(
                      color: selected ? Colors.white70 : _kTextSub,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── 用戶卡片 ──────────────────────────────────────────
  Widget _buildUserCard(Map<String, dynamic> user) {
    final status = _userStatusText(user);
    final color = _userStatusColor(status);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.035),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 4,
            height: 90,
            decoration: BoxDecoration(
              color: _kBlue,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          const SizedBox(width: 14),
          CircleAvatar(
            radius: 24,
            backgroundColor: _kBlue.withOpacity(.10),
            child: Text(
              (user['name'] ?? '?').toString().isNotEmpty
                  ? (user['name'] ?? '?').toString()[0]
                  : '?',
              style: const TextStyle(
                color: _kBlue,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        (user['name'] ?? '').toString(),
                        style: const TextStyle(
                          color: _kTextMain,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    _statusBadge(status, color),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'ID：${user['id'] ?? '--'}  ·  血型：${user['bloodType'] ?? '--'}',
                  style: const TextStyle(
                    color: _kTextSub,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _tag(
                      Icons.phone_outlined,
                      (user['phone'] ?? '').toString(),
                      _kBlue,
                    ),
                    _tag(
                      Icons.location_on_outlined,
                      (user['area'] ?? '').toString(),
                      _kGreen,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: _kCardBg2,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _kBorder),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.call_outlined,
                        color: _kTextSub,
                        size: 13,
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          '緊急聯絡：${user['emergencyContactName'] ?? ''}'
                          ' (${user['emergencyContactRelation'] ?? ''}) '
                          '${user['emergencyContactPhone'] ?? ''}',
                          style: const TextStyle(
                            color: _kTextSub,
                            fontSize: 12,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => _showDetail(user),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: _kBlue.withOpacity(.06),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _kBlue.withOpacity(.2),
                ),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.visibility_outlined,
                    color: _kBlue,
                    size: 14,
                  ),
                  SizedBox(width: 5),
                  Text(
                    '詳情',
                    style: TextStyle(
                      color: _kBlue,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── 詳情 Dialog ──────────────────────────────────────
  void _showDetail(Map<String, dynamic> user) {
    final status = _userStatusText(user);
    final color = _userStatusColor(status);

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(.35),
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: 480,
          decoration: BoxDecoration(
            color: _kCardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _kBorder),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 12, 16),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: _kBlue.withOpacity(.10),
                      child: Text(
                        (user['name'] ?? '?').toString().isNotEmpty
                            ? (user['name'] ?? '?').toString()[0]
                            : '?',
                        style: const TextStyle(
                          color: _kBlue,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            (user['name'] ?? '').toString(),
                            style: const TextStyle(
                              color: _kTextMain,
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              _statusBadge(status, color),
                              const SizedBox(width: 8),
                              Text(
                                'ID：${user['id'] ?? '--'}',
                                style: const TextStyle(
                                  color: _kTextSub,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(
                        Icons.close,
                        color: _kTextSub,
                        size: 18,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: _kBorder),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    _dialogRow('電話', (user['phone'] ?? '').toString()),
                    _dialogRow('區域', (user['area'] ?? '').toString()),
                    _dialogRow('血型', (user['bloodType'] ?? '').toString()),
                    _dialogRow(
                      '醫療資訊',
                      (user['medicalInfo'] ?? '無').toString(),
                    ),
                    _dialogRow(
                      '緊急聯絡人',
                      '${user['emergencyContactName'] ?? ''} (${user['emergencyContactRelation'] ?? ''})',
                    ),
                    _dialogRow(
                      '緊急聯絡電話',
                      (user['emergencyContactPhone'] ?? '').toString(),
                    ),
                    _dialogRow(
                      '註冊時間',
                      (user['registeredAt'] ?? '').toString(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dialogRow(String label, String value) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color: _kCardBg2,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _kBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: const TextStyle(
                color: _kTextSub,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '未填寫' : value,
              style: const TextStyle(
                color: _kTextMain,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── 錯誤狀態 ──────────────────────────────────────────
  Widget _buildError() {
    return Center(
      child: Container(
        width: 420,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: _kCardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _kRed.withOpacity(.2),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: _kRed.withOpacity(.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline,
                color: _kRed,
                size: 26,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              _errorMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _kRed,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: () => _loadUsers(),
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('重新載入'),
              style: OutlinedButton.styleFrom(
                foregroundColor: _kBlue,
                side: BorderSide(
                  color: _kBlue.withOpacity(.4),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 空狀態 ────────────────────────────────────────────
  Widget _buildEmpty(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(48),
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: _kBlue.withOpacity(.06),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.inbox_outlined,
              size: 26,
              color: _kTextSub,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            text,
            style: const TextStyle(
              color: _kTextSub,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ── 共用小元件 ─────────────────────────────────────────
  static Widget _statusBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: color.withOpacity(.2),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  static Widget _tag(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(.06),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(
          color: color.withOpacity(.18),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 12,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            text.isEmpty ? '未填寫' : text,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  static Widget _pill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: color.withOpacity(.18),
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}