import 'package:json_annotation/json_annotation.dart';

part 'session.g.dart';

@JsonSerializable(checked: true)
class Session {
  const Session({
    required this.userId,
    required this.email,
    this.role = 'user',
    required this.accessToken,
    required this.refreshToken,
  });
  @JsonKey(name: 'user_id')
  final int userId;
  final String email;
  @JsonKey(defaultValue: 'user')
  final String role;
  @JsonKey(name: 'access_token')
  final String accessToken;
  @JsonKey(name: 'refresh_token')
  final String refreshToken;
  factory Session.fromJson(Map<String, dynamic> json) =>
      _$SessionFromJson(json);
  Map<String, dynamic> toJson() => _$SessionToJson(this);
}
