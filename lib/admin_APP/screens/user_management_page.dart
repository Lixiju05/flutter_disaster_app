
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
class UserManagementPage extends StatefulWidget {
  const UserManagementPage({super.key});

  @override
  State<UserManagementPage> createState() => _UserManagementPageState();
}

class _UserManagementPageState extends State<UserManagementPage> {
  // ⭐ 新增这一行（放最上面）
static const Color moduleColor = Color(0xFF4A90E2);
  final TextEditingController _searchController = TextEditingController();

  Timer? _debounce;
  Timer? _refreshTimer;

  List<dynamic> _allUsers = [];
  List<dynamic> _users = [];

  bool _isLoading = false;
  String _errorMessage = '';

  String _searchKeyword = '';
  String _selectedArea = 'all';

 //static const String _baseUrl = 'http://localhost:8080';
 static const String _baseUrl = 'https://delphine-eisteddfodic-afflictively.ngrok-free.dev';

  static const Color _bg = Color(0xFFF5F7FB);
  static const Color _card = Colors.white;
  static const Color _border = Color(0xFFE2E8F0);
  static const Color _textMain = Color(0xFF0F172A);
  static const Color _textSub = Color(0xFF64748B);
  static const Color _blue = Color(0xFF2563EB);
  static const Color _green = Color(0xFF16A34A);
  static const Color _orange = Color(0xFFF59E0B);
  static const Color _red = Color.fromARGB(255, 208, 35, 35);

