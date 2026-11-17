import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'notification_store.dart';

class NotificationPolicy {
  final String projectId;
  final Set<int> adminIds;
  final Set<int> broadcastAdminIds;
  NotificationPolicy({
    required this.projectId,
    required Set<int> adminIds,
    required Set<int> broadcastAdminIds,
  }) : adminIds = Set.unmodifiable(adminIds),
       broadcastAdminIds = Set.unmodifiable(broadcastAdminIds) {
    if (!adminIds.containsAll(broadcastAdminIds)) {
      throw ArgumentError('Broadcast admins must also be notification admins');
    }
  }
  void authorize(int adminId, {bool broadcast = false}) {
    if (!adminIds.contains(adminId) ||
        (broadcast && !broadcastAdminIds.contains(adminId))) {
      throw const NotificationException(
        403,
        'NOTIFICATION_FORBIDDEN',
        '此管理員未獲通知操作／廣播權限',
      );
    }
  }
}

class NotificationService {
  static const maxRecipients = 100;
  final NotificationStore store;
  final NotificationPolicy policy;
  final DateTime Function() _now;
  NotificationService(this.store, this.policy, {DateTime Function()? now})
    : _now = now ?? DateTime.now {
    if (store.projectId != policy.projectId) {
      throw ArgumentError('Notification project mismatch');
    }
  }

  String _text(Map<String, dynamic> input, String key, int max) {
    final value = input[key];
    if (value is! String || value.trim().isEmpty || value.runes.length > max) {
      throw NotificationException(
        400,
        'INVALID_ARGUMENT',
        '$key 必須為非空字串，且不超過 $max 字',
      );
    }
    return value.trim();
  }

  bool _validUid(String uid) =>
      uid.isNotEmpty &&
      uid.length <= 128 &&
      uid == uid.trim() &&
      !['.', '..'].contains(uid) &&
      !uid.contains('/') &&
      !uid.contains('\\') &&
      !RegExp(r'[\x00-\x1f\x7f]').hasMatch(uid);

  Map<String, Object?>? _profile(NotificationDocument doc) {
    final uid = doc.path.split('/').last;
    final d = doc.data;
    if (!_validUid(uid) ||
        d['email'] is! String ||
        (d['email'] as String).trim().isEmpty) {
      return null;
    }
    // UID always comes from users/{uid}; a legacy profile id is not authorization.
    return {
      'uid': uid,
      'id': d['id'] is String ? d['id'] : null,
      for (final key in ['email', 'name', 'phone', 'area'])
        key: d[key] is String ? d[key] : '',
    };
  }

  ({int limit, String? token}) _page(Map<String, dynamic> input) {
    final limit = input['limit'] ?? 50;
    final token = input['pageToken'];
    if (limit is! int ||
        limit < 1 ||
        limit > 100 ||
        (token != null && (token is! String || token.length > 8192))) {
      throw const NotificationException(
        400,
        'INVALID_ARGUMENT',
        'limit 必須為 1～100，pageToken 必須為字串',
      );
    }
    return (limit: limit, token: token as String?);
  }

  Future<Map<String, Object?>> recipients(
    int adminId,
    Map<String, dynamic> input,
  ) async {
    policy.authorize(adminId);
    final p = _page(input);
    final page = await store.list('users', limit: p.limit, pageToken: p.token);
    final profiles = page.documents
        .map(_profile)
        .whereType<Map<String, Object?>>()
        .toList();
    return {
      'recipients': profiles,
      'nextPageToken': page.nextPageToken,
      'skippedInvalidProfiles': page.documents.length - profiles.length,
      'scope': {'type': 'project', 'projectId': policy.projectId},
    };
  }

