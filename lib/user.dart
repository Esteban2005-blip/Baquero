class User {
  final int? id;
  final String name;
  final String email;
  final String password;
  final String role;

  User({this.id, required this.name, required this.email, required this.password, required this.role});

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email.toLowerCase().trim(),
      'password': password.trim(),
      'role': role,
    };
  }

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'] as int?,
      name: map['name'] as String,
      email: map['email'] as String,
      password: map['password'] as String,
      role: map['role'] as String,
    );
  }
}
