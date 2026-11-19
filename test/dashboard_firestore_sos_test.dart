import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_disaster_app/admin_APP/widgets/dashboard_firestore_sos.dart';
import 'package:flutter_disaster_app/admin_APP/widgets/firebase_reports_panel.dart';
import 'package:flutter_disaster_app/admin_APP/viewModels/firebase_reports_view_model.dart';
import 'package:flutter_disaster_app/core/models/firebase_report.dart';
import 'firebase_reports_ui_test.dart' show report, reply, repository;

void main() {
  late FirebaseReportsViewModel vm;
  late Future<http.Response> Function(http.Request) response;
  late int calls;
  List<FirebaseReport> markers = [];
  setUp(() {
    calls = 0;
    markers = [];
    response = (_) async => reply([report()]);
    vm = FirebaseReportsViewModel(repository((r) {
      calls++;
      return response(r);
    }), sosOnly: true);
  });
  tearDown(() => vm.dispose());
  Future<void> mount(WidgetTester tester) async {
    tester.view.resetPhysicalSize();
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SizedBox(
                height: 500,
                child: DashboardFirestoreSos(
                    model: vm,
                    onViewAll: () {},
                    mapBuilder: (located) {
                      markers = located;
                      return Text('TEST_MAP_MARKERS:${located.length}');
                    })))));
  }

  testWidgets('one SOS without GPS counts and lists it but creates no marker',
      (tester) async {
    await vm.refresh();
    await mount(tester);
    expect(firestoreSosCount(vm), '1');
    expect(find.text('SYNTHETIC RESIDENT'), findsOneWidget);
    expect(find.textContaining('位置未知／轄區未確認'), findsOneWidget);
    expect(find.text('目前沒有可標示的 SOS 位置'), findsOneWidget);
    expect(markers, isEmpty);
  });
  testWidgets(
      'valid GPS is preserved in the sole marker, clinical status is not workflow',
      (tester) async {
    response = (_) async => reply([
          {
            ...report(),
            'status': '安全',
            'latitude': 24.123456789,
            'longitude': 121.987654321
          }
        ]);
    await vm.refresh();
    await mount(tester);
    expect(firestoreSosCount(vm), '1');
    expect(markers.single.latitude, 24.123456789);
    expect(markers.single.longitude, 121.987654321);
    expect(find.textContaining('健康狀態：安全'), findsOneWidget);
    expect(find.text('處理中'), findsNothing);
    expect(find.textContaining('回報時間不等於定位時間'), findsOneWidget);
  });
  testWidgets('unloaded snapshot does not pretend there are zero SOS',
      (tester) async {
    await mount(tester);
    expect(firestoreSosCount(vm), '尚未取得資料');
    expect(find.text('目前沒有 SOS'), findsNothing);
  });
  testWidgets('upstream failure retains last success with stale notice',
      (tester) async {
    await vm.refresh();
    final timestamp = vm.updatedAt;
    response = (_) async => http.Response('{}', 503);
    await vm.refresh();
    await mount(tester);
    expect(firestoreSosCount(vm), '1');
    expect(vm.updatedAt, timestamp);
    expect(find.textContaining('資料可能過期'), findsOneWidget);
    expect(find.text('SYNTHETIC RESIDENT'), findsOneWidget);
  });
  for (final status in [401, 403]) {
    testWidgets('$status clears protected records rather than preserving names',
        (tester) async {
      await vm.refresh();
      response = (_) async => http.Response('{}', status);
      await vm.refresh();
      await mount(tester);
      expect(vm.reports, isEmpty);
      expect(vm.updatedAt, isNull);
      expect(firestoreSosCount(vm), '尚未取得資料');
      expect(find.text('SYNTHETIC RESIDENT'), findsNothing);
    });
  }
  testWidgets('cleared SOS disappears after complete refresh', (tester) async {
    await vm.refresh();
    await mount(tester);
    // Upstream sos=false is filtered by server, so the next SOS page is empty.
    response = (_) async => reply([]);
    await vm.refresh();
    await tester.pump();
    expect(firestoreSosCount(vm), '0');
    expect(find.text('SYNTHETIC RESIDENT'), findsNothing);
    expect(find.text('目前沒有 SOS'), findsOneWidget);
  });
  test('empty page with cursor continues before publishing count', () async {
    response =
        (_) async => calls == 1 ? reply([], next: 'second') : reply([report()]);
    await vm.refresh();
    expect(calls, 2);
    expect(firestoreSosCount(vm), '1');
  });
  testWidgets('complete empty response is a legitimate zero', (tester) async {
    response = (_) async => reply([]);
    await vm.refresh();
    await mount(tester);
    expect(firestoreSosCount(vm), '0');
    expect(find.text('目前沒有 SOS'), findsOneWidget);
  });
  testWidgets(
      'source switch synchronizes count/list and never mounts SQLite in Firestore mode',
      (tester) async {
    await vm.refresh();
    bool firestore = true;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: StatefulBuilder(
                builder: (context, setState) => Column(children: [
                      TextButton(
                          onPressed: () =>
                              setState(() => firestore = !firestore),
                          child: const Text('切換')),
                      Text('COUNT:${dashboardSosCount(firestore, vm, 7)}'),
                      Expanded(
                          child: DashboardSosContent(
                              firestore: firestore,
                              model: vm,
                              onViewAll: () {},
                              sqliteBuilder: (_) =>
                                  const Text('SQLITE_LEGACY_SEVEN'),
                              mapBuilder: (_) => const SizedBox())),
                    ])))));
    expect(find.text('COUNT:1'), findsOneWidget);
    expect(find.text('SQLITE_LEGACY_SEVEN'), findsNothing);
    await tester.tap(find.text('切換'));
    await tester.pump();
    expect(find.text('COUNT:7'), findsOneWidget);
    expect(find.text('SQLITE_LEGACY_SEVEN'), findsOneWidget);
    expect(find.text('SYNTHETIC RESIDENT'), findsNothing);
    await tester.tap(find.text('切換'));
    await tester.pump();
    expect(find.text('COUNT:1'), findsOneWidget);
    expect(calls, 1);
  });
  testWidgets(
      'shared SOS page reuses snapshot and does not close Dashboard model',
      (tester) async {
    await vm.refresh();
    await tester.pumpWidget(MaterialApp(
        home: FirebaseSosScope(
            model: vm,
            child: const Scaffold(body: FirebaseReportsPanel(sosOnly: true)))));
    await tester.pump();
    expect(calls, 1);
    await tester.pumpWidget(const SizedBox());
    await vm.refresh();
    expect(calls, 2);
    expect(vm.hasLoaded, true);
  });
  testWidgets('detail remains read-only and removal invalidates open detail',
      (tester) async {
    await vm.refresh();
    await mount(tester);
    await tester.tap(find.text('SYNTHETIC RESIDENT'));
    await tester.pumpAndSettle();
    expect(find.text('Firestore SOS 詳細資料（唯讀）'), findsOneWidget);
    expect(find.text('標記已完成'), findsNothing);
    expect(find.text('刪除'), findsNothing);
    response = (_) async => reply([]);
    await vm.refresh();
    await tester.pumpAndSettle();
    expect(find.textContaining('此回報已更新或無權檢視'), findsOneWidget);
  });
  testWidgets(
      'refresh in progress keeps prior snapshot, no duplicate concurrent query',
      (tester) async {
    await vm.refresh();
    final pending = Completer<http.Response>();
    response = (_) => pending.future;
    final refresh = vm.refresh();
    await mount(tester);
    await vm.refresh();
    expect(firestoreSosCount(vm), '1');
    expect(calls, 2);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    pending.complete(reply([]));
    await refresh;
    await tester.pump();
    expect(firestoreSosCount(vm), '0');
  });
  test('invalid or zero coordinates never become a default marker', () {
    for (final coords in [
      [null, null],
      [0, 0],
      [91, 121],
      [24, 181],
      [double.nan, 121]
    ]) {
      final dto = FirebaseReport.fromJson(
          {...report(), 'latitude': coords[0], 'longitude': coords[1]});
      expect(dto.hasCoordinates, false);
    }
  });
  testWidgets(
      'Dashboard polls every 30 seconds only while active and stops on close',
      (tester) async {
    bool active = true;
    final loop = FirebaseReportsRefreshLoop(vm, isActive: () => active);
    await tester.pump(const Duration(seconds: 29));
    expect(calls, 0);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(calls, 1);
    active = false;
    await tester.pump(const Duration(seconds: 30));
    expect(calls, 1);
    active = true;
    await tester.pump(const Duration(seconds: 30));
    await tester.pump();
    expect(calls, 2);
    loop.close();
    await tester.pump(const Duration(seconds: 30));
    expect(calls, 2);
  });
  testWidgets('SQLite drilldown mounts only the explicit legacy source',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: ReportSourcePage(
                sosOnly: true,
                initialFirestore: false,
                sqliteBuilder: (_) => const Text('LEGACY_SQLITE_ONLY'),
                repositoryFactory: () =>
                    throw StateError('must not query Firestore')))));
    expect(find.text('LEGACY_SQLITE_ONLY'), findsOneWidget);
    expect(calls, 0);
  });
}