  Future<Map<String, Object?>> send(
    int adminId,
    Map<String, dynamic> input,
  ) async {
    policy.authorize(adminId);
    final audience = input['audience'];
    if (!['broadcast', 'users'].contains(audience)) {
      throw const NotificationException(
        400,
        'INVALID_ARGUMENT',
        'audience 必須為 broadcast 或 users',
      );
    }
    policy.authorize(adminId, broadcast: audience == 'broadcast');
    final title = _text(input, 'title', 100);
    final body = _text(input, 'body', 4000);
    final category = _text(
      {'category': input['category'] ?? 'general'},
      'category',
      40,
    );
    final requestId = _text(input, 'clientRequestId', 128);
    if (!RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(requestId)) {
      throw const NotificationException(
        400,
        'INVALID_ARGUMENT',
        'clientRequestId 只允許英數字、底線與連字號',
      );
    }
    final expiryText = _text(input, 'expiresAt', 64);
    final expiry = DateTime.tryParse(expiryText);
    if (expiry == null ||
        !RegExp(r'(Z|[+-]\d{2}:\d{2})$').hasMatch(expiryText)) {
      throw const NotificationException(
        400,
        'INVALID_ARGUMENT',
        'expiresAt 必須為有時區的 ISO 8601 時間',
      );
    }
    final expiresAt = expiry.toUtc();
    final rawUids = input['recipientUids'];
    final uids = <String>[];
    if (audience == 'users') {
      if (rawUids is! List ||
          rawUids.isEmpty ||
          rawUids.length > maxRecipients ||
          rawUids.any((uid) => uid is! String || !_validUid(uid))) {
        throw const NotificationException(
          400,
          'INVALID_RECIPIENTS',
          'recipientUids 必須為 1～100 個有效 Firebase UID',
        );
      }
      uids.addAll(rawUids.cast<String>());
      if (uids.toSet().length != uids.length) {
        throw const NotificationException(
          400,
          'INVALID_RECIPIENTS',
          'recipientUids 不可重複',
        );
      }
      uids.sort();
    } else if (rawUids != null && (rawUids is! List || rawUids.isNotEmpty)) {
      throw const NotificationException(
        400,
        'INVALID_RECIPIENTS',
        '廣播不可指定 recipientUids',
      );
    }
    final normalized = <String, Object?>{
      'audience': audience,
      'recipientUids': uids,
      'title': title,
      'body': body,
      'category': category,
      'expiresAt': expiresAt.toIso8601String(),
      'projectId': policy.projectId,
    };
    final fingerprint = sha256
        .convert(utf8.encode(jsonEncode(normalized)))
        .toString();
    final messageId = sha256
        .convert(
          utf8.encode(jsonEncode([policy.projectId, adminId, requestId])),
        )
        .toString();
    final logPath = 'notification_sends/$messageId';
    return store.transaction((tx) async {
      final previous = await tx.get(logPath);
      if (previous != null) {
        if (previous.data['requestFingerprint'] != fingerprint ||
            previous.data['createdByAdminId'] != adminId ||
            previous.data['status'] != 'published') {
          throw const NotificationException(
            409,
            'IDEMPOTENCY_CONFLICT',
            '此 clientRequestId 已用於不同內容，請勿重用',
          );
        }
        return _published(previous.data, replayed: true);
      }
      final now = _now().toUtc();
      if (!expiresAt.isAfter(now) ||
          expiresAt.isAfter(now.add(const Duration(days: 30)))) {
        throw const NotificationException(
          400,
          'INVALID_EXPIRY',
          '有效期限必須在未來 30 天內',
        );
      }
      // All recipient reads are inside the transaction, before any write.
      final profiles = await Future.wait([
        for (final uid in uids) tx.get('users/$uid'),
      ]);
      for (var i = 0; i < profiles.length; i++) {
        if (profiles[i] == null || _profile(profiles[i]!) == null) {
          throw NotificationException(
            422,
            'RECIPIENT_UNAVAILABLE',
            '收件者不存在或使用者文件不完整，整筆未發布',
          );
        }
      }
      final common = <String, Object?>{
        'messageId': messageId,
        'title': title,
        'body': body,
        'category': category,
        'createdAt': now,
        'expiresAt': expiresAt,
        'createdByAdminId': adminId,
        'clientRequestId': requestId,
        'audience': audience,
        'projectId': policy.projectId,
        'schemaVersion': 1,
      };
      final log = <String, Object?>{
        ...common,
        'status': 'published',
        'recipientUids': uids,
        'recipientCount': audience == 'broadcast' ? null : uids.length,
        'requestFingerprint': fingerprint,
      };
      tx.create(logPath, log);
      if (audience == 'broadcast') {
        tx.create('broadcasts/$messageId', common);
      } else {
        for (final uid in uids) {
          tx.create('users/$uid/notifications/$messageId', common);
        }
      }
      return _published(log, replayed: false);
    });
  }

  Map<String, Object?> _published(
    Map<String, Object?> log, {
    required bool replayed,
  }) => {
    'messageId': log['messageId'],
    'status': 'published',
    'replayed': replayed,
    'createdAt': log['createdAt'],
    'expiresAt': log['expiresAt'],
    'audience': log['audience'],
    'recipientCount': log['recipientCount'],
    'deliveryStatus': 'not_tracked',
    'readStatus': 'not_tracked',
  };

  Future<Map<String, Object?>> sent(
    int adminId,
    Map<String, dynamic> input,
  ) async {
    policy.authorize(adminId);
    final id = input['messageId'];
    if (id != null) {
      if (id is! String || !RegExp(r'^[0-9a-f]{64}$').hasMatch(id)) {
        throw const NotificationException(
          400,
          'INVALID_ARGUMENT',
          'messageId 格式錯誤',
        );
      }
      final doc = await store.get('notification_sends/$id');
      if (doc == null || doc.data['createdByAdminId'] != adminId) {
        throw const NotificationException(404, 'NOT_FOUND', '找不到自己的發送紀錄');
      }
      return {
        'notifications': [_logForApi(doc.data)],
        'nextPageToken': null,
      };
    }
    final p = _page(input);
    final page = await store.list(
      'notification_sends',
      limit: p.limit,
      pageToken: p.token,
      orderBy: 'createdAt desc',
    );
    return {
      'notifications': [
        for (final doc in page.documents)
          if (doc.data['createdByAdminId'] == adminId) _logForApi(doc.data),
      ],
      'nextPageToken': page.nextPageToken,
    };
  }

  Map<String, Object?> _logForApi(Map<String, Object?> log) => {
    for (final key in [
      'messageId',
      'title',
      'body',
      'category',
      'createdAt',
      'expiresAt',
      'createdByAdminId',
      'clientRequestId',
      'audience',
      'recipientUids',
      'recipientCount',
      'status',
    ])
      key: log[key],
    'deliveryStatus': 'not_tracked',
    'readStatus': 'not_tracked',
  };
}

/// Convert Firestore timestamps only at the HTTP boundary.
Object? notificationJson(Object? value) {
  if (value is DateTime) return value.toUtc().toIso8601String();
  if (value is List) return value.map(notificationJson).toList();
  if (value is Map) {
    return value.map((key, v) => MapEntry(key.toString(), notificationJson(v)));
  }
  return value;
}
