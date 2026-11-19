import 'dart:io';
import 'package:path/path.dart' as p;
import '../database/database_service.dart';

/// Only a direct, named temp child is accepted. Never follow links/junctions.
/// Local test host only: the parent directory must be controlled by this user.
class IntegrationDatabase {
  static const marker = 'hucares-integration-8085-';
  static String validate(String root, {String? tempRoot}) {
    final db = _validatePaths(root, tempRoot: tempRoot);
    // Never read marker contents until its type, canonical path and hard-link
    // count have been checked, even when the database does not yet exist.
    final stamp = File(p.join(root, '.hucares-test-database'));
    if ((stamp.existsSync() && stamp.readAsStringSync() != db) ||
        (File(db).existsSync() && !stamp.existsSync())) {
      throw StateError('INTEGRATION_DB_UNOWNED');
    }
    return db;
  }

  static String _validatePaths(String root, {String? tempRoot}) {
    final temp = p.normalize(p.absolute(tempRoot ?? Directory.systemTemp.path));
    if (!p.isAbsolute(root) ||
        root != p.normalize(root) ||
        !p.equals(p.dirname(root), temp) ||
        !RegExp(
          r'^hucares-integration-8085-[a-zA-Z0-9_-]+$',
        ).hasMatch(p.basename(root))) {
      throw StateError('INTEGRATION_DB_PATH_REJECTED');
    }
    // Inspect every ancestor, including the temp directory, without following links.
    var current = root;
    while (true) {
      final type = FileSystemEntity.typeSync(current, followLinks: false);
      if (type == FileSystemEntityType.link ||
          (type != FileSystemEntityType.notFound &&
              type != FileSystemEntityType.directory)) {
        throw StateError('INTEGRATION_DB_LINK_REJECTED');
      }
      if (type == FileSystemEntityType.directory &&
          !p.equals(
            Directory(current).resolveSymbolicLinksSync(),
            p.normalize(current),
          )) {
        throw StateError('INTEGRATION_DB_ALIAS_REJECTED');
      }
      final parent = p.dirname(current);
      if (parent == current) break;
      current = parent;
    }
    final db = p.join(root, 'integration.sqlite');
    for (final name in [
      db,
      '$db-wal',
      '$db-shm',
      '$db-journal',
      p.join(root, '.hucares-test-database'),
    ]) {
      final type = FileSystemEntity.typeSync(name, followLinks: false);
      if (type != FileSystemEntityType.notFound &&
          type != FileSystemEntityType.file) {
        throw StateError('INTEGRATION_DB_LINK_REJECTED');
      }
      if (type == FileSystemEntityType.file) {
        if (!p.equals(File(name).resolveSymbolicLinksSync(), name)) {
          throw StateError('INTEGRATION_DB_ALIAS_REJECTED');
        }
        final result = Platform.isWindows
            ? Process.runSync('fsutil', ['hardlink', 'list', name])
            : Process.runSync('stat', ['-c', '%h', name]);
        final output = result.stdout.toString().trim();
        final single = Platform.isWindows
            ? output
                      .split(RegExp(r'[\r\n]+'))
                      .where((s) => s.trim().isNotEmpty)
                      .length ==
                  1
            : output == '1';
        if (result.exitCode != 0 || !single) {
          throw StateError('INTEGRATION_DB_HARDLINK_CHECK_FAILED');
        }
      }
    }
    return db;
  }

  static Future<String> initialize(String root, String password) async {
    if (password.length < 16) throw StateError('INTEGRATION_PASSWORD_REQUIRED');
    final path = validate(root);
    Directory(root).createSync();
    validate(root);
    // No production seeds, passwords or personal data are copied.
    await DatabaseService.init(
      databasePath: path,
      seedDemo: false,
      createDefaultAdmin: false,
    );
    final db = DatabaseService.instance;
    final columns = await db.select('PRAGMA table_info(admins)');
    if (!columns.any((row) => row['name'] == 'zoneId')) {
      await db.execute('ALTER TABLE admins ADD COLUMN zoneId TEXT');
    }
    await db.execute(
      "INSERT INTO admins(id,username,password,zoneId) VALUES(1,'integration_test',?,'OFFICE001') ON CONFLICT(id) DO UPDATE SET password=excluded.password",
      [password],
    );
    await db.execute(
      "INSERT OR IGNORE INTO stations VALUES('OFFICE001','Synthetic community center','office',0,0,NULL)",
    );
    await db.execute(
      "INSERT OR IGNORE INTO users(id,name,area,registeredAt) VALUES('INTEGRATION_USER','SYNTHETIC TEST USER','TEST AREA','2026-01-01T00:00:00Z')",
    );
    await db.execute(
      "INSERT OR IGNORE INTO inventory(id,name,category,unit) VALUES(1,'Synthetic item','test','unit')",
    );
    await db.execute(
      "INSERT OR IGNORE INTO station_inventory VALUES('OFFICE001',1,20,0,'2026-01-01T00:00:00Z')",
    );
    // Check again before marker IO; do not rewrite an existing valid marker.
    // The isolated directory must remain controlled by this user throughout.
    _validatePaths(root);
    final stamp = File(p.join(root, '.hucares-test-database'));
    if (stamp.existsSync()) {
      if (stamp.readAsStringSync() != path) {
        throw StateError('INTEGRATION_DB_UNOWNED');
      }
    } else {
      stamp.writeAsStringSync(path, flush: true);
    }
    return path;
  }
}
