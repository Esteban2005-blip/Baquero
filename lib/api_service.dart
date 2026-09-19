import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:json_annotation/json_annotation.dart';
import 'note.dart';
import 'session.dart';
import 'session_storage.dart';

enum FailureFamily { connectivity, timeout, client, server }

class ApiException implements Exception {
  const ApiException(
    this.message, {
    this.code = 'API_ERROR',
    this.statusCode,
    this.family = FailureFamily.server,
    this.fields = const {},
    this.draft,
  });
  final Note? draft;
  final String message;
  final String code;
  final int? statusCode;
  final FailureFamily family;
  final Map<String, List<String>> fields;
  bool get transient =>
      family != FailureFamily.client &&
      code != 'INVALID_RESPONSE' &&
      code != 'TLS_ERROR';
  String? field(String name) => fields[name]?.join(' ');
  @override
  String toString() => message;

  static ApiException fromDio(DioException e) {
    if (e.error is ApiException) return e.error as ApiException;
    if (e.error is FormatException ||
        e.error is TypeError ||
        e.error is CheckedFromJsonException) {
      return ApiService.invalidResponse;
    }
    if (e.type == DioExceptionType.cancel) {
      return const ApiException(
        'Operación cancelada.',
        code: 'CANCELLED',
        family: FailureFamily.client,
      );
    }
    if ({
      DioExceptionType.connectionTimeout,
      DioExceptionType.receiveTimeout,
      DioExceptionType.sendTimeout,
    }.contains(e.type)) {
      return const ApiException(
        'El servidor tardó demasiado. Inténtalo de nuevo.',
        code: 'TIMEOUT',
        family: FailureFamily.timeout,
      );
    }
    if (e.type == DioExceptionType.badCertificate) {
      return const ApiException(
        'No se pudo verificar la conexión segura.',
        code: 'TLS_ERROR',
        family: FailureFamily.connectivity,
      );
    }
    if (e.type == DioExceptionType.connectionError ||
        (e.response == null && e.type != DioExceptionType.cancel)) {
      return const ApiException(
        'Sin conexión con el servidor. Tus cambios se conservarán en este dispositivo.',
        code: 'CONNECTION_ERROR',
        family: FailureFamily.connectivity,
      );
    }
    final status = e.response?.statusCode;
    final body = e.response?.data;
    final details = body is Map && body['error'] is Map
        ? body['error'] as Map
        : const {};
    final rawFields = details['fields'];
    final fields = <String, List<String>>{};
    if (rawFields is Map) {
      for (final entry in rawFields.entries) {
        fields[entry.key.toString()] = entry.value is List
            ? (entry.value as List).map((v) => v.toString()).toList()
            : [entry.value.toString()];
      }
    }
    final client = status != null && status >= 400 && status < 500;
    return ApiException(
      details['message'] is String
          ? details['message'] as String
          : client
          ? 'No se pudo completar la solicitud.'
          : 'El servidor no está disponible. Inténtalo más tarde.',
      code: details['code']?.toString() ?? 'HTTP_$status',
      statusCode: status,
      family: client ? FailureFamily.client : FailureFamily.server,
      fields: fields,
    );
  }
}

