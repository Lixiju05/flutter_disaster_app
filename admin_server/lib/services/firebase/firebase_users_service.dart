import 'package:admin_server/core/models/firebase_user.dart';
import 'firebase_config.dart';
import 'firebase_connection.dart';
import 'firestore_readonly_reader.dart';

class FirebaseUsersException implements Exception {
  final int statusCode;
  final String code;
  final String message;
  const FirebaseUsersException(this.statusCode, this.code, this.message);
  @override
  String toString() => code; // Never include input or upstream details.
}

class FirebaseUsersPolicy {
  final Set<int> adminIds;
  FirebaseUsersPolicy(Set<int> adminIds)
    : adminIds = Set.unmodifiable(adminIds);
  void authorize(int adminId) {
    if (!adminIds.contains(adminId)) {
      throw const FirebaseUsersException(
        403,
        'FIREBASE_USERS_FORBIDDEN',
        'Administrator has no approved project user-read permission',
      );
    }
  }
}

class FirebaseUsersService {
  static const fields = ['name', 'area', 'registeredAt'];
  final FirebaseConfig config;
  final FirebaseUsersPolicy policy;
  final FirestoreReadonlyReader reader;
  FirebaseUsersService(this.config, this.policy, this.reader) {
    if (!config.enabled || !config.readOnly || config.notificationsEnabled) {
      throw const FirebaseUsersException(
        503,
        'FIREBASE_USERS_CONFIGURATION',
        'User queries require enabled, read-only Firebase and disabled notifications',
      );
    }
  }
  String get _database =>
      'projects/${config.projectId}/databases/${config.databaseId}';

  void _keys(Map<String, dynamic> input, Set<String> allowed) {
    if (input.keys.any((key) => !allowed.contains(key))) {
      throw const FirebaseUsersException(
        400,
        'INVALID_ARGUMENT',
        'Unsupported query field; project, database and collection are server-controlled',
      );
    }
  }

  FirebaseUser _user(Object? raw, {String? expectedUid}) {
    final prefix = '$_database/documents/users/';
    if (raw is! Map ||
        raw['name'] is! String ||
        !(raw['name'] as String).startsWith(prefix)) {
      throw const FirebaseConnectionException(
        'INVALID_FIRESTORE_RESPONSE',
        'users',
        200,
      );
    }
    final uid = (raw['name'] as String).substring(prefix.length);
    if (!FirebaseUser.validUid(uid) ||
        (expectedUid != null && uid != expectedUid)) {
      throw const FirebaseConnectionException(
        'INVALID_FIRESTORE_RESPONSE',
        'users',
        200,
      );
    }
    final values = raw['fields'] ?? <String, Object?>{};
    if (values is! Map) {
      throw const FirebaseConnectionException(
        'INVALID_FIRESTORE_RESPONSE',
        'users',
        200,
      );
    }
    return FirebaseUser.fromFields(uid, values);
  }

  Future<Map<String, Object?>> list(
    int adminId,
    Map<String, dynamic> input,
  ) async {
    policy.authorize(adminId);
    _keys(input, {'type', 'limit', 'pageToken'});
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
      throw const FirebaseUsersException(
        400,
        'INVALID_ARGUMENT',
        'Invalid limit or page token',
      );
    }
    final query = <String, Object>{
      'pageSize': '$limit',
      'orderBy': '__name__ asc',
      'mask.fieldPaths': fields,
    };
    if (token != null) query['pageToken'] = token;
    final Map<String, dynamic> data;
    try {
      data = (await reader.get(
        '$_database/documents/users',
        'users_list',
        query: query,
      ))!;
    } on FirebaseConnectionException catch (error) {
      if (error.httpStatus == 400 && token != null) {
        throw const FirebaseUsersException(
          400,
          'INVALID_PAGE_TOKEN',
          'Page token is invalid or expired',
        );
      }
      rethrow;
    }
    final documents = data['documents'] ?? <Object>[];
    final next = data['nextPageToken'];
    if (documents is! List ||
        documents.length > limit ||
        (next != null &&
            (next is! String ||
                next.length > 8192 ||
                RegExp(r'[\x00-\x1f\x7f]').hasMatch(next)))) {
      throw const FirebaseConnectionException(
        'INVALID_FIRESTORE_RESPONSE',
        'users_list',
        200,
      );
    }
    final users = documents.map(_user).toList();
    if (users.map((user) => user.uid).toSet().length != users.length) {
      throw const FirebaseConnectionException(
        'INVALID_FIRESTORE_RESPONSE',
        'users_list',
        200,
      );
    }
    return {
      'users': users.map((user) => user.toJson()).toList(),
      'nextPageToken': next is String && next.isNotEmpty ? next : null,
    };
  }

  Future<Map<String, Object?>> get(
    int adminId,
    Map<String, dynamic> input,
  ) async {
    policy.authorize(adminId);
    _keys(input, {'type', 'uid'});
    final uid = input['uid'];
    if (!FirebaseUser.validUid(uid)) {
      throw const FirebaseUsersException(
        400,
        'INVALID_UID',
        'A valid Firebase document UID is required',
      );
    }
    final document = await reader.get(
      '$_database/documents/users/$uid',
      'user_detail',
      query: {'mask.fieldPaths': fields},
      missingAllowed: true,
    );
    if (document == null) {
      // A missing database must not masquerade as a missing user. Metadata is
      // read only on a 404, with the same ADC and a GET, never a transaction.
      final database = await reader.get(_database, 'database_metadata');
      if (database?['name'] != _database) {
        throw const FirebaseConnectionException(
          'DATABASE_TARGET_MISMATCH',
          'database_metadata',
          200,
        );
      }
      throw const FirebaseUsersException(
        404,
        'FIREBASE_USER_NOT_FOUND',
        'Firebase user document not found',
      );
    }
    return _user(document, expectedUid: uid as String).toJson();
  }

  void close() => reader.client.close();
}
