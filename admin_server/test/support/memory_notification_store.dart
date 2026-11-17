import 'dart:async';
import 'package:admin_server/services/notifications/notification_store.dart';

/// Test double only. Production bootstrap never instantiates this class.
class MemoryNotificationStore implements NotificationStore {
  @override
  final String projectId;
  final Map<String, Map<String, Object?>> documents = {};
  bool failNextCommit = false;
  bool loseNextAcknowledgement = false;
  int commits = 0;
  Future<void> _tail = Future.value();
  MemoryNotificationStore(this.projectId);
  @override
  Future<NotificationDocument?> get(String path) async {
    final data = documents[path];
    return data == null ? null : NotificationDocument(path, _copy(data));
  }

  @override
  Future<NotificationPage> list(
    String collection, {
    required int limit,
    String? pageToken,
    String? orderBy,
  }) async {
    final docs = documents.entries
        .where(
          (e) =>
              e.key.startsWith('$collection/') &&
              e.key.split('/').length == collection.split('/').length + 1,
        )
        .toList();
    docs.sort(
      (a, b) => orderBy == 'createdAt desc'
          ? (b.value['createdAt'] as DateTime).compareTo(
              a.value['createdAt'] as DateTime,
            )
          : a.key.compareTo(b.key),
    );
    final offset = pageToken == null ? 0 : int.parse(pageToken);
    final selected = docs.skip(offset).take(limit).toList();
    return NotificationPage(
      [for (final d in selected) NotificationDocument(d.key, _copy(d.value))],
      offset + selected.length < docs.length
          ? '${offset + selected.length}'
          : null,
    );
  }

  @override
  Future<T> transaction<T>(
    Future<T> Function(NotificationTransaction tx) action,
  ) async {
    final previous = _tail;
    final done = Completer<void>();
    _tail = done.future;
    await previous;
    try {
      final tx = _MemoryTransaction(this);
      final result = await action(tx);
      if (tx.writes.isNotEmpty) {
        if (failNextCommit) {
          failNextCommit = false;
          throw const NotificationException(
            503,
            'TEST_WRITE_FAILURE',
            '測試寫入失敗，未發布',
          );
        }
        if (tx.writes.keys.any(documents.containsKey)) {
          throw NotificationConflict();
        }
        documents.addAll({
          for (final e in tx.writes.entries) e.key: _copy(e.value),
        });
        commits++;
        if (loseNextAcknowledgement) {
          loseNextAcknowledgement = false;
          throw const NotificationException(
            503,
            'FIRESTORE_UNCONFIRMED',
            '測試模擬提交回應遺失',
          );
        }
      }
      return result;
    } finally {
      done.complete();
    }
  }
}

class _MemoryTransaction implements NotificationTransaction {
  final MemoryNotificationStore store;
  final Map<String, Map<String, Object?>> writes = {};
  _MemoryTransaction(this.store);
  @override
  Future<NotificationDocument?> get(String path) {
    if (writes.isNotEmpty) throw StateError('Read after write');
    return store.get(path);
  }

  @override
  void create(String path, Map<String, Object?> data) {
    if (writes.containsKey(path)) throw StateError('Duplicate write');
    writes[path] = _copy(data);
  }
}

Map<String, Object?> _copy(Map<String, Object?> value) =>
    value.map((k, v) => MapEntry(k, _clone(v)));
Object? _clone(Object? v) {
  if (v is Map<String, Object?>) return _copy(v);
  if (v is List) return v.map(_clone).toList();
  return v;
}
