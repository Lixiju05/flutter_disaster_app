class EmergencyRequest {
  final String id;
  final String citizenId;
  final double latitude;
  final double longitude;
  final String type;
  final DateTime createdAt;
  bool handled; // ← 新增，非 final 才能修改

  EmergencyRequest({
    required this.id,
    required this.citizenId,
    required this.latitude,
    required this.longitude,
    required this.type,
    required this.createdAt,
    this.handled = false, // ← 預設未處理
  });

  factory EmergencyRequest.fromJson(Map<String, dynamic> json) {
    return EmergencyRequest(
<<<<<<< HEAD
      id: json['id']?.toString() ?? '',
      citizenId: json['citizenId']?.toString() ?? '',
      latitude: _toDouble(json['latitude']),
      longitude: _toDouble(json['longitude']),
      type: json['type']?.toString() ?? '',
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      handled: json['handled'] == true || json['handled'] == 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'citizenId': citizenId,
      'latitude': latitude,
      'longitude': longitude,
      'type': type,
      'createdAt': createdAt.toIso8601String(),
      'handled': handled,
    };
  }

  static double _toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }
=======
      id: json['uuid']?.toString() ?? json['id']?.toString() ?? '',
      citizenId: json['reporterId']?.toString() ?? '',
      latitude: (json['lat'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['lng'] as num?)?.toDouble() ?? 0.0,
      type: json['status']?.toString() ?? 'sos', // 根據你資料庫欄位調整
      description: json['description']?.toString(),
      // 處理 List<String>，如果傳過來的是 JSON 字串，需要做 decode
      neededSupplies: json['neededSupplies'] != null 
          ? List<String>.from(json['neededSupplies']) 
          : null,
      createdAt: DateTime.tryParse(json['reportTime'] ?? json['createdAt'] ?? '') ?? DateTime.now(),
      // 處理 SQLite 存 0/1 的情況
      handled: json['handled'] == 1 || json['handled'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
        'uuid': id,
        'reporterId': citizenId,
        'lat': latitude,
        'lng': longitude,
        'status': type,
        'description': description,
        'reportTime': createdAt.toIso8601String(),
        'handled': handled ? 1 : 0,
      };
>>>>>>> f69460cd2207e884a63750829a091e7e38ece7cf
}