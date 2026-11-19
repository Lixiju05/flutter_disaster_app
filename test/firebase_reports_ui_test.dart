import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_disaster_app/core/models/firebase_report.dart';
import 'package:flutter_disaster_app/core/repositories/firebase_reports_repository.dart';
import 'package:flutter_disaster_app/admin_APP/services/firebase_reports_client.dart';
import 'package:flutter_disaster_app/admin_APP/viewModels/firebase_reports_view_model.dart';
import 'package:flutter_disaster_app/admin_APP/widgets/firebase_reports_panel.dart';
import 'package:flutter_disaster_app/admin_APP/screens/full_map_page.dart';

Map<String, dynamic> report({String uid = 'test-uid', bool sos = true}) => {
      'uid': uid,
      'eventId': '00000000-0000-4000-8000-000000000001',
      'name': 'SYNTHETIC RESIDENT',
      'status': '未宣告',
      'sos': sos,
      'reportTime': '2026-11-17T00:00:00.000Z',
      'latitude': null,
      'longitude': null,
      'dataQuality': <String>[],
    };
http.Response reply(List<Object?> reports,
        {String? next, int status = 200, String source = 'firestore'}) =>
    http.Response(
        jsonEncode({
          'success': status == 200,
          'source': source,
          'collection': 'health_reports',
          'data': {
            'reports': reports,
            'nextPageToken': next,
            'semantics': 'latest_per_uid'
          },
        }),
        status,
        headers: {'content-type': 'application/json; charset=utf-8'});
FirebaseReportsRepository repository(
        Future<http.Response> Function(http.Request) responder,
        {int maxPages = 20,
        String? Function()? tokenProvider}) =>
    FirebaseReportsRepository(
        FirebaseReportsClient(MockClient(responder),
            baseUrl: 'http://isolated.test/',
            tokenProvider: tokenProvider ?? () => 'SYNTHETIC_SESSION'),
        maxPages: maxPages);

