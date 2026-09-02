class Session {
  const Session({
    required this.userId,
    required this.email,
    required this.role,
    required this.accessToken,
    required this.refreshToken,
  });

  final int userId;
  final String email;
  final String role;
  final String accessToken;
  final String refreshToken;

  factory Session.fromJson(Map<String, dynamic> json) {
    return Session(
      userId: json['user_id'] as int,
      email: json['email'] as String,
      role: json['role'] as String? ?? 'user',
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String? ?? '',
    );
  }
}
