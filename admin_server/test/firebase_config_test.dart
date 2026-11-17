import 'package:admin_server/services/firebase/firebase_config.dart';
import 'package:admin_server/services/notifications/notification_bootstrap.dart';
import 'package:admin_server/services/notifications/notification_store.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

// Every cloud client in this suite is an explicit Mock. No live verification.
void main() {
  const readConfig = {
    'FIREBASE_ENABLED': 'true',
    'FIREBASE_PROJECT_ID': 'hucares-firebase-test',
  };
  Matcher configError(String code) => isA<FirebaseConfigurationException>()
      .having((error) => error.code, 'code', code);

  test('defaults are disabled/read-only, with no inferred project', () {
    final config = FirebaseConfig.fromEnvironment({});
    expect(config.enabled, false);
    expect(config.projectId, isNull);
    expect(config.databaseId, '(default)');
    expect(config.readOnly, true);
    expect(config.notificationsEnabled, false);
  });
  test('enabled Firebase requires explicit project', () {
    expect(
      () => FirebaseConfig.fromEnvironment({'FIREBASE_ENABLED': 'true'}),
      throwsA(configError('FIREBASE_PROJECT_REQUIRED')),
    );
  });
  test(
    'project is configurable without either production project as a default',
    () {
      for (final project in [
        'bitchat-android-disaster-app',
        'hucares-staging-test',
      ]) {
        expect(
          FirebaseConfig.fromEnvironment({
            ...readConfig,
            'FIREBASE_PROJECT_ID': project,
          }).projectId,
          project,
        );
      }
    },
  );
  test('legacy project must match shared project', () {
    expect(
      () => FirebaseConfig.fromEnvironment({
        ...readConfig,
        'NOTIFICATION_FIREBASE_PROJECT': 'different-project',
      }),
      throwsA(configError('FIREBASE_PROJECT_MISMATCH')),
    );
    expect(
      FirebaseConfig.fromEnvironment({
        ...readConfig,
        'NOTIFICATION_FIREBASE_PROJECT': readConfig['FIREBASE_PROJECT_ID']!,
      }).enabled,
      true,
    );
  });
  test('read-only mode cannot enable notification writes', () {
    expect(
      () => FirebaseConfig.fromEnvironment({
        ...readConfig,
        'NOTIFICATIONS_ENABLED': 'true',
      }),
      throwsA(configError('FIREBASE_READ_ONLY')),
    );
  });
  test('disabled Firebase cannot enable notification writes', () {
    expect(
      () => FirebaseConfig.fromEnvironment({'NOTIFICATIONS_ENABLED': 'true'}),
      throwsA(configError('FIREBASE_DISABLED')),
    );
  });
  test('invalid flags/IDs fail closed without echoing values', () {
    for (final key in [
      'FIREBASE_ENABLED',
      'FIREBASE_READ_ONLY',
      'NOTIFICATIONS_ENABLED',
    ]) {
      expect(
        () => FirebaseConfig.fromEnvironment({
          ...readConfig,
          key: 'private-value',
        }),
        throwsA(configError('INVALID_FIREBASE_FLAG')),
      );
    }
    expect(
      () => FirebaseConfig.fromEnvironment({
        ...readConfig,
        'FIREBASE_PROJECT_ID': 'https://private.example/users/secret',
      }),
      throwsA(configError('INVALID_FIREBASE_PROJECT')),
    );
    expect(
      () => FirebaseConfig.fromEnvironment({
        ...readConfig,
        'FIREBASE_DATABASE_ID': '../private',
      }),
      throwsA(configError('INVALID_FIREBASE_DATABASE')),
    );
  });
  test(
    'named database supported; probe rejects a write-enabled configuration',
    () {
      expect(
        FirebaseConfig.fromEnvironment({
          ...readConfig,
          'FIREBASE_DATABASE_ID': 'test-db',
        }).databaseId,
        'test-db',
      );
      expect(
        () => FirebaseConfig.fromEnvironment({
          ...readConfig,
          'FIREBASE_READ_ONLY': 'false',
        }).requireReadonlyProbe(),
        throwsA(configError('READONLY_PROBE_REQUIRED')),
      );
    },
  );

  test(
    'disabled/read-only notifications never acquire ADC or establish transport',
    () async {
      var adcCalls = 0, httpCalls = 0;
      Future<http.Client> factory() async {
        adcCalls++;
        return MockClient((_) async {
          httpCalls++;
          return http.Response('{}', 200);
        });
      }

      for (final env in [<String, String>{}, readConfig]) {
        expect(
          await createNotificationServiceFromEnvironment(
            environment: env,
            authenticatedClientFactory: factory,
          ),
          isNull,
        );
      }
      for (final env in [
        {'FIREBASE_ENABLED': 'true', 'NOTIFICATIONS_ENABLED': 'true'},
        {...readConfig, 'NOTIFICATIONS_ENABLED': 'true'},
        {...readConfig, 'NOTIFICATION_FIREBASE_PROJECT': 'different-project'},
      ]) {
        await expectLater(
          createNotificationServiceFromEnvironment(
            environment: env,
            authenticatedClientFactory: factory,
          ),
          throwsA(isA<NotificationException>()),
        );
      }
      expect(adcCalls, 0);
      expect(httpCalls, 0);
    },
  );
  test('notification scope/admin failures occur before ADC', () async {
    var calls = 0;
    final env = {
      ...readConfig,
      'FIREBASE_READ_ONLY': 'false',
      'NOTIFICATIONS_ENABLED': 'true',
    };
    for (final invalid in [
      env,
      {...env, 'NOTIFICATION_SCOPE': 'project'},
      {
        ...env,
        'NOTIFICATION_SCOPE': 'project',
        'NOTIFICATION_ADMIN_IDS': 'invalid',
      },
    ]) {
      await expectLater(
        createNotificationServiceFromEnvironment(
          environment: invalid,
          authenticatedClientFactory: () async {
            calls++;
            return MockClient((_) async => http.Response('{}', 200));
          },
        ),
        throwsA(isA<NotificationException>()),
      );
    }
    expect(calls, 0);
  });
  test(
    'Mock-only notification bootstrap preserves policies and configured target',
    () async {
      final client = MockClient((_) async => http.Response('{}', 200));
      final service = await createNotificationServiceFromEnvironment(
        environment: {
          ...readConfig,
          'FIREBASE_READ_ONLY': 'false',
          'NOTIFICATIONS_ENABLED': 'true',
          'FIREBASE_DATABASE_ID': 'test-db',
          'NOTIFICATION_SCOPE': 'project',
          'NOTIFICATION_ADMIN_IDS': '7,8',
          'NOTIFICATION_BROADCAST_ADMIN_IDS': '7',
        },
        authenticatedClientFactory: () async => client,
      );
      expect(service!.policy.projectId, readConfig['FIREBASE_PROJECT_ID']);
      expect(service.policy.adminIds, {7, 8});
      expect(service.policy.broadcastAdminIds, {7});
      expect(
        (service.store as FirestoreNotificationStore).databaseId,
        'test-db',
      );
      client.close();
    },
  );
  test('read-only adapter blocks transactions before transport', () async {
    var calls = 0;
    final client = MockClient((_) async {
      calls++;
      return http.Response('{}', 200);
    });
    final store = FirestoreNotificationStore(
      'hucares-firebase-test',
      client,
      readOnly: true,
    );
    await expectLater(
      store.transaction((_) async => 'must not run'),
      throwsA(
        isA<NotificationException>().having(
          (e) => e.code,
          'code',
          'FIREBASE_READ_ONLY',
        ),
      ),
    );
    expect(calls, 0);
    client.close();
  });
}
