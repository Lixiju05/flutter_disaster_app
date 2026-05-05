class SupplyItem {
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

  int get shortageQty {
    final shortage = neededQty - stockQty;
    return shortage > 0 ? shortage : 0;
  }

  bool get isLowStock => stockQty < neededQty;

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

  Map<String, dynamic> toMap() {
    return toJson();
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
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }
}