import 'dart:io';
import 'package:http/http.dart' as http;
import 'firebase_config.dart';
import 'firebase_connection.dart';
import 'firestore_readonly_reader.dart';
import 'firestore_health_report_reader.dart';

Future<FirestoreHealthReportReader?>
createFirebaseReportsReaderFromEnvironment({
  Map<String, String>? environment,
  Future<http.Client> Function()? authenticatedClientFactory,
}) async {
  final env = environment ?? Platform.environment;
  final enabled = env['FIREBASE_REPORTS_ENABLED'] ?? 'false';
  if (enabled == 'false') return null;
  if (enabled != 'true') {
    throw const FirebaseConfigurationException(
      'INVALID_FIREBASE_REPORTS_FLAG',
      'FIREBASE_REPORTS_ENABLED must be true or false',
    );
  }
  final config = FirebaseConfig.fromEnvironment(env);
  if (!config.enabled ||
      !config.readOnly ||
      config.notificationsEnabled ||
      env['FIREBASE_REPORTS_SCOPE'] != 'project') {
    throw const FirebaseConfigurationException(
      'FIREBASE_REPORTS_CONFIGURATION',
      'Explicit project scope, read-only Firebase and disabled notifications required',
    );
  }
  final ids = (env['FIREBASE_REPORTS_ADMIN_IDS'] ?? '')
      .split(',')
      .map((v) => int.tryParse(v.trim()))
      .toList();
  if (ids.any((id) => id == null || id <= 0)) {
    throw const FirebaseConfigurationException(
      'FIREBASE_REPORTS_ADMIN_IDS_REQUIRED',
      'Explicit positive administrator IDs required',
    );
  }
  final client =
      await (authenticatedClientFactory ?? createFirebaseAdcClient)();
  try {
    return FirestoreHealthReportReader(
      config,
      ids.cast<int>().toSet(),
      FirestoreReadonlyReader(client, timeout: const Duration(seconds: 10)),
    );
  } catch (_) {
    client.close();
    rethrow;
  }
}
