import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_disaster_app/admin_APP/widgets/sos_address_details.dart';
import 'package:flutter_disaster_app/admin_APP/services/reverse_geocoding_client.dart';

void main() {
  Widget host(SosAddressDetails child) =>
      MaterialApp(home: Scaffold(body: child));
  testWidgets('provided App address never queries backend and keeps full GPS',
      (tester) async {
    var calls = 0;
    await tester.pumpWidget(host(SosAddressDetails(
        latitude: 25.033964,
        longitude: 121.564468,
        providedAddress: 'App supplied address',
        lookup: (a, b) async {
          calls++;
          return {};
        })));
    expect(calls, 0);
    expect(find.text('App supplied address'), findsOneWidget);
    expect(find.text('地址來源：使用者 App'), findsOneWidget);
    expect(find.text('GPS：25.033964, 121.564468'), findsOneWidget);
  });
  testWidgets(
      'single detail mounts once, shows loading and real response with attribution',
      (tester) async {
    var calls = 0;
    final completion = Completer<Map<String, dynamic>>();
    final child = SosAddressDetails(
        latitude: 25.033964,
        longitude: 121.564468,
        lookup: (a, b) {
          calls++;
          return completion.future;
        });
    await tester.pumpWidget(host(child));
    expect(find.text('正在查詢附近地址…'), findsOneWidget);
    expect(calls, 1);
    await tester.pumpWidget(host(child));
    expect(calls, 1);
    completion.complete(
        {'address': 'MOCK ADDRESS ONLY', 'source': 'OpenStreetMap Nominatim'});
    await tester.pumpAndSettle();
    expect(find.text('MOCK ADDRESS ONLY'), findsOneWidget);
    expect(find.text('地址僅供參考'), findsOneWidget);
    expect(find.text('© OpenStreetMap contributors (ODbL)'), findsOneWidget);
  });
  testWidgets('failure keeps GPS, manual retry only, no background polling',
      (tester) async {
    var calls = 0;
    await tester.pumpWidget(host(SosAddressDetails(
        latitude: 25.033964,
        longitude: 121.564468,
        lookup: (a, b) async {
          calls++;
          if (calls == 1) throw const AddressLookupException('Offline');
          return {
            'address': 'MOCK RECOVERY',
            'source': 'OpenStreetMap Nominatim'
          };
        })));
    await tester.pumpAndSettle();
    expect(find.text('地址無法取得'), findsOneWidget);
    expect(find.text('GPS：25.033964, 121.564468'), findsOneWidget);
    await tester.pump(const Duration(minutes: 1));
    expect(calls, 1);
    await tester.tap(find.text('重試查詢附近地址'));
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(find.text('MOCK RECOVERY'), findsOneWidget);
  });
  testWidgets('null and zero GPS never query', (tester) async {
    var calls = 0;
    for (final point in [(null, null), (0.0, 0.0), (91.0, 120.0)]) {
      await tester.pumpWidget(host(SosAddressDetails(
          latitude: point.$1,
          longitude: point.$2,
          lookup: (a, b) async {
            calls++;
            return {};
          })));
    }
    expect(calls, 0);
  });
  testWidgets('cooldown enables manual retry without doing a lookup',
      (tester) async {
    var calls = 0;
    await tester.pumpWidget(host(SosAddressDetails(
        latitude: 25.033964,
        longitude: 121.564468,
        lookup: (a, b) async {
          calls++;
          throw const AddressLookupException('Cooling down', 30);
        })));
    await tester.pumpAndSettle();
    expect(find.text('服務冷卻中，請稍後重試'), findsOneWidget);
    await tester.pump(const Duration(seconds: 31));
    expect(calls, 1);
    expect(find.text('重試查詢附近地址'), findsOneWidget);
  });
  test(
      'client uses Bearer Token, backend only and sends coordinates without identities',
      () async {
    AdminApiSession.token = 'session-test-only';
    final client = MockClient((req) async {
      expect(req.url.host, 'backend.example.test');
      expect(req.headers['Authorization'], 'Bearer session-test-only');
      expect(jsonDecode(req.body), {
        'type': 'reverseGeocode',
        'latitude': 25.033964,
        'longitude': 121.564468
      });
      return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'status': 'resolved',
              'address': 'MOCK ONLY',
              'source': 'OpenStreetMap Nominatim'
            }
          }),
          200);
    });
    await ReverseGeocodingClient(client,
            baseUrl: 'https://backend.example.test')
        .lookup(25.033964, 121.564468);
    AdminApiSession.token = null;
    await expectLater(
        ReverseGeocodingClient(client).lookup(25.033964, 121.564468),
        throwsA(isA<AddressLookupException>()));
    client.close();
  });
}
