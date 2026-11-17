// ══════════════════════════════════════════════════════════
//  notification_page.dart
//  訊息通知管理：查詢收件者、發送通知（單一／群發／全體廣播）、查詢發送紀錄
//
//  對接後端通知 API（type: getNotificationRecipients / sendNotification /
//  getSentNotifications），格式依管理端提供的規格：
//    - 收件者一律用後端回傳的 Firebase UID，不使用 SQLite 的 U001 這種 id
//    - 同一次發送（含失敗重試）沿用同一個 clientRequestId；全新發送才產生新的
//    - API 回傳 published 只代表已送到通知服務，不代表使用者已收到／已讀
//    - 後端 Firebase 尚未正式啟用，未設定時可能回傳 503 —— 一律把後端訊息
//      原文顯示出來，不自行假設成功或失敗
// ══════════════════════════════════════════════════════════

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'package:flutter_disaster_app/core/api_config.dart';
import 'package:flutter_disaster_app/core/offline_demo_data.dart';
import 'package:flutter_disaster_app/admin_APP/widgets/page_header.dart';
import 'package:flutter_disaster_app/admin_APP/widgets/offline_demo_badge.dart';
import 'package:flutter_disaster_app/admin_APP/widgets/user_avatar.dart';

class NotificationPage extends StatefulWidget {
  const NotificationPage({super.key});
  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage>
    with SingleTickerProviderStateMixin {
  static const String _baseUrl = ApiConfig.baseUrl;
  static const _uuid = Uuid();

  late final TabController _tabController;

  Color get _blue   => const Color(0xFF2563EB);
  Color get _green  => const Color(0xFF16A34A);
  Color get _orange => const Color(0xFFF59E0B);
  Color get _red    => const Color(0xFFDC2626);
  Color get _bg     => const Color(0xFFF5F7FA);
  Color get _card   => Colors.white;

  bool _isOfflineDemo = false;

  // ── 收件者名單 ──────────────────────────────────────────
  List<Map<String, dynamic>> _recipients = [];
  bool _isLoadingRecipients = false;
  String _recipientKeyword = '';
  final TextEditingController _recipientSearchCtrl = TextEditingController();

  // ── 發送紀錄 ────────────────────────────────────────────
  List<Map<String, dynamic>> _sentList = [];
  bool _isLoadingSent = false;

  // ── 撰寫表單 ────────────────────────────────────────────
  /// single：單一使用者／multi：多人群發（最多 100 人）／broadcast：全體廣播
  String _audience = 'single';
  final Set<String> _selectedUids = {};
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  /// 老師說不用分類，固定送 general 就好，表單上不再讓人選
  final String _category = 'general';
  bool _isSending = false;
  String? _sendError;
  String? _sendOkMessage;
  /// 同一次發送（含重試）沿用的 clientRequestId；換內容或換對象就清空，下次送出會產生新的
  String? _pendingClientRequestId;
  /// 懸浮的「填寫通知內容」面板是否開啟
  bool _composeOpen = false;

  static const List<(String, String)> _categories = [
    ('general', '一般公告'),
    ('supply', '物資'),
    ('emergency', '緊急事件'),
    ('system', '系統'),
  ];

  static const int _multiLimit = 100;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _titleCtrl.addListener(_onComposeChanged);
    _bodyCtrl.addListener(_onComposeChanged);
    loadRecipients();
    loadSentNotifications();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _recipientSearchCtrl.dispose();
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  // ── 共用 POST（帶管理員 Token）────────────────────────────
  Future<String> _authToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('adminToken') ?? '';
  }

  String _truncate(String s, int n) => s.length <= n ? s : '${s.substring(0, n)}…';

  Future<Map<String, dynamic>> _post(Map<String, dynamic> payload) async {
    final token = await _authToken();
    final response = await http
        .post(
          Uri.parse(_baseUrl),
          headers: {
            'Content-Type': 'application/json',
            if (token.isNotEmpty) 'Authorization': 'Bearer $token',
          },
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 15));

