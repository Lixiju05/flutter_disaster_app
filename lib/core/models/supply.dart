class SupplyItem {
  final String id;
  final String name;
  final String unit;
  final String category;
  final int neededQty;
  final int pledgedQty;

  const SupplyItem({
    required this.id,
    required this.name,
    required this.unit,
    required this.category,
    required this.neededQty,
    this.pledgedQty = 0,
  });

  factory SupplyItem.fromJson(Map<String, dynamic> json) {
    return SupplyItem(
      // 考慮到 SQLite 或 API 回傳可能為 int，統一轉成 String 或 int
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      unit: json['unit']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      // 這裡使用轉型保護，防止 API 回傳 Double 或 String 導致當機
      neededQty: _toInt(json['neededQty']),
      pledgedQty: _toInt(json['pledgedQty'] ?? json['stockQty']), // 依據你資料庫欄位名稱調整
    );
  }

  // 輔助工具：安全轉型為 int
  static int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'unit': unit,
        'category': category,
        'neededQty': neededQty,
        'pledgedQty': pledgedQty,
      };
}