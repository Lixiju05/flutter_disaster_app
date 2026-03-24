import 'package:flutter/material.dart';
import '../repositories/healthReport_repository.dart';
import '../../core/models/healthReport.dart';

class HealthReportViewModel extends ChangeNotifier {

  final HealthReportRepository _repository =
      HealthReportRepository();

  List<HealthReport> _reports = [];

  List<HealthReport> get reports => _reports;

  HealthReportViewModel() {
    loadReports(); // ⭐ 一进来就加载
  }

  void loadReports() {
    _reports = _repository.getReports();
    notifyListeners(); // ⭐ 关键！！
  }

  /// 給通訊模組呼叫
  void receiveReport(Map<String, dynamic> json) {
    _repository.addReportFromJson(json);
    loadReports(); // ⭐ 不是直接 notify，要重新加载
  }
}
