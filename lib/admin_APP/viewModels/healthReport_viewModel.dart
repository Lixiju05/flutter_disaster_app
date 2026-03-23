import 'package:flutter/material.dart';
import '../repositories/healthReport_repository.dart';
import '../../core/models/healthReport.dart';

class HealthReportViewModel extends ChangeNotifier {

  final HealthReportRepository _repository =
      HealthReportRepository();

  List<HealthReport> get reports =>
      _repository.getReports();

  /// 給通訊模組呼叫
  void receiveReport(Map<String, dynamic> json) {
    _repository.addReportFromJson(json);

    notifyListeners();
  }
}
