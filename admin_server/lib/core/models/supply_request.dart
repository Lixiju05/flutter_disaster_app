class SupplyRequest {
  final String requestId;
  final String userId;
  final int itemId;
  final int qty;
  final double? lat;
  final double? lng;
  final String? receiverAdminId;
  final int hopCount;
  final String status;
  final DateTime createdAt;
  final DateTime? receivedAt;

  SupplyRequest({
    required this.requestId,
    required this.userId,
    required this.itemId,
    required this.qty,
    this.lat,
    this.lng,
    this.receiverAdminId,
    this.hopCount = 0,
    this.status = 'pending',
    required this.createdAt,
    this.receivedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'requestId': requestId,
      'userId': userId,
      'itemId': itemId,
      'qty': qty,
      'lat': lat,
      'lng': lng,
      'receiverAdminId': receiverAdminId,
      'hopCount': hopCount,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
      'receivedAt': receivedAt?.toIso8601String(),
    };
  }

  factory SupplyRequest.fromJson(Map<String, dynamic> json) {
    return SupplyRequest(
      requestId: (json['requestId'] ?? '').toString(),
      userId: (json['userId'] ?? '').toString(),
      itemId: _toInt(json['itemId']),
      qty: _toInt(json['qty']),
      lat: (json['lat'] as num?)?.toDouble(),
      lng: (json['lng'] as num?)?.toDouble(),
      receiverAdminId: json['receiverAdminId']?.toString(),
      hopCount: _toInt(json['hopCount']),
      status: json['status'] ?? 'pending',
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
      receivedAt: json['receivedAt'] == null
          ? null
          : DateTime.tryParse(json['receivedAt']),
    );
  }

  static int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }
}