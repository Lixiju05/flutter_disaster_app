class EmergencyRequest {

  final String emergencyId;
  final String userId;
  final String userName;
  final String phone;
  final double lat;
  final double lng;
  final String? address;
  final String status;
  final String? receiverAdminId;
  final int hopCount;
  final DateTime sentAt;
  final DateTime? receivedAt;

  EmergencyRequest({
    required this.emergencyId,
    required this.userId,
    required this.userName,
    required this.phone,
    required this.lat,
    required this.lng,
    this.address,
    this.status = 'active',
    this.receiverAdminId,
    this.hopCount = 0,
    required this.sentAt,
    this.receivedAt,
  });

  factory EmergencyRequest.fromJson(Map<String, dynamic> json) {
    return EmergencyRequest(
      emergencyId: json['emergencyId']?.toString() ?? '',
      userId: json['userId']?.toString() ?? '',
      userName: json['userName']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      lat: (json['latitude'] as num?)?.toDouble() ?? 0,
      lng: (json['longitude'] as num?)?.toDouble() ?? 0,
      address: json['address']?.toString(),
      status: json['status']?.toString() ?? 'active',
      receiverAdminId: json['receiverAdminId']?.toString(),
      hopCount: _toInt(json['hopCount']),
      sentAt: DateTime.tryParse(
            json['sentAt']?.toString() ?? '',
          ) ??
          DateTime.now(),
      receivedAt: json['receivedAt'] == null
          ? null
          : DateTime.tryParse(
              json['receivedAt'].toString(),
            ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'emergencyId': emergencyId,
      'userId': userId,
      'userName': userName,
      'phone': phone,
      'latitude': lat,
      'longitude': lng,
      'status': status,
      'receiverAdminId': receiverAdminId,
      'hopCount': hopCount,
      'sentAt': sentAt.toIso8601String(),
      'receivedAt': receivedAt?.toIso8601String(),
      'address': address,
    };
  }

  static int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }
}