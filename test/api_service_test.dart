import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:aplicacion_moviles/api_service.dart';

void main() {
  test('login interpreta la sesión devuelta por la API', () async {
    final client = MockClient((request) async {
      expect(request.url.path, '/api/auth/login');
      return http.Response(
        jsonEncode(<String, dynamic>{
          'success': true,
          'data': <String, dynamic>{
            'user_id': 7,
            'email': 'ana@example.com',
            'role': 'user',
            'access_token': 'access',
            'refresh_token': 'refresh',
          },
        }),
        200,
        headers: <String, String>{'content-type': 'application/json'},
      );
    });
    final api = ApiService(client: client)..initialize(baseUrl: 'http://localhost:5000/api');

    final session = await api.login('ana@example.com', 'Secure123!');

    expect(session.userId, 7);
    expect(session.accessToken, 'access');
  });

  test('conserva el mensaje estructurado de error', () async {
    final client = MockClient((request) async => http.Response(
          jsonEncode(<String, dynamic>{
            'success': false,
            'error': <String, dynamic>{
              'code': 'DUPLICATE_TITLE',
              'message': 'Ya existe una nota con ese título',
            },
          }),
          409,
          headers: <String, String>{'content-type': 'application/json'},
        ));
    final api = ApiService(client: client)..initialize(baseUrl: 'http://localhost:5000/api');

    expect(
      () => api.createNote('token', title: 'Repetida', content: 'Contenido'),
      throwsA(isA<ApiException>().having((error) => error.code, 'code', 'DUPLICATE_TITLE')),
    );
  });
}
