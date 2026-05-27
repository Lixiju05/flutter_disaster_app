import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'admin_setup_page.dart' show kAreaList;

// ── 色系 ────────────────────────────────────────────────────────
const Color _kBg       = Color(0xFFF5F7FA);
const Color _kCardBg   = Color(0xFFFFFFFF);
const Color _kBorder   = Color(0xFFE2E8F0);
const Color _kBlue     = Color(0xFF2563EB);
const Color _kTextMain = Color(0xFF0F172A);
const Color _kTextSub  = Color(0xFF64748B);
const Color _kRed      = Color(0xFFDC2626);

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
  List<Map<String, dynamic>> _users    = [];

  bool   _isLoading     = true;
  String _errorMessage  = '';
  String _searchKeyword = '';
  String _adminArea     = '暨大';
  bool   _showAll       = true;

  int _currentPage = 0;
  int _pageSize    = 10;

  @override
  void initState() {
    super.initState();
    _loadAdminArea();
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

  Future<void> _loadAdminArea() async {
    final prefs = await SharedPreferences.getInstance();
    final area = prefs.getString('adminArea') ?? '暨大';
    if (!mounted) return;
    setState(() => _adminArea = area);
    _applyFilters();
  }

  Future<void> _loadUsers({bool showLoading = true}) async {
    if (showLoading && mounted) {
      setState(() { _isLoading = true; _errorMessage = ''; });
    }
    try {
      final response = await http.post(
        Uri.parse(_umBaseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: jsonEncode({'type': 'getAllUsers'}),
      ).timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        final users = List<Map<String, dynamic>>.from(data['data']);
        if (!mounted) return;
        setState(() {
          _allUsers     = users;
          _isLoading    = false;
          _errorMessage = '';
        });
        _applyFilters();
      } else {
        if (!mounted) return;
        setState(() {
          _errorMessage = data['message'] ?? '取得用戶資料失敗';
          _isLoading    = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() { _errorMessage = '連線錯誤：$e'; _isLoading = false; });
    }
  }

  // ── 過濾 ────────────────────────────────────────────────────
  List<String> get _areaKeywords {
    final entry = kAreaList.firstWhere(
      (a) => a['name'] == _adminArea,
      orElse: () => {'name': _adminArea, 'keywords': _adminArea},
    );
    return (entry['keywords'] ?? _adminArea)
        .split(',')
        .map((k) => k.trim())
        .where((k) => k.isNotEmpty)
        .toList();
  }

  void _applyFilters() {
    List<Map<String, dynamic>> result;
    if (_showAll) {
      result = List.from(_allUsers);
    } else {
      final keywords = _areaKeywords;
      result = _allUsers.where((u) {
        final area    = (u['area']    ?? '').toString();
        final village = (u['village'] ?? '').toString();
        if (area.isEmpty && village.isEmpty) return true;
        return keywords.any((k) =>
            area.contains(k) || village.contains(k));
      }).toList();
    }
    if (_searchKeyword.isNotEmpty) {
      result = result.where((u) {
        final name  = (u['name']  ?? '').toString().toLowerCase();
        final phone = (u['phone'] ?? '').toString().toLowerCase();
        final id    = (u['id']    ?? '').toString().toLowerCase();
        return name.contains(_searchKeyword) ||
               phone.contains(_searchKeyword) ||
               id.contains(_searchKeyword);
      }).toList();
    }
    if (mounted) setState(() { _users = result; _currentPage = 0; });
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 280), () {
      setState(() => _searchKeyword = value.trim().toLowerCase());
      _applyFilters();
    });
  }

  // ── 統計 ────────────────────────────────────────────────────
  int get _areaTotal {
    if (_showAll) return _allUsers.length;
    final keywords = _areaKeywords;
    return _allUsers.where((u) {
      final area    = (u['area']    ?? '').toString();
      final village = (u['village'] ?? '').toString();
      if (area.isEmpty && village.isEmpty) return true;
      return keywords.any((k) => area.contains(k) || village.contains(k));
    }).length;
  }

  int get _totalPages =>
      (_users.isEmpty ? 1 : (_users.length / _pageSize).ceil());

  List<Map<String, dynamic>> get _pagedUsers {
    final start = _currentPage * _pageSize;
    if (start >= _users.length) return [];
    return _users.sublist(start, (start + _pageSize).clamp(0, _users.length));
  }

  List<int?> get _visiblePageNums {
    if (_totalPages <= 7) return List.generate(_totalPages, (i) => i);
    final Set<int> show = {0, _totalPages - 1};
    for (int i = _currentPage - 1; i <= _currentPage + 1; i++) {
      if (i >= 0 && i < _totalPages) show.add(i);
    }
    final sorted = show.toList()..sort();
    final result = <int?>[];
    for (int i = 0; i < sorted.length; i++) {
      if (i > 0 && sorted[i] - sorted[i - 1] > 1) result.add(null);
      result.add(sorted[i]);
    }
    return result;
  }

  // ════════════════════════════════════════════════════════════
  //  BUILD
  // ════════════════════════════════════════════════════════════
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

  // ── Header ──────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 20, 14),
      decoration: const BoxDecoration(
        color: _kCardBg,
        border: Border(bottom: BorderSide(color: _kBorder)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  '用戶管理',
                  style: TextStyle(
                    color: _kTextMain,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'USER MANAGEMENT',
                  style: TextStyle(
                    color: _kTextSub,
                    fontSize: 11,
                    letterSpacing: 1.4,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          // 本區 / 全部 toggle
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () {
              setState(() => _showAll = !_showAll);
              _applyFilters();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: _showAll
                    ? _kBlue.withValues(alpha: .08)
                    : _kCardBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: _showAll
                        ? _kBlue.withValues(alpha: .35)
                        : _kBorder),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _showAll
                        ? Icons.public_rounded
                        : Icons.filter_alt_outlined,
                    color: _showAll ? _kBlue : _kTextSub,
                    size: 14,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    _showAll ? '全部' : '本區',
                    style: TextStyle(
                      color: _showAll ? _kBlue : _kTextSub,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          // 刷新
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: _loadUsers,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _kCardBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _kBorder),
              ),
              child: const Icon(Icons.refresh_rounded,
                  color: _kBlue, size: 17),
            ),
          ),
        ],
      ),
    );
  }

  // ── Body ────────────────────────────────────────────────────
  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: _kBlue));
    }
    if (_errorMessage.isNotEmpty) return _buildError();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatsRow(),
          const SizedBox(height: 16),
          _buildSearchBar(),
          const SizedBox(height: 14),
          _buildTable(),
        ],
      ),
    );
  }

  // ── Stats Row ────────────────────────────────────────────────
  Widget _buildStatsRow() {
    return _statCard(
      label: '用戶總數',
      value: '$_areaTotal',
      icon: Icons.groups_rounded,
      color: _kBlue,
      gradient: const LinearGradient(
        colors: [Color(0xFF2563EB), Color(0xFF3B82F6)],
        begin: Alignment.topLeft, end: Alignment.bottomRight,
      ),
    );
  }

  Widget _statCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    required LinearGradient gradient,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: .25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .20),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
        const SizedBox(width: 14),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: .85),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ]),
      ]),
    );
  }

  // ── Search Bar ───────────────────────────────────────────────
  Widget _buildSearchBar() {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: _onSearchChanged,
        style: const TextStyle(color: _kTextMain, fontSize: 14),
        decoration: InputDecoration(
          hintText: '搜尋姓名 / ID / 電話號碼…',
          hintStyle: const TextStyle(color: _kTextSub, fontSize: 13),
          prefixIcon: const Icon(Icons.search_rounded,
              color: _kTextSub, size: 18),
          suffixIcon: _searchKeyword.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close_rounded,
                      color: _kTextSub, size: 16),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchKeyword = '');
                    _applyFilters();
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
        ),
      ),
    );
  }

  // ── Table ────────────────────────────────────────────────────
  Widget _buildTable() {
    return Container(
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .05),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildTableHeader(),
          if (_users.isEmpty)
            _buildTableEmpty()
          else
            ..._pagedUsers.asMap().entries.map(
                  (e) => _buildTableRow(
                      e.value, _currentPage * _pageSize + e.key),
                ),
          _buildPagination(),
        ],
      ),
    );
  }

  Widget _buildTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(15),
          topRight: Radius.circular(15),
        ),
        border: Border(
            bottom: BorderSide(color: _kBorder.withValues(alpha: .8))),
      ),
      child: Row(children: [
        const Expanded(
            flex: 5,
            child: Text('用戶', style: _headerStyle)),
        const Expanded(
            flex: 3,
            child: Text('ID', style: _headerStyle)),
        const Expanded(
            flex: 4,
            child: Text('聯絡電話', style: _headerStyle)),
      ]),
    );
  }

  Widget _buildTableRow(Map<String, dynamic> user, int globalIndex) {
    final name  = (user['name']  ?? '').toString();
    final id    = (user['id']    ?? '—').toString();
    final phone = (user['phone'] ?? '').toString();
    final area  = (user['area']  ?? '').toString();
    final isLast =
        globalIndex == _currentPage * _pageSize + _pagedUsers.length - 1;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(
                bottom: BorderSide(
                    color: _kBorder.withValues(alpha: .6), width: 0.8)),
      ),
      child: Row(children: [
        // 頭像 + 姓名
        Expanded(
          flex: 5,
          child: Row(children: [
            _buildAvatar(name),
            const SizedBox(width: 12),
            Flexible(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(
                  name.isEmpty ? '未填寫' : name,
                  style: const TextStyle(
                    color: _kTextMain,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (area.isNotEmpty)
                  Text(
                    area,
                    style: const TextStyle(
                        color: _kTextSub, fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ]),
            ),
          ]),
        ),
        // ID
        Expanded(
          flex: 3,
          child: Text(
            id.isEmpty ? '—' : id,
            style: const TextStyle(
              color: _kTextSub,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        // 電話
        Expanded(
          flex: 4,
          child: Row(children: [
            Icon(Icons.phone_outlined,
                size: 13,
                color: phone.isEmpty
                    ? _kTextSub.withValues(alpha: .35)
                    : _kTextSub.withValues(alpha: .6)),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                phone.isEmpty ? '未填寫' : phone,
                style: TextStyle(
                  color: phone.isEmpty
                      ? _kTextSub.withValues(alpha: .4)
                      : _kTextSub,
                  fontSize: 13,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ]),
        ),
        const SizedBox(width: 8),
        _actionBtn(() => _showUserDetail(user)),
      ]),
    );
  }

  Widget _actionBtn(VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: _kBlue.withValues(alpha: .06),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _kBlue.withValues(alpha: .2)),
        ),
        child: const Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.visibility_outlined, color: _kBlue, size: 13),
          SizedBox(width: 4),
          Text('詳情',
              style: TextStyle(
                  color: _kBlue, fontSize: 11, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }

  void _showUserDetail(Map<String, dynamic> user) {
    final name     = (user['name']    ?? '').toString();
    final id       = (user['id']      ?? '').toString();
    final phone    = (user['phone']   ?? '').toString();
    final area     = (user['area']    ?? '').toString();
    final village  = (user['village'] ?? '').toString();
    final ecName   = (user['emergencyContactName']     ?? '').toString();
    final ecPhone  = (user['emergencyContactPhone']    ?? '').toString();
    final ecRel    = (user['emergencyContactRelation'] ?? '').toString();
    final blood    = (user['bloodType']  ?? '').toString();
    final medical  = (user['medicalInfo'] ?? '').toString();
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: .35),
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: 480,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          decoration: BoxDecoration(
            color: _kCardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _kBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: .10),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── 標題列 ──────────────────────────────
              Container(
                padding: const EdgeInsets.fromLTRB(18, 16, 12, 14),
                decoration: const BoxDecoration(
                  color: Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
                  border: Border(bottom: BorderSide(color: _kBorder)),
                ),
                child: Row(children: [
                  Container(
                    width: 46, height: 46,
                    decoration: BoxDecoration(
                      color: _kBlue.withValues(alpha: .10),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Center(
                      child: Text(
                        name.isNotEmpty ? name[0] : '?',
                        style: const TextStyle(
                          color: _kBlue,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name.isEmpty ? '未填寫' : name,
                          style: const TextStyle(
                            color: _kTextMain,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: _kTextSub, size: 18),
                  ),
                ]),
              ),
              // ── 內容（可滾動）────────────────────────
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _detailSection('基本資料', Icons.person_outline_rounded, _kBlue, [
                        _detailRow('用戶 ID', id),
                        _detailRow('電話', phone),
                        _detailRow('所在區域', area),
                      ]),
                      const SizedBox(height: 14),
                      _detailSection('醫療資訊', Icons.favorite_border_rounded, _kRed, [
                        _detailRow('血型', blood),
                        _detailRow('病史 / 過敏', medical),
                      ]),
                      const SizedBox(height: 14),
                      _detailSection('緊急聯絡人', Icons.contact_phone_outlined, const Color(0xFFF59E0B), [
                        _detailRow('姓名', ecName),
                        _detailRow('電話', ecPhone),
                        _detailRow('關係', ecRel),
                      ]),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailSection(String title, IconData icon, Color color, List<Widget> rows) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .10),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 14),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ]),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _kBorder),
          ),
          child: Column(children: rows),
        ),
      ],
    );
  }

  Widget _detailRow(String label, String value) {
    final isEmpty = value.isEmpty;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _kBorder, width: 0.6)),
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
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              isEmpty ? '未填寫' : value,
              style: TextStyle(
                color: isEmpty ? _kTextSub.withValues(alpha: .5) : _kTextMain,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildAvatar(String name) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: _kBlue.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0] : '?',
          style: const TextStyle(
            color: _kBlue,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _buildTableEmpty() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 52),
      child: Column(children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: _kTextSub.withValues(alpha: .06),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.group_off_outlined,
              size: 28,
              color: _kTextSub.withValues(alpha: .5)),
        ),
        const SizedBox(height: 14),
        Text(
          _searchKeyword.isNotEmpty
              ? '沒有符合「$_searchKeyword」的用戶'
              : '目前沒有用戶資料',
          style: const TextStyle(
              color: _kTextSub,
              fontSize: 14,
              fontWeight: FontWeight.w500),
        ),
      ]),
    );
  }

  // ── Pagination ───────────────────────────────────────────────
  Widget _buildPagination() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: _kBorder.withValues(alpha: .8))),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(15),
          bottomRight: Radius.circular(15),
        ),
      ),
      child: Row(children: [
        const Text('顯示',
            style: TextStyle(color: _kTextSub, fontSize: 12)),
        const SizedBox(width: 6),
        _pageSizeDropdown(),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            '共 ${_users.length} 位用戶',
            style: const TextStyle(color: _kTextSub, fontSize: 12),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const Spacer(),
        _navBtn(Icons.chevron_left,
            _currentPage > 0
                ? () => setState(() => _currentPage--)
                : null,
            label: '上一頁'),
        const SizedBox(width: 4),
        ..._visiblePageNums.map((p) => p == null
            ? const Padding(
                padding: EdgeInsets.symmetric(horizontal: 3),
                child: Text('…',
                    style:
                        TextStyle(color: _kTextSub, fontSize: 12)),
              )
            : _pageNumBtn(p)),
        const SizedBox(width: 4),
        _navBtn(Icons.chevron_right,
            _currentPage < _totalPages - 1
                ? () => setState(() => _currentPage++)
                : null,
            label: '下一頁'),
      ]),
    );
  }

  Widget _pageSizeDropdown() {
    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        border: Border.all(color: _kBorder),
        borderRadius: BorderRadius.circular(7),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: _pageSize,
          isDense: true,
          style: const TextStyle(color: _kTextMain, fontSize: 12),
          icon: const Icon(Icons.keyboard_arrow_down_rounded,
              size: 14, color: _kTextSub),
          items: [10, 20, 50]
              .map((v) =>
                  DropdownMenuItem(value: v, child: Text('$v')))
              .toList(),
          onChanged: (v) {
            if (v == null) return;
            setState(() { _pageSize = v; _currentPage = 0; });
          },
        ),
      ),
    );
  }

  Widget _pageNumBtn(int page) {
    final selected = _currentPage == page;
    return GestureDetector(
      onTap: () => setState(() => _currentPage = page),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: 32,
        height: 32,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: selected ? _kBlue : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: selected ? _kBlue : _kBorder),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: _kBlue.withValues(alpha: .25),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  )
                ]
              : [],
        ),
        child: Center(
          child: Text(
            '${page + 1}',
            style: TextStyle(
              color: selected ? Colors.white : _kTextSub,
              fontSize: 12,
              fontWeight: selected
                  ? FontWeight.w700
                  : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }

  Widget _navBtn(IconData icon, VoidCallback? onTap,
      {required String label}) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: enabled
                  ? _kBorder
                  : _kBorder.withValues(alpha: .4)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon == Icons.chevron_left) ...[
            Icon(icon,
                size: 14,
                color: enabled
                    ? _kTextSub
                    : _kTextSub.withValues(alpha: .3)),
            const SizedBox(width: 2),
          ],
          Text(
            label,
            style: TextStyle(
              color: enabled
                  ? _kTextSub
                  : _kTextSub.withValues(alpha: .3),
              fontSize: 12,
            ),
          ),
          if (icon == Icons.chevron_right) ...[
            const SizedBox(width: 2),
            Icon(icon,
                size: 14,
                color: enabled
                    ? _kTextSub
                    : _kTextSub.withValues(alpha: .3)),
          ],
        ]),
      ),
    );
  }

  // ── Error ────────────────────────────────────────────────────
  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: _kRed.withValues(alpha: .08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.error_outline,
                color: _kRed, size: 28),
          ),
          const SizedBox(height: 14),
          Text(
            _errorMessage,
            textAlign: TextAlign.center,
            style: const TextStyle(color: _kRed, fontSize: 14),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: _loadUsers,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('重新載入'),
            style: OutlinedButton.styleFrom(
              foregroundColor: _kBlue,
              side: BorderSide(color: _kBlue.withValues(alpha: .4)),
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 10),
            ),
          ),
        ]),
      ),
    );
  }
}

// ── Shared styles ────────────────────────────────────────────────
const TextStyle _headerStyle = TextStyle(
  color: _kTextSub,
  fontSize: 11,
  fontWeight: FontWeight.w700,
  letterSpacing: 0.8,
);
