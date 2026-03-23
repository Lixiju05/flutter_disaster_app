import '../../core/models/healthReport.dart';

class HealthReportRepository {
  final List<HealthReport> _reports = [];

  List<HealthReport> getReports() {
    return _reports;
  }

  /// 給通訊層呼叫（收到 Nostr 訊息）
  void addReportFromJson(Map<String, dynamic> json) {
    final report = HealthReport.fromJson(json);
    _reports.insert(0, report);
  }
}