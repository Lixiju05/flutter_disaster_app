import 'firebase_user.dart';
import 'report_location.dart';

/// Current resident state, not a SQLite row or an append-only incident.
class FirestoreHealthReport {
  final String uid;
  final String? eventId;
  final bool? eventIdIsUuid;
  final bool? reporterIdMatchesUid;
  final String? name;
  final String? status;
  final String? description;
  final bool? sos;
  final double? latitude;
  final double? longitude;
  final DateTime? reportTime;
  final List<String> dataQuality;
  FirestoreHealthReport._(
    this.uid,
    this.eventId,
    this.eventIdIsUuid,
    this.reporterIdMatchesUid,
    this.name,
    this.status,
    this.description,
    this.sos,
    this.latitude,
    this.longitude,
    this.reportTime,
    List<String> quality,
  ) : dataQuality = List.unmodifiable(quality);

  factory FirestoreHealthReport.fromFields(String uid, Map fields) {
    final quality = <String>[];
    String? text(String key) {
      final value = fields[key];
      return value is Map && value['stringValue'] is String
          ? value['stringValue'] as String
          : null;
    }

    double? coordinate(String key, double bound) {
      final value = fields[key];
      final raw = value is Map
          ? value['doubleValue'] ?? value['integerValue']
          : null;
      final number = raw is num
          ? raw.toDouble()
          : raw is String
          ? double.tryParse(raw)
          : null;
      return number != null && number.isFinite && number.abs() <= bound
          ? number
          : null;
    }

    var lat = coordinate('lat', 90);
    var lng = coordinate('lng', 180);
    if (lat == null || lng == null || (lat == 0 && lng == 0)) {
      lat = null;
      lng = null;
      quality.add('coordinates_missing_or_invalid');
    }
    final rawTime = fields['reportTime'];
    final timeValue = rawTime is Map
        ? rawTime['stringValue'] ?? rawTime['timestampValue']
        : null;
    final DateTime? time =
        timeValue is String &&
            RegExp(
              r'(Z|[+-]\d{2}:?\d{2})$',
              caseSensitive: false,
            ).hasMatch(timeValue)
        ? ReportLocation.time(timeValue)?.toUtc()
        : null;
    if (time == null) {
      quality.add('report_time_missing_invalid_or_timezone_unknown');
    }
    final rawSos = fields['sos'];
    final sos = rawSos is Map && rawSos['booleanValue'] is bool
        ? rawSos['booleanValue'] as bool
        : null;
    if (sos == null) quality.add('sos_missing_or_invalid');
    final reporter = text('reporterId');
    final matches = reporter == null ? null : reporter == uid;
    if (matches != true) quality.add('reporter_id_missing_or_mismatch');
    var event = text('id');
    if (event != null && (!FirebaseUser.validUid(event))) event = null;
    final uuid = event == null
        ? null
        : RegExp(
            r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
            caseSensitive: false,
          ).hasMatch(event);
    if (uuid != true) quality.add('event_id_missing_or_not_uuid');
    final status = text('status');
    if (!const ['安全', '輕傷', '重傷', '未宣告'].contains(status)) {
      quality.add('status_missing_or_unrecognized');
    }
    if ((status == '安全' && sos == true) || (status == '未宣告' && sos == false)) {
      quality.add('status_sos_inconsistent');
    }
    return FirestoreHealthReport._(
      uid,
      event,
      uuid,
      matches,
      text('name'),
      status,
      text('description'),
      sos,
      lat,
      lng,
      time,
      quality,
    );
  }

  Map<String, Object?> toJson() => {
    'uid': uid,
    'eventId': eventId,
    'eventIdIsUuid': eventIdIsUuid,
    'reporterIdMatchesUid': reporterIdMatchesUid,
    'name': name,
    'status': status,
    'description': description,
    'sos': sos,
    'latitude': latitude,
    'longitude': longitude,
    'reportTime': reportTime?.toUtc().toIso8601String(),
    'location': {
      'source': 'app_reported',
      'precision': 'unspecified',
      'freshness': 'unknown',
      'capturedAt': null,
      'isRealtime': false,
    },
    'dataQuality': dataQuality,
  };
}
