// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Session _$SessionFromJson(Map<String, dynamic> json) => $checkedCreate(
  'Session',
  json,
  ($checkedConvert) {
    final val = Session(
      userId: $checkedConvert('user_id', (v) => (v as num).toInt()),
      email: $checkedConvert('email', (v) => v as String),
      role: $checkedConvert('role', (v) => v as String? ?? 'user'),
      accessToken: $checkedConvert('access_token', (v) => v as String),
      refreshToken: $checkedConvert('refresh_token', (v) => v as String),
    );
    return val;
  },
  fieldKeyMap: const {
    'userId': 'user_id',
    'accessToken': 'access_token',
    'refreshToken': 'refresh_token',
  },
);

Map<String, dynamic> _$SessionToJson(Session instance) => <String, dynamic>{
  'user_id': instance.userId,
  'email': instance.email,
  'role': instance.role,
  'access_token': instance.accessToken,
  'refresh_token': instance.refreshToken,
};
