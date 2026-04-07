import 'package:flutter/material.dart';
import '../repositories/healthReport_repository.dart';
import '../../core/models/healthReport.dart';

class HealthReportPage extends StatelessWidget {
  HealthReportPage({super.key});

  final HealthReportRepository repo = HealthReportRepository();

  @override
  Widget build(BuildContext context) {
    final reports = repo.getReports();

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF1E3A5F),
        title: const Text(
          "健康回報管理",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: reports.isEmpty
          ? const Center(
              child: Text(
                "目前沒有健康回報資料",
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.health_and_safety,
                          color: Color(0xFF1E3A5F),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          "回報列表",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E3A5F).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            "共 ${reports.length} 筆",
                            style: const TextStyle(
                              color: Color(0xFF1E3A5F),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    itemCount: reports.length,
                    itemBuilder: (context, index) {
                      final report = reports[index];
                      final statusColor = _getStatusColor(report.status);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 12,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CircleAvatar(
                                    radius: 24,
                                    backgroundColor:
                                        statusColor.withOpacity(0.12),
                                    child: Icon(
                                      _getStatusIcon(report.status),
                                      color: statusColor,
                                      size: 26,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          report.name,
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF1E293B),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          "回報者 ID：${report.reporterId}",
                                          style: const TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  _buildStatusChip(report.status),
                                ],
                              ),

                              const SizedBox(height: 14),

                              _buildInfoRow(
                                Icons.phone,
                                "聯絡電話",
                                report.phone,
                              ),

                              _buildInfoRow(
                                Icons.bloodtype,
                                "血型",
                                report.bloodType ?? "未填寫",
                              ),

                              _buildInfoRow(
                                Icons.access_time,
                                "回報時間",
                                _formatTime(report.reportTime),
                              ),

                              _buildInfoRow(
                                Icons.location_on,
                                "位置",
                                (report.lat != null && report.lng != null)
                                    ? "${report.lat}, ${report.lng}"
                                    : "未提供位置",
                              ),

                              const SizedBox(height: 10),

                              const Text(
                                "補充說明",
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF334155),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  (report.description != null &&
                                          report.description!.trim().isNotEmpty)
                                      ? report.description!
                                      : "無補充說明",
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF475569),
                                    height: 1.5,
                                  ),
                                ),
                              ),

                              const SizedBox(height: 12),

                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton.icon(
                                  onPressed: () {
                                    _showDetailDialog(context, report);
                                  },
                                  icon: const Icon(Icons.info_outline),
                                  label: const Text("查看詳情"),
                                  style: TextButton.styleFrom(
                                    foregroundColor: const Color(0xFF1E3A5F),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case '安全':
      case 'safe':
        return Colors.green;
      case '輕傷':
      case 'injured':
        return Colors.orange;
      case '重傷':
      case 'critical':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case '安全':
      case 'safe':
        return Icons.verified_user;
      case '輕傷':
      case 'injured':
        return Icons.healing;
      case '重傷':
      case 'critical':
        return Icons.warning_rounded;
      default:
        return Icons.info_outline;
    }
  }

  Widget _buildStatusChip(String status) {
    final color = _getStatusColor(status);

    String text;
    switch (status) {
      case 'safe':
        text = '安全';
        break;
      case 'injured':
        text = '輕傷';
        break;
      case 'critical':
        text = '重傷';
        break;
      default:
        text = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: const Color(0xFF1E3A5F)),
          const SizedBox(width: 8),
          Text(
            "$label：",
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF334155),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF475569),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    return "${time.year}/"
        "${time.month.toString().padLeft(2, '0')}/"
        "${time.day.toString().padLeft(2, '0')} "
        "${time.hour.toString().padLeft(2, '0')}:"
        "${time.minute.toString().padLeft(2, '0')}";
  }

  void _showDetailDialog(BuildContext context, HealthReport report) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        title: Text(
          report.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("回報者 ID：${report.reporterId}"),
              const SizedBox(height: 8),
              Text("聯絡電話：${report.phone}"),
              const SizedBox(height: 8),
              Text("血型：${report.bloodType ?? '未填寫'}"),
              const SizedBox(height: 8),
              Text("狀態：${report.status}"),
              const SizedBox(height: 8),
              Text("時間：${_formatTime(report.reportTime)}"),
              const SizedBox(height: 8),
              Text(
                "位置：${(report.lat != null && report.lng != null) ? '${report.lat}, ${report.lng}' : '未提供位置'}",
              ),
              const SizedBox(height: 8),
              Text("備註：${report.description ?? '無'}"),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("關閉"),
          ),
        ],
      ),
    );
  }
}