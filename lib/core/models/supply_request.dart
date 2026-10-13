/// 物資需求（義工認領用）
/// 對應後端 getPendingSupplyRequests / getSupplyRequestDetails 回傳的欄位
class SupplyRequest {
  final String requestId;
  final String userId;
  final int itemId;
  final String itemName;
  final String unit;
  final int qty;
  final double? lat;
  final double? lng;
  final String address;
  final String status; // pending / claimed
  final String? volunteerId;
  final DateTime? createdAt;
  final DateTime? claimedAt;

  SupplyRequest({
    required this.requestId,
    required this.userId,
    required this.itemId,
    required this.itemName,
    required this.unit,
    required this.qty,
    this.lat,
    this.lng,
    required this.address,
    required this.status,
    this.volunteerId,
    this.createdAt,
    this.claimedAt,
  });

  /// 後端可能回傳 pending 或 reserved（已預留庫存），對義工來說都是「待認領」
  bool get isPending => status == 'pending' || status == 'reserved';
  bool get isClaimed => status == 'claimed';
  /// 配送中：義工已取貨（dispatched），尚未交給災民
  bool get isDelivering => status == 'dispatched';
  /// 已完成：已交給災民
  bool get isDone => status == 'completed';

  /// 有沒有可用的座標（0,0 視為沒有）
  bool get hasLocation => lat != null && lng != null && !(lat == 0 && lng == 0);

  /// 狀態中文顯示
  String get statusLabel {
    switch (status) {
      case 'pending':
      case 'reserved':
        return '待認領';
      case 'claimed':
        return '已認領';
      case 'dispatched':
        return '配送中';
      case 'completed':
        return '已完成';
      default:
        return status;
    }
  }

  factory SupplyRequest.fromJson(Map<String, dynamic> json) {
    return SupplyRequest(
      requestId: (json['requestId'] ?? '').toString(),
      userId: (json['userId'] ?? '').toString(),
      itemId: (json['itemId'] as num?)?.toInt() ?? 0,
      itemName: (json['itemName'] ?? '物資 #${json['itemId']}').toString(),
      unit: (json['unit'] ?? '').toString(),
      qty: (json['qty'] as num?)?.toInt() ?? 0,
      lat: (json['lat'] as num?)?.toDouble(),
      lng: (json['lng'] as num?)?.toDouble(),
      address: (json['address'] ?? '').toString(),
      status: (json['status'] ?? 'pending').toString(),
      volunteerId: json['volunteerId']?.toString(),
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
      claimedAt: DateTime.tryParse(json['claimedAt']?.toString() ?? ''),
    );
  }

  SupplyRequest copyWith({String? status, String? volunteerId, DateTime? claimedAt}) {
    return SupplyRequest(
      requestId: requestId,
      userId: userId,
      itemId: itemId,
      itemName: itemName,
      unit: unit,
      qty: qty,
      lat: lat,
      lng: lng,
      address: address,
      status: status ?? this.status,
      volunteerId: volunteerId ?? this.volunteerId,
      createdAt: createdAt,
      claimedAt: claimedAt ?? this.claimedAt,
    );
  }
}
