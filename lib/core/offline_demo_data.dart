// ══════════════════════════════════════════════════════════
//  offline_demo_data.dart
//  連不上後端（admin_server）時使用的「離線示範資料」。
//  只在各 API 呼叫真的連線失敗時才會被用到；後端連線正常時完全不影響。
//  資料全部標註「示範」，避免跟真實資料搞混。
// ══════════════════════════════════════════════════════════

import 'models/citizen.dart';
import 'models/supply.dart';
import 'models/emergency_request.dart';

List<Citizen> demoCitizens() => [
      Citizen(id: 'U001', name: '示範-王小明', latitude: 23.9479, longitude: 120.9686,
          needsRescue: false, phone: '0912-000-001', area: '南投縣埔里鎮'),
      Citizen(id: 'U002', name: '示範-陳美玲', latitude: 23.9502, longitude: 120.9711,
          needsRescue: true, phone: '0912-000-002', area: '南投縣埔里鎮'),
      Citizen(id: 'U003', name: '示範-林志豪', latitude: 23.9455, longitude: 120.9654,
          needsRescue: false, phone: '0912-000-003', area: '暨南大學'),
      Citizen(id: 'U004', name: '示範-黃淑芬', latitude: 23.9488, longitude: 120.9699,
          needsRescue: false, phone: '0912-000-004', area: '南投縣埔里鎮'),
      Citizen(id: 'U005', name: '示範-張家豪', latitude: 23.9467, longitude: 120.9672,
          needsRescue: true, phone: '0912-000-005', area: '暨南大學'),
    ];

List<Map<String, dynamic>> demoUserMaps() => demoCitizens()
    .map((c) => {
          'id': c.id,
          'name': c.name,
          'phone': c.phone,
          'area': c.area,
          'village': '',
        })
    .toList();

List<SupplyItem> demoSupplies() => const [
      SupplyItem(itemId: 1, name: '示範-礦泉水', category: '飲水', unit: '箱',
          stockQty: 120, reservedQty: 20, neededQty: 150),
      SupplyItem(itemId: 2, name: '示範-泡麵', category: '食物', unit: '箱',
          stockQty: 60, reservedQty: 10, neededQty: 80),
      SupplyItem(itemId: 3, name: '示範-毛毯', category: '生活用品', unit: '件',
          stockQty: 30, reservedQty: 5, neededQty: 50),
      SupplyItem(itemId: 4, name: '示範-急救包', category: '醫療', unit: '組',
          stockQty: 15, reservedQty: 2, neededQty: 20),
      SupplyItem(itemId: 5, name: '示範-手電筒', category: '生活用品', unit: '支',
          stockQty: 40, reservedQty: 0, neededQty: 25),
    ];

List<EmergencyRequest> demoEmergencies() => [
      EmergencyRequest(
        userId: 'U002', userName: '示範-陳美玲', phone: '0912-000-002',
        lat: 23.9502, lng: 120.9711, address: '南投縣埔里鎮中山路一段',
        status: 'active', sentAt: DateTime.now().subtract(const Duration(minutes: 6)),
      ),
      EmergencyRequest(
        userId: 'U005', userName: '示範-張家豪', phone: '0912-000-005',
        lat: 23.9467, lng: 120.9672, address: '暨南大學學生宿舍',
        status: 'processing', sentAt: DateTime.now().subtract(const Duration(minutes: 25)),
        receivedAt: DateTime.now().subtract(const Duration(minutes: 20)),
      ),
      EmergencyRequest(
        userId: 'U001', userName: '示範-王小明', phone: '0912-000-001',
        lat: 23.9479, lng: 120.9686, address: '南投縣埔里鎮南投路',
        status: 'resolved', sentAt: DateTime.now().subtract(const Duration(hours: 3)),
        receivedAt: DateTime.now().subtract(const Duration(hours: 2, minutes: 50)),
      ),
    ];

