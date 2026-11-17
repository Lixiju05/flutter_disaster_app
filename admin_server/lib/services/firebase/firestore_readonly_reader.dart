import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'firebase_connection.dart';

/// Shared, bounded-time GET transport for the probe and user reader. OAuth
/// traffic belongs to the ADC client; Firestore traffic here is always GET.
class FirestoreReadonlyReader {
  final http.Client client;
  final Duration timeout;
  FirestoreReadonlyReader(
    this.client, {
    this.timeout = const Duration(seconds: 20),
  });

  Future<Map<String, dynamic>?> get(
    String path,
    String stage, {
    Map<String, Object>? query,
    bool missingAllowed = false,
  }) async {
    final abort = Completer<void>();
    try {
      final request = http.AbortableRequest(
        'GET',
        Uri.https('firestore.googleapis.com', '/v1/$path', query),
        abortTrigger: abort.future,
      )..followRedirects = false;
      request.headers['Accept'] = 'application/json';
      final response = await client
          .send(request)
          .then(http.Response.fromStream)
          .timeout(timeout);
      Map<String, dynamic>? data;
      try {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        if (decoded is Map<String, dynamic>) data = decoded;
      } catch (_) {
        /* Never expose response contents. */
      }
      if (response.statusCode == 404 && missingAllowed) return null;
      if (response.statusCode != 200) {
        final error = data?['error'];
        final details = error is Map ? error['details'] : null;
        final reasons = <String>{};
        if (details is List) {
          for (final detail in details) {
            if (detail is Map && detail['reason'] is String) {
              reasons.add(detail['reason'] as String);
            }
          }
        }
        final code =
            reasons.contains('SERVICE_DISABLED') ||
                reasons.contains('API_DISABLED')
            ? 'API_NOT_ENABLED'
            : response.statusCode == 401
            ? 'ADC_REJECTED'
            : response.statusCode == 403
            ? 'PERMISSION_DENIED'
            : response.statusCode == 404
            ? 'DATABASE_NOT_FOUND_OR_INACCESSIBLE'
            : response.statusCode == 429
            ? 'QUOTA_EXCEEDED'
            : 'FIRESTORE_HTTP_ERROR';
        throw FirebaseConnectionException(code, stage, response.statusCode);
      }
      if (data == null || data.containsKey('error')) {
        throw FirebaseConnectionException(
          'INVALID_FIRESTORE_RESPONSE',
          stage,
          200,
        );
      }
      return data;
    } catch (error) {
      throw firebaseConnectionFailure(error, stage);
    } finally {
      // Real IOClient cancels an outstanding request on timeout/disconnect.
      // Mock tests can also observe this signal; no automatic retry is issued.
      if (!abort.isCompleted) abort.complete();
    }
  }
}
