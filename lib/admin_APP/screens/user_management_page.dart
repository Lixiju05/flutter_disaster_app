import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_disaster_app/admin_APP/widgets/page_header.dart';
import 'package:flutter_disaster_app/admin_APP/widgets/offline_demo_badge.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'admin_setup_page.dart' show kAreaList;
import 'package:flutter_disaster_app/core/api_config.dart';
import 'package:flutter_disaster_app/core/offline_demo_data.dart';

// ── 色系 ────────────────────────────────────────────────────────
const Color _kBg       = Color(0xFFF5F7FA);
const Color _kCardBg   = Color(0xFFFFFFFF);
const Color _kBorder   = Color(0xFFCBD5E1);
const Color _kBlue     = Color(0xFF2563EB);
const Color _kTextMain = Color(0xFF0F172A);
const Color _kTextSub  = Color(0xFF475569);
const Color _kRed      = Color(0xFFDC2626);

const String _umBaseUrl = ApiConfig.baseUrl;


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
  bool   _isOfflineDemo = false;

  int _currentPage = 0;
  final ScrollController _listCtrl = ScrollController();
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
    _listCtrl.dispose();
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
          _isOfflineDemo = false;
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
      // 連不上後端時，先用示範資料讓畫面可以照常顯示、方便改 UI
      setState(() {
        _allUsers      = demoUserMaps();
        _errorMessage  = '';
        _isLoading     = false;
        _isOfflineDemo = true;
      });
      _applyFilters();
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
    return PageHeader(
      title: '用戶管理',
      subtitle: 'USER MANAGEMENT',
      badges: [
        if (!_isLoading && _errorMessage.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _kBlue.withValues(alpha: .08),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: _kBlue.withValues(alpha: .18)),
            ),
            child: Text('共 $_areaTotal 位',
                style: const TextStyle(color: _kBlue, fontSize: 13, fontWeight: FontWeight.w700)),
          ),
        if (_isOfflineDemo) const OfflineDemoBadge(),
      ],
      actions: [
          // 地區篩選：全部區域 / kAreaList 各區
          _areaDropdown(),
          const SizedBox(width: 8),
          // 刷新
          PageHeaderButton(
              icon: Icons.refresh_rounded, tooltip: '重新整理', onPressed: _loadUsers),
      ],
    );
  }

  Widget _areaDropdown() {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: _showAll ? _kBlue.withValues(alpha: .08) : _kCardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _showAll ? _kBlue.withValues(alpha: .35) : _kBorder),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _showAll ? '全部區域' : _adminArea,
          isDense: true,
          icon: Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: _showAll ? _kBlue : _kTextSub),
          style: TextStyle(color: _showAll ? _kBlue : _kTextMain, fontSize: 13, fontWeight: FontWeight.w700),
          items: [
            const DropdownMenuItem(value: '全部區域', child: Text('全部區域')),
            for (final a in kAreaList) DropdownMenuItem(value: a['name'], child: Text(a['name']!)),
          ],
          onChanged: (v) {
            if (v == null) return;
            setState(() {
              _showAll = v == '全部區域';
              if (!_showAll) _adminArea = v;
            });
            _applyFilters();
          },
        ),
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

    // 搜尋列固定，只有用戶資料在表格內上下滑動（同其他頁）
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSearchBar(),
          const SizedBox(height: 12),
          Expanded(child: _buildTable()),
        ],
      ),
    );
  }

  // ── Search Bar ───────────────────────────────────────────────
  Widget _buildSearchBar() {
    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kBorder),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: _onSearchChanged,
        style: const TextStyle(color: _kTextMain, fontSize: 16),
        decoration: InputDecoration(
          hintText: '搜尋姓名 / ID / 電話號碼…',
          hintStyle: const TextStyle(color: _kTextSub, fontSize: 15),
          prefixIcon: const Icon(Icons.search_rounded,
              color: _kTextSub, size: 20),
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
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBorder),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: .10), blurRadius: 24, offset: const Offset(0, 8)),
          BoxShadow(color: Colors.black.withValues(alpha: .04), blurRadius: 4, offset: const Offset(0, 1)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _buildTableHeader(),
          Expanded(
            child: _users.isEmpty
                ? SingleChildScrollView(child: _buildTableEmpty())
                : Scrollbar(
                    controller: _listCtrl,
                    thumbVisibility: true,
                    child: ListView.builder(
                      controller: _listCtrl,
                      itemCount: _pagedUsers.length,
                      itemBuilder: (_, i) => _buildTableRow(
                          _pagedUsers[i], _currentPage * _pageSize + i),
                    ),
                  ),
          ),
          _buildPagination(),
        ],
      ),
    );
  }

  Widget _buildTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        border: Border(bottom: BorderSide(color: _kBorder)),
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
        const SizedBox(
            width: _actionWidth,
            child: Text('操作', style: _headerStyle)),
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
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: globalIndex.isEven ? _kCardBg : const Color(0xFFF8FAFC),
        border: isLast
            ? null
            : const Border(bottom: BorderSide(color: Color(0xFFCBD5E1), width: 1.2)),
      ),
      child: Row(children: [
        // 頭像 + 姓名
        Expanded(
          flex: 5,
          child: Row(children: [
            _buildAvatar(name, globalIndex),
            const SizedBox(width: 12),
            Flexible(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(
                  name.isEmpty ? '未填寫' : name,
                  style: const TextStyle(
                    color: _kTextMain,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (area.isNotEmpty)
                  Row(children: [
                    const Icon(Icons.location_on, size: 12, color: Color(0xFF94A3B8)),
                    const SizedBox(width: 2),
                    Flexible(
                      child: Text(
                        area,
                        style: const TextStyle(color: _kTextSub, fontSize: 14),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ]),
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
              color: _kTextMain,
              fontSize: 15,
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
            Flexible(
              child: Text(
                phone.isEmpty ? '未填寫' : phone,
                style: TextStyle(
                  color: phone.isEmpty ? _kTextSub : _kTextMain,
                  fontSize: 15,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ]),
        ),
        SizedBox(
          width: _actionWidth,
          child: Align(
            alignment: Alignment.centerLeft,
            child: _actionBtn(() => _showUserDetail(user)),
          ),
        ),
      ]),
    );
  }

  /// 白底外框按鈕（同緊急事件、健康回報、物資管理的「詳情」）
  Widget _actionBtn(VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _kBlue.withValues(alpha: .4)),
        ),
        child: const Text('詳情',
            style: TextStyle(
                color: _kBlue, fontSize: 14, fontWeight: FontWeight.w700)),
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
              color: color,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [BoxShadow(color: color.withValues(alpha: .32), blurRadius: 6, offset: const Offset(0, 2))],
            ),
            child: Icon(icon, color: Colors.white, size: 14),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              color: color,
              fontSize: 14,
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
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              isEmpty ? '未填寫' : value,
              style: TextStyle(
                color: isEmpty ? _kTextSub.withValues(alpha: .5) : _kTextMain,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }


  static const _avatarColors = [
    Color(0xFFDC2626), Color(0xFFD97706), Color(0xFF16A34A),
    Color(0xFF2563EB), Color(0xFF7C3AED), Color(0xFFDB2777),
  ];

  Widget _buildAvatar(String name, int index) {
    final color = name.isEmpty
        ? const Color(0xFF64748B)
        : _avatarColors[index % _avatarColors.length];
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: color.withValues(alpha: .20),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0] : '?',
          style: TextStyle(
            color: color,
            fontSize: 16,
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
              fontSize: 15,
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
        border: Border(top: BorderSide(color: _kBorder)),
      ),
      child: Row(children: [
        const Text('每頁顯示',
            style: TextStyle(color: _kTextSub, fontSize: 14)),
        const SizedBox(width: 6),
        _pageSizeDropdown(),
        const SizedBox(width: 6),
        const Text('筆',
            style: TextStyle(color: _kTextSub, fontSize: 14)),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            '共 ${_users.length} 位用戶',
            style: const TextStyle(color: _kTextSub, fontSize: 14),
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
                        TextStyle(color: _kTextSub, fontSize: 14)),
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
          style: const TextStyle(color: _kTextMain, fontSize: 14),
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
        ),
        child: Center(
          child: Text(
            '${page + 1}',
            style: TextStyle(
              color: selected ? Colors.white : _kTextSub,
              fontSize: 13,
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
              fontSize: 13,
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
            style: const TextStyle(color: _kRed, fontSize: 15),
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
  color: Color(0xFF334155),
  fontSize: 14,
  fontWeight: FontWeight.w700,
);

/// 「操作」欄寬度（表頭與每列對齊）
const double _actionWidth = 96;
