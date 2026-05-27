import 'package:uuid/uuid.dart';

const _uuid = Uuid();

class EmergencyRequest {
  final String emergencyId;
  final String userId;
  final String userName;
  final String phone;
  final double lat;
  final double lng;
  final String status;
  final String? receiverAdminId;
  final int hopCount;
  final DateTime sentAt;
  final DateTime? receivedAt;

  EmergencyRequest({
    String? emergencyId,
    required this.userId,
    required this.userName,
    required this.phone,
    required this.lat,
    required this.lng,
    this.status = 'active',
    this.receiverAdminId,
    this.hopCount = 0,
    DateTime? sentAt,

    this.receivedAt,
  })  : emergencyId =
            emergencyId ?? _uuid.v4(),
        sentAt = sentAt ?? DateTime.now();

  /// JSON → Model
  factory EmergencyRequest.fromJson(
    Map<String, dynamic> json,
  ) {
    return EmergencyRequest(
      emergencyId:
          json['emergencyId']?.toString(),

      userId:
          json['userId']?.toString() ?? '',

      userName:
          json['userName']?.toString() ?? '',

      phone:
          json['phone']?.toString() ?? '',

      lat:
          (json['latitude'] as num?)
              ?.toDouble() ?? 0.0,

      lng:
          (json['longitude'] as num?)
              ?.toDouble() ?? 0.0,

      status:
          json['status']?.toString() ??
              'active',

      receiverAdminId:
          json['receiverAdminId']
              ?.toString(),

      hopCount:
          _toInt(json['hopCount']),

      sentAt:
          DateTime.tryParse(
            json['sentAt']
                    ?.toString() ??
                '',
          ) ??
          DateTime.now(),

      receivedAt:
          json['receivedAt'] == null
              ? null
              : DateTime.tryParse(
                  json['receivedAt']
                      .toString(),
                ),
    );
  }

  /// Model → JSON
  Map<String, dynamic> toJson() {
    return {
      'emergencyId': emergencyId,
      'userId': userId,
      'userName': userName,
      'phone': phone,
      'latitude': lat,
      'longitude': lng,
      'status': status,
      'receiverAdminId':
          receiverAdminId,
      'hopCount': hopCount,
      'sentAt':
          sentAt.toIso8601String(),
      'receivedAt':
          receivedAt?.toIso8601String(),
    };
  }

  EmergencyRequest copyWith({
    String? status,
    String? receiverAdminId,
    int? hopCount,
    DateTime? receivedAt,
  }) {
    return EmergencyRequest(
      emergencyId: emergencyId,
      userId: userId,
      userName: userName,
      phone: phone,
      lat: lat,
      lng: lng,

      status: status ?? this.status,

      receiverAdminId:
          receiverAdminId ??
              this.receiverAdminId,

      hopCount:
          hopCount ?? this.hopCount,

      sentAt: sentAt,

      receivedAt:
          receivedAt ?? this.receivedAt,
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