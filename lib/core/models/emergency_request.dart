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
}