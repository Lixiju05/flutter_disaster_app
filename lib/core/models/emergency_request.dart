class EmergencyRequest {
  final String id;
  final String citizenId;

  final double latitude;
  final double longitude;

  final String type;
  // sos / medical / supply

  final String? description;

  final List<String>? neededSupplies;
  // 可為 null 純求救

  final DateTime createdAt;

  bool handled;

  EmergencyRequest({
    required this.id,
    required this.citizenId,
    required this.latitude,
    required this.longitude,
    required this.type,
    this.description,
    this.neededSupplies,
    required this.createdAt,
    this.handled=false,
  });

  factory EmergencyRequest.fromJson(Map<String, dynamic> json) {
    return EmergencyRequest(
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
}