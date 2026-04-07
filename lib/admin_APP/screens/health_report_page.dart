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
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("健康回報管理"),
        backgroundColor: const Color(0xFF1E3A5F),
      ),
      body: Column(
        children: [
          // 🔷 标题区
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Text(
                  "回報列表",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Text(
                  "共 ${reports.length} 筆",
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),

          // 🔷 列表
          Expanded(
            child: ListView.builder(
              itemCount: reports.length,
              itemBuilder: (context, index) {
                final report = reports[index];

                return Card(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),

                    // 👤 姓名
                    title: Text(
                      report.name,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                    ),

                    // 📝 描述
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 8),

                        // 状态
                        Row(
                          children: [
                            _buildStatusChip(report.status),
                          ],
                        ),

                        const SizedBox(height: 8),

                        // 备注
                        if (report.description != null)
                          Text("備註：${report.description}"),

                        const SizedBox(height: 6),

                        // 时间
                        Text(
                          "時間：${report.reportTime}",
                          style: const TextStyle(
                              fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),

                    // 👉 右边按钮
                    trailing: IconButton(
                      icon: const Icon(Icons.info_outline),
                      onPressed: () {
                        _showDetailDialog(context, report);
                      },
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

  // 🔥 状态颜色标签
  Widget _buildStatusChip(String status) {
    Color color;
    String text;

    switch (status) {
      case 'safe':
        color = Colors.green;
        text = '安全';
        break;
      case 'injured':
        color = Colors.orange;
        text = '受傷';
        break;
      case 'critical':
        color = Colors.red;
        text = '危急';
        break;
      default:
        color = Colors.grey;
        text = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }

  // 🔥 弹窗详情（超加分）
  void _showDetailDialog(BuildContext context, HealthReport report) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(report.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("ID：${report.reporterId}"),
            const SizedBox(height: 8),
            Text("狀態：${report.status}"),
            const SizedBox(height: 8),
            Text("時間：${report.reportTime}"),
            const SizedBox(height: 8),
            Text("備註：${report.description ?? '無'}"),
          ],
        ),
        actions: [
          TextButton(
            child: const Text("關閉"),
            onPressed: () => Navigator.pop(context),
          )
        ],
      ),
    );
  }
}