class ApiService {
  ApiService({
    Dio? dio,
    SessionStorage? storage,
    String? baseUrl,
    bool production = kReleaseMode,
    Duration retryDelay = const Duration(milliseconds: 400),
    void Function(String)? logger,
  }) : storage = storage ?? SessionStorage(),
       dio = dio ?? Dio() {
    const environment = String.fromEnvironment(
      'APP_ENV',
      defaultValue: 'development',
    );
    const configured = String.fromEnvironment('API_BASE_URL');
    final url =
        baseUrl ??
        (configured.isEmpty ? 'http://10.0.2.2:5000/api' : configured);
    final uri = Uri.tryParse(url);
    if (uri == null ||
        !uri.hasAuthority ||
        !{'http', 'https'}.contains(uri.scheme) ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        ((production || environment == 'production') &&
            uri.scheme != 'https')) {
      throw ArgumentError(
        'API_BASE_URL debe ser una URL válida y usar HTTPS en producción.',
      );
    }
    this.dio.options = BaseOptions(
      baseUrl: url.replaceFirst(RegExp(r'/$'), ''),
      connectTimeout: const Duration(seconds: 10),
      sendTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 20),
      followRedirects: false,
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
    );
    this.dio.interceptors.addAll([
      AuthenticationInterceptor(this.storage),
      RefreshInterceptor(this.dio, this.storage),
      SafeRetryInterceptor(this.dio, retryDelay),
      if (!production && environment != 'production')
        SafeLogInterceptor(logger ?? debugPrint),
    ]);
  }
  final Dio dio;
  final SessionStorage storage;

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Object? data,
    Map<String, dynamic>? headers,
    bool public = false,
  }) async {
    try {
      final response = await dio.request<dynamic>(
        path,
        data: data,
        options: Options(
          method: method,
          headers: headers,
          extra: {'public': public},
        ),
      );
      if (response.data is! Map<String, dynamic>) throw const FormatException();
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    } on FormatException {
      throw invalidResponse;
    }
  }

  static const invalidResponse = ApiException(
    'El servidor devolvió datos incompatibles.',
    code: 'INVALID_RESPONSE',
  );
  T _parse<T>(T Function() parse) {
    try {
      return parse();
    } on CheckedFromJsonException {
      throw invalidResponse;
    } on TypeError {
      throw invalidResponse;
    } on FormatException {
      throw invalidResponse;
    }
  }

  Map<String, dynamic> _data(Map<String, dynamic> body) =>
      _parse(() => body['data'] as Map<String, dynamic>);
  Future<Session> _authenticate(
    String path,
    String email,
    String password,
  ) async {
    final body = await _request(
      'POST',
      path,
      public: true,
      data: {'email': email, 'password': password},
    );
    final session = _parse(() => Session.fromJson(_data(body)));
    await storage.save(session);
    return session;
  }

  Future<Session> login(String email, String password) =>
      _authenticate('/auth/login', email, password);
  Future<Session> register(String email, String password) =>
      _authenticate('/auth/register', email, password);
  Future<List<Note>> getNotes() async {
    final notes = <Note>[];
    for (var page = 1; ; page++) {
      final body = await _request('GET', '/notes?page=$page&limit=50');
      final batch = _parse(
        () => (body['data'] as List)
            .map((v) => Note.fromJson(v as Map<String, dynamic>))
            .toList(),
      );
      notes.addAll(batch);
      final total = _parse(() => (body['pagination'] as Map)['total'] as int);
      if (notes.length >= total) break;
      if (batch.isEmpty || page >= 10000) throw invalidResponse;
    }
    return notes;
  }

  Future<Note> createNote({
    required String title,
    required String content,
    required String operationId,
    required int createdAt,
  }) async {
    final body = await _request(
      'POST',
      '/notes',
      headers: {'Idempotency-Key': operationId},
      data: {'title': title, 'content': content, 'createdAt': createdAt},
    );
    return _parse(() => Note.fromJson(_data(body)));
  }

  Future<Note> updateNote(
    int id, {
    required String title,
    required String content,
  }) async {
    final body = await _request(
      'PUT',
      '/notes/$id',
      data: {'title': title, 'content': content},
    );
    return _parse(() => Note.fromJson(_data(body)));
  }

  Future<void> deleteNote(int id) async {
    try {
      await _request('DELETE', '/notes/$id');
    } on ApiException catch (e) {
      if (e.statusCode != 404) rethrow;
    }
  }

  Future<void> logout() async {
    try {
      final session = await storage.read();
      if (session != null) {
        await _request(
          'POST',
          '/auth/logout',
          public: true,
          headers: {'Authorization': 'Bearer ${session.refreshToken}'},
        );
      }
    } finally {
      await storage.clear();
    }
  }
}

