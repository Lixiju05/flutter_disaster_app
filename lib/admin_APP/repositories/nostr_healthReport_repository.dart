import 'dart:convert';

import '../../core/models/healthReport.dart';
import '../../core/repositories/health_repository.dart';

class NostrHealthRepository implements HealthRepository {

  @override
  Stream<HealthReport> listenHealthReports() async* {

    /// 模擬收到 Nostr JSON
    final jsonString = '''
    {
      "reporterId":"A01",
      "name":"小明",
      "status":"輕傷",
      "description":"腳受傷",
      "reportTime":"2026-03-24T12:00:00Z"
    }
    ''';

    final Map<String, dynamic> jsonData =
        jsonDecode(jsonString);

    yield HealthReport.fromJson(jsonData);
  }
}