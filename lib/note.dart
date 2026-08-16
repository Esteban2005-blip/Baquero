class Note {
  final int? id;
  final String title;
  final String content;
  final int createdAt;

  Note({this.id, required this.title, required this.content, required this.createdAt});

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'createdAt': createdAt,
    };
  }

  factory Note.fromMap(Map<String, dynamic> map) {
    return Note(
      id: map['id'] as int?,
      title: map['title'] as String,
      content: map['content'] as String,
      createdAt: map['createdAt'] as int,
    );
  }
}
