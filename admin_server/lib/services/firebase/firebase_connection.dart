import 'dart:async';
import 'dart:io';
import 'package:googleapis_auth/auth_io.dart' as auth;
import 'package:http/http.dart' as http;

/// Safe diagnostics only. Never retain or print the original exception/body.
class FirebaseConnectionException implements Exception {
  final String code;
  final String stage;
  final int? httpStatus;
  const FirebaseConnectionException(this.code, this.stage, [this.httpStatus]);
  @override
  String toString() => '$code ($stage)';
}

FirebaseConnectionException firebaseConnectionFailure(
  Object error,
  String stage,
) {
  if (error is FirebaseConnectionException) return error;
  if (error is TimeoutException) {
    return FirebaseConnectionException('NETWORK_TIMEOUT', stage);
  }
  if (error is SocketException ||
      error is http.ClientException ||
      error is HandshakeException) {
    return FirebaseConnectionException('NETWORK_ERROR', stage);
  }
  if (error is auth.CredentialsFileException || error is FileSystemException) {
    return const FirebaseConnectionException(
      'ADC_INVALID_OR_UNREADABLE',
      'adc',
    );
  }
  if (error is auth.AccessDeniedException) {
    return const FirebaseConnectionException('ADC_REJECTED', 'adc');
  }
  if (error is auth.ServerRequestFailedException) {
    return FirebaseConnectionException(
      error.statusCode == 403 ? 'ADC_PERMISSION_DENIED' : 'ADC_REJECTED',
      'adc',
      error.statusCode,
    );
  }
  return FirebaseConnectionException('UNEXPECTED_RESPONSE', stage);
}

/// Production factory only. No mock/emulator mode or printed credentials.
Future<http.Client> createFirebaseAdcClient() async {
  final env = Platform.environment;
  final explicitPath = env['GOOGLE_APPLICATION_CREDENTIALS'];
  if (explicitPath != null && explicitPath.isNotEmpty) {
    if (!File(explicitPath).existsSync()) {
      throw const FirebaseConnectionException('ADC_NOT_FOUND', 'adc');
    }
  } else if (Platform.isWindows) {
    // This probe targets local Windows development. Do not silently fall back
    // to a metadata-server network attempt when local credentials are absent.
    final appData = env['APPDATA'];
    if (appData == null ||
        !File(
          '$appData/gcloud/application_default_credentials.json',
        ).existsSync()) {
      throw const FirebaseConnectionException('ADC_NOT_FOUND', 'adc');
    }
  }
  final transport = _AdcTransport(http.Client());
  try {
    final authenticated = await auth
        .clientViaApplicationDefaultCredentials(
          scopes: ['https://www.googleapis.com/auth/datastore'],
          baseClient: transport,
        )
        .timeout(const Duration(seconds: 20));
    return _OwnedAdcClient(authenticated, transport);
  } catch (error) {
    transport.close();
    throw firebaseConnectionFailure(error, 'adc');
  }
}

class _AdcTransport extends http.BaseClient {
  final http.Client inner;
  _AdcTransport(this.inner);
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    try {
      return await inner.send(request).timeout(const Duration(seconds: 20));
    } catch (error) {
      throw firebaseConnectionFailure(error, 'adc_transport');
    }
  }

  @override
  void close() => inner.close();
}

class _OwnedAdcClient extends http.BaseClient {
  final http.Client authenticated;
  final http.Client transport;
  _OwnedAdcClient(this.authenticated, this.transport);
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      authenticated.send(request);
  @override
  void close() {
    authenticated.close();
    transport.close();
  }
}