class AuthenticationInterceptor extends Interceptor {
  AuthenticationInterceptor(this.storage);
  final SessionStorage storage;
  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    try {
      if (options.extra['public'] != true) {
        final session = await storage.read();
        if (session == null) {
          throw const ApiException(
            'Vuelve a iniciar sesión.',
            code: 'SESSION_EXPIRED',
            statusCode: 401,
            family: FailureFamily.client,
          );
        }
        final account = options.extra['sessionIdentity'];
        if (account != null && account != session.refreshToken) {
          throw const ApiException(
            'La cuenta cambió. Vuelve a realizar la operación.',
            code: 'SESSION_CHANGED',
            family: FailureFamily.client,
          );
        }
        options.extra['sessionIdentity'] = session.refreshToken;
        options.headers['Authorization'] = 'Bearer ${session.accessToken}';
      }
      handler.next(options);
    } catch (e) {
      handler.reject(DioException(requestOptions: options, error: e));
    }
  }
}

class RefreshInterceptor extends Interceptor {
  RefreshInterceptor(this.dio, this.storage);
  final Dio dio;
  final SessionStorage storage;
  Future<void>? _refreshing;

  Future<void> _refresh() async {
    final previous = await storage.read();
    if (previous == null) {
      throw const ApiException(
        'Vuelve a iniciar sesión.',
        code: 'SESSION_EXPIRED',
        statusCode: 401,
        family: FailureFamily.client,
      );
    }
    try {
      final response = await dio.post<dynamic>(
        '/auth/refresh',
        options: Options(
          headers: {'Authorization': 'Bearer ${previous.refreshToken}'},
          extra: {'public': true, 'refresh': true},
        ),
      );
      final data = (response.data as Map)['data'] as Map<String, dynamic>;
      final next = Session.fromJson({
        ...data,
        'refresh_token': data['refresh_token'] ?? previous.refreshToken,
      });
      // Logging out or switching accounts while refreshing must not resurrect a session.
      if ((await storage.read())?.refreshToken == previous.refreshToken) {
        await storage.save(next);
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401 || e.response?.statusCode == 403) {
        await storage.clear();
      }
      rethrow;
    } on Object {
      throw ApiService.invalidResponse;
    }
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final error = err;
    final options = error.requestOptions;
    if (error.response?.statusCode != 401 ||
        options.extra['public'] == true ||
        options.extra['authRetried'] == true) {
      if (error.response?.statusCode == 401 &&
          options.extra['authRetried'] == true) {
        await storage.clear();
      }
      handler.next(error);
      return;
    }
    try {
      final current = await storage.read();
      if (current != null &&
          options.headers['Authorization'] == 'Bearer ${current.accessToken}') {
        final flight = _refreshing ??= _refresh();
        try {
          await flight;
        } finally {
          if (identical(_refreshing, flight)) _refreshing = null;
        }
      }
      options.extra['authRetried'] = true;
      handler.resolve(await dio.fetch<dynamic>(options));
    } on DioException catch (e) {
      handler.next(e);
    } catch (e) {
      handler.next(DioException(requestOptions: options, error: e));
    }
  }
}

class SafeRetryInterceptor extends Interceptor {
  SafeRetryInterceptor(this.dio, this.delay);
  final Dio dio;
  final Duration delay;
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final error = err;
    final options = error.requestOptions;
    final safe =
        {'GET', 'HEAD', 'PUT', 'DELETE', 'OPTIONS'}.contains(options.method) ||
        (options.method == 'POST' &&
            options.headers['Idempotency-Key'] != null);
    final attempt = options.extra['retryCount'] as int? ?? 0;
    final failure = ApiException.fromDio(error);
    if (!safe ||
        !failure.transient ||
        attempt >= 2 ||
        options.extra['refresh'] == true ||
        options.extra['public'] == true ||
        error.type == DioExceptionType.cancel) {
      handler.next(error);
      return;
    }
    options.extra['retryCount'] = attempt + 1;
    await Future<void>.delayed(delay * (1 << attempt));
    try {
      handler.resolve(await dio.fetch<dynamic>(options));
    } on DioException catch (e) {
      handler.next(e);
    }
  }
}

class SafeLogInterceptor extends Interceptor {
  SafeLogInterceptor(this.log);
  final void Function(String) log;
  // An allow-list: no bodies, query strings, headers or credentials are logged.
  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    log(
      '${response.requestOptions.method} ${response.requestOptions.uri.path} -> ${response.statusCode}',
    );
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final error = err;
    log(
      '${error.requestOptions.method} ${error.requestOptions.uri.path} -> ${error.response?.statusCode ?? error.type.name}',
    );
    handler.next(error);
  }
}
