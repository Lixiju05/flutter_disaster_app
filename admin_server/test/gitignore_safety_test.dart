import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// Query ignore rules for fictional paths; never create credentials or DB files.
void main() {
  final repo = p.dirname(Directory.current.path);
  void check(List<String> paths, {required bool ignored}) {
    final result = Process.runSync('git', [
      '-C',
      repo,
      '-c',
      'core.excludesFile=${Platform.isWindows ? 'NUL' : '/dev/null'}',
      'check-ignore',
      '--no-index',
      '--',
      ...paths,
    ]);
    expect(result.exitCode, ignored ? 0 : 1);
    final matched = result.stdout
        .toString()
        .split(RegExp(r'[\r\n]+'))
        .where((s) => s.isNotEmpty)
        .toSet();
    expect(matched, ignored ? unorderedEquals(paths) : isEmpty);
  }

  test('local databases, sidecars and backup formats are ignored', () {
    check([
      'admin_server/data/admin.db',
      'admin_server/data/admin.db-wal',
      'admin_server/data/admin.db.backup',
      'admin_server/data/admin.db.backup.zip',
      'admin_server/data/admin.sqlite',
      'admin_server/data/admin.sqlite-shm',
      'admin_server/data/admin.sqlite3',
      'admin_server/data/admin.sqlite3-journal',
      'admin_server/data/backup.zip',
      'admin_server/data/backup.7z',
      'local/history.bak',
      'local/history.backup',
      'local/.hucares-test-database',
    ], ignored: true);
  });
  test('local keys, ADC and service account credentials are ignored', () {
    check([
      'application_default_credentials.json',
      'local/application_default_credentials.json',
      'service-account.json',
      'local/service_account_reader.json',
      'local/serviceAccount.json',
      'local/project-firebase-adminsdk-test.json',
      'local/credentials.json',
      'local/adc-reader.json',
      'local/server.key',
      'local/server.pem',
      'local/server.pfx',
      'local/server.p12',
      'local/android.keystore',
      'local/android.jks',
      'local/session.token',
      '.env',
      '.env.local',
      'admin_server/.env',
      'admin_server/.env.test',
    ], ignored: true);
  });
  test(
    'reviewed examples, source and public Firebase config stay includable',
    () {
      check([
        'admin_server/data/admin.db.example',
        'local/test.sqlite.example',
        '.env.example',
        'admin_server/.env.example',
        'local/server.key.example',
        'local/service-account.json.example',
        'lib/firebase_options.dart',
        'android/app/google-services.json',
        'admin_server/lib/services/integration_database.dart',
      ], ignored: false);
    },
  );
}
