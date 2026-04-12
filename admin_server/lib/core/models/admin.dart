class Admin {
  final int? id;
  final String username;
  final String password;

  Admin({
    this.id,
    required this.username,
    required this.password,
  });

  /// 轉 Map（存進 DB）
  Map<String, Object?> toMap() {
    return {
      'id': id,
      'username': username,
      'password': password,
    };
  }

  /// 從 DB 轉回物件
  factory Admin.fromMap(Map<String, Object?> map) {
    return Admin(
      id: map['id'] as int?,
      username: map['username'] as String,
      password: map['password'] as String,
    );
  }
}