/// 給 supply_page.dart「物資需求」分頁用的原始 Map 格式（對應後端 getSupplyRequestDetails）
/// 流程：pending → reserved → dispatched → completed
List<Map<String, dynamic>> demoSupplyRequestMaps() => [
      {
        'requestId': 'R-DEMO-001', 'userId': 'U001', 'itemId': 1, 'itemName': '示範-礦泉水',
        'unit': '箱', 'qty': 3, 'lat': 23.9479, 'lng': 120.9686, 'address': '南投縣埔里鎮南投路',
        'status': 'pending',
        'createdAt': DateTime.now().subtract(const Duration(minutes: 40)).toIso8601String(),
      },
      {
        'requestId': 'R-DEMO-002', 'userId': 'U004', 'itemId': 3, 'itemName': '示範-毛毯',
        'unit': '件', 'qty': 2, 'lat': 23.9488, 'lng': 120.9699, 'address': '南投縣埔里鎮中正路',
        'status': 'reserved',
        'createdAt': DateTime.now().subtract(const Duration(minutes: 30)).toIso8601String(),
      },
      {
        'requestId': 'R-DEMO-003', 'userId': 'U003', 'itemId': 2, 'itemName': '示範-泡麵',
        'unit': '箱', 'qty': 1, 'lat': 23.9455, 'lng': 120.9654, 'address': '暨南大學學生宿舍',
        'status': 'dispatched',
        'createdAt': DateTime.now().subtract(const Duration(hours: 1)).toIso8601String(),
      },
      {
        'requestId': 'R-DEMO-006', 'userId': 'U001', 'itemId': 5, 'itemName': '示範-手電筒',
        'unit': '支', 'qty': 2, 'lat': 23.9479, 'lng': 120.9686, 'address': '南投縣埔里鎮南投路',
        'status': 'completed',
        'createdAt': DateTime.now().subtract(const Duration(hours: 5)).toIso8601String(),
      },
      {
        'requestId': 'R-DEMO-004', 'userId': 'U002', 'itemId': 1, 'itemName': '示範-礦泉水',
        'unit': '箱', 'qty': 50, 'lat': 23.9502, 'lng': 120.9711, 'address': '南投縣埔里鎮中山路一段',
        'status': 'pending',
        'createdAt': DateTime.now().subtract(const Duration(minutes: 10)).toIso8601String(),
      },
      {
        'requestId': 'R-DEMO-005', 'userId': 'U005', 'itemId': 4, 'itemName': '示範-急救包',
        'unit': '組', 'qty': 3, 'lat': 23.9467, 'lng': 120.9672, 'address': '暨南大學學生宿舍',
        'status': 'pending',
        'createdAt': DateTime.now().subtract(const Duration(minutes: 5)).toIso8601String(),
      },
    ];

/// 通知收件者名單（getNotificationRecipients）—— 用 uid（非 SQLite id）
List<Map<String, dynamic>> demoNotificationRecipients() => [
      {'uid': 'demo-uid-001', 'name': '示範-王小明', 'phone': '0912-000-001', 'area': '南投縣埔里鎮'},
      {'uid': 'demo-uid-002', 'name': '示範-陳美玲', 'phone': '0912-000-002', 'area': '南投縣埔里鎮'},
      {'uid': 'demo-uid-003', 'name': '示範-林志豪', 'phone': '0912-000-003', 'area': '暨南大學'},
      {'uid': 'demo-uid-004', 'name': '示範-黃淑芬', 'phone': '0912-000-004', 'area': '南投縣埔里鎮'},
      {'uid': 'demo-uid-005', 'name': '示範-張家豪', 'phone': '0912-000-005', 'area': '暨南大學'},
    ];

/// 通知發送紀錄（getSentNotifications）
List<Map<String, dynamic>> demoSentNotifications() => [
      {
        'notificationId': 'N-DEMO-001',
        'title': '示範-物資領取通知',
        'body': '請至社區管理中心領取物資。',
        'audience': 'users',
        'recipientCount': 2,
        'category': 'supply',
        'status': 'published',
        'sentAt': DateTime.now().subtract(const Duration(hours: 2)).toIso8601String(),
      },
      {
        'notificationId': 'N-DEMO-002',
        'title': '示範-防災公告',
        'body': '今日豪雨特報，請注意居家安全。',
        'audience': 'broadcast',
        'recipientCount': 0,
        'category': 'emergency',
        'status': 'published',
        'sentAt': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
      },
    ];

/// 異常待審需求（getSupplyRequestReviews）：維持 pending，另外標記需要人工審核
List<Map<String, dynamic>> demoSupplyRequestReviews() => [
      {
        'requestId': 'R-DEMO-004', 'userId': 'U002', 'itemId': 1, 'itemName': '示範-礦泉水',
        'unit': '箱', 'qty': 50, 'lat': 23.9502, 'lng': 120.9711, 'address': '南投縣埔里鎮中山路一段',
        'status': 'pending', 'reason': '單筆需求數量超過上限',
        'createdAt': DateTime.now().subtract(const Duration(minutes: 10)).toIso8601String(),
      },
      {
        'requestId': 'R-DEMO-005', 'userId': 'U005', 'itemId': 4, 'itemName': '示範-急救包',
        'unit': '組', 'qty': 3, 'lat': 23.9467, 'lng': 120.9672, 'address': '暨南大學學生宿舍',
        'status': 'pending', 'reason': '庫存不足',
        'createdAt': DateTime.now().subtract(const Duration(minutes: 5)).toIso8601String(),
      },
    ];
