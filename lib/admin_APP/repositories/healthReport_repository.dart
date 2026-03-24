import '../../core/models/healthReport.dart';

class HealthReportRepository {
  final List<HealthReport> _reports = [];

  
  HealthReportRepository() {
    _loadFakeData();
  }
  List<HealthReport> getReports() {
    return _reports;
  }
  void _loadFakeData() {
    _reports.addAll([
      HealthReport(
        reporterId: 'H001',
        name: '王小明',
        status: 'safe',
        description: '目前安全，已在避難所。',
        reportTime: DateTime.now().subtract(const Duration(minutes: 10)),
      ),
      HealthReport(
        reporterId: 'H002',
        name: '李小華',
        status: 'injured',
        description: '腳受傷，需要醫療協助。',
        reportTime: DateTime.now().subtract(const Duration(minutes: 30)),
      ),
      HealthReport(
        reporterId: 'H003',
        name: '陳大明',
        status: 'critical',
        description: '昏迷中，急需救援。',
        reportTime: DateTime.now().subtract(const Duration(hours: 1)),
      ),
      HealthReport(
        reporterId: 'H004',
        name: '林美玲',
        status: 'safe',
        description: '已與家人會合。',
        reportTime: DateTime.now().subtract(const Duration(hours: 2)),
      ),
      HealthReport(
        reporterId: 'H005',
        name: '張志強',
        status: 'injured',
        description: '手部流血，等待包紮。',
        reportTime: DateTime.now().subtract(const Duration(hours: 3)),
      ),
    ]);
  }
  void addReportFromJson(Map<String, dynamic> json) {
    final report = HealthReport.fromJson(json);
    _reports.insert(0, report);
  }
}