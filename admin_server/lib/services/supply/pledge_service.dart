import 'package:uuid/uuid.dart';

const _uuid = Uuid();

class SupplyPledge {

  final String pledgeId;
  final String userId;
  final String userName;
  final int itemId;
  final String itemName;
  final String unit;
  final int qty;
  final String status;
  final DateTime pledgedAt;

  SupplyPledge({
    String? pledgeId,

    required this.userId,

    required this.userName,

    required this.itemId,

    required this.itemName,

    required this.unit,

    required this.qty,

    this.status = 'pledged',

    DateTime? pledgedAt,
  })  : pledgeId = pledgeId ?? _uuid.v4(),
        pledgedAt = pledgedAt ?? DateTime.now();

  /// JSON → Model
  factory SupplyPledge.fromJson(
    Map<String, dynamic> json,
  ) {
    return SupplyPledge(
      pledgeId: json['pledgeId']?.toString(),

      userId: json['userId']?.toString() ?? '',

      userName: json['userName']?.toString() ?? '',

      itemId: _toInt(json['itemId']),

      itemName: json['itemName']?.toString() ?? '',

      unit: json['unit']?.toString() ?? '',

      qty: _toInt(json['qty']),

      status: json['status']?.toString() ?? 'pledged',

      pledgedAt:
          DateTime.tryParse(
            json['pledgedAt']?.toString() ?? '',
          ) ??
          DateTime.now(),
    );
  }

  /// Model → JSON
  Map<String, dynamic> toJson() {
    return {
      'pledgeId': pledgeId,

      'userId': userId,

      'userName': userName,

      'itemId': itemId,

      'itemName': itemName,

      'unit': unit,

      'qty': qty,

      'status': status,

      'pledgedAt': pledgedAt.toIso8601String(),
    };
  }

  /// copyWith
  SupplyPledge copyWith({
    int? qty,
    String? status,
  }) {
    return SupplyPledge(
      pledgeId: pledgeId,

      userId: userId,

      userName: userName,

      itemId: itemId,

      itemName: itemName,

      unit: unit,

      qty: qty ?? this.qty,

      status: status ?? this.status,

      pledgedAt: pledgedAt,
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