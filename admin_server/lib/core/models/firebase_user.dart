import 'report_location.dart';

/// Deliberately separate from SQLite AppUser. No contact or medical fields.
class FirebaseUser {
  final String uid;
  final String? name;
  final String? area;
  final DateTime? registeredAt;
  const FirebaseUser(this.uid, this.name, this.area, this.registeredAt);

  static bool validUid(Object? value) =>
      value is String &&
      value.isNotEmpty &&
      value.runes.length <= 128 &&
      value == value.trim() &&
      value != '.' &&
      value != '..' &&
      !value.contains('/') &&
      !value.contains(r'\') &&
      !RegExp(r'[\x00-\x1f\x7f-\x9f]').hasMatch(value);

  factory FirebaseUser.fromFields(String uid, Map fields) {
    String? text(String key) {
      final value = fields[key];
      return value is Map && value['stringValue'] is String
          ? value['stringValue'] as String
          : null;
    }

    final raw = fields['registeredAt'];
    final timestamp = raw is Map
        ? raw['timestampValue'] ?? raw['stringValue']
        : null;
    final time =
        timestamp is String &&
            RegExp(
              r'(Z|[+-]\d{2}:?\d{2})$',
              caseSensitive: false,
            ).hasMatch(timestamp)
        ? ReportLocation.time(timestamp)?.toUtc()
        : null;
    return FirebaseUser(uid, text('name'), text('area'), time);
  }

  Map<String, Object?> toJson() => {
    'uid': uid,
    'name': name,
    'area': area,
    'registeredAt': registeredAt?.toUtc().toIso8601String(),
  };
}
