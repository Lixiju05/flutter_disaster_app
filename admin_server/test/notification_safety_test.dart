import 'package:admin_server/services/admin_session_store.dart';
import 'package:admin_server/services/notifications/notification_bootstrap.dart';
import 'package:admin_server/services/notifications/notification_store.dart';
import 'package:test/test.dart';

// Local configuration/session tests only. No ADC, Firebase or SQLite access.
void main() {
  test('disabled notifications never request an authenticated client', () async {
    var clientRequests = 0;
    final service = await createNotificationServiceFromEnvironment(
      environment: const {
        'FIREBASE_ENABLED': 'true',
        'FIREBASE_PROJECT_ID': 'hucares-notification-test',
        'FIREBASE_READ_ONLY': 'true',
        'NOTIFICATIONS_ENABLED': 'false',
      },
      authenticatedClientFactory: () async {
        clientRequests++;
        throw StateError('Must not request ADC');
      },
    );
    expect(service, isNull);
    expect(clientRequests, 0);
  });

  test('read-only configuration refuses notification writes before ADC', () async {
    var clientRequests = 0;
    await expectLater(
      createNotificationServiceFromEnvironment(
        environment: const {
          'FIREBASE_ENABLED': 'true',
          'FIREBASE_PROJECT_ID': 'hucares-notification-test',
          'FIREBASE_READ_ONLY': 'true',
          'NOTIFICATIONS_ENABLED': 'true',
        },
        authenticatedClientFactory: () async {
          clientRequests++;
          throw StateError('Must not request ADC');
        },
      ),
      throwsA(isA<NotificationException>()
          .having((e) => e.code, 'code', 'FIREBASE_READ_ONLY')),
    );
    expect(clientRequests, 0);
  });

  test('expired administrator session is rejected at expiry boundary', () {
    var now = DateTime.utc(2026, 11, 17);
    final sessions = AdminSessionStore(
      now: () => now,
      lifetime: const Duration(minutes: 1),
    );
    final token = sessions.create(7);
    expect(sessions.authenticate('Bearer $token')?.adminId, 7);
    now = now.add(const Duration(minutes: 1));
    expect(sessions.authenticate('Bearer $token'), isNull);
  });
}
