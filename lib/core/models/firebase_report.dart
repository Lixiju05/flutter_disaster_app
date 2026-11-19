/// Read-only resident current state. UID is never a SQLite business ID.
class FirebaseReport {
  final String uid;
  final String? eventId;
  final String? name;
  final String? status;
  final String? description;
  final bool? sos;
  final DateTime? reportTime;
  final double? latitude;
  final double? longitude;
  final List<String> dataQuality;
  const FirebaseReport(
      {required this.uid,
      this.eventId,
      this.name,
      this.status,
      this.description,
      this.sos,
      this.reportTime,
      this.latitude,
      this.longitude,
      this.dataQuality = const []});

  factory FirebaseReport.fromJson(Map<String, dynamic> json) {
    final uid = json['uid'];
    if (uid is! String ||
        uid.isEmpty ||
        uid == '.' ||
        uid == '..' ||
        uid.trim() != uid ||
        uid.runes.length > 128 ||
        RegExp(r'[/\\\x00-\x1f\x7f-\x9f]').hasMatch(uid)) {
      throw const FormatException('Invalid report identity');
    }
    String? text(String key) =>
        json[key] is String ? json[key] as String : null;
    final rawTime = text('reportTime');
    final time = _parseTime(rawTime);
    double? coordinate(String key, double limit) {
      final raw = json[key];
      return raw is num && raw.toDouble().isFinite && raw.abs() <= limit
          ? raw.toDouble()
          : null;
    }

    var lat = coordinate('latitude', 90), lng = coordinate('longitude', 180);
    if (lat == null || lng == null || (lat == 0 && lng == 0)) {
      lat = null;
      lng = null;
    }
    return FirebaseReport(
        uid: uid,
        eventId: text('eventId'),
        name: text('name'),
        status: text('status'),
        description: text('description'),
        sos: json['sos'] is bool ? json['sos'] as bool : null,
        reportTime: time,
        latitude: lat,
        longitude: lng,
        dataQuality: List.unmodifiable((json['dataQuality'] is List
                ? json['dataQuality'] as List
                : const [])
            .whereType<String>()));
  }
  bool get hasCoordinates =>
      latitude != null &&
      longitude != null &&
      latitude!.isFinite &&
      longitude!.isFinite &&
      latitude!.abs() <= 90 &&
      longitude!.abs() <= 180 &&
      !(latitude == 0 && longitude == 0);
  static DateTime? _parseTime(String? raw) {
    if (raw == null) return null;
    final parts = RegExp(
            r'^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})(?:\.\d+)?(Z|[+-]\d{2}:\d{2})$')
        .firstMatch(raw);
    if (parts == null) return null;
    final year = int.parse(parts[1]!),
        month = int.parse(parts[2]!),
        day = int.parse(parts[3]!);
    if (month < 1 ||
        month > 12 ||
        day < 1 ||
        day > DateTime.utc(year, month + 1, 0).day ||
        int.parse(parts[4]!) > 23 ||
        int.parse(parts[5]!) > 59 ||
        int.parse(parts[6]!) > 59) {
      return null;
    }
    final zone = parts[7]!;
    if (zone != 'Z' &&
        (int.parse(zone.substring(1, 3)) > 23 ||
            int.parse(zone.substring(4, 6)) > 59)) {
      return null;
    }
    return DateTime.tryParse(raw)?.toUtc();
  }
}

class FirebaseReportPage {
  final List<FirebaseReport> reports;
  final String? nextPageToken;
  const FirebaseReportPage(this.reports, this.nextPageToken);
}
