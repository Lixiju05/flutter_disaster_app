class AllocationItem {
  final int allocationId;
  final int itemId;
  final String itemName;
  final String zoneId;
  final int qty;
  final String unit;
  final String createdAt;
  final String status;              // ← 原来是 bool dispatched，改成 String status

  const AllocationItem({
    required this.allocationId,
    required this.itemId,
    required this.itemName,
    required this.zoneId,
    required this.qty,
    required this.unit,
    required this.createdAt,
    required this.status,           // ← 改
  });

  // ← 加这个 getter，SupplyPage 里所有 a.dispatched 完全不用动
  bool get dispatched => status == 'shipped';

  factory AllocationItem.fromJson(Map<String, dynamic> json) {
    return AllocationItem(
      allocationId: _toInt(json['allocationId'] ?? json['id']),
      itemId:       _toInt(json['itemId']),
      itemName:     (json['itemName'] ?? json['name'] ?? '').toString(),
      zoneId:       (json['zoneId'] ?? '').toString(),
      qty:          _toInt(json['qty'] ?? json['quantity']),
      unit:         (json['unit'] ?? '').toString(),
      createdAt:    (json['createdAt'] ?? '').toString(),
      status:       (json['status'] ?? 'reserved').toString(), // ← 原来读 dispatched，改成读 status
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