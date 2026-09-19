// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'note.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Note _$NoteFromJson(Map<String, dynamic> json) => $checkedCreate(
  'Note',
  json,
  ($checkedConvert) {
    final val = Note(
      id: $checkedConvert('id', (v) => (v as num?)?.toInt()),
      clientId: $checkedConvert('client_id', (v) => v as String?),
      userId: $checkedConvert('user_id', (v) => (v as num?)?.toInt()),
      authorEmail: $checkedConvert('author_email', (v) => v as String?),
      title: $checkedConvert('title', (v) => v as String),
      content: $checkedConvert('content', (v) => v as String),
      createdAt: $checkedConvert('createdAt', (v) => (v as num).toInt()),
    );
    return val;
  },
  fieldKeyMap: const {
    'clientId': 'client_id',
    'userId': 'user_id',
    'authorEmail': 'author_email',
  },
);

Map<String, dynamic> _$NoteToJson(Note instance) => <String, dynamic>{
  'id': instance.id,
  'client_id': instance.clientId,
  'user_id': instance.userId,
  'author_email': instance.authorEmail,
  'title': instance.title,
  'content': instance.content,
  'createdAt': instance.createdAt,
};
