class DispatchItem {
  final int dispatchId;
  final int allocationId;
  final String itemName;
  final String zoneId;
  final int qty;
  final String unit;
  final String dispatchedAt;

  const DispatchItem({
    required this.dispatchId,
    required this.allocationId,
    required this.itemName,
    required this.zoneId,
    required this.qty,
    required this.unit,
    required this.dispatchedAt,
  });

  factory DispatchItem.fromJson(Map<String, dynamic> json) {
    return DispatchItem(
      dispatchId:   _toInt(json['dispatchId'] ?? json['id']),
      allocationId: _toInt(json['allocationId']),
      itemName:     (json['itemName'] ?? json['name'] ?? '').toString(),
      zoneId:       (json['zoneId'] ?? '').toString(),
      qty:          _toInt(json['qty']),
      unit:         (json['unit'] ?? '').toString(),
      dispatchedAt: (json['dispatchedAt'] ?? json['createdAt'] ?? '').toString(),
    );
  }

  static int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }
}