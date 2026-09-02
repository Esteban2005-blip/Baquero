import 'dart:async';
import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import 'note.dart';
import 'session.dart';

class ApiException implements Exception {
  const ApiException(this.message, {this.code = 'API_ERROR', this.statusCode});

  final String message;
  final String code;
  final int? statusCode;

  @override
  String toString() => message;
}

class ApiService {
  ApiService({http.Client? client}) : _client = client ?? http.Client();

  static final ApiService instance = ApiService();

  final http.Client _client;
  String _baseUrl = 'http://10.0.2.2:5000/api';
  Duration _timeout = const Duration(seconds: 30);

  void initialize({String? baseUrl, int? timeoutSeconds}) {
    final configuredBaseUrl =
        dotenv.isInitialized ? dotenv.env['API_BASE_URL'] : null;
    final configuredTimeoutValue =
        dotenv.isInitialized ? dotenv.env['API_TIMEOUT'] : null;
    _baseUrl = baseUrl ?? configuredBaseUrl ?? _baseUrl;
    final configuredTimeout = int.tryParse(configuredTimeoutValue ?? '');
    _timeout = Duration(seconds: timeoutSeconds ?? configuredTimeout ?? 30);
  }

  Future<Session> login(String email, String password) async {
    final body = await _request(
      'POST',
      '/auth/login',
      payload: <String, dynamic>{'email': email, 'password': password},
    );
    return Session.fromJson(_data(body));
  }

  Future<Session> register(String email, String password) async {
    final body = await _request(
      'POST',
      '/auth/register',
      payload: <String, dynamic>{'email': email, 'password': password},
    );
    return Session.fromJson(_data(body));
  }

  Future<List<Note>> getNotes(String accessToken) async {
    final body = await _request('GET', '/notes', accessToken: accessToken);
    final raw = body['data'];
    if (raw is! List) return <Note>[];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(Note.fromJson)
        .toList(growable: false);
  }

  Future<Note> createNote(
    String accessToken, {
    required String title,
    required String content,
  }) async {
    final body = await _request(
      'POST',
      '/notes',
      accessToken: accessToken,
      payload: <String, dynamic>{
        'title': title,
        'content': content,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
      },
    );
    return Note.fromJson(_data(body));
  }

  Future<Note> updateNote(
    String accessToken,
    int id, {
    required String title,
    required String content,
  }) async {
    final body = await _request(
      'PUT',
      '/notes/$id',
      accessToken: accessToken,
      payload: <String, dynamic>{'title': title, 'content': content},
    );
    return Note.fromJson(_data(body));
  }

  Future<void> deleteNote(String accessToken, int id) async {
    await _request('DELETE', '/notes/$id', accessToken: accessToken);
  }

  Future<void> logout(String accessToken) async {
    await _request('POST', '/auth/logout', accessToken: accessToken);
  }

  Map<String, dynamic> _data(Map<String, dynamic> body) {
    final data = body['data'];
    if (data is Map<String, dynamic>) return data;
    throw const ApiException('La API devolvió una respuesta inesperada.');
  }

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    String? accessToken,
    Map<String, dynamic>? payload,
  }) async {
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      if (accessToken != null) 'Authorization': 'Bearer $accessToken',
    };

    try {
      final uri = Uri.parse('$_baseUrl$path');
      late http.Response response;
      switch (method) {
        case 'POST':
          response = await _client
              .post(uri,
                  headers: headers,
                  body: jsonEncode(payload ?? <String, dynamic>{}))
              .timeout(_timeout);
          break;
        case 'PUT':
          response = await _client
              .put(uri,
                  headers: headers,
                  body: jsonEncode(payload ?? <String, dynamic>{}))
              .timeout(_timeout);
          break;
        case 'DELETE':
          response =
              await _client.delete(uri, headers: headers).timeout(_timeout);
          break;
        default:
          response = await _client.get(uri, headers: headers).timeout(_timeout);
      }

      final decoded = response.body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return decoded;
      }

      final error = decoded['error'];
      final details =
          error is Map<String, dynamic> ? error : <String, dynamic>{};
      throw ApiException(
        details['message'] as String? ?? 'No se pudo completar la operación.',
        code: details['code'] as String? ?? 'HTTP_${response.statusCode}',
        statusCode: response.statusCode,
      );
    } on TimeoutException {
      throw const ApiException(
        'La API tardó demasiado en responder. Inténtalo de nuevo.',
        code: 'TIMEOUT',
      );
    } on FormatException {
      throw const ApiException(
        'La API devolvió datos que no se pudieron interpretar.',
        code: 'INVALID_RESPONSE',
      );
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException(
        'No se pudo conectar con la API. Verifica que el servidor esté activo.',
        code: 'CONNECTION_ERROR',
      );
    }
  }
}
