class SupplyRequest {
  final String requestId;
  final int itemId;
  final int qty;

  final double? lat;
  final double? lng;

  final String? zoneId;
  final String? gridId;

  final String status;
  final DateTime createdAt;

  SupplyRequest({
    required this.requestId,
    required this.itemId,
    required this.qty,
    this.lat,
    this.lng,
    this.zoneId,
    this.gridId,
    this.status = 'pending',
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'requestId': requestId,
      'itemId': itemId,
      'qty': qty,
      'lat': lat,
      'lng': lng,
      'zoneId': zoneId,
      'gridId': gridId,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory SupplyRequest.fromJson(Map<String, dynamic> json) {
    return SupplyRequest(
      requestId: json['requestId'],
      itemId: json['itemId'],
      qty: json['qty'],
      lat: (json['lat'] as num?)?.toDouble(),
      lng: (json['lng'] as num?)?.toDouble(),
      zoneId: json['zoneId'],
      gridId: json['gridId'],
      status: json['status'] ?? 'pending',
      createdAt: DateTime.parse(json['createdAt']),
    );
  }
}