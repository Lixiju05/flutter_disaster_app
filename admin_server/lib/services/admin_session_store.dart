import 'dart:math';

/// Process-local sessions. Restarting the server invalidates all tokens.
class AdminSession {
  final int adminId;
  final DateTime expiresAt;

  const AdminSession(this.adminId, this.expiresAt);
}

class AdminSessionStore {
  final Duration lifetime;
  final DateTime Function() _now;
  final Map<String, AdminSession> _sessions = {};

  AdminSessionStore({
    this.lifetime = const Duration(hours: 8),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  static String generateToken() {
    final random = Random.secure();
    return List.generate(
      32,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }

  String create(int adminId) {
    final now = _now().toUtc();
    _sessions.removeWhere((_, session) => !now.isBefore(session.expiresAt));
    final token = generateToken();
    _sessions[token] = AdminSession(adminId, now.add(lifetime));
    return token;
  }

  AdminSession? authenticate(String? authorization) {
    if (authorization == null) return null;
    final match = RegExp(r'^Bearer ([0-9a-f]{64})$', caseSensitive: false)
        .firstMatch(authorization);
    if (match == null) return null;
    final token = match.group(1)!;
    final session = _sessions[token];
    if (session == null) return null;
    if (!_now().toUtc().isBefore(session.expiresAt)) {
      _sessions.remove(token);
      return null;
    }
    return session;
  }
}
