class Citizen {
  final String id;
  final String name;
<<<<<<< HEAD

  double latitude;
  double longitude;

=======
  final double latitude;
  final double longitude;
>>>>>>> f69460cd2207e884a63750829a091e7e38ece7cf
  bool needsRescue;

  Citizen({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.needsRescue,
  });

<<<<<<< HEAD
  factory Citizen.fromJson(
    Map<String, dynamic> json,
  ) {
    return Citizen(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      latitude:
          (json['latitude'] ?? 0).toDouble(),
      longitude:
          (json['longitude'] ?? 0).toDouble(),
      needsRescue:
          json['needsRescue'] ?? false,
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
=======
  factory Citizen.fromJson(Map<String, dynamic> json) {
    return Citizen(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Unknown',
      // 考慮到後端可能沒有存座標，給予預設值
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      // 處理 SQLite 存 0/1 的情況
      needsRescue: json['needsRescue'] == 1 || json['needsRescue'] == true,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'latitude': latitude,
        'longitude': longitude,
        'needsRescue': needsRescue ? 1 : 0,
      };
>>>>>>> f69460cd2207e884a63750829a091e7e38ece7cf
}