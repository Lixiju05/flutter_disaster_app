import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

class NotificationException implements Exception {
  final int statusCode;
  final String code;
  final String message;
  const NotificationException(this.statusCode, this.code, this.message);
  @override
  String toString() => message;
}

class NotificationConflict implements Exception {}

class NotificationDocument {
  final String path;
  final Map<String, Object?> data;
  const NotificationDocument(this.path, this.data);
}

class NotificationPage {
  final List<NotificationDocument> documents;
  final String? nextPageToken;
  const NotificationPage(this.documents, this.nextPageToken);
}

abstract interface class NotificationTransaction {
  Future<NotificationDocument?> get(String path);
  void create(String path, Map<String, Object?> data);
}

abstract interface class NotificationStore {
  String get projectId;
  Future<NotificationDocument?> get(String path);
  Future<NotificationPage> list(
    String collection, {
    required int limit,
    String? pageToken,
    String? orderBy,
  });
  Future<T> transaction<T>(
    Future<T> Function(NotificationTransaction tx) action,
  );
}

/// The client must be server-authenticated (ADC); never pass a Flutter API key.
class FirestoreNotificationStore implements NotificationStore {
  @override
  final String projectId;
  final http.Client client;
  final Duration timeout;
  final String databaseId;
  final bool readOnly;
  FirestoreNotificationStore(
    this.projectId,
    this.client, {
    this.timeout = const Duration(seconds: 20),
    this.databaseId = '(default)',
    this.readOnly = false,
  });
  String get _database => 'projects/$projectId/databases/$databaseId';
  String _name(String path) => '$_database/documents/$path';

  Future<Map<String, dynamic>?> _request(
    String method,
    String path, {
    Map<String, String>? query,
    Map<String, Object?>? body,
    bool missingAllowed = false,
  }) async {
    if (readOnly && method != 'GET') {
      throw const NotificationException(
        403,
        'FIREBASE_READ_ONLY',
        'Firestore write operations are disabled in read-only mode',
      );
    }
    try {
      final request = http.Request(
        method,
        Uri.https('firestore.googleapis.com', '/v1/$path', query),
      );
      request.headers['Content-Type'] = 'application/json';
      if (body != null) request.body = jsonEncode(body);
      final response = await (() async => http.Response.fromStream(
        await client.send(request),
      ))().timeout(timeout);
      if (response.statusCode == 404 && missingAllowed) return null;
      if (response.statusCode < 200 || response.statusCode >= 300) {
        String? status;
        try {
          status =
              (jsonDecode(response.body)['error'] as Map?)?['status']
                  as String?;
        } catch (_) {
          /* no upstream body disclosure */
        }
        if (['ABORTED', 'ALREADY_EXISTS'].contains(status) ||
            response.statusCode == 409) {
          throw NotificationConflict();
        }
        throw const NotificationException(
          503,
          'FIRESTORE_UNAVAILABLE',
          'Firestore 操作未成功，請確認授權、設定及連線後以相同 clientRequestId 重試',
        );
      }
      return response.body.isEmpty
          ? {}
          : jsonDecode(response.body) as Map<String, dynamic>;
    } on NotificationException {
      rethrow;
    } on NotificationConflict {
      rethrow;
    } catch (_) {
      throw const NotificationException(
        503,
        'FIRESTORE_UNCONFIRMED',
        'Firestore 結果未確認，請以相同 clientRequestId 重試或查詢紀錄',
      );
    }
  }

  NotificationDocument _document(Map<String, dynamic> raw) {
    final name = raw['name'] as String;
    final prefix = '$_database/documents/';
    if (!name.startsWith(prefix)) {
      throw const FormatException('Unexpected project');
    }
    return NotificationDocument(
      name.substring(prefix.length),
      decodeFirestoreFields(raw['fields'] as Map? ?? {}),
    );
  }

  @override
  Future<NotificationDocument?> get(String path) async {
    final raw = await _request('GET', _name(path), missingAllowed: true);
    return raw == null ? null : _document(raw);
  }

  @override
  Future<NotificationPage> list(
    String collection, {
    required int limit,
    String? pageToken,
    String? orderBy,
  }) async {
    final query = <String, String>{'pageSize': '$limit'};
    if (pageToken != null) query['pageToken'] = pageToken;
    if (orderBy != null) query['orderBy'] = orderBy;
    final raw = (await _request('GET', _name(collection), query: query))!;
    return NotificationPage([
      for (final doc in raw['documents'] as List? ?? [])
        _document(Map<String, dynamic>.from(doc as Map)),
    ], raw['nextPageToken'] as String?);
  }

