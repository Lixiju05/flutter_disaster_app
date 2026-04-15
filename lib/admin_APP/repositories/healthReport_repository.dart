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
        phone: '0912345678',
        bloodType: 'O',
        status: '安全', 
        description: '目前安全，已在避難所。',
          lat: 23.951178, // 暨大
        lng: 120.930978,
        reportTime: DateTime.now().subtract(const Duration(minutes: 10)),
      ),
      HealthReport(
        reporterId: 'H002',
        name: '李小華',
        phone: '0922333444',
        bloodType: 'A',
        status: '輕傷',
        description: '腳受傷，需要醫療協助。',
       lat: 23.966667, // 埔里
        lng: 120.966667,
        reportTime: DateTime.now().subtract(const Duration(minutes: 30)),
      ),
      HealthReport(
        reporterId: 'H003',
        name: '陳大明',
        phone: '0933555666',
        bloodType: 'B',
        status: '重傷',
        description: '昏迷中，急需救援。',
         lat: 23.866664, // 日月潭
        lng: 120.916664,
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