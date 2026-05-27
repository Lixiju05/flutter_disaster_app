class HealthReport {
  final String uuid;
  final String reporterId;   // 回報者 ID
  final String name;         // 回報者姓名
  final String phone;        // 聯絡電話
  final String? bloodType;   // 血型（可選）
  final String status;       // 健康狀態
  final String? description; // 補充說明（可選）
  final double? lat;         // 緯度（可選）
  final double? lng;         // 經度（可選）
  final String? address;
  final DateTime reportTime; // 回報時間
  final String? receiverAdminId;
  final int hopCount;
  final DateTime? receivedAt;

  HealthReport({
    required this.uuid,
    required this.reporterId,
    required this.name,
    required this.phone,
    this.bloodType,
    required this.status,
    this.description,
    this.lat,
    this.lng,
    this.address,
    required this.reportTime,
    this.receiverAdminId,
    this.hopCount = 0,
    this.receivedAt,
  });

  /// JSON → Model
  factory HealthReport.fromJson(Map<String, dynamic> json) {
    return HealthReport(
      uuid: json['uuid'] ?? '',
      reporterId: json['reporterId'] ?? '',
      name: json['name'] ?? '',
      phone: json['phone'] ?? '',
      bloodType: json['bloodType'],
      status: json['status'] ?? '',
      description: json['description'],
      lat: (json['lat'] as num?)?.toDouble(),
      lng: (json['lng'] as num?)?.toDouble(),
      address: json['address']?.toString(),
      reportTime: DateTime.tryParse(json['reportTime'] ?? '') ??
          DateTime.now(),
       receiverAdminId:
          json['receiverAdminId']
              ?.toString(),

      hopCount:
          _toInt(json['hopCount']),

      receivedAt:
          json['receivedAt'] == null
              ? null
              : DateTime.tryParse(
                  json['receivedAt']
                      .toString(),
                ),
    );
  }

  /// Model → JSON (API 用)
  Map<String, dynamic> toJson() {
    return {
      'uuid': uuid,
      'reporterId': reporterId,
      'name': name,
      'phone': phone,
      'bloodType': bloodType,
      'status': status,
      'description': description,
      'lat': lat,
      'lng': lng,
      'reportTime': reportTime.toIso8601String(),
      'receiverAdminId':
          receiverAdminId,
      'hopCount': hopCount,
      'receivedAt':
          receivedAt?.toIso8601String(),
      'address': address,
    };
  }

  /// SQLite row → Model
  factory HealthReport.fromMap(Map<String, Object?> map) {
    return HealthReport(
      uuid: map['uuid']?.toString() ?? '',
      reporterId: map['reporterId']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      phone: map['phone']?.toString() ?? '',
      bloodType: map['bloodType']?.toString(),
      status: map['status']?.toString() ?? '',
      description: map['description']?.toString(),
      lat: (map['lat'] as num?)?.toDouble(),
      lng: (map['lng'] as num?)?.toDouble(),
      address: map['address']?.toString(),
      reportTime: DateTime.tryParse(
            map['reportTime']?.toString() ?? '',
          ) ??
          DateTime.now(),
      receiverAdminId: map['receiverAdminId']?.toString(),
      hopCount: _toInt(map['hopCount']),
      receivedAt: map['receivedAt'] == null
          ? null
          : DateTime.tryParse(
              map['receivedAt'].toString(),
            ),
    );
  }
  static int _toInt(dynamic value) {
    if (value == null) return 0;

    if (value is int) return value;

    if (value is num) return value.toInt();

    if (value is String) {
      return int.tryParse(value) ?? 0;
    }

    return 0;
  }
}