  @override
  Future<T> transaction<T>(
    Future<T> Function(NotificationTransaction tx) action,
  ) async {
    if (readOnly) {
      throw const NotificationException(
        403,
        'FIREBASE_READ_ONLY',
        'Firestore transactions are disabled in read-only mode',
      );
    }
    for (var attempt = 0; attempt < 3; attempt++) {
      String? token;
      try {
        final start = (await _request(
          'POST',
          '$_database/documents:beginTransaction',
          body: {
            'options': {'readWrite': {}},
          },
        ))!;
        token = start['transaction'] as String;
        final tx = _FirestoreTransaction(this, token);
        final result = await action(tx);
        if (tx.writes.isEmpty) {
          await _rollback(token);
        } else {
          final acknowledgement = await _request(
            'POST',
            '$_database/documents:commit',
            body: {'transaction': token, 'writes': tx.writes},
          );
          final commitTime = acknowledgement?['commitTime'];
          final writeResults = acknowledgement?['writeResults'];
          if (commitTime is! String ||
              DateTime.tryParse(commitTime) == null ||
              writeResults is! List ||
              writeResults.length != tx.writes.length) {
            throw const NotificationException(
              503,
              'FIRESTORE_UNCONFIRMED',
              'Firestore 提交確認不完整，請以相同 clientRequestId 重試或查詢紀錄',
            );
          }
        }
        return result; // Publication is reported only after commit acknowledgement.
      } on NotificationConflict {
        if (token != null) await _rollback(token);
        if (attempt == 2) {
          throw const NotificationException(
            409,
            'RETRY_REQUIRED',
            '併發衝突，請以相同 clientRequestId 重試',
          );
        }
      } catch (_) {
        if (token != null) await _rollback(token);
        rethrow;
      }
    }
    throw StateError('Unreachable');
  }

  Future<void> _rollback(String token) async {
    try {
      await _request(
        'POST',
        '$_database/documents:rollback',
        body: {'transaction': token},
      );
    } catch (_) {
      /* best effort cleanup; never log credentials */
    }
  }
}

class _FirestoreTransaction implements NotificationTransaction {
  final FirestoreNotificationStore store;
  final String token;
  final List<Map<String, Object?>> writes = [];
  _FirestoreTransaction(this.store, this.token);
  @override
  Future<NotificationDocument?> get(String path) async {
    if (writes.isNotEmpty) {
      throw StateError('Transaction reads must precede writes');
    }
    final raw = await store._request(
      'GET',
      store._name(path),
      query: {'transaction': token},
      missingAllowed: true,
    );
    return raw == null ? null : store._document(raw);
  }

  @override
  void create(String path, Map<String, Object?> data) => writes.add({
    'update': {
      'name': store._name(path),
      'fields': encodeFirestoreFields(data),
    },
    'currentDocument': {'exists': false},
  });
}

Map<String, Object?> encodeFirestoreFields(Map<String, Object?> data) =>
    data.map((key, value) => MapEntry(key, _encode(value)));
Map<String, Object?> _encode(Object? value) {
  if (value == null) return {'nullValue': null};
  if (value is DateTime) {
    return {'timestampValue': value.toUtc().toIso8601String()};
  }
  if (value is String) return {'stringValue': value};
  if (value is bool) return {'booleanValue': value};
  if (value is int) return {'integerValue': '$value'};
  if (value is double) return {'doubleValue': value};
  if (value is List) {
    return {
      'arrayValue': {'values': value.map(_encode).toList()},
    };
  }
  if (value is Map<String, Object?>) {
    return {
      'mapValue': {'fields': encodeFirestoreFields(value)},
    };
  }
  throw ArgumentError('Unsupported Firestore value');
}

Map<String, Object?> decodeFirestoreFields(Map data) =>
    data.map((key, value) => MapEntry(key.toString(), _decode(value as Map)));
Object? _decode(Map value) {
  if (value.containsKey('nullValue')) return null;
  if (value.containsKey('stringValue')) return value['stringValue'];
  if (value.containsKey('timestampValue')) {
    return DateTime.parse(value['timestampValue'] as String).toUtc();
  }
  if (value.containsKey('booleanValue')) return value['booleanValue'];
  if (value.containsKey('integerValue')) {
    return int.parse(value['integerValue'].toString());
  }
  if (value.containsKey('doubleValue')) return value['doubleValue'];
  if (value.containsKey('arrayValue')) {
    return ((value['arrayValue'] as Map)['values'] as List? ?? [])
        .map((v) => _decode(v as Map))
        .toList();
  }
  if (value.containsKey('mapValue')) {
    return decodeFirestoreFields(
      (value['mapValue'] as Map)['fields'] as Map? ?? {},
    );
  }
  return null; // Unused profile fields (geo/reference/bytes) are not exposed by the API.
}
