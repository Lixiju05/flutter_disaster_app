import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_disaster_app/core/models/healthReport.dart';
import 'package:flutter_disaster_app/core/models/emergency_request.dart';

void main() {
  Map<String, dynamic> healthJson() => {
        'reporterId': 'test-user',
        'name': 'Test',
        'phone': '',
        'status': 'safe',
        'lat': 25.033964,
        'lng': 121.564468,
        'reportTime': '2026-11-17T00:00:00.000Z',
      };

  test('health address round-trips without changing original GPS', () {
    final report = HealthReport.fromJson({
      ...healthJson(),
      'address': 'Test address',
    });
    expect(report.address, 'Test address');
    expect(report.toJson()['address'], 'Test address');
    expect(report.lat, 25.033964);
    expect(report.lng, 121.564468);
  });

  test('legacy health JSON permits absent or null address', () {
    expect(HealthReport.fromJson(healthJson()).address, isNull);
    expect(HealthReport.fromJson({...healthJson(), 'address': null}).address,
        isNull);
  });

  test('SOS status changes and serialization preserve App address', () {
    final original = EmergencyRequest(
      emergencyId: 'test-sos',
      userId: 'test-user',
      userName: 'Test',
      phone: '',
      lat: 25.033964,
      lng: 121.564468,
      address: 'Test address',
    );
    final updated = original.copyWith(status: 'resolved');
    expect(updated.emergencyId, original.emergencyId);
    expect(updated.status, 'resolved');
    expect(updated.address, original.address);
    expect(updated.toJson()['address'], original.address);
    expect(updated.lat, original.lat);
    expect(updated.lng, original.lng);
  });
}
