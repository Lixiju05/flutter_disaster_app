import 'package:uuid/uuid.dart';

const _uuid = Uuid();

class EmergencyRequest {

  /// 緊急事件唯一 ID
  final String emergencyId;

  /// 使用者 ID
  final String userId;

  /// 使用者名稱
  final String userName;

  /// 電話
  final String phone;

  /// 座標
  final double lat;
  final double lng;

  /// 血型
  final String? bloodType;

  /// 醫療資訊
  final String? medicalInfo;

  /// sos / medical / trapped / fire
  final String type;

  /// active / resolved / cancelled
  final String status;

  /// 哪個管理端收到
  final String? receiverAdminId;

  /// P2P 跳數
  final int hopCount;

  /// 發送時間
  final DateTime sentAt;

  /// 管理端收到時間
  final DateTime? receivedAt;

  EmergencyRequest({
    String? emergencyId,

    required this.userId,

    required this.userName,

    required this.phone,

    required this.lat,

    required this.lng,

    this.bloodType,

    this.medicalInfo,

    this.type = 'sos',

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
          (json['latitude'] as num)
              .toDouble(),

      lng:
          (json['longitude'] as num)
              .toDouble(),

      bloodType:
          json['bloodType']?.toString(),

      medicalInfo:
          json['medicalInfo']?.toString(),

      type:
          json['type']?.toString() ?? 'sos',

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

      'bloodType': bloodType,

      'medicalInfo': medicalInfo,

      'type': type,

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

      bloodType: bloodType,

      medicalInfo: medicalInfo,

      type: type,

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