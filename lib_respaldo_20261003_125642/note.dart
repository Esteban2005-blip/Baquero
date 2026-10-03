import 'package:json_annotation/json_annotation.dart';

part 'note.g.dart';

@JsonSerializable(checked: true)
class Note {
  const Note({
    this.id,
    this.clientId,
    this.userId,
    this.authorEmail,
    required this.title,
    required this.content,
    required this.createdAt,
  });
  final int? id;
  @JsonKey(name: 'client_id')
  final String? clientId;
  @JsonKey(name: 'user_id')
  final int? userId;
  @JsonKey(name: 'author_email')
  final String? authorEmail;
  final String title;
  final String content;
  final int createdAt;
  DateTime get createdDate => DateTime.fromMillisecondsSinceEpoch(createdAt);
  factory Note.fromJson(Map<String, dynamic> json) => _$NoteFromJson(json);
  Map<String, dynamic> toJson() => _$NoteToJson(this);
  factory Note.fromMap(Map<String, dynamic> map) => Note.fromJson(map);
  Map<String, dynamic> toMap() => toJson();
  Note withIdentity({int? id, String? clientId}) => Note(
    id: id ?? this.id,
    clientId: clientId ?? this.clientId,
    userId: userId,
    authorEmail: authorEmail,
    title: title,
    content: content,
    createdAt: createdAt,
  );
}
