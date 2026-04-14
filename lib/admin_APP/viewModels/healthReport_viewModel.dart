import 'package:flutter/material.dart';
import '../repositories/healthReport_repository.dart';
import '../../core/models/healthReport.dart';

class HealthReportViewModel extends ChangeNotifier {
  final HealthReportRepository _repository = HealthReportRepository();

  List<HealthReport> _reports = [];
  List<HealthReport> _filteredReports = [];

  List<HealthReport> get reports => _filteredReports;

  HealthReportViewModel() {
    loadReports();
  }

  /// 初始加载
  void loadReports() {
    _reports = List.from(_repository.getReports());
    _filteredReports = List.from(_reports);
    notifyListeners();
  }

  /// 給通訊模組呼叫
  void receiveReport(Map<String, dynamic> json) {
    _repository.addReportFromJson(json);
    loadReports();
  }

  /// 总人数
  int get totalCount => _reports.length;

  /// 安全人数
  int get safeCount =>
      _reports.where((report) => report.status == 'safe').length;

  /// 等待救援人数
  int get waitingCount =>
      _reports.where((report) => report.status != 'safe').length;

  /// 搜尋
  void searchReports(String keyword) {
    final text = keyword.trim().toLowerCase();

    if (text.isEmpty) {
      _filteredReports = List.from(_reports);
    } else {
      _filteredReports = _reports.where((report) {
        final name = report.name.toLowerCase();
        final id = report.reporterId.toLowerCase();
        return name.contains(text) || id.contains(text);
      }).toList();
    }

    notifyListeners();
  }

  /// 顯示全部
  void showAllReports() {
    _filteredReports = List.from(_reports);
    notifyListeners();
  }

  /// 只顯示安全
  void showSafeReports() {
    _filteredReports =
        _reports.where((report) => report.status == 'safe').toList();
    notifyListeners();
  }

  /// 只顯示等待救援
  void showWaitingReports() {
    _filteredReports =
        _reports.where((report) => report.status != 'safe').toList();
    notifyListeners();
  }

  /// 新增資料
  void addReport(HealthReport report) {
    _reports.add(report);
    _filteredReports = List.from(_reports);
    notifyListeners();
  }

  /// 刪除資料
  void deleteReport(int index) {
    final reportToDelete = _filteredReports[index];
    _reports.remove(reportToDelete);
    _filteredReports.removeAt(index);
    notifyListeners();
  }

  /// 更新資料
  void updateReport(int index, HealthReport updatedReport) {
    final oldReport = _filteredReports[index];

    final realIndex = _reports.indexOf(oldReport);
    if (realIndex != -1) {
      _reports[realIndex] = updatedReport;
    }

    _filteredReports[index] = updatedReport;
    notifyListeners();
  }

  /// 重新整理
  void refresh() {
    loadReports();
  }
}