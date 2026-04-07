import 'package:flutter/material.dart';
import '../../core/models/healthReport.dart';

class HealthReportRepository extends ChangeNotifier {

  final List<HealthReport> _reports = [];

  HealthReportRepository() {
    _loadFakeData();
  }

  /// UI 讀取資料
  List<HealthReport> getReports() {
    return _reports;
  }

  /// 假資料（UI 測試用）
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
    ]);
  }

  /// ⭐ 接收「真實 JSON 資料」
  void addReportFromJson(Map<String, dynamic> json) {
    final report = HealthReport.fromJson(json);

    _reports.insert(0, report);

    /// ⭐ 通知 UI 更新
    notifyListeners();
  }
}