void main() {
  test('DTO handles nullable values without invented identities, dates or GPS',
      () {
    final value = FirebaseReport.fromJson({'uid': 'U1', 'status': '未宣告'});
    expect(value.uid, 'U1');
    expect(value.eventId, isNull);
    expect(value.sos, isNull);
    expect(value.reportTime, isNull);
    expect(value.hasCoordinates, false);
    for (final time in [
      'invalid',
      '2026-02-31T00:00:00Z',
      '2026-11-17T08:00:00'
    ]) {
      expect(
          FirebaseReport.fromJson({...report(), 'reportTime': time}).reportTime,
          isNull);
    }
    final offset = FirebaseReport.fromJson({
      ...report(),
      'reportTime': '2026-11-17T08:00:00+08:00',
      'latitude': 24.123456789,
      'longitude': 121.987654321
    });
    expect(offset.reportTime, DateTime.utc(2026, 11, 17));
    expect(offset.latitude, 24.123456789);
    expect(
        FirebaseReport.fromJson({...report(), 'latitude': 91, 'longitude': 121})
            .hasCoordinates,
        false);
    expect(
        FirebaseReport.fromJson({...report(), 'latitude': 0, 'longitude': 0})
            .hasCoordinates,
        false);
    expect(() => FirebaseReport.fromJson({'uid': 'bad/uid'}),
        throwsFormatException);
  });
  test(
      'client attaches session and exact type, rejects SQLite response and false SOS',
      () async {
    final repo = repository((request) async {
      expect(request.method, 'POST');
      expect(request.headers['Authorization'], 'Bearer SYNTHETIC_SESSION');
      expect(jsonDecode(request.body),
          {'type': 'getFirebaseSosReports', 'limit': 25});
      return reply([report()]);
    });
    expect((await repo.fetch(sosOnly: true)).single.sos, true);
    repo.close();
    for (final response in [
      reply([report()], source: 'sqlite'),
      reply([report(sos: false)])
    ]) {
      final invalid = repository((_) async => response);
      await expectLater(invalid.fetch(sosOnly: true),
          throwsA(isA<FirebaseReportsClientException>()));
      invalid.close();
    }
  });
  test('missing token never sends a request', () async {
    final repo = repository((_) async => throw StateError('must not send'),
        tokenProvider: () => null);
    await expectLater(
        repo.fetch(sosOnly: true),
        throwsA(isA<FirebaseReportsClientException>()
            .having((e) => e.status, 'status', 401)));
    repo.close();
  });
  test(
      'empty SOS page continues, deduplicates by UID and never treats event UUID as identity',
      () async {
    var calls = 0;
    final repo = repository((request) async {
      final input = jsonDecode(request.body) as Map;
      calls++;
      if (calls == 1) return reply([], next: 'page-two');
      if (calls == 2) {
        expect(input['pageToken'], 'page-two');
        return reply([report(uid: 'U1')], next: 'page-three');
      }
      return reply([
        {...report(uid: 'U1'), 'status': '重傷'},
        report(uid: 'second-uid')
      ]);
    });
    final rows = await repo.fetch(sosOnly: true);
    expect(rows, hasLength(2));
    expect(rows.singleWhere((r) => r.uid == 'U1').status, '重傷');
    expect(calls, 3);
    repo.close();
  });
  test('repeated cursor and page cap reject incomplete snapshots', () async {
    for (final cap in [1, 20]) {
      final repo = repository((_) async => reply([report()], next: 'same'),
          maxPages: cap);
      await expectLater(
          repo.fetch(sosOnly: true),
          throwsA(isA<FirebaseReportsClientException>()
              .having((e) => e.code, 'code', 'INCOMPLETE_REFRESH')));
      repo.close();
    }
  });
  test('token change during cloud request cannot release previous session data',
      () async {
    var token = 'FIRST';
    final repo = repository((_) async {
      token = 'SECOND';
      return reply([report()]);
    }, tokenProvider: () => token);
    await expectLater(
        repo.fetch(sosOnly: true),
        throwsA(isA<FirebaseReportsClientException>()
            .having((e) => e.code, 'code', 'SESSION_CHANGED')));
    repo.close();
  });
  test(
      'refresh replaces snapshots, clears withdrawn SOS, and retains data on network error',
      () async {
    var phase = 0;
    final vm = FirebaseReportsViewModel(repository((_) async {
      if (phase == 2) throw http.ClientException('PRIVATE_DIAGNOSTIC');
      return reply(phase == 1 ? [] : [report()]);
    }), sosOnly: true);
    await vm.refresh();
    expect(vm.reports, hasLength(1));
    final first = vm.updatedAt;
    phase = 2;
    await vm.refresh();
    expect(vm.reports, hasLength(1));
    expect(vm.updatedAt, first);
    expect(vm.error, isNot(contains('PRIVATE_DIAGNOSTIC')));
    phase = 1;
    await vm.refresh();
    expect(vm.reports, isEmpty);
    expect(vm.error, isNull);
    vm.dispose();
  });
  test('failed later page keeps whole previous snapshot', () async {
    var phase = 0;
    final vm = FirebaseReportsViewModel(repository((request) async {
      if (phase == 0) return reply([report(uid: 'old')]);
      final input = jsonDecode(request.body) as Map;
      return input.containsKey('pageToken')
          ? reply([], status: 503)
          : reply([report(uid: 'partial')], next: 'tail');
    }), sosOnly: true);
    await vm.refresh();
    phase = 1;
    await vm.refresh();
    expect(vm.reports.single.uid, 'old');
    expect(vm.error, isNotNull);
    vm.dispose();
  });
  test('401/403 remove cached personal reports even with non-JSON errors',
      () async {
    for (final status in [401, 403]) {
      var fail = false;
      final vm = FirebaseReportsViewModel(
          repository((_) async =>
              fail ? http.Response('PRIVATE_HTML', status) : reply([report()])),
          sosOnly: true);
      await vm.refresh();
      fail = true;
      await vm.refresh();
      expect(vm.reports, isEmpty);
      expect(vm.hasLoaded, false);
      expect(vm.error, isNot(contains('PRIVATE_HTML')));
      vm.dispose();
    }
  });
  test('overlapping refresh is coalesced and dispose handles late response',
      () async {
    var calls = 0;
    final gate = Completer<http.Response>();
    final vm = FirebaseReportsViewModel(repository((_) {
      calls++;
      return gate.future;
    }), sosOnly: true);
    final pending = vm.refresh();
    await Future<void>.delayed(Duration.zero);
    await vm.refresh();
    expect(calls, 1);
    vm.dispose();
    gate.complete(reply([report()]));
    await pending;
  });
  testWidgets(
      'one SOS renders read-only, no completion/delete controls and no map without GPS',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: FirebaseReportsPanel(
                sosOnly: true,
                refreshInterval: Duration.zero,
                repositoryFactory: () =>
                    repository((_) async => reply([report()]))))));
    await tester.pumpAndSettle();
    expect(find.text('SOS 1 筆'), findsOneWidget);
    expect(find.text('SYNTHETIC RESIDENT'), findsOneWidget);
    expect(find.text('標記完成'), findsNothing);
    expect(find.text('刪除'), findsNothing);
    await tester.tap(find.text('詳細資料'));
    await tester.pumpAndSettle();
    expect(find.text('未提供有效 GPS'), findsOneWidget);
    expect(find.text('查看地圖'), findsNothing);
  });
  test('map can omit reference circle without changing legacy default', () {
    expect(const FullMapPage(lat: 24, lng: 121).showReferenceCircle, true);
    expect(
        const FullMapPage(lat: 24, lng: 121, showReferenceCircle: false)
            .showReferenceCircle,
        false);
  });
  test(
      'health endpoint preserves non-SOS injury reports without classifying them as SOS',
      () async {
    final repo = repository((request) async {
      expect(jsonDecode(request.body)['type'], 'getFirebaseHealthReports');
      return reply([
        {...report(sos: false), 'status': '重傷'}
      ]);
    });
    final result = await repo.fetch(sosOnly: false);
    expect(result.single.status, '重傷');
    expect(result.single.sos, false);
    repo.close();
  });
  testWidgets(
      'detail follows successful SOS withdrawal without showing old personal fields',
      (tester) async {
    var phase = 0;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: FirebaseReportsPanel(
                sosOnly: true,
                repositoryFactory: () => repository(
                    (_) async => reply(phase == 0 ? [report()] : []))))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('詳細資料'));
    await tester.pumpAndSettle();
    phase = 1;
    await tester.pump(const Duration(seconds: 30));
    await tester.pumpAndSettle();
    expect(find.text('回報狀態已更新'), findsOneWidget);
    expect(find.textContaining('姓名：SYNTHETIC'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
      'valid GPS requires explicit map confirmation and never geocodes automatically',
      (tester) async {
    var calls = 0;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: FirebaseReportsPanel(
                sosOnly: true,
                refreshInterval: Duration.zero,
                repositoryFactory: () => repository((_) async {
                      calls++;
                      return reply([
                        {
                          ...report(),
                          'latitude': 24.123456789,
                          'longitude': 121.987654321
                        }
                      ]);
                    })))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('詳細資料'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('查看地圖'));
    await tester.pumpAndSettle();
    expect(find.text('開啟回報位置'), findsOneWidget);
    expect(find.byType(FullMapPage), findsNothing);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(calls, 1);
  });
  testWidgets('loading never presents an unknown result as zero SOS',
      (tester) async {
    final gate = Completer<http.Response>();
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: FirebaseReportsPanel(
                sosOnly: true,
                refreshInterval: Duration.zero,
                repositoryFactory: () => repository((_) => gate.future)))));
    await tester.pump();
    expect(find.text('SOS 尚未取得資料'), findsOneWidget);
    expect(find.text('SOS 0 筆'), findsNothing);
    gate.complete(reply([]));
    await tester.pumpAndSettle();
    expect(find.text('SOS 0 筆'), findsOneWidget);
  });
  testWidgets('polling removes cleared SOS on next successful full refresh',
      (tester) async {
    var phase = 0;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: FirebaseReportsPanel(
                sosOnly: true,
                repositoryFactory: () => repository(
                    (_) async => reply(phase == 0 ? [report()] : []))))));
    await tester.pumpAndSettle();
    expect(find.text('SOS 1 筆'), findsOneWidget);
    phase = 1;
    await tester.pump(const Duration(seconds: 30));
    await tester.pumpAndSettle();
    expect(find.text('目前沒有 sos=true 的回報'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
      'refresh failure shows stale banner and preserves last known report',
      (tester) async {
    var fail = false;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: FirebaseReportsPanel(
                sosOnly: true,
                refreshInterval: Duration.zero,
                repositoryFactory: () => repository((_) async => reply(
                    fail ? [] : [report()],
                    status: fail ? 503 : 200))))));
    await tester.pumpAndSettle();
    fail = true;
    await tester.tap(find.byTooltip('重新整理 Firestore 回報'));
    await tester.pumpAndSettle();
    expect(find.text('SYNTHETIC RESIDENT'), findsOneWidget);
    expect(find.textContaining('保留上次成功資料'), findsOneWidget);
  });
  testWidgets('source selection does not mount SQLite until explicit choice',
      (tester) async {
    var legacyBuilds = 0;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: ReportSourcePage(
                sosOnly: true,
                repositoryFactory: () =>
                    repository((_) async => reply([report()])),
                sqliteBuilder: (_) {
                  legacyBuilds++;
                  return const Text('ISOLATED SQLITE VIEW');
                }))));
    await tester.pumpAndSettle();
    expect(legacyBuilds, 0);
    await tester.tap(find.byType(DropdownButton<bool>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('SQLite 原有回報').last);
    await tester.pumpAndSettle();
    expect(find.text('ISOLATED SQLITE VIEW'), findsOneWidget);
    expect(legacyBuilds, greaterThan(0));
    expect(find.text('SYNTHETIC RESIDENT'), findsNothing);
  });
}
