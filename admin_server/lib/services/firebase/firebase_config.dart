class FirebaseConfigurationException implements Exception {
  final String code;
  final String message;
  const FirebaseConfigurationException(this.code, this.message);
  @override
  String toString() => '$code: $message';
}

/// Configuration only: constructing this object never discovers credentials.
class FirebaseConfig {
  final bool enabled;
  final String? projectId;
  final String databaseId;
  final bool readOnly;
  final bool notificationsEnabled;

  const FirebaseConfig._(
    this.enabled,
    this.projectId,
    this.databaseId,
    this.readOnly,
    this.notificationsEnabled,
  );

  factory FirebaseConfig.fromEnvironment(Map<String, String> env) {
    bool flag(String name, bool fallback) {
      final raw = env[name];
      if (raw == null) return fallback;
      if (raw == 'true') return true;
      if (raw == 'false') return false;
      throw FirebaseConfigurationException(
        'INVALID_FIREBASE_FLAG',
        '$name must be true or false',
      );
    }

    final enabled = flag('FIREBASE_ENABLED', false);
    final readOnly = flag('FIREBASE_READ_ONLY', true);
    final notifications = flag('NOTIFICATIONS_ENABLED', false);
    final project = env['FIREBASE_PROJECT_ID']?.trim();
    final database = env['FIREBASE_DATABASE_ID']?.trim() ?? '(default)';
    if (notifications && !enabled) {
      throw const FirebaseConfigurationException(
        'FIREBASE_DISABLED',
        'Notifications require explicitly enabled Firebase',
      );
    }
    if (enabled) {
      if (project == null || project.isEmpty) {
        throw const FirebaseConfigurationException(
          'FIREBASE_PROJECT_REQUIRED',
          'FIREBASE_PROJECT_ID must be explicitly specified',
        );
      }
      if (!RegExp(r'^[a-z][a-z0-9-]{4,28}[a-z0-9]$').hasMatch(project)) {
        throw const FirebaseConfigurationException(
          'INVALID_FIREBASE_PROJECT',
          'FIREBASE_PROJECT_ID must be a project ID, not a URL or project number',
        );
      }
      if (database != '(default)' &&
          !RegExp(r'^[a-z][a-z0-9-]{2,61}[a-z0-9]$').hasMatch(database)) {
        throw const FirebaseConfigurationException(
          'INVALID_FIREBASE_DATABASE',
          'FIREBASE_DATABASE_ID must be (default) or a valid named database ID',
        );
      }
      if (env.containsKey('NOTIFICATION_FIREBASE_PROJECT') &&
          env['NOTIFICATION_FIREBASE_PROJECT']?.trim() != project) {
        throw const FirebaseConfigurationException(
          'FIREBASE_PROJECT_MISMATCH',
          'Legacy notification project must match FIREBASE_PROJECT_ID',
        );
      }
    }
    if (notifications && readOnly) {
      throw const FirebaseConfigurationException(
        'FIREBASE_READ_ONLY',
        'Read-only mode prohibits enabling notification writes',
      );
    }
    return FirebaseConfig._(
      enabled,
      project,
      database,
      readOnly,
      notifications,
    );
  }

  void requireReadonlyProbe() {
    if (!enabled) {
      throw const FirebaseConfigurationException(
        'FIREBASE_DISABLED',
        'Firebase is disabled; no credentials or connections were requested',
      );
    }
    if (!readOnly || notificationsEnabled) {
      throw const FirebaseConfigurationException(
        'READONLY_PROBE_REQUIRED',
        'Probe requires FIREBASE_READ_ONLY=true and NOTIFICATIONS_ENABLED=false',
      );
    }
  }
}