  @override
  void initState() {
    super.initState();

    loadUsers();

    _refreshTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) {
        loadUsers(showLoading: false);
      },
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }
  Future<void> loadUsers({bool showLoading = true}) async {
  final url = Uri.parse(_baseUrl);
  final requestBody = jsonEncode({
    'type': 'getAllUsers',
  });

  print('========== Flutter 準備呼叫 getAllUsers ==========');
  print('URL: $url');
  print('BODY: $requestBody');
  print('時間: ${DateTime.now()}');
  print('===============================================');

  if (showLoading && mounted) {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
  }

  try {
    final response = await http
        .post(
          url,
          headers: {
            'Content-Type': 'application/json',
              'Accept': 'application/json',
            'ngrok-skip-browser-warning': 'true',
          },
          body: requestBody,
        )
        .timeout(const Duration(seconds: 10));

    print('========== Flutter 收到 API ==========');
    print('statusCode: ${response.statusCode}');
    print('response.body: ${response.body}');
    print('=====================================');

    final data = jsonDecode(response.body);

    if (response.statusCode == 200 && data['success'] == true) {
      final users = List<Map<String, dynamic>>.from(data['data']);

      if (!mounted) return;

      setState(() {
        _allUsers = users;
      });

      _applyFilters();
    } else {
      if (!mounted) return;

      setState(() {
        _errorMessage = data['message'] ?? '取得用戶資料失敗';
      });
    }
  } catch (e, stack) {
    print('========== Flutter API 呼叫失敗 ==========');
    print('錯誤: $e');
    print(stack);
    print('=======================================');

    if (!mounted) return;

    setState(() {
      _errorMessage = '連線錯誤：$e';
    });
  } finally {
    if (mounted && showLoading) {
      setState(() {
        _isLoading = false;
      });
    }
  }
}

  

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      setState(() {
        _searchKeyword = value.trim().toLowerCase();
      });
      _applyFilters();
    });
  }

  void _applyFilters() {
    List<dynamic> result = List.from(_allUsers);

    if (_selectedArea != 'all') {
      result = result.where((u) {
        final area = (u['area'] ?? '').toString().toLowerCase();
        return area == _selectedArea.toLowerCase();
      }).toList();
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

    if (!mounted) return;

    setState(() {
      _users = result;
    });
  }

  List<String> _getAreas() {
    final areas = _allUsers
        .map((u) => (u['area'] ?? '').toString())
        .where((a) => a.isNotEmpty)
        .toSet()
        .toList();

    areas.sort();
    return ['all', ...areas];
  }

  int _countByArea(String area) {
    return _allUsers.where((u) => (u['area'] ?? '') == area).length;
  }

  String _getStatusText(dynamic user) {
    final raw = (user['status'] ?? '').toString().trim();
    if (raw.isEmpty) return '一般';

    if (raw == 'safe' || raw == '正常') return '正常';
    if (raw == 'warning' || raw == '需關注') return '需關注';
    if (raw == 'critical' || raw == 'danger' || raw == '危急') return '危急';
    return raw;
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case '正常':
        return _green;
      case '需關注':
        return _orange;
      case '危急':
        return _red;
      default:
        return _blue;
    }
  }

  Color _getStatusBgColor(String status) {
    switch (status) {
      case '正常':
        return const Color(0xFFDCFCE7);
      case '需關注':
        return const Color(0xFFFEF3C7);
      case '危急':
        return const Color(0xFFFEE2E2);
      default:
        return const Color(0xFFDBEAFE);
    }
  }

  @override
  Widget build(BuildContext context) {
    final areaList = _getAreas();

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage.isNotEmpty
                ? Center(
                    child: Text(
                      _errorMessage,
                      style: const TextStyle(
                        color: Colors.red,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                : SingleChildScrollView(
                    child: Column(
                      children: [
                        _buildHeroHeader(),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                          child: Column(
                            children: [
                              _buildStatsRow(
                                total: _allUsers.length,
                                current: _users.length,
                                areaCount: areaList.length - 1,
                              ),
                              const SizedBox(height: 22),
                              _buildSearchActionBar(),
                              const SizedBox(height: 22),
                              _buildSegmentTabs(areaList),
                              const SizedBox(height: 22),
                              if (_allUsers.isEmpty)
                                _buildEmptyState('目前沒有用戶資料')
                              else if (_users.isEmpty)
                                _buildEmptyState('沒有符合條件的用戶資料')
                              else
                                ..._users.map(
                                  (user) => Padding(
                                    padding: const EdgeInsets.only(bottom: 18),
                                    child: _buildUserCard(user),
                                  ),
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

  Widget _buildHeroHeader() {
    return Container(
      margin: const EdgeInsets.all(24),
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 18,
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
              color: moduleColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.groups_rounded,
              color: moduleColor,
              size: 30,
            ),
          ),
          const SizedBox(width: 18),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '用戶管理',
                  style: TextStyle(
                    color: _textMain,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  '管理災民基本資料、聯絡資訊與區域分佈',
                  style: TextStyle(
                    color: _textSub,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.notifications_none_rounded,
              color: moduleColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow({
    required int total,
    required int current,
    required int areaCount,
  }) {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            title: '全部用戶',
            subtitle: '所有註冊用戶',
            value: total.toString(),
            icon: Icons.groups_2_outlined,
            iconColor: _blue,
            iconBg: const Color(0xFFE8F0FF),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            title: '目前顯示',
            subtitle: '當前列表數量',
            value: current.toString(),
            icon: Icons.remove_red_eye_outlined,
            iconColor: _green,
            iconBg: const Color(0xFFE8F8ED),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            title: '區域數量',
            subtitle: '服務區域數量',
            value: areaCount.toString(),
            icon: Icons.apartment_outlined,
            iconColor: _orange,
            iconBg: const Color(0xFFFFF3E0),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String subtitle,
    required String value,
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
  }) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.035),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(icon, color: iconColor, size: 30),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: _textSub,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: const TextStyle(
                    color: _textMain,
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: _textSub,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: _textSub),
        ],
      ),
    );
  }

  Widget _buildSearchActionBar() {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 64,
            decoration: BoxDecoration(
              color: _card,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              style: const TextStyle(
                color: _textMain,
                fontSize: 16,
              ),
              decoration: InputDecoration(
                hintText: '搜尋姓名 / 電話 / 區域...',
                hintStyle: const TextStyle(color: _textSub),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: _textSub,
                  size: 24,
                ),
                suffixIcon: _searchKeyword.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded, color: _textSub),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchKeyword = '';
                          });
                          _applyFilters();
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 18,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),
        _buildActionButton(Icons.filter_alt_outlined, '篩選'),
        const SizedBox(width: 12),
        _buildActionButton(Icons.sort_rounded, '排序'),
      ],
    );
  }

  Widget _buildActionButton(IconData icon, String label) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.025),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: _textSub, size: 22),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: _textMain,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentTabs(List<String> areaList) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.025),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: areaList.map((area) {
          final bool isSelected = _selectedArea == area;
          final label = area == 'all' ? '全部' : area;
          final count = area == 'all' ? _allUsers.length : _countByArea(area);

          return InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () {
              setState(() {
                _selectedArea = area;
              });
              _applyFilters();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: isSelected ? _blue : Colors.transparent,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Text(
                '$label ($count)',
                style: TextStyle(
                  color: isSelected ? Colors.white : _textMain,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildUserCard(dynamic user) {
    final status = _getStatusText(user);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.035),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: const Color(0xFFEAF1FF),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(
              Icons.person_rounded,
              color: moduleColor,
              size: 42,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            flex: 7,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (user['name'] ?? '未命名').toString(),
                  style: const TextStyle(
                    color: _textMain,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'ID: ${(user['id'] ?? '').toString()}',
                  style: const TextStyle(
                   color: moduleColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: _buildPhoneBox(
                        value: (user['phone'] ?? '').toString(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildInfoBox(
                        icon: Icons.location_on_outlined,
                        label: '區域',
                        value: (user['area'] ?? '').toString(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildInfoBox(
                        icon: Icons.favorite_outline_rounded,
                        label: '血型',
                        value: (user['bloodType'] ?? '未填').toString(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.call_outlined,
                        color: _textSub,
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '緊急聯絡人：${(user['emergencyContactName'] ?? '').toString()} ｜ ${(user['emergencyContactPhone'] ?? '').toString()}',
                          style: const TextStyle(
                            color: _textSub,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: _getStatusBgColor(status),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.circle,
                        size: 10,
                        color: _getStatusColor(status),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        status,
                        style: TextStyle(
                          color: _getStatusColor(status),
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: 170,
                  child: ElevatedButton.icon(
                    onPressed: () => _showDetailDialog(context, user),
                    icon: const Icon(Icons.visibility_outlined, size: 18),
                    label: const Text('查看詳情'),
                    style: ElevatedButton.styleFrom(
                      elevation: 0,
                      backgroundColor: _blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      textStyle: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhoneBox({required String value}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF8FBFF), Color(0xFFEEF4FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFD7E3FF),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFE3EDFF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.phone_rounded,
             color: moduleColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value.isEmpty ? '未填寫' : value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _textMain,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  '聯絡電話',
                  style: TextStyle(
                    color: _textSub,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBox({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFFBFCFE),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE6ECF5)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5FF),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: moduleColor,size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value.isEmpty ? '未填寫' : value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _textMain,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  style: const TextStyle(
                    color: _textSub,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(42),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _border),
      ),
      child: Column(
        children: [
          const Icon(Icons.inbox_outlined, size: 50, color: _textSub),
          const SizedBox(height: 14),
          Text(
            message,
            style: const TextStyle(
              color: _textSub,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  void _showDetailDialog(BuildContext context, dynamic user) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: 620,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(24),
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (user['name'] ?? '未命名').toString(),
                  style: const TextStyle(
                    color: _textMain,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '用戶 ID：${(user['id'] ?? '').toString()}',
                  style: const TextStyle(
                    color: _textSub,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 20),
                _buildDialogItem('電話', (user['phone'] ?? '').toString()),
                _buildDialogItem('區域', (user['area'] ?? '').toString()),
                _buildDialogItem(
                  '血型',
                  (user['bloodType'] ?? '未填寫').toString(),
                ),
                _buildDialogItem(
                  '醫療資訊',
                  (user['medicalInfo'] ?? '無').toString(),
                ),
                _buildDialogItem(
                  '緊急聯絡人',
                  '${(user['emergencyContactName'] ?? '').toString()} (${(user['emergencyContactRelation'] ?? '').toString()})',
                ),
                _buildDialogItem(
                  '緊急聯絡電話',
                  (user['emergencyContactPhone'] ?? '').toString(),
                ),
                _buildDialogItem(
                  '註冊時間',
                  (user['registeredAt'] ?? '').toString(),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      '關閉',
                      style: TextStyle(
                        color: moduleColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDialogItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14),
        ),
        child: RichText(
          text: TextSpan(
            style: const TextStyle(
              fontSize: 14,
              color: _textMain,
              height: 1.6,
            ),
            children: [
              TextSpan(
                text: '$label：',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              TextSpan(
                text: value.isEmpty ? '未填寫' : value,
                style: const TextStyle(color: _textSub),
              ),
            ],
          ),
        ),
      ),
    );
  }
}