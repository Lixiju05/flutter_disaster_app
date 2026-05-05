class AllocationItem {
  final int allocationId;
  final int itemId;
  final String itemName;
  final String zoneId;
  final int qty;
  final String unit;
  final String createdAt;
  final bool dispatched;

  const AllocationItem({
    required this.allocationId,
    required this.itemId,
    required this.itemName,
    required this.zoneId,
    required this.qty,
    required this.unit,
    required this.createdAt,
    required this.dispatched,
  });

  factory AllocationItem.fromJson(Map<String, dynamic> json) {
    return AllocationItem(
      allocationId: _toInt(json['allocationId'] ?? json['id']),
      itemId:       _toInt(json['itemId']),
      itemName:     (json['itemName'] ?? json['name'] ?? '').toString(),
      zoneId:       (json['zoneId'] ?? '').toString(),
      qty:          _toInt(json['qty']),
      unit:         (json['unit'] ?? '').toString(),
      createdAt:    (json['createdAt'] ?? '').toString(),
      dispatched:   json['dispatched'] == true || json['dispatched'] == 1,
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