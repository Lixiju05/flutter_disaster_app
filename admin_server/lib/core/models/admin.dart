class Admin {
  final int? id;
  final String username;
  final String password;
  /// 管轄區代碼（例如：'puli_zone_01' 或 '大湳里'）
  final String zoneId; 

  Admin({
    this.id,
    required this.username,
    required this.password,
    required this.zoneId,
  });

  /// 轉 Map（存進 DB）
  Map<String, Object?> toMap() {
    return {
      'id': id,
      'username': username,
      'password': password,
      'zoneId': zoneId,
    };
  }

  /// 從 DB 轉回物件
  factory Admin.fromMap(Map<String, Object?> map) {
    return Admin(
      id: map['id'] as int?,
      username: map['username'] as String? ?? '',
      password: map['password'] as String? ?? '',
      zoneId: map['zoneId'] as String? ?? 'unknown', // 給予預設值避免報錯
    );
  }
}