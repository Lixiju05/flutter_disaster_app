class Citizen {
  final String id;
  final String name;

  double latitude;
  double longitude;

  bool needsRescue;

  Citizen({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.needsRescue,
  });

  factory Citizen.fromJson(Map<String, dynamic> json) {
    return Citizen(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      latitude: (json['latitude'] ?? 0).toDouble(),
      longitude: (json['longitude'] ?? 0).toDouble(),
      needsRescue: json['needsRescue'] ?? false,
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