import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'session.dart';

class SessionStorage {
  SessionStorage({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _sessionKey = 'baquero.session';
  final FlutterSecureStorage _storage;

  Future<void> save(Session session) async {
    await _storage.write(key: _sessionKey, value: jsonEncode(session.toJson()));
  }

  Future<Session?> read() async {
    final value = await _storage.read(key: _sessionKey);
    if (value == null) return null;
    try {
      return Session.fromJson(jsonDecode(value) as Map<String, dynamic>);
    } on Object {
      await clear();
      return null;
    }
  }

  Future<void> clear() => _storage.delete(key: _sessionKey);
}