    try {
      final data = jsonDecode(response.body);
      if (data is Map<String, dynamic>) return data;
    } catch (_) {
      // 後端沒回 JSON（例如 503 服務未設定時回純文字），往下組一個統一格式
    }
    return {
      'success': false,
      'message': '伺服器回應異常（HTTP ${response.statusCode}）：'
          '${_truncate(response.body.isEmpty ? '無回應內容' : response.body, 200)}',
    };
  }

  // ── 載入收件者名單 ──────────────────────────────────────
  Future<void> loadRecipients({bool silent = false}) async {
    if (!silent) setState(() => _isLoadingRecipients = true);
    try {
      final data = await _post({'type': 'getNotificationRecipients'});
      if (data['success'] == true) {
        final list = (data['data'] ?? data['recipients'] ?? []) as List;
        if (!mounted) return;
        setState(() {
          _recipients = list.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
          _isOfflineDemo = false;
        });
      } else if (mounted) {
        setState(() => _recipients = []);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _recipients = demoNotificationRecipients();
          _isOfflineDemo = true;
        });
      }
    } finally {
      if (mounted) setState(() => _isLoadingRecipients = false);
    }
  }

  // ── 載入發送紀錄 ────────────────────────────────────────
  Future<void> loadSentNotifications({bool silent = false}) async {
    if (!silent) setState(() => _isLoadingSent = true);
    try {
      final data = await _post({'type': 'getSentNotifications'});
      if (data['success'] == true) {
        final list = (data['data'] ?? data['notifications'] ?? []) as List;
        if (!mounted) return;
        setState(() {
          _sentList = list.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
            ..sort((a, b) => (b['sentAt']?.toString() ?? '').compareTo((a['sentAt']?.toString() ?? '')));
          _isOfflineDemo = false;
        });
      } else if (mounted) {
        setState(() => _sentList = []);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _sentList = demoSentNotifications();
          _isOfflineDemo = true;
        });
      }
    } finally {
      if (mounted) setState(() => _isLoadingSent = false);
    }
  }

  // ── 收件者輔助 ──────────────────────────────────────────
  String _uidOf(Map<String, dynamic> r) =>
      (r['uid'] ?? r['firebaseUid'] ?? r['firebase_uid'] ?? r['userUid'] ?? '').toString();

  List<Map<String, dynamic>> get _filteredRecipients {
    final kw = _recipientKeyword.trim().toLowerCase();
    if (kw.isEmpty) return _recipients;
    return _recipients.where((r) {
      final name = (r['name'] ?? '').toString().toLowerCase();
      final phone = (r['phone'] ?? '').toString().toLowerCase();
      final area = (r['area'] ?? '').toString().toLowerCase();
      final id = _uidOf(r).toLowerCase();
      return name.contains(kw) || phone.contains(kw) || area.contains(kw) || id.contains(kw);
    }).toList();
  }

  /// 任何撰寫內容變動都要重新整理畫面（發送按鈕是否可按），
  /// 如果這次變動發生在「送出失敗、準備重試」之後，就代表接下來要送的是「新的一次發送」
  void _onComposeChanged() {
    setState(() {
      if (_pendingClientRequestId != null) {
        _pendingClientRequestId = null;
        _sendError = null;
        _sendOkMessage = null;
      }
    });
  }

  void _setAudience(String value) {
    setState(() {
      _audience = value;
      _selectedUids.clear();
      _composeOpen = false;
    });
    _onComposeChanged();
  }

  void _toggleRecipient(String uid) {
    setState(() {
      if (_selectedUids.contains(uid)) {
        _selectedUids.remove(uid);
      } else {
        if (_selectedUids.length >= _multiLimit) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(backgroundColor: _red, content: Text('單次最多只能選 $_multiLimit 人')));
          return;
        }
        _selectedUids.add(uid);
      }
    });
    _onComposeChanged();
  }

  bool get _canSend {
    if (_isSending) return false;
    if (_titleCtrl.text.trim().isEmpty || _bodyCtrl.text.trim().isEmpty) return false;
    if (_audience != 'broadcast' && _selectedUids.isEmpty) return false;
    if (_audience != 'broadcast' && _selectedUids.length > _multiLimit) return false;
    return true;
  }

  Future<void> _send() async {
    if (!_canSend) return;
    final clientRequestId = _pendingClientRequestId ?? _uuid.v4();
    setState(() {
      _isSending = true;
      _sendError = null;
      _sendOkMessage = null;
      _pendingClientRequestId = clientRequestId;
    });

    final payload = <String, dynamic>{
      'type': 'sendNotification',
      'audience': _audience == 'broadcast' ? 'broadcast' : 'users',
      if (_audience != 'broadcast') 'recipientUids': _selectedUids.toList(),
      'title': _titleCtrl.text.trim(),
      'body': _bodyCtrl.text.trim(),
      'category': _category,
      'clientRequestId': clientRequestId,
    };

    try {
      final data = await _post(payload);
      if (!mounted) return;
      if (data['success'] == true) {
        final status = (data['status'] ?? data['data']?['status'] ?? 'published').toString();
        setState(() {
          _sendOkMessage = '已送出（狀態：$status）。published 代表已交給通知服務，不代表使用者已收到或已讀。';
          _pendingClientRequestId = null;
          _titleCtrl.clear();
          _bodyCtrl.clear();
          _selectedUids.clear();
        });
        await loadSentNotifications(silent: true);
      } else {
        setState(() => _sendError = data['message']?.toString() ?? '發送失敗，後端沒有提供原因');
      }
    } catch (e) {
      if (_isOfflineDemo) {
        // 離線示範：直接在本機模擬一筆成功發送紀錄，方便測試 UI
        final demoRecord = {
          'notificationId': 'N-DEMO-${DateTime.now().millisecondsSinceEpoch}',
          'title': _titleCtrl.text.trim(),
          'body': _bodyCtrl.text.trim(),
          'audience': _audience == 'broadcast' ? 'broadcast' : 'users',
          'recipientCount': _audience == 'broadcast' ? 0 : _selectedUids.length,
          'category': _category,
          'status': 'published',
          'sentAt': DateTime.now().toIso8601String(),
        };
        if (!mounted) return;
        setState(() {
          _sentList.insert(0, demoRecord);
          _sendOkMessage = '離線示範：已在本機模擬發送成功。';
          _pendingClientRequestId = null;
          _titleCtrl.clear();
          _bodyCtrl.clear();
          _selectedUids.clear();
        });
      } else if (mounted) {
        setState(() => _sendError = '連線失敗：$e（可以直接按「重新送出」重試，會沿用同一筆發送紀錄）');
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  // ── Build ───────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Column(children: [
        PageHeader(
          title: '訊息通知',
          subtitle: 'NOTIFICATION MANAGEMENT',
          badges: [if (_isOfflineDemo) const OfflineDemoBadge()],
          actions: [
            PageHeaderButton(
              icon: Icons.refresh_rounded,
              tooltip: '重新整理',
              onPressed: () {
                if (_tabController.index == 0) {
                  loadRecipients();
                } else {
                  loadSentNotifications();
                }
              },
            ),
          ],
        ),
        Container(
          decoration: BoxDecoration(
            color: _card,
            border: const Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
          ),
          child: TabBar(
            controller: _tabController,
            labelColor: _blue,
            unselectedLabelColor: const Color(0xFF475569),
            indicatorColor: _blue,
            dividerColor: Colors.transparent,
            labelStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            unselectedLabelStyle: const TextStyle(fontSize: 15),
            tabs: [
              for (final (icon, text) in const [
                (Icons.campaign_outlined, '發送通知'),
                (Icons.history_rounded, '發送紀錄'),
              ])
                Tab(
                  height: 48,
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(icon, size: 19),
                    const SizedBox(width: 8),
                    Text(text),
                  ]),
                ),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [_composeTab(), _historyTab()],
          ),
        ),
      ]),
    );
  }

  // ══════════════════════════════════════════════════════════
  // Tab 0：發送通知
  // ══════════════════════════════════════════════════════════
  Widget _composeTab() {
    return Stack(children: [
      Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _stepLabel('1', '選擇發送對象'),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _audienceChip('single', Icons.person_outline, '單一使用者')),
            const SizedBox(width: 8),
            Expanded(child: _audienceChip('broadcast', Icons.campaign_outlined, '全體廣播')),
          ]),
          const SizedBox(height: 14),
          // 固定高度：切換單一／群發／廣播時，版面不會跳動
          SizedBox(
            height: 360,
            child: _audience == 'broadcast' ? _broadcastPlaceholder() : _recipientSelectArea(),
          ),
          const SizedBox(height: 16),
          _composeTriggerButton(),
        ]),
      ),
      if (_composeOpen) _composeOverlay(),
    ]);
  }

  Widget _recipientSelectArea() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      TextField(
        controller: _recipientSearchCtrl,
        onChanged: (v) => setState(() => _recipientKeyword = v),
        decoration: InputDecoration(
          hintText: '搜尋姓名 / ID / 電話 / 地區...',
          prefixIcon: const Icon(Icons.search, size: 20),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
          ),
        ),
      ),
      const SizedBox(height: 8),
      Row(children: [
        Text('已選 ${_selectedUids.length} / $_multiLimit 人（可複選）',
            style: const TextStyle(color: Color(0xFF475569), fontSize: 13, fontWeight: FontWeight.w600)),
        const Spacer(),
        if (_selectedUids.isNotEmpty)
          TextButton(
            onPressed: () { setState(() => _selectedUids.clear()); _onComposeChanged(); },
            child: const Text('清除選擇'),
          ),
      ]),
      const SizedBox(height: 4),
      Expanded(child: _recipientList()),
    ]);
  }

  Widget _stepLabel(String n, String text) => Row(children: [
        Container(
          width: 20, height: 20,
          decoration: BoxDecoration(color: _blue, shape: BoxShape.circle),
          child: Center(child: Text(n, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800))),
        ),
        const SizedBox(width: 8),
        Text(text, style: const TextStyle(color: Color(0xFF0F172A), fontSize: 15, fontWeight: FontWeight.w800)),
      ]);

  Widget _broadcastPlaceholder() => Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.campaign_outlined, color: Color(0xFF94A3B8), size: 36),
            const SizedBox(height: 10),
            const Text('將發送給全體使用者', style: TextStyle(color: Color(0xFF475569), fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            const Text('不用另外選收件者', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
            const SizedBox(height: 18),
            if (_isLoadingRecipients)
              const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
            else if (_recipients.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(color: _blue.withValues(alpha: .08), borderRadius: BorderRadius.circular(999)),
                child: Text('預估發送對象：目前共 ${_recipients.length} 位使用者',
                    style: TextStyle(color: _blue, fontSize: 13, fontWeight: FontWeight.w700)),
              ),
          ]),
        ),
      );

  Widget _composeTriggerButton() {
    final ready = _audience == 'broadcast' || _selectedUids.isNotEmpty;
    final label = switch (_audience) {
      'single' => ready ? '填寫通知內容（已選 ${_selectedUids.length} 人）' : '請先選擇收件者（可複選，最多 $_multiLimit 人）',
      _        => '填寫通知內容',
    };
    return SizedBox(
      width: double.infinity, height: 46,
      child: ElevatedButton.icon(
        onPressed: ready ? () => setState(() => _composeOpen = true) : null,
        style: ElevatedButton.styleFrom(backgroundColor: _blue, foregroundColor: Colors.white),
        icon: const Icon(Icons.edit_note_rounded, size: 20),
        label: Text(label),
      ),
    );
  }

  Widget _audienceChip(String value, IconData icon, String label) {
    final sel = _audience == value;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => _setAudience(value),
      child: Container(
        height: 62,
        decoration: BoxDecoration(
          color: sel ? _blue : _card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: sel ? _blue : const Color(0xFFE5E7EB)),
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 18, color: sel ? Colors.white : const Color(0xFF475569)),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(
              color: sel ? Colors.white : const Color(0xFF475569),
              fontSize: 12.5, fontWeight: sel ? FontWeight.w700 : FontWeight.w500)),
        ]),
      ),
    );
  }

  // ── 懸浮的「填寫通知內容」面板 ──────────────────────────
  String _selectedRecipientName() {
    if (_selectedUids.isEmpty) return '—';
    final uid = _selectedUids.first;
    final match = _recipients.where((e) => _uidOf(e) == uid);
    final name = match.isEmpty ? '' : (match.first['name'] ?? '').toString();
    return name.isEmpty ? uid : name;
  }

  Widget _composeOverlay() {
    final targetLabel = switch (_audience) {
      'single' => _selectedUids.length == 1 ? _selectedRecipientName() : '已選 ${_selectedUids.length} 人',
      _        => '全體廣播',
    };
    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _composeOpen = false),
        child: Container(
          color: Colors.black.withValues(alpha: .35),
          child: Center(
            child: GestureDetector(
              onTap: () {},
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480, maxHeight: 620),
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: _card,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .20), blurRadius: 30, offset: const Offset(0, 12))],
                    ),
                    child: SingleChildScrollView(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              const Text('填寫通知內容', style: TextStyle(color: Color(0xFF0F172A), fontSize: 16, fontWeight: FontWeight.w800)),
                              const SizedBox(height: 2),
                              Text('收件者：$targetLabel', style: const TextStyle(color: Color(0xFF64748B), fontSize: 12.5)),
                            ]),
                          ),
                          InkWell(
                            onTap: () => setState(() => _composeOpen = false),
                            child: const Icon(Icons.close, size: 20, color: Color(0xFF94A3B8)),
                          ),
                        ]),
                        const Divider(height: 24, color: Color(0xFFE5E7EB)),
                        _composeForm(),
                      ]),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _recipientList() {
    if (_isLoadingRecipients && _recipients.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    final rows = _filteredRecipients;
    if (rows.isEmpty) {
      return Center(
        child: Text(_recipientKeyword.isNotEmpty ? '找不到符合的使用者' : '目前沒有可通知的使用者',
            style: const TextStyle(color: Color(0xFF64748B), fontSize: 14)),
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      clipBehavior: Clip.antiAlias,
      child: ListView.separated(
        itemCount: rows.length,
        separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
        itemBuilder: (_, i) {
          final r = rows[i];
          final uid = _uidOf(r);
          final name = (r['name'] ?? '').toString();
          final selected = _selectedUids.contains(uid);
          final nameColor = name.isEmpty ? const Color(0xFF64748B) : UserAvatar.colorFor(i);
          return InkWell(
            onTap: uid.isEmpty ? null : () => _toggleRecipient(uid),
            child: Container(
              color: selected ? _blue.withValues(alpha: .05) : (i.isEven ? _card : const Color(0xFFF8FAFC)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Container(
                    width: 20, height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: selected ? _blue : Colors.transparent,
                      border: Border.all(color: selected ? _blue : const Color(0xFFCBD5E1), width: 1.5),
                    ),
                    child: selected
                        ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
                        : null,
                  ),
                ),
                UserAvatar(name: name, index: i),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(name.isEmpty ? '未填寫' : name,
                        style: TextStyle(color: nameColor, fontSize: 14, fontWeight: FontWeight.w700)),
                    Text(
                        [
                          if ((r['phone'] ?? '').toString().isNotEmpty) r['phone'].toString(),
                          if ((r['area'] ?? '').toString().isNotEmpty) r['area'].toString(),
                        ].join('　'),
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Color(0xFF64748B), fontSize: 12.5)),
                  ]),
                ),
                if (uid.isEmpty)
                  Tooltip(
                    message: '這筆資料沒有 Firebase UID，無法發送通知',
                    child: Icon(Icons.warning_amber_rounded, size: 16, color: _orange),
                  ),
              ]),
            ),
          );
        },
      ),
    );
  }

  Widget _composeForm() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _formLabel('標題'),
        TextField(
          controller: _titleCtrl,
          maxLength: 40,
          decoration: _fieldDeco('例如：物資領取通知'),
        ),
        _formLabel('內容'),
        TextField(
          controller: _bodyCtrl,
          maxLines: 4,
          maxLength: 200,
          decoration: _fieldDeco('例如：請至社區管理中心領取。'),
        ),
        const SizedBox(height: 4),
        if (_sendError != null) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _red.withValues(alpha: .06),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _red.withValues(alpha: .2)),
            ),
            child: Text(_sendError!, style: TextStyle(color: _red, fontSize: 13)),
          ),
          const SizedBox(height: 10),
        ],
        if (_sendOkMessage != null) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _green.withValues(alpha: .06),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _green.withValues(alpha: .2)),
            ),
            child: Text(_sendOkMessage!, style: TextStyle(color: _green, fontSize: 13)),
          ),
          const SizedBox(height: 10),
        ],
        SizedBox(
          width: double.infinity,
          height: 46,
          child: ElevatedButton.icon(
            onPressed: _canSend ? _send : null,
            style: ElevatedButton.styleFrom(backgroundColor: _blue, foregroundColor: Colors.white),
            icon: _isSending
                ? const SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.send_rounded, size: 18),
            label: Text(_sendError != null && _pendingClientRequestId != null ? '重新送出' : '發送通知'),
          ),
        ),
      ]);
  }

  Widget _formLabel(String text) => Padding(
        padding: const EdgeInsets.only(top: 10, bottom: 6),
        child: Text(text, style: const TextStyle(color: Color(0xFF475569), fontSize: 13, fontWeight: FontWeight.w600)),
      );

  InputDecoration _fieldDeco(String hint) => InputDecoration(
        hintText: hint,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _blue)),
      );

  String _formatDateTime(DateTime t) =>
      '${t.year}/${t.month.toString().padLeft(2, '0')}/${t.day.toString().padLeft(2, '0')} '
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  // ══════════════════════════════════════════════════════════
  // Tab 1：發送紀錄
  // ══════════════════════════════════════════════════════════
  Widget _historyTab() {
    if (_isLoadingSent && _sentList.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_sentList.isEmpty) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.history_rounded, color: Color(0xFF94A3B8), size: 40),
        const SizedBox(height: 10),
        const Text('目前沒有發送紀錄', style: TextStyle(color: Color(0xFF64748B), fontSize: 14)),
      ]));
    }
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: const Color(0xFFF8FAFC),
            child: const Row(children: [
              Expanded(flex: 4, child: Text('標題', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF475569)))),
              Expanded(flex: 2, child: Text('對象', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF475569)))),
              Expanded(flex: 2, child: Text('分類', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF475569)))),
              Expanded(flex: 2, child: Text('狀態', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF475569)))),
              Expanded(flex: 3, child: Text('發送時間', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF475569)))),
            ]),
          ),
          const Divider(height: 1, color: Color(0xFFE5E7EB)),
          Expanded(
            child: ListView.separated(
              itemCount: _sentList.length,
              separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
              itemBuilder: (_, i) => _historyRow(_sentList[i], i),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _historyRow(Map<String, dynamic> n, int index) {
    final audience = (n['audience'] ?? '').toString();
    final count = (n['recipientCount'] as num?)?.toInt() ?? (n['recipientUids'] as List?)?.length ?? 0;
    final audienceLabel = audience == 'broadcast' ? '全體廣播' : (count <= 1 ? '單一使用者' : '群發 $count 人');
    final category = _categoryLabel(n['category']?.toString() ?? '');
    final status = (n['status'] ?? '').toString();
    final sentAt = n['sentAt']?.toString() ?? '';

    return InkWell(
      onTap: () => _showHistoryDetail(n),
      child: Container(
        color: index.isEven ? _card : const Color(0xFFF8FAFC),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(children: [
          Expanded(flex: 4, child: Text(n['title']?.toString() ?? '（無標題）',
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)))),
          Expanded(flex: 2, child: Text(audienceLabel, style: const TextStyle(fontSize: 13, color: Color(0xFF475569)))),
          Expanded(flex: 2, child: Text(category, style: const TextStyle(fontSize: 13, color: Color(0xFF475569)))),
          Expanded(flex: 2, child: _statusBadge(status)),
          Expanded(flex: 3, child: Text(_formatRaw(sentAt), style: const TextStyle(fontSize: 13, color: Color(0xFF475569)))),
        ]),
      ),
    );
  }

  String _categoryLabel(String v) {
    for (final (value, label) in _categories) {
      if (value == v) return label;
    }
    return v.isEmpty ? '—' : v;
  }

  String _formatRaw(String raw) {
    final t = DateTime.tryParse(raw);
    if (t == null) return raw.isEmpty ? '—' : raw;
    return _formatDateTime(t.toLocal());
  }

  Widget _statusBadge(String status) {
    final (label, color) = switch (status) {
      'published' => ('已發布', _green),
      'failed'    => ('失敗', _red),
      'pending'   => ('處理中', _orange),
      _           => (status.isEmpty ? '—' : status, const Color(0xFF64748B)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: .1), borderRadius: BorderRadius.circular(999)),
      child: Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
    );
  }

  void _showHistoryDetail(Map<String, dynamic> n) {
    final audience = (n['audience'] ?? '').toString();
    final count = (n['recipientCount'] as num?)?.toInt() ?? (n['recipientUids'] as List?)?.length ?? 0;
    final audienceLabel = audience == 'broadcast' ? '全體廣播' : '$count 人';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(children: [
          Expanded(child: Text(n['title']?.toString() ?? '（無標題）')),
          InkWell(
            onTap: () => Navigator.pop(ctx),
            borderRadius: BorderRadius.circular(16),
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(Icons.close, size: 20, color: Color(0xFF94A3B8)),
            ),
          ),
        ]),
        content: SizedBox(
          width: 420,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(n['body']?.toString() ?? '', style: const TextStyle(fontSize: 14, color: Color(0xFF0F172A))),
            const SizedBox(height: 14),
            _detailLine('對象', audienceLabel),
            _detailLine('分類', _categoryLabel(n['category']?.toString() ?? '')),
            _detailLine('狀態', n['status']?.toString() ?? '—'),
            _detailLine('發送時間', _formatRaw(n['sentAt']?.toString() ?? '')),
            if ((n['notificationId'] ?? n['id'])?.toString().isNotEmpty == true)
              _detailLine('通知編號', (n['notificationId'] ?? n['id']).toString()),
            if ((n['clientRequestId'])?.toString().isNotEmpty == true)
              _detailLine('發送識別碼', n['clientRequestId'].toString()),
          ]),
        ),
      ),
    );
  }

  Widget _detailLine(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 72, child: Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF475569)))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)))),
        ]),
      );
}
