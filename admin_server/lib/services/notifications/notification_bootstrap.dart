import 'dart:io';
import 'package:http/http.dart' as http;
import '../firebase/firebase_config.dart';
import '../firebase/firebase_connection.dart';
import 'notification_service.dart';
import 'notification_store.dart';

/// Disabled by default. No ADC discovery, cloud call, or fake publication when disabled.
Future<NotificationService?> createNotificationServiceFromEnvironment({
  Map<String, String>? environment,
  Future<http.Client> Function()? authenticatedClientFactory,
}) async {
  final env = environment ?? Platform.environment;
  final FirebaseConfig config;
  try {
    config = FirebaseConfig.fromEnvironment(env);
  } on FirebaseConfigurationException catch (error) {
    throw NotificationException(503, error.code, error.message);
  }
  if (!config.enabled || !config.notificationsEnabled) return null;
  if (env['NOTIFICATION_SCOPE'] != 'project') {
    throw const NotificationException(
      503,
      'NOTIFICATION_CONFIGURATION',
      '必須明確設定通知專案與 project 發送範圍',
    );
  }
  Set<int> ids(String name, {bool required = false}) {
    final raw = env[name] ?? '';
    if (raw.isEmpty && !required) return {};
    final parts = raw.split(',');
    final parsed = parts.map((s) => int.tryParse(s.trim())).toList();
    if (parsed.any((id) => id == null || id <= 0)) {
      throw NotificationException(
        503,
        'NOTIFICATION_CONFIGURATION',
        '$name 必須為有效管理員 ID 清單',
      );
    }
    return parsed.cast<int>().toSet();
  }

  final policy = NotificationPolicy(
    projectId: config.projectId!,
    adminIds: ids('NOTIFICATION_ADMIN_IDS', required: true),
    broadcastAdminIds: ids('NOTIFICATION_BROADCAST_ADMIN_IDS'),
  );
  final client =
      await (authenticatedClientFactory ?? createFirebaseAdcClient)();
  return NotificationService(
    FirestoreNotificationStore(
      config.projectId!,
      client,
      databaseId: config.databaseId,
      readOnly: config.readOnly,
    ),
    policy,
  );
}
