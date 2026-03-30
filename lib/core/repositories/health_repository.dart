import '../models/healthReport.dart';

abstract class HealthRepository {

  /// 管理端監聽健康回報
  Stream<HealthReport> listenHealthReports();
}