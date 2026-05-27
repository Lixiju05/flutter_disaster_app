class HealthReport {
  final String reporterId;
  final String name;
  final String phone;
  final String? bloodType;
  final String status;
  final String? description;
  final double? lat;
  final double? lng;
  final String? address;
  final DateTime reportTime;
  final String? uuid;
  final String? receiverAdminId;
  final int hopCount;
  final DateTime? receivedAt;

  HealthReport({
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
    this.uuid,
    this.receiverAdminId,
    this.hopCount = 0,
    this.receivedAt,
  });

  Map<String, dynamic> toJson() => {
        'reporterId': reporterId,
        'name': name,
        'phone': phone,
        'bloodType': bloodType,
        'status': status,
        'description': description,
        'lat': lat,
        'lng': lng,
        'address': address,
        'reportTime': reportTime.toIso8601String(),
      };

  factory HealthReport.fromJson(Map<String, dynamic> json) => HealthReport(
        reporterId: json['reporterId']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        phone: json['phone']?.toString() ?? '',
        bloodType: json['bloodType']?.toString(),
        status: json['status']?.toString() ?? '',
        description: json['description']?.toString(),
        lat: (json['lat'] as num?)?.toDouble(),
        lng: (json['lng'] as num?)?.toDouble(),
        address: json['address']?.toString(),
        reportTime: DateTime.tryParse(json['reportTime']?.toString() ?? '') ?? DateTime.now(),
        uuid: json['uuid']?.toString(),
        receiverAdminId: json['receiverAdminId']?.toString(),
        hopCount: (json['hopCount'] as num?)?.toInt() ?? 0,
        receivedAt: json['receivedAt'] == null ? null : DateTime.tryParse(json['receivedAt'].toString()),
      );

  factory HealthReport.fromMap(Map<String, Object?> map) => HealthReport.fromJson(
        map.map((k, v) => MapEntry(k, v)),
      );
}
