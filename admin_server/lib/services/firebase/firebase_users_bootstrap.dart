import 'dart:io';
import 'package:http/http.dart' as http;
import 'firebase_config.dart';
import 'firebase_connection.dart';
import 'firebase_users_service.dart';
import 'firestore_readonly_reader.dart';

Future<FirebaseUsersService?> createFirebaseUsersServiceFromEnvironment({
  Map<String, String>? environment,
  Future<http.Client> Function()? authenticatedClientFactory,
}) async {
  final env = environment ?? Platform.environment;
  final enabled = env['FIREBASE_USERS_ENABLED'] ?? 'false';
  if (enabled == 'false') return null; // No ADC discovery or network activity.
  if (enabled != 'true') {
    throw const FirebaseConfigurationException(
      'INVALID_FIREBASE_USERS_FLAG',
      'FIREBASE_USERS_ENABLED must be true or false',
    );
  }
  final config = FirebaseConfig.fromEnvironment(env);
  if (!config.enabled ||
      !config.readOnly ||
      config.notificationsEnabled ||
      env['FIREBASE_USERS_SCOPE'] != 'project') {
    throw const FirebaseConfigurationException(
      'FIREBASE_USERS_CONFIGURATION',
      'Explicit project scope, read-only Firebase and disabled notifications are required',
    );
  }
  final parts = (env['FIREBASE_USERS_ADMIN_IDS'] ?? '').split(',');
  final ids = parts.map((value) => int.tryParse(value.trim())).toList();
  if (ids.any((id) => id == null || id <= 0)) {
    throw const FirebaseConfigurationException(
      'FIREBASE_USERS_ADMIN_IDS_REQUIRED',
      'Explicit positive administrator IDs are required',
    );
  }
  final client =
      await (authenticatedClientFactory ?? createFirebaseAdcClient)();
  try {
    return FirebaseUsersService(
      config,
      FirebaseUsersPolicy(ids.cast<int>().toSet()),
      FirestoreReadonlyReader(client, timeout: const Duration(seconds: 10)),
    );
  } catch (_) {
    client.close();
    rethrow;
  }
}
