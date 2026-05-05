class SupplyItem {
<<<<<<< HEAD
  final int itemId;
  final String name;
  final String category;
  final String unit;
  final int stockQty;
  final int neededQty;

  const SupplyItem({
    required this.itemId,
    required this.name,
    required this.category,
    required this.unit,
    required this.stockQty,
    required this.neededQty,
  });

  /// 还需要多少数量
  int get shortageQty {
    final shortage = neededQty - stockQty;
    return shortage > 0 ? shortage : 0;
  }

  /// 是否库存不足
  bool get isLowStock => stockQty < neededQty;

  /// 库存达成率，例如 100 / 200 = 0.5
  double get stockRate {
    if (neededQty <= 0) return 1.0;
    return stockQty / neededQty;
  }

  factory SupplyItem.fromJson(Map<String, dynamic> json) {
    return SupplyItem(
      itemId: _toInt(json['itemId'] ?? json['id']),
      name: (json['name'] ?? json['itemName'] ?? '').toString(),
      category: (json['category'] ?? '').toString(),
      unit: (json['unit'] ?? '').toString(),
      stockQty: _toInt(json['stockQty'] ?? json['totalQuantity']),
      neededQty: _toInt(json['neededQty']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'itemId': itemId,
      'name': name,
      'category': category,
      'unit': unit,
      'stockQty': stockQty,
      'neededQty': neededQty,
    };
  }

  SupplyItem copyWith({
    int? itemId,
    String? name,
    String? category,
    String? unit,
    int? stockQty,
    int? neededQty,
  }) {
    return SupplyItem(
      itemId: itemId ?? this.itemId,
      name: name ?? this.name,
      category: category ?? this.category,
      unit: unit ?? this.unit,
      stockQty: stockQty ?? this.stockQty,
      neededQty: neededQty ?? this.neededQty,
    );
  }

  static int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
=======
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
>>>>>>> f69460cd2207e884a63750829a091e7e38ece7cf
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