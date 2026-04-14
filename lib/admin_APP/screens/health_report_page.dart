import 'package:flutter/material.dart';
import '../repositories/healthReport_repository.dart';
import '../../core/models/healthReport.dart';

class HealthReportPage extends StatefulWidget {
  const HealthReportPage({super.key});

  @override
  State<HealthReportPage> createState() => _HealthReportPageState();
}

class _HealthReportPageState extends State<HealthReportPage> {
  final HealthReportRepository repo = HealthReportRepository();
  final TextEditingController _searchController = TextEditingController();

  List<HealthReport> _reports = [];
  String selectedFilter = 'all';
  String searchKeyword = '';

  @override
  void initState() {
    super.initState();
    _reports = List<HealthReport>.from(repo.getReports());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final safeCount =
        _reports.where((r) => r.status == 'safe' || r.status == '安全').length;
    final injuredCount = _reports
        .where((r) => r.status == 'injured' || r.status == '輕傷')
        .length;
    final criticalCount = _reports
        .where((r) => r.status == 'critical' || r.status == '重傷')
        .length;

    final filteredReports = _getFilteredReports(_reports);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(
        elevation: 0,
        centerTitle: false,
        backgroundColor: const Color(0xFF1E3A5F),
        title: const Text(
          "健康回報管理",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _reports.isEmpty
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
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFF1E3A5F),
                          Color(0xFF2C5282),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF1E3A5F).withOpacity(0.18),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.16),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(
                                Icons.health_and_safety,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "回報列表",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    "即時查看災民健康與安全狀況",
                                    style: TextStyle(
                                      color: Color(0xFFD6E4F0),
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.14),
                                borderRadius: BorderRadius.circular(22),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.18),
                                ),
                              ),
                              child: Text(
                                "共 ${_reports.length} 筆",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        Row(
                          children: [
                            Expanded(
                              child: _buildFilterCard(
                                title: "全部",
                                count: _reports.length.toString(),
                                icon: Icons.list_alt,
                                color: Colors.white,
                                filterValue: 'all',
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _buildFilterCard(
                                title: "安全",
                                count: safeCount.toString(),
                                icon: Icons.verified_user,
                                color: Colors.green,
                                filterValue: 'safe',
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _buildFilterCard(
                                title: "輕傷",
                                count: injuredCount.toString(),
                                icon: Icons.healing,
                                color: Colors.orange,
                                filterValue: 'injured',
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _buildFilterCard(
                                title: "重傷",
                                count: criticalCount.toString(),
                                icon: Icons.warning_rounded,
                                color: Colors.red,
                                filterValue: 'critical',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: Row(
                    children: [
                      const Text(
                        "目前篩選：",
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E3A5F).withOpacity(0.08),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _getFilterLabel(selectedFilter),
                          style: const TextStyle(
                            color: Color(0xFF1E3A5F),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const Spacer(),
                      SizedBox(
                        width: 260,
                        child: TextField(
                          controller: _searchController,
                          onChanged: (value) {
                            setState(() {
                              searchKeyword = value.trim().toLowerCase();
                            });
                          },
                          decoration: InputDecoration(
                            hintText: "搜尋姓名 / ID",
                            prefixIcon: const Icon(Icons.search),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: filteredReports.isEmpty
                      ? const Center(
                          child: Text(
                            "此分類目前沒有資料",
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey,
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                          itemCount: filteredReports.length,
                          itemBuilder: (context, index) {
                            final report = filteredReports[index];
                            final statusColor = _getStatusColor(report.status);

                            return Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 14,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 6,
                                    height: 285,
                                    decoration: BoxDecoration(
                                      color: statusColor,
                                      borderRadius: const BorderRadius.only(
                                        topLeft: Radius.circular(20),
                                        bottomLeft: Radius.circular(20),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Container(
                                      decoration: const BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.only(
                                          topRight: Radius.circular(20),
                                          bottomRight: Radius.circular(20),
                                        ),
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.all(16),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Container(
                                                  padding:
                                                      const EdgeInsets.all(12),
                                                  decoration: BoxDecoration(
                                                    color: statusColor
                                                        .withOpacity(0.10),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            16),
                                                  ),
                                                  child: Icon(
                                                    _getStatusIcon(report.status),
                                                    color: statusColor,
                                                    size: 28,
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
                                                          fontSize: 20,
                                                          fontWeight:
                                                              FontWeight.w700,
                                                          letterSpacing: 0.3,
                                                          color:
                                                              Color(0xFF0F172A),
                                                        ),
                                                      ),
                                                      const SizedBox(height: 4),
                                                      Text(
                                                        "回報者 ID：${report.reporterId}",
                                                        style: const TextStyle(
                                                          fontSize: 13,
                                                          color:
                                                              Color(0xFF94A3B8),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                _buildStatusChip(report.status),
                                              ],
                                            ),
                                            const SizedBox(height: 18),
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
                                              (report.lat != null &&
                                                      report.lng != null)
                                                  ? "${report.lat}, ${report.lng}"
                                                  : "未提供位置",
                                            ),
                                            const SizedBox(height: 12),
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
                                              padding: const EdgeInsets.all(14),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFF8FAFC),
                                                borderRadius:
                                                    BorderRadius.circular(14),
                                                border: Border.all(
                                                  color: Colors.grey
                                                      .withOpacity(0.12),
                                                ),
                                              ),
                                              child: Text(
                                                (report.description != null &&
                                                        report.description!
                                                            .trim()
                                                            .isNotEmpty)
                                                    ? report.description!
                                                    : "無補充說明",
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  color: Color(0xFF475569),
                                                  height: 1.6,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: 14),
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.end,
                                              children: [
                                                OutlinedButton.icon(
                                                  onPressed: () {
                                                    _showEditDialog(report);
                                                  },
                                                  icon: const Icon(
                                                    Icons.edit_outlined,
                                                    size: 18,
                                                  ),
                                                  label: const Text("編輯"),
                                                  style:
                                                      OutlinedButton.styleFrom(
                                                    foregroundColor:
                                                        const Color(0xFF1E3A5F),
                                                    side: const BorderSide(
                                                      color: Color(0xFF1E3A5F),
                                                    ),
                                                    shape:
                                                        RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              12),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 10),
                                                OutlinedButton.icon(
                                                  onPressed: () {
                                                    _showDeleteDialog(report);
                                                  },
                                                  icon: const Icon(
                                                    Icons.delete_outline,
                                                    size: 18,
                                                  ),
                                                  label: const Text("刪除"),
                                                  style:
                                                      OutlinedButton.styleFrom(
                                                    foregroundColor: Colors.red,
                                                    side: const BorderSide(
                                                      color: Colors.red,
                                                    ),
                                                    shape:
                                                        RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              12),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 10),
                                                ElevatedButton.icon(
                                                  onPressed: () {
                                                    _showDetailDialog(
                                                        context, report);
                                                  },
                                                  icon: const Icon(
                                                    Icons.visibility_outlined,
                                                    size: 18,
                                                  ),
                                                  label: const Text("查看詳情"),
                                                  style: ElevatedButton.styleFrom(
                                                    elevation: 0,
                                                    backgroundColor:
                                                        const Color(0xFF1E3A5F),
                                                    foregroundColor: Colors.white,
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                      horizontal: 16,
                                                      vertical: 10,
                                                    ),
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              12),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  List<HealthReport> _getFilteredReports(List<HealthReport> reports) {
    List<HealthReport> result;

    switch (selectedFilter) {
      case 'safe':
        result = reports
            .where((r) => r.status == 'safe' || r.status == '安全')
            .toList();
        break;
      case 'injured':
        result = reports
            .where((r) => r.status == 'injured' || r.status == '輕傷')
            .toList();
        break;
      case 'critical':
        result = reports
            .where((r) => r.status == 'critical' || r.status == '重傷')
            .toList();
        break;
      case 'all':
      default:
        result = reports;
    }

    if (searchKeyword.isEmpty) return result;

    return result.where((r) {
      final name = r.name.toLowerCase();
      final id = r.reporterId.toLowerCase();
      return name.contains(searchKeyword) || id.contains(searchKeyword);
    }).toList();
  }

  String _getFilterLabel(String filter) {
    switch (filter) {
      case 'safe':
        return '安全';
      case 'injured':
        return '輕傷';
      case 'critical':
        return '重傷';
      case 'all':
      default:
        return '全部';
    }
  }

  Widget _buildFilterCard({
    required String title,
    required String count,
    required IconData icon,
    required Color color,
    required String filterValue,
  }) {
    final bool isSelected = selectedFilter == filterValue;

    return GestureDetector(
      onTap: () {
        setState(() {
          selectedFilter = filterValue;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.white.withOpacity(0.18)
              : Colors.white.withOpacity(0.10),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? Colors.white.withOpacity(0.45)
                : Colors.white.withOpacity(0.10),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 8),
            Text(
              count,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(
                color: Color(0xFFD6E4F0),
                fontSize: 12,
              ),
            ),
          ],
        ),
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: color.withOpacity(0.22),
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 28,
            child: Icon(
              icon,
              size: 18,
              color: const Color(0xFF1E3A5F),
            ),
          ),
          const SizedBox(width: 6),
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
                height: 1.4,
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

  void _showDeleteDialog(HealthReport report) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text("確認刪除"),
        content: Text("確定要刪除 ${report.name} 的健康回報資料嗎？"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("取消"),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _reports.remove(report);
              });
              Navigator.pop(context);

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("資料已刪除"),
                  backgroundColor: Colors.redAccent,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text("刪除"),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(HealthReport report) {
    final nameController = TextEditingController(text: report.name);
    final phoneController = TextEditingController(text: report.phone);
    final bloodTypeController =
        TextEditingController(text: report.bloodType ?? '');
    final descriptionController =
        TextEditingController(text: report.description ?? '');

    String selectedStatus = report.status;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text("編輯健康回報"),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: "姓名"),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: phoneController,
                    decoration: const InputDecoration(labelText: "聯絡電話"),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: bloodTypeController,
                    decoration: const InputDecoration(labelText: "血型"),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedStatus,
                    decoration: const InputDecoration(labelText: "狀態"),
                    items: const [
                      DropdownMenuItem(value: 'safe', child: Text('安全')),
                      DropdownMenuItem(value: 'injured', child: Text('輕傷')),
                      DropdownMenuItem(value: 'critical', child: Text('重傷')),
                      DropdownMenuItem(value: '安全', child: Text('安全（中文）')),
                      DropdownMenuItem(value: '輕傷', child: Text('輕傷（中文）')),
                      DropdownMenuItem(value: '重傷', child: Text('重傷（中文）')),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setDialogState(() {
                        selectedStatus = value;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descriptionController,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: "補充說明"),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("取消"),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  final index = _reports.indexOf(report);
                  if (index != -1) {
                    _reports[index] = HealthReport(
                      reporterId: report.reporterId,
                      name: nameController.text.trim().isEmpty
                          ? report.name
                          : nameController.text.trim(),
                      status: selectedStatus,
                      description: descriptionController.text.trim(),
                      reportTime: report.reportTime,
                      phone: phoneController.text.trim().isEmpty
                          ? report.phone
                          : phoneController.text.trim(),
                      bloodType: bloodTypeController.text.trim().isEmpty
                          ? null
                          : bloodTypeController.text.trim(),
                      lat: report.lat,
                      lng: report.lng,
                    );
                  }
                });

                Navigator.pop(context);

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("資料已更新"),
                    backgroundColor: Colors.green,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E3A5F),
                foregroundColor: Colors.white,
              ),
              child: const Text("保存"),
            ),
          ],
        ),
      ),
    );
  }

  void _showDetailDialog(BuildContext context, HealthReport report) {
    String statusText;
    switch (report.status) {
      case 'safe':
        statusText = '安全';
        break;
      case 'injured':
        statusText = '輕傷';
        break;
      case 'critical':
        statusText = '重傷';
        break;
      default:
        statusText = report.status;
    }

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: _getStatusColor(report.status).withOpacity(0.12),
              child: Icon(
                _getStatusIcon(report.status),
                color: _getStatusColor(report.status),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                report.name,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDialogText("回報者 ID", report.reporterId),
              _buildDialogText("聯絡電話", report.phone),
              _buildDialogText("血型", report.bloodType ?? '未填寫'),
              _buildDialogText("狀態", statusText),
              _buildDialogText("時間", _formatTime(report.reportTime)),
              _buildDialogText(
                "位置",
                (report.lat != null && report.lng != null)
                    ? "${report.lat}, ${report.lng}"
                    : "未提供位置",
              ),
              _buildDialogText(
                "備註",
                (report.description != null &&
                        report.description!.trim().isNotEmpty)
                    ? report.description!
                    : "無",
              ),
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

  Widget _buildDialogText(String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF334155),
            height: 1.5,
          ),
          children: [
            TextSpan(
              text: "$title：",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}