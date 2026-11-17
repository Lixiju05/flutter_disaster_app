import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:sqlite3/sqlite3.dart';

class ReverseGeocodingException implements Exception {
  final int statusCode;
  final String code;
  final String message;
  final int? retryAfterSeconds;
  const ReverseGeocodingException(
    this.statusCode,
    this.code,
    this.message, [
    this.retryAfterSeconds,
  ]);
}

/// Public-landmark fixtures only. No resident coordinates can be authorized
/// by a caller. The labels are NOT used as lookup results.
const reverseGeocodingDemoSites = <String, (double, double)>{
  'taipei101': (25.033964, 121.564468),
  'taipei_main_station': (25.0478, 121.5170),
};

/// Dedicated state DB; never the application's admin.db. Persisted quota,
/// pacing protect against restarts sharing this file. Addresses stay in memory.
class ReverseGeocodingService {
  final http.Client client;
  final Database state;
  final Set<String> sites;
  final String userAgent;
  final Uri endpoint;
  final int dailyLimit;
  final Duration timeout;
  final Duration cacheTtl;
  final Duration failureCooldown;
  final DateTime Function() now;
  final Map<String, Future<Map<String, Object?>>> _pending = {};
  final Map<String, (String?, int, ReverseGeocodingException?)> _cacheEntries =
      {};

  ReverseGeocodingService({
    required this.client,
    required this.state,
    required Set<String> sites,
    required this.userAgent,
    Uri? endpoint,
    this.dailyLimit = 20,
    this.timeout = const Duration(seconds: 6),
    this.cacheTtl = const Duration(hours: 24),
    this.failureCooldown = const Duration(seconds: 30),
    DateTime Function()? now,
  }) : sites = Set.unmodifiable(sites),
       endpoint =
           endpoint ?? Uri.https('nominatim.openstreetmap.org', '/reverse'),
       now = now ?? DateTime.now {
    if (sites.isEmpty ||
        sites.any((s) => !reverseGeocodingDemoSites.containsKey(s)) ||
        dailyLimit < 1 ||
        dailyLimit > 100 ||
        !userAgent.startsWith('HuCARES-Demo/') ||
        !(userAgent.contains('https://') || userAgent.contains('@')) ||
        userAgent.contains('\n') ||
        userAgent.contains('\r') ||
        this.endpoint.scheme != 'https' ||
        this.endpoint.userInfo.isNotEmpty ||
        this.endpoint.hasQuery ||
        this.endpoint.hasFragment ||
        timeout <= Duration.zero) {
      throw ArgumentError('Invalid explicit DEMO configuration');
    }
    state.execute('PRAGMA busy_timeout=1000');
    state.execute(
      '''CREATE TABLE IF NOT EXISTS control (
      id INTEGER PRIMARY KEY CHECK(id=1), day TEXT NOT NULL,
      used INTEGER NOT NULL, nextAt INTEGER NOT NULL, cooldownAt INTEGER NOT NULL)''',
    );
    state.execute("INSERT OR IGNORE INTO control VALUES (1,'',0,0,0)");
  }

  static (double, double) validate(Object? latitude, Object? longitude) {
    // POST contract is numeric; strings/booleans/null are rejected.
    if (latitude is! num || longitude is! num) {
      throw const ReverseGeocodingException(400, 'INVALID_GPS', '需要有效的數值座標');
    }
    final lat = latitude.toDouble(), lng = longitude.toDouble();
    if (!lat.isFinite ||
        !lng.isFinite ||
        lat.abs() > 90 ||
        lng.abs() > 180 ||
        (lat == 0 && lng == 0)) {
      throw const ReverseGeocodingException(400, 'INVALID_GPS', '座標無效或未知');
    }
    return (lat, lng);
  }

  Future<Map<String, Object?>> reverse(Object? latitude, Object? longitude) {
    final (lat, lng) = validate(latitude, longitude);
    if (!sites.any((s) => reverseGeocodingDemoSites[s] == (lat, lng))) {
      throw const ReverseGeocodingException(
        403,
        'DEMO_COORDINATES_ONLY',
        '只允許已啟用的公開地標測試座標，不得查詢真實居民位置',
      );
    }
    final key = '$lat,$lng'; // No rounding, including in the external request.
    final stamp = now().toUtc().millisecondsSinceEpoch;
    final cached = _cacheEntries[key];
    if (cached != null && cached.$2 > stamp) {
      final error = cached.$3;
      if (error != null) {
        throw ReverseGeocodingException(
          error.statusCode,
          error.code,
          error.message,
          (cached.$2 - stamp + 999) ~/ 1000,
        );
      }
      return Future.value(_result(lat, lng, cached.$1!, true));
    }
    final pending = _pending[key];
    if (pending != null) return pending;
    // _lookup reserves pacing/quota synchronously before its first await.
    final future = _lookup(key, lat, lng);
    _pending[key] = future;
    return future.whenComplete(() => _pending.remove(key));
  }

  Map<String, Object?> _result(
    double lat,
    double lng,
    String address,
    bool cached,
  ) => {
    'latitude': lat,
    'longitude': lng,
    'address': address,
    'source': 'OpenStreetMap Nominatim',
    'status': 'resolved',
    'cached': cached,
    'attribution': '© OpenStreetMap contributors (ODbL)',
    'attributionUrl': 'https://www.openstreetmap.org/copyright',
    'notice': '地址僅供參考',
    'demo': true,
  };

