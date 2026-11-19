import 'package:admin_server/core/models/firebase_user.dart';
import 'package:admin_server/core/models/firestore_health_report.dart';
import 'firebase_config.dart';
import 'firebase_connection.dart';
import 'firestore_readonly_reader.dart';

class FirebaseReportsException implements Exception {
  final int statusCode;
  final String code;
  final String message;
  const FirebaseReportsException(this.statusCode, this.code, this.message);
  @override
  String toString() => code;
}

class FirestoreHealthReportReader {
  static const fields = [
    'id',
    'reporterId',
    'name',
    'status',
    'description',
    'sos',
    'lat',
    'lng',
    'reportTime',
  ];
  final FirebaseConfig config;
  final Set<int> adminIds;
  final FirestoreReadonlyReader transport;
  FirestoreHealthReportReader(this.config, Set<int> adminIds, this.transport)
    : adminIds = Set.unmodifiable(adminIds) {
    if (!config.enabled || !config.readOnly || config.notificationsEnabled) {
      throw const FirebaseReportsException(
        503,
        'FIREBASE_REPORTS_CONFIGURATION',
        'Read-only Firebase with notifications disabled is required',
      );
    }
  }
  void authorize(int adminId) {
    if (!adminIds.contains(adminId)) {
      throw const FirebaseReportsException(
        403,
        'FIREBASE_REPORTS_FORBIDDEN',
        'Administrator has no approved report-read permission',
      );
    }
  }

  Never _invalidResponse() => throw const FirebaseConnectionException(
    'INVALID_FIRESTORE_RESPONSE',
    'health_reports',
    200,
  );

  Future<Map<String, Object?>> list(
    int adminId,
    Map<String, dynamic> input, {
    required bool sosOnly,
  }) async {
    authorize(adminId);
    if (input.keys.any(
      (key) => !const {'type', 'limit', 'pageToken'}.contains(key),
    )) {
      throw const FirebaseReportsException(
        400,
        'INVALID_ARGUMENT',
        'Unsupported query field',
      );
    }
    final limit = input.containsKey('limit') ? input['limit'] : 25;
    final token = input['pageToken'];
    if (limit is! int ||
        limit < 1 ||
        limit > 100 ||
        (input.containsKey('pageToken') &&
            (token is! String ||
                token.isEmpty ||
                token.length > 8192 ||
                RegExp(r'[\x00-\x1f\x7f]').hasMatch(token)))) {
      throw const FirebaseReportsException(
        400,
        'INVALID_ARGUMENT',
        'Invalid limit or page token',
      );
    }
    final database =
        'projects/${config.projectId}/databases/${config.databaseId}';
    final prefix = '$database/documents/health_reports/';
    final query = <String, Object>{
      'pageSize': '$limit',
      'orderBy': '__name__ asc',
      'mask.fieldPaths': fields,
    };
    if (token != null) query['pageToken'] = token;
    final Map<String, dynamic> page;
    try {
      page = (await transport.get(
        '$database/documents/health_reports',
        'health_reports',
        query: query,
      ))!;
    } on FirebaseConnectionException catch (error) {
      if (error.httpStatus == 400 && token != null) {
        throw const FirebaseReportsException(
          400,
          'INVALID_PAGE_TOKEN',
          'Page token is invalid or expired',
        );
      }
      rethrow;
    }
    final documents = page['documents'] ?? <Object>[];
    final next = page['nextPageToken'];
    if (documents is! List ||
        documents.length > limit ||
        (next != null &&
            (next is! String ||
                next.length > 8192 ||
                RegExp(r'[\x00-\x1f\x7f]').hasMatch(next)))) {
      _invalidResponse();
    }
    final reports = <FirestoreHealthReport>[];
    final seen = <String>{};
    for (final raw in documents) {
      if (raw is! Map ||
          raw['name'] is! String ||
          !(raw['name'] as String).startsWith(prefix)) {
        _invalidResponse();
      }
      final uid = (raw['name'] as String).substring(prefix.length);
      if (!FirebaseUser.validUid(uid) || !seen.add(uid)) _invalidResponse();
      final values = raw['fields'] ?? <String, Object?>{};
      if (values is! Map) _invalidResponse();
      reports.add(FirestoreHealthReport.fromFields(uid, values));
    }
    return {
      'reports': [
        for (final report in reports)
          if (!sosOnly || report.sos == true) report.toJson(),
      ],
      'nextPageToken': next is String && next.isNotEmpty ? next : null,
      'scannedCount': documents.length,
      'semantics': 'latest_per_uid',
      'pagination': 'source_page',
      'sosOnly': sosOnly,
    };
  }

  void close() => transport.client.close();
}
