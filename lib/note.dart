class Note {
  const Note({
    this.id,
    this.userId,
    this.authorEmail,
    required this.title,
    required this.content,
    required this.createdAt,
  });

  final int? id;
  final int? userId;
  final String? authorEmail;
  final String title;
  final String content;
  final int createdAt;

  DateTime get createdDate => DateTime.fromMillisecondsSinceEpoch(createdAt);

  factory Note.fromJson(Map<String, dynamic> json) {
    return Note(
      id: json['id'] as int?,
      userId: json['user_id'] as int?,
      authorEmail: json['author_email'] as String?,
      title: json['title'] as String? ?? '',
      content: json['content'] as String? ?? '',
      createdAt: json['createdAt'] as int? ?? 0,
    );
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'id': id,
      'title': title,
      'content': content,
      'createdAt': createdAt,
    };
  }

  factory Note.fromMap(Map<String, dynamic> map) => Note.fromJson(map);
}