  void _reserveAttempt() {
    final current = now().toUtc();
    final stamp = current.millisecondsSinceEpoch;
    final day = current.toIso8601String().substring(0, 10);
    state.execute('BEGIN IMMEDIATE');
    try {
      final row = state.select('SELECT * FROM control WHERE id=1').single;
      final until = (row['nextAt'] as int) > (row['cooldownAt'] as int)
          ? row['nextAt'] as int
          : row['cooldownAt'] as int;
      if (stamp < until) {
        throw ReverseGeocodingException(
          429,
          'RATE_LIMITED',
          '查詢過於頻繁或服務冷卻中，請稍後重試',
          (until - stamp + 999) ~/ 1000,
        );
      }
      final used = row['day'] == day ? row['used'] as int : 0;
      if (used >= dailyLimit) {
        throw const ReverseGeocodingException(
          429,
          'DAILY_QUOTA_EXCEEDED',
          '已達今日 DEMO 查詢額度',
        );
      }
      state.execute('UPDATE control SET day=?,used=?,nextAt=? WHERE id=1', [
        day,
        used + 1,
        stamp + 1000,
      ]);
      state.execute('COMMIT');
    } catch (_) {
      state.execute('ROLLBACK');
      rethrow;
    }
  }

  Future<Map<String, Object?>> _lookup(
    String key,
    double lat,
    double lng,
  ) async {
    _reserveAttempt();
    try {
      final uri = endpoint.replace(
        queryParameters: {
          'format': 'jsonv2',
          'lat': '$lat',
          'lon': '$lng',
          'accept-language': 'zh-TW',
          'addressdetails': '0',
        },
      );
      // No identity, authorization token, report ID, free text or description.
      final request = http.Request('GET', uri)..followRedirects = false;
      request.headers.addAll({
        'User-Agent': userAgent,
        'Accept': 'application/json',
      });
      final response = await client
          .send(request)
          .then(http.Response.fromStream)
          .timeout(timeout);
      if (response.statusCode != 200) {
        throw ReverseGeocodingException(
          502,
          response.statusCode == 429
              ? 'UPSTREAM_RATE_LIMITED'
              : 'UPSTREAM_ERROR',
          '地址服務暫時無法使用',
        );
      }
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      final address = data is Map ? data['display_name'] : null;
      if (address is! String ||
          address.trim().isEmpty ||
          address.length > 4096) {
        throw const ReverseGeocodingException(
          502,
          'ADDRESS_NOT_FOUND',
          '附近地址無法取得',
        );
      }
      _cache(key, address.trim(), cacheTtl, null);
      return _result(lat, lng, address.trim(), false);
    } on TimeoutException {
      const error = ReverseGeocodingException(
        504,
        'GEOCODING_TIMEOUT',
        '地址查詢逾時',
      );
      _failed(key, error);
      throw error;
    } on ReverseGeocodingException catch (error) {
      _failed(key, error);
      rethrow;
    } catch (_) {
      const error = ReverseGeocodingException(
        503,
        'GEOCODING_UNAVAILABLE',
        '無法連線或地址服務回應無效',
      );
      _failed(key, error);
      throw error;
    }
  }

  void _failed(String key, ReverseGeocodingException error) {
    _cache(key, null, failureCooldown, error);
    final until = now().toUtc().add(failureCooldown).millisecondsSinceEpoch;
    // Across all administrators and all keys, even after restarting.
    state.execute(
      'UPDATE control SET cooldownAt=MAX(cooldownAt,?) WHERE id=1',
      [until],
    );
  }

  void _cache(
    String key,
    String? address,
    Duration ttl,
    ReverseGeocodingException? error,
  ) {
    final stamp = now().toUtc().millisecondsSinceEpoch;
    _cacheEntries.removeWhere((_, entry) => entry.$2 <= stamp);
    _cacheEntries[key] = (address, stamp + ttl.inMilliseconds, error);
    while (_cacheEntries.length > 256) {
      _cacheEntries.remove(_cacheEntries.keys.first);
    }
  }
}

ReverseGeocodingService? createReverseGeocodingService([
  Map<String, String>? environment,
]) {
  final env = environment ?? Platform.environment;
  if (env['REVERSE_GEOCODING_DEMO'] != 'true') return null;
  final sites = (env['REVERSE_GEOCODING_DEMO_SITES'] ?? '')
      .split(',')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toSet();
  final agent = env['REVERSE_GEOCODING_USER_AGENT'] ?? '';
  // Fixed, dedicated temp state. No application database or Migration.
  final dir = Directory('${Directory.systemTemp.path}/hucares_geocoding_demo');
  dir.createSync(recursive: true);
  final state = sqlite3.open('${dir.path}/state.sqlite');
  final client = http.Client();
  try {
    return ReverseGeocodingService(
      client: client,
      state: state,
      sites: sites,
      userAgent: agent,
      dailyLimit:
          int.tryParse(env['REVERSE_GEOCODING_DAILY_LIMIT'] ?? '20') ?? 0,
      endpoint: env['REVERSE_GEOCODING_ENDPOINT'] == null
          ? null
          : Uri.parse(env['REVERSE_GEOCODING_ENDPOINT']!),
    );
  } catch (_) {
    client.close();
    state.dispose();
    rethrow;
  }
}
