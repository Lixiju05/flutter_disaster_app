class LoginResponse {
  final bool success;
  final String token;
  final String adminId;

  LoginResponse({
    required this.success,
    required this.token,
    required this.adminId,
  });

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    return LoginResponse(
      success: json['success'],
      token: json['token'],
      adminId: json['adminId'],
    );
  }
}