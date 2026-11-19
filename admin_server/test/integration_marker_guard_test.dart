import 'dart:io';
import 'package:admin_server/database/database_service.dart';
import 'package:admin_server/services/integration_database.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// Filesystem-only guard tests. No ADC, HTTP server or production DB access.
void main() {
  late Directory root;
  late Directory outside;
  late File target;
  late String stamp;
  setUp(() {
    root = Directory.systemTemp.createTempSync(
      '${IntegrationDatabase.marker}marker-',
    );
    outside = Directory.systemTemp.createTempSync('hucares-marker-target-');
    target = File(p.join(outside.path, 'sentinel.txt'))
      ..writeAsStringSync('UNCHANGED_SYNTHETIC_SENTINEL');
    stamp = p.join(root.path, '.hucares-test-database');
  });
  tearDown(() {
    expect(target.readAsStringSync(), 'UNCHANGED_SYNTHETIC_SENTINEL');
    expect(p.basename(root.path), startsWith(IntegrationDatabase.marker));
    expect(p.basename(outside.path), startsWith('hucares-marker-target-'));
    root.deleteSync(recursive: true);
    outside.deleteSync(recursive: true);
  });
  void expectRejectedBeforeCreation() {
    expect(() => IntegrationDatabase.validate(root.path), throwsStateError);
    expect(File(p.join(root.path, 'integration.sqlite')).existsSync(), false);
  }

  test('first-start validation with no marker creates no files', () {
    expect(
      IntegrationDatabase.validate(root.path),
      p.join(root.path, 'integration.sqlite'),
    );
    expect(root.listSync(), isEmpty);
  });
  test('wrong regular marker is rejected even before database exists', () {
    File(stamp).writeAsStringSync('not-the-approved-path');
    expectRejectedBeforeCreation();
    expect(File(stamp).readAsStringSync(), 'not-the-approved-path');
  });
  test('directory marker rejected on first start', () {
    Directory(stamp).createSync();
    expectRejectedBeforeCreation();
  });
  test(
    'hard-link marker cannot overwrite or read external target on first start',
    () async {
      final result = Platform.isWindows
          ? Process.runSync('fsutil', [
              'hardlink',
              'create',
              stamp,
              target.path,
            ])
          : Process.runSync('ln', [target.path, stamp]);
      expect(result.exitCode, 0);
      try {
        expectRejectedBeforeCreation();
        await expectLater(
          IntegrationDatabase.initialize(root.path, 'SYNTHETIC-TEST-PASSWORD'),
          throwsStateError,
        );
      } finally {
        File(stamp).deleteSync();
      }
    },
  );
  test(
    'junction/directory link marker rejected before SQLite initialization',
    () async {
      if (Platform.isWindows) {
        expect(
          Process.runSync('cmd', [
            '/c',
            'mklink',
            '/J',
            stamp,
            outside.path,
          ]).exitCode,
          0,
        );
      } else {
        Link(stamp).createSync(outside.path);
      }
      try {
        expectRejectedBeforeCreation();
        await expectLater(
          IntegrationDatabase.initialize(root.path, 'SYNTHETIC-TEST-PASSWORD'),
          throwsStateError,
        );
      } finally {
        Link(stamp).deleteSync();
      }
    },
  );
  for (final dangling in [false, true]) {
    test(
      '${dangling ? 'dangling' : 'existing-target'} file symlink marker rejected on first start',
      () async {
        final destination = dangling
            ? p.join(outside.path, 'does-not-exist')
            : target.path;
        try {
          Link(stamp).createSync(destination);
        } on FileSystemException catch (error) {
          if (Platform.isWindows &&
              [1314, 5].contains(error.osError?.errorCode)) {
            markTestSkipped(
              'Windows file-symlink privilege unavailable; junction and hard-link tests run separately',
            );
            return;
          }
          rethrow;
        }
        try {
          expectRejectedBeforeCreation();
          await expectLater(
            IntegrationDatabase.initialize(
              root.path,
              'SYNTHETIC-TEST-PASSWORD',
            ),
            throwsStateError,
          );
          if (dangling) expect(File(destination).existsSync(), false);
        } finally {
          Link(stamp).deleteSync();
        }
      },
    );
  }
  test('reopen valid isolated DB leaves existing marker unchanged', () async {
    await IntegrationDatabase.initialize(root.path, 'SYNTHETIC-TEST-PASSWORD');
    // This test created the only opened DB; never accesses the running host.
    final file = File(stamp);
    final time = DateTime.utc(2020, 1, 1);
    file.setLastModifiedSync(time);
    final before = file.lastModifiedSync();
    var opened = true;
    try {
      expect(
        IntegrationDatabase.validate(root.path),
        p.join(root.path, 'integration.sqlite'),
      );
      DatabaseService.instance.close();
      opened = false;
      await IntegrationDatabase.initialize(
        root.path,
        'SYNTHETIC-TEST-PASSWORD',
      );
      opened = true;
      expect(file.lastModifiedSync(), before);
    } finally {
      if (opened) DatabaseService.instance.close();
    }
  });
}
