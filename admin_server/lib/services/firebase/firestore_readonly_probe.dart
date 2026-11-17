import 'package:http/http.dart' as http;
import 'firebase_config.dart';
import 'firebase_connection.dart';
import 'firestore_readonly_reader.dart';

/// GET-only Firestore reader. Tests inject MockClient explicitly; the CLI only
/// supplies createFirebaseAdcClient(). No SQLite, notifications or server init.
class FirestoreReadonlyProbe {
  final FirebaseConfig config;
  final http.Client client;
  final Duration timeout;
  FirestoreReadonlyProbe(
    this.config,
    this.client, {
    this.timeout = const Duration(seconds: 20),
  }) {
    config.requireReadonlyProbe();
  }

  static const fields = [
    'id',
    'email',
    'name',
    'phone',
    'area',
    'registeredAt',
    'createdAt',
    'updatedAt',
  ];
  static const types = <String, String>{
    'nullValue': 'null',
    'booleanValue': 'boolean',
    'integerValue': 'integer',
    'doubleValue': 'double',
    'timestampValue': 'timestamp',
    'stringValue': 'string',
    'bytesValue': 'bytes',
    'referenceValue': 'reference',
    'geoPointValue': 'geoPoint',
    'arrayValue': 'array',
    'mapValue': 'map',
  };
  String get _database =>
      'projects/${config.projectId}/databases/${config.databaseId}';

  Future<Map<String, dynamic>> _get(
    String path,
    String stage, [
    Map<String, Object>? query,
  ]) async {
    return (await FirestoreReadonlyReader(
      client,
      timeout: timeout,
    ).get(path, stage, query: query))!;
  }

  Future<Map<String, Object?>> run({bool includeMetadata = false}) async {
    if (includeMetadata) {
      final metadata = await _get(_database, 'database_metadata');
      if (metadata['name'] != _database) {
        throw const FirebaseConnectionException(
          'DATABASE_TARGET_MISMATCH',
          'database_metadata',
          200,
        );
      }
    }
    final data = await _get('$_database/documents/users', 'users', {
      'pageSize': '1',
      'mask.fieldPaths': fields,
    });
    final documents = data['documents'] ?? <Object>[];
    if (documents is! List || documents.length > 1) {
      throw const FirebaseConnectionException(
        'INVALID_FIRESTORE_RESPONSE',
        'users',
        200,
      );
    }
    final summary = <String, String>{};
    if (documents.isNotEmpty) {
      final doc = documents.single;
      final prefix = '$_database/documents/users/';
      if (doc is! Map ||
          doc['name'] is! String ||
          !(doc['name'] as String).startsWith(prefix) ||
          (doc['name'] as String).substring(prefix.length).isEmpty ||
          (doc['name'] as String).substring(prefix.length).contains('/')) {
        throw const FirebaseConnectionException(
          'INVALID_FIRESTORE_RESPONSE',
          'users',
          200,
        );
      }
      final values = doc['fields'] ?? <String, Object?>{};
      if (values is! Map) {
        throw const FirebaseConnectionException(
          'INVALID_FIRESTORE_RESPONSE',
          'users',
          200,
        );
      }
      for (final name in fields) {
        final value = values[name];
        if (value is Map) {
          final matches = types.keys.where(value.containsKey).toList();
          summary[name] = matches.length == 1
              ? types[matches.single]!
              : 'unknown';
        }
      }
    }
    return {
      'projectId': config.projectId,
      'databaseId': config.databaseId,
      'status': documents.isEmpty ? 'read_ok_empty' : 'read_ok',
      'httpStatus': 200,
      'documentsRead': documents.length,
      'fieldTypes': summary,
    };
  }
}
