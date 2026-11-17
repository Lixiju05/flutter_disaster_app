import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:admin_server/services/firebase/firebase_config.dart';
import 'package:admin_server/services/firebase/firebase_connection.dart';
import 'package:admin_server/services/firebase/firestore_readonly_probe.dart';

/// Real ADC only. Never import the application server or initialize SQLite.
Future<void> main(List<String> arguments) async {
  FirebaseConfig? config;
  http.Client? client;
  try {
    if (arguments.any((argument) => argument != '--metadata') ||
        arguments.length > 1) {
      throw const FirebaseConfigurationException(
        'INVALID_PROBE_ARGUMENTS',
        'Only the optional --metadata argument is supported',
      );
    }
    config = FirebaseConfig.fromEnvironment(Platform.environment);
    config.requireReadonlyProbe();
    client = await createFirebaseAdcClient();
    final result = await FirestoreReadonlyProbe(
      config,
      client,
    ).run(includeMetadata: arguments.contains('--metadata'));
    stdout.writeln(jsonEncode({'verification': 'live_adc', ...result}));
  } on FirebaseConfigurationException catch (error) {
    stdout.writeln(
      jsonEncode({
        'status': error.code == 'FIREBASE_DISABLED'
            ? 'disabled'
            : 'configuration_error',
        'code': error.code,
        'message': error.message,
        'httpStatus': null,
        'documentsRead': 0,
      }),
    );
    exitCode = 2;
  } catch (error) {
    final failure = firebaseConnectionFailure(error, 'adc_or_probe');
    stdout.writeln(
      jsonEncode({
        'projectId': config?.projectId,
        'databaseId': config?.databaseId,
        'status': 'failed',
        'code': failure.code,
        'stage': failure.stage,
        'httpStatus': failure.httpStatus,
        'documentsRead': 0,
      }),
    );
    exitCode = 1;
  } finally {
    client?.close();
  }
}
