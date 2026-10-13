class Citizen {
  final String id;
  final String name;

  double latitude;
  double longitude;

  bool needsRescue;

  /// 電話、地址（後端 getAllUsers 的 phone / area）
  final String phone;
  final String area;

  Citizen({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.needsRescue,
    this.phone = '',
    this.area = '',
  });

  factory Citizen.fromJson(Map<String, dynamic> json) {
    return Citizen(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      latitude: (json['latitude'] ?? 0).toDouble(),
      longitude: (json['longitude'] ?? 0).toDouble(),
      needsRescue: json['needsRescue'] ?? false,
      phone: json['phone']?.toString() ?? '',
      area: json['area']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'latitude': latitude,
      'longitude': longitude,
      'needsRescue': needsRescue,
    };
  }
}