class HealthReport {
  final String reporterId;
  final String name;
  final String status;
  final String? description;
  final DateTime reportTime;

  HealthReport({
    required this.reporterId,
    required this.name,
    required this.status,
    this.description,
    required this.reportTime,
  });

  factory HealthReport.fromJson(Map<String, dynamic> json) {
    return HealthReport(
      reporterId: json['reporterId'],
      name: json['name'],
      status: json['status'],
      description: json['description'],
      reportTime: DateTime.parse(json['reportTime']),
    );
  }

  Map<String, dynamic> toJson() => {
        'reporterId': reporterId,
        'name': name,
        'status': status,
        'description': description,
        'reportTime': reportTime.toIso8601String(),
      };
}
