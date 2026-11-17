import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:admin_server/database/database_service.dart';
import 'package:admin_server/services/reverse_geocoding_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';
import '../bin/admin_server.dart' as api;

void main() {
  late Database state;
  late ReverseGeocodingService service;
  late DateTime clock;
  late int calls;
  late Future<http.Response> Function(http.Request) upstream;
  final (lat, lng) = reverseGeocodingDemoSites['taipei101']!;
  setUp(() {
    state = sqlite3.openInMemory();
    clock = DateTime.utc(2026, 11, 11);
    calls = 0;
    upstream = (request) async {
      expect(request.url.host, 'nominatim.openstreetmap.org');
      expect(request.url.queryParameters.keys.toSet(), {
        'format',
        'lat',
        'lon',
        'accept-language',
        'addressdetails',
      });
      expect(request.headers['User-Agent'], contains('HuCARES-Demo/'));
      expect(request.headers.containsKey('Authorization'), false);
      expect(request.followRedirects, false);
      return http.Response(
        jsonEncode({'display_name': 'MOCK ADDRESS — NOT A LIVE RESULT'}),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    };
    service = ReverseGeocodingService(
      client: MockClient((req) {
        calls++;
        return upstream(req);
      }),
      state: state,
      sites: reverseGeocodingDemoSites.keys.toSet(),
      userAgent: 'HuCARES-Demo/1.0 (https://example.test/contact)',
      now: () => clock,
      timeout: const Duration(milliseconds: 30),
      dailyLimit: 2,
    );
  });
  tearDown(() => state.dispose());
  Matcher code(String value) =>
      isA<ReverseGeocodingException>().having((e) => e.code, 'code', value);

  test(
    'normal public test coordinates, original precision, safe outbound fields and cache',
    () async {
      final first = await service.reverse(lat, lng);
      expect(first['status'], 'resolved');
      expect(first['latitude'], lat);
      expect(first['longitude'], lng);
      expect(first['source'], 'OpenStreetMap Nominatim');
      expect(first['cached'], false);
      expect((await service.reverse(lat, lng))['cached'], true);
      expect(calls, 1);
    },
  );
  test(
    'rejects null, zero pair, wrong type, nonfinite and out-of-range before network',
    () {
      for (final point in [
        (null, null),
        (0, 0),
        (91, 120),
        (24, 181),
        (double.nan, 120),
        (24, double.infinity),
        ('25', 121),
        (true, 121),
      ]) {
        expect(
          () => service.reverse(point.$1, point.$2),
          throwsA(code('INVALID_GPS')),
        );
      }
      expect(calls, 0);
    },
  );
  test(
    'rejects all non-allowlisted resident coordinates, without rounding into allowlist',
    () {
      expect(
        () => service.reverse(24, 121),
        throwsA(code('DEMO_COORDINATES_ONLY')),
      );
      expect(
        () => service.reverse(lat + 0.000000001, lng),
        throwsA(code('DEMO_COORDINATES_ONLY')),
      );
      expect(calls, 0);
    },
  );
  test(
    'same-coordinate concurrent requests share exactly one outgoing request',
    () async {
      final result = Completer<http.Response>();
      upstream = (_) => result.future;
      final first = service.reverse(lat, lng);
      final second = service.reverse(lat, lng);
      result.complete(http.Response('{"display_name":"MOCK ONLY"}', 200));
      expect((await first)['address'], (await second)['address']);
      expect(calls, 1);
    },
  );
  test(
    'global one-second pacing rejects other coordinates before quota/network',
    () async {
      await service.reverse(lat, lng);
      final other = reverseGeocodingDemoSites['taipei_main_station']!;
      await expectLater(
        Future.sync(() => service.reverse(other.$1, other.$2)),
        throwsA(code('RATE_LIMITED')),
      );
      clock = clock.add(const Duration(seconds: 1));
      await service.reverse(other.$1, other.$2);
      expect(calls, 2);
    },
  );
  test(
    'daily quota persists across service restart, UTC day resets and cache expires',
    () async {
      await service.reverse(lat, lng);
      clock = clock.add(const Duration(seconds: 1));
      final other = reverseGeocodingDemoSites['taipei_main_station']!;
      await service.reverse(other.$1, other.$2);
      final restarted = ReverseGeocodingService(
        client: service.client,
        state: state,
        sites: service.sites,
        userAgent: service.userAgent,
        dailyLimit: 2,
        now: () => clock,
      );
      clock = clock.add(const Duration(seconds: 1));
      await expectLater(
        Future.sync(() => restarted.reverse(lat, lng)),
        throwsA(code('DAILY_QUOTA_EXCEEDED')),
      );
      clock = clock.add(const Duration(days: 1));
      await restarted.reverse(lat, lng);
      clock = clock.add(const Duration(days: 1));
      expect((await restarted.reverse(lat, lng))['cached'], false);
      expect(calls, 4);
    },
  );
  for (final errorCase in [
    'network',
    'timeout',
    '500',
    '429',
    'malformed',
    'empty',
    'redirect',
  ]) {
    test(
      '$errorCase returns honest failure, cooldown and consumes a single attempt',
      () async {
        upstream = (_) async {
          if (errorCase == 'network') throw const SocketException('offline');
          if (errorCase == 'timeout') return Completer<http.Response>().future;
          if (errorCase == 'malformed') {
            return http.Response('broken JSON', 200);
          }
          if (errorCase == 'empty') return http.Response('{}', 200);
          if (errorCase == 'redirect') {
            return http.Response(
              '',
              302,
              headers: {'location': 'https://unapproved.test'},
            );
          }
          return http.Response('private upstream text', int.parse(errorCase));
        };
        await expectLater(
          service.reverse(lat, lng),
          throwsA(isA<ReverseGeocodingException>()),
        );
        expect(
          () => service.reverse(lat, lng),
          throwsA(isA<ReverseGeocodingException>()),
        );
        final other = reverseGeocodingDemoSites['taipei_main_station']!;
        await expectLater(
          Future.sync(() => service.reverse(other.$1, other.$2)),
          throwsA(code('RATE_LIMITED')),
        );
        expect(calls, 1);
        expect(state.select('SELECT used FROM control').single['used'], 1);
        expect(
          state
              .select("SELECT name FROM sqlite_master WHERE type='table'")
              .map((row) => row['name']),
          ['control'],
        );
        clock = clock.add(const Duration(seconds: 31));
        upstream = (_) async =>
            http.Response('{"display_name":"MOCK RECOVERY"}', 200);
        expect((await service.reverse(lat, lng))['status'], 'resolved');
        expect(calls, 2);
      },
    );
  }
  test(
    'disabled bootstrap never initializes provider and invalid config fails closed',
    () {
      expect(createReverseGeocodingService({}), isNull);
      expect(
        createReverseGeocodingService({'REVERSE_GEOCODING_DEMO': 'false'}),
        isNull,
      );
      expect(
        () => ReverseGeocodingService(
          client: service.client,
          state: state,
          sites: {'resident'},
          userAgent: service.userAgent,
        ),
        throwsArgumentError,
      );
    },
  );

  group('actual local HTTP API with isolated SQLite', () {
    late Database records;
    late HttpServer server;
    late HttpClient client;
    late StreamSubscription<HttpRequest> listener;
    setUp(() async {
      records = sqlite3.openInMemory();
      records.execute('CREATE TABLE admins (id INTEGER PRIMARY KEY)');
      records.execute('INSERT INTO admins VALUES (7)');
      DatabaseService.instance = DatabaseService(records);
      api.reverseGeocodingService = service;
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      listener = server.listen(api.handleRequest);
      client = HttpClient();
    });
    tearDown(() async {
      client.close(force: true);
      await listener.cancel();
      await server.close(force: true);
      api.reverseGeocodingService = null;
      records.dispose();
    });
    Future<(int, Map)> post([
      String? token,
      Map<String, Object?>? fields,
    ]) async {
      final req = await client.postUrl(
        Uri.parse('http://127.0.0.1:${server.port}'),
      );
      req.headers.contentType = ContentType.json;
      if (token != null) req.headers.set('Authorization', 'Bearer $token');
      req.write(
        jsonEncode({
          'type': 'reverseGeocode',
          'latitude': lat,
          'longitude': lng,
          'userId': 'MUST_NOT_FORWARD',
          'phone': 'MUST_NOT_FORWARD',
          ...?fields,
        }),
      );
      final response = await req.close();
      return (
        response.statusCode,
        jsonDecode(await utf8.decoder.bind(response).join()) as Map,
      );
    }

    test(
      'missing/invalid Token and deleted admin are rejected without provider calls',
      () async {
        expect((await post()).$1, 401);
        expect((await post('invalid')).$1, 401);
        final token = api.adminSessions.create(7);
        records.execute('DELETE FROM admins');
        expect((await post(token)).$1, 403);
        expect(calls, 0);
      },
    );
    test(
      'disabled returns 503; enabled returns real service contract and never writes report DB',
      () async {
        final token = api.adminSessions.create(7);
        api.reverseGeocodingService = null;
        expect((await post(token)).$1, 503);
        api.reverseGeocodingService = service;
        final result = await post(token);
        expect(result.$1, 200);
        expect(result.$2['data']['status'], 'resolved');
        expect((await post(token, {'latitude': null})).$1, 400);
        expect((await post(token, {'latitude': 24, 'longitude': 121})).$1, 403);
        expect(records.select('SELECT * FROM admins').single['id'], 7);
        expect(
          records
              .select("SELECT name FROM sqlite_master WHERE type='table'")
              .length,
          1,
        );
        expect(calls, 1);
      },
    );
  });

  test('isolated DEMO launcher starts, logs in and returns disabled without opening formal DB', () async {
    final root = Directory.current.absolute.path;
    final sdk = File(Platform.resolvedExecutable).parent.path;
    final process = await Process.start('$sdk/${Platform.isWindows ? 'dart.exe' : 'dart'}', [
      '--packages=$root/.dart_tool/package_config.json',
      '$root/bin/reverse_geocoding_demo.dart',
    ], environment: {
      'DEMO_PORT': '0', 'REVERSE_GEOCODING_DEMO': 'false',
    });
    final ready = Completer<Uri>();
    final logs = <String>[];
    final output = process.stdout.transform(utf8.decoder).transform(const LineSplitter()).listen((line) {
      logs.add(line);
      if (line.startsWith('Isolated DEMO: ') && !ready.isCompleted) {
        ready.complete(Uri.parse(line.substring('Isolated DEMO: '.length)));
      }
    });
    final errors = process.stderr.transform(utf8.decoder).listen(logs.add);
    final local = HttpClient();
    try {
      final url = await ready.future.timeout(const Duration(seconds: 30));
      final login = await local.postUrl(url);
      login.headers.contentType = ContentType.json;
      login.write(jsonEncode({'type':'login', 'username':'demo_admin', 'password':'DemoOnly123!'}));
      final response = await login.close();
      final session = jsonDecode(await utf8.decoder.bind(response).join()) as Map;
      expect(response.statusCode, 200, reason: logs.join('\n'));
      final query = await local.postUrl(url);
      query.headers.contentType = ContentType.json;
      query.headers.set('Authorization', 'Bearer ${session['token']}');
      query.write(jsonEncode({'type':'reverseGeocode','latitude':lat,'longitude':lng}));
      final disabled = await query.close();
      expect(disabled.statusCode, 503);
      expect((jsonDecode(await utf8.decoder.bind(disabled).join()) as Map)['code'], 'GEOCODING_DEMO_DISABLED');
    } finally {
      local.close(force:true);
      process.kill(); // Only the isolated process created by this test.
      await process.exitCode;
      await output.cancel();
      await errors.cancel();
    }
  });
}
