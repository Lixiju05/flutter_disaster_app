import 'dart:math';

class AppUser {
  final String id;
  final String name;
  final String phone;
  final String area;
  final String village;

  final String emergencyContactName;
  final String emergencyContactPhone;
  final String emergencyContactRelation;
  final String? bloodType;
  final String? medicalInfo;

  final double latitude;
  final double longitude;
  final bool online;
  final DateTime? lastSync;

  final DateTime registeredAt;

  AppUser({
    required this.id,
    required this.name,
    required this.phone,
    required this.area,
    required this.village,
    required this.emergencyContactName,
    required this.emergencyContactPhone,
    required this.emergencyContactRelation,
    this.bloodType,
    this.medicalInfo,
    required this.latitude,
    required this.longitude,
    required this.online,
    this.lastSync,
    required this.registeredAt,
  });

  static String generateId() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rand = Random();
    final code = List.generate(6, (_) => chars[rand.nextInt(chars.length)]).join();
    return 'UID-$code';
  }

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        id: (json['id'] ?? '').toString(),
        name: (json['name'] ?? '').toString(),
        phone: (json['phone'] ?? '').toString(),
        area: (json['area'] ?? '').toString(),
        village: (json['village'] ?? '').toString(),

        emergencyContactName:
            (json['emergencyContactName'] ?? '').toString(),
        emergencyContactPhone:
            (json['emergencyContactPhone'] ?? '').toString(),
        emergencyContactRelation:
            (json['emergencyContactRelation'] ?? '').toString(),

        bloodType: json['bloodType']?.toString(),
        medicalInfo: json['medicalInfo']?.toString(),

        latitude: double.tryParse((json['latitude'] ?? '0').toString()) ?? 0,
        longitude: double.tryParse((json['longitude'] ?? '0').toString()) ?? 0,

        online: json['online'] == true ||
            json['online'].toString() == '1' ||
            json['online'].toString() == 'true',

        lastSync: json['lastSync'] == null || json['lastSync'].toString().isEmpty
            ? null
            : DateTime.tryParse(json['lastSync'].toString()),

        registeredAt: json['registeredAt'] == null
            ? DateTime.now()
            : DateTime.tryParse(json['registeredAt'].toString()) ?? DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'area': area,
        'village': village,
        'emergencyContactName': emergencyContactName,
        'emergencyContactPhone': emergencyContactPhone,
        'emergencyContactRelation': emergencyContactRelation,
        'bloodType': bloodType,
        'medicalInfo': medicalInfo,
        'latitude': latitude,
        'longitude': longitude,
        'online': online,
        'lastSync': lastSync?.toIso8601String(),
        'registeredAt': registeredAt.toIso8601String(),
      };
}