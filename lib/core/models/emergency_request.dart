class EmergencyRequest {
  final String id;
  final String citizenId;
  final double latitude;
  final double longitude;
  final String type;
  final String description;
  final DateTime createdAt;
  bool handled;

  EmergencyRequest({
    required this.id,
    required this.citizenId,
    required this.latitude,
    required this.longitude,
    required this.type,
    required this.description,
    required this.createdAt,
    this.handled = false,
  });

  factory EmergencyRequest.fromJson(
    Map<String, dynamic> json,
  ) {
    return EmergencyRequest(
      id: (json['id'] ?? json['uuid'] ?? '')
          .toString(),

      citizenId:
          (json['citizenId'] ??
                  json['reporterId'] ??
                  '')
              .toString(),

      latitude: _toDouble(
        json['latitude'] ?? json['lat'],
      ),

      longitude: _toDouble(
        json['longitude'] ?? json['lng'],
      ),

      type: (json['type'] ??
              json['status'] ??
              'SOS')
          .toString(),

      description:
          (json['description'] ?? '')
              .toString(),

      createdAt:
          DateTime.tryParse(
            json['createdAt']
                    ?.toString() ??
                '',
          ) ??
          DateTime.now(),

      handled:
          json['handled'] == true ||
              json['handled'] == 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'citizenId': citizenId,
      'latitude': latitude,
      'longitude': longitude,
      'type': type,
      'description': description,
      'createdAt':
          createdAt.toIso8601String(),
      'handled': handled,
    };
  }

  EmergencyRequest copyWith({
    String? id,
    String? citizenId,
    double? latitude,
    double? longitude,
    String? type,
    String? description,
    DateTime? createdAt,
    bool? handled,
  }) {
    return EmergencyRequest(
      id: id ?? this.id,
      citizenId:
          citizenId ?? this.citizenId,
      latitude: latitude ?? this.latitude,
      longitude:
          longitude ?? this.longitude,
      type: type ?? this.type,
      description:
          description ?? this.description,
      createdAt:
          createdAt ?? this.createdAt,
      handled: handled ?? this.handled,
    );
  }

  static double _toDouble(dynamic value) {
    if (value == null) return 0;

    if (value is double) return value;

    if (value is int) {
      return value.toDouble();
    }

    if (value is String) {
      return double.tryParse(value) ?? 0;
    }

    return 0;
  }
}