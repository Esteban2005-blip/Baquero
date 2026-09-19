import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aplicacion_moviles/api_service.dart';
import 'package:aplicacion_moviles/session.dart';
import 'package:aplicacion_moviles/note.dart';
import 'support.dart';

void main() {
  late MemoryStorage storage;
  late Dio dio;
  ApiService api(Future<ResponseBody> Function(RequestOptions) handler) {
    dio.httpClientAdapter = TestAdapter(handler);
    return ApiService(
      dio: dio,
      storage: storage,
      baseUrl: 'http://localhost:5000/api',
      retryDelay: Duration.zero,
      logger: (_) {},
    );
  }

  setUp(() {
    storage = MemoryStorage()..value = session;
    dio = Dio();
  });
  test('login saves session without sending access token', () async {
    final service = api((r) async {
      expect(r.headers['Authorization'], isNull);
      return jsonResponse({'data': session.toJson()});
    });
    storage.value = null;
    expect((await service.login('ana@example.com', 'password')).userId, 7);
    expect(storage.value?.refreshToken, 'refresh');
  });
  test('reads current secure storage credentials on every request', () async {
    final sent = <String>[];
    final service = api((r) async {
      sent.add(r.headers['Authorization'] as String);
      return notesResponse();
    });
    await service.getNotes();
    await storage.save(sessionFromToken('changed'));
    await service.getNotes();
    expect(sent, ['Bearer old', 'Bearer changed']);
  });
  test(
    'three concurrent 401 cause one refresh and preserve refresh token',
    () async {
      var refreshes = 0;
      final service = api((r) async {
        if (r.path == '/auth/refresh') {
          refreshes++;
          expect(r.headers['Authorization'], 'Bearer refresh');
          await Future<void>.delayed(const Duration(milliseconds: 20));
          return jsonResponse({
            'data': {...session.toJson(), 'access_token': 'new'}
              ..remove('refresh_token'),
          });
        }
        if (r.headers['Authorization'] == 'Bearer old') {
          return jsonResponse({
            'error': {'code': 'TOKEN_EXPIRED'},
          }, 401);
        }
        expect(r.headers['Authorization'], 'Bearer new');
        expect(r.extra['authRetried'], true);
        return notesResponse();
      });
      await Future.wait([
        service.getNotes(),
        service.getNotes(),
        service.getNotes(),
      ]);
      expect(refreshes, 1);
      expect(storage.value?.refreshToken, 'refresh');
      expect(storage.value?.accessToken, 'new');
    },
  );
  test('persistent 401 does not cause refresh loop', () async {
    var refreshes = 0, requests = 0;
    final service = api((r) async {
      if (r.path == '/auth/refresh') {
        refreshes++;
        return jsonResponse({'data': sessionFromToken('new').toJson()});
      }
      requests++;
      return jsonResponse({
        'error': {'code': 'UNAUTHORIZED'},
      }, 401);
    });
    await expectLater(service.getNotes(), throwsA(isA<ApiException>()));
    expect(refreshes, 1);
    expect(requests, 2);
    expect(storage.value, isNull);
  });
  test('invalid refresh clears session without recursion', () async {
    var count = 0;
    final service = api((r) async {
      count++;
      return jsonResponse({}, 401);
    });
    await expectLater(service.getNotes(), throwsA(isA<ApiException>()));
    expect(count, 2);
    expect(storage.value, isNull);
  });
  test('transient refresh failure retains credentials', () async {
    final service = api((r) async {
      if (r.path == '/auth/refresh') {
        throw DioException(
          requestOptions: r,
          type: DioExceptionType.connectionError,
        );
      }
      return jsonResponse({}, 401);
    });
    await expectLater(service.getNotes(), throwsA(isA<ApiException>()));
    expect(storage.value, isNotNull);
  });
  test('422 preserves field errors and never retries', () async {
    var count = 0;
    final service = api((r) async {
      count++;
      return jsonResponse({
        'error': {
          'code': 'VALIDATION_ERROR',
          'message': 'Revisa los campos.',
          'fields': {
            'title': ['Título inválido'],
            'content': ['Contenido requerido'],
          },
        },
      }, 422);
    });
    await expectLater(
      service.createNote(
        title: 'x',
        content: '',
        operationId: '12345678',
        createdAt: 1,
      ),
      throwsA(
        isA<ApiException>()
            .having((e) => e.field('title'), 'title', 'Título inválido')
            .having((e) => e.family, 'family', FailureFamily.client),
      ),
    );
    expect(count, 1);
  });
  test('creation retries with identical idempotency key and data', () async {
    final requests = <RequestOptions>[];
    final service = api((r) async {
      requests.add(r);
      if (requests.length < 3) return jsonResponse({}, 503);
      return jsonResponse({
        'data': {'id': 1, 'title': 'Test', 'content': 'Body', 'createdAt': 1},
      });
    });
    await service.createNote(
      title: 'Test',
      content: 'Body',
      operationId: '12345678',
      createdAt: 1,
    );
    expect(requests.length, 3);
    expect(requests.map((r) => r.headers['Idempotency-Key']).toSet(), {
      '12345678',
    });
    expect(requests.map((r) => (r.data as Map)['createdAt']).toSet(), {1});
  });
  test('login POST does not retry server errors', () async {
    var count = 0;
    final service = api((r) async {
      count++;
      return jsonResponse({}, 503);
    });
    await expectLater(service.login('a', 'b'), throwsA(isA<ApiException>()));
    expect(count, 1);
  });
  test('consumes all pagination pages', () async {
    final service = api(
      (r) async => jsonResponse({
        'data': [
          {
            'id': r.uri.queryParameters['page'] == '1' ? 1 : 2,
            'title': 'Test',
            'content': 'Body',
            'createdAt': 1,
          },
        ],
        'pagination': {'total': 2},
      }),
    );
    expect((await service.getNotes()).length, 2);
  });
  test('malformed success is not an empty list', () async {
    final service = api(
      (r) async => jsonResponse({
        'data': [
          {'id': 'wrong'},
        ],
        'pagination': {'total': 1},
      }),
    );
    await expectLater(
      service.getNotes(),
      throwsA(
        isA<ApiException>().having((e) => e.code, 'code', 'INVALID_RESPONSE'),
      ),
    );
  });
  test('production rejects HTTP and disables logs', () {
    expect(
      () => ApiService(baseUrl: 'http://localhost/api', production: true),
      throwsArgumentError,
    );
    expect(
      ApiService(
        baseUrl: 'https://example.com/api',
        production: true,
      ).dio.interceptors.whereType<SafeLogInterceptor>(),
      isEmpty,
    );
  });
  test('logs omit credentials and query strings', () async {
    final messages = <String>[];
    dio.httpClientAdapter = TestAdapter((r) async => notesResponse());
    final service = ApiService(
      dio: dio,
      storage: storage,
      logger: messages.add,
    );
    await service.getNotes();
    for (final secret in ['Bearer', 'old', 'page=', 'refresh']) {
      expect(messages.join(), isNot(contains(secret)));
    }
  });
  test('logout during refresh cannot resurrect the old session', () async {
    final started = Completer<void>();
    final release = Completer<void>();
    final service = api((r) async {
      if (r.path == '/auth/refresh') {
        started.complete();
        await release.future;
        return jsonResponse({'data': sessionFromToken('new').toJson()});
      }
      return jsonResponse({}, 401);
    });
    final request = service.getNotes();
    final assertion = expectLater(request, throwsA(isA<ApiException>()));
    await started.future;
    await storage.clear();
    release.complete();
    await assertion;
    expect(storage.value, isNull);
  });
  test('a transport retry cannot replay a mutation as a different account', () async {
    var requests = 0;
    final service = api((r) async {
      requests++;
      await storage.save(Session.fromJson({...session.toJson(), 'user_id': 8,
        'access_token': 'other', 'refresh_token': 'other-refresh'}));
      return jsonResponse({}, 503);
    });
    await expectLater(service.updateNote(1, title: 'Test', content: 'Body'),
      throwsA(isA<ApiException>().having((e) => e.code, 'code', 'SESSION_CHANGED')));
    expect(requests, 1);
  });
  test('invalid JSON is a protocol failure and is not retried', () async {
    var requests = 0;
    final service = api((r) async {
      requests++;
      return ResponseBody.fromString('{broken', 200,
        headers: {Headers.contentTypeHeader: [Headers.jsonContentType]});
    });
    await expectLater(service.getNotes(), throwsA(isA<ApiException>()
      .having((e) => e.code, 'code', 'INVALID_RESPONSE')));
    expect(requests, 1);
  });
  test('generated mappers preserve nullable optional fields and server names', () {
    final note = Note.fromJson({'title':'Test','content':'Body','createdAt':1});
    expect(note.id, isNull);
    expect(note.authorEmail, isNull);
    expect(note.toJson(), contains('user_id'));
    final data = session.toJson()..remove('role');
    expect(Session.fromJson(data).role, 'user');
  });
  for (final type in [
    DioExceptionType.connectionError,
    DioExceptionType.receiveTimeout,
  ]) {
    test('translates $type', () async {
      final service = api(
        (r) async => throw DioException(requestOptions: r, type: type),
      );
      await expectLater(
        service.getNotes(),
        throwsA(
          isA<ApiException>().having(
            (e) => e.family,
            'family',
            type == DioExceptionType.connectionError
                ? FailureFamily.connectivity
                : FailureFamily.timeout,
          ),
        ),
      );
    });
  }
}

Session sessionFromToken(String token) =>
    Session.fromJson({...session.toJson(), 'access_token': token});
