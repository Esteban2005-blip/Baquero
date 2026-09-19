import 'dart:typed_data';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:aplicacion_moviles/session.dart';
import 'package:aplicacion_moviles/session_storage.dart';

class MemoryStorage extends SessionStorage {
  Session? value;
  @override
  Future<Session?> read() async => value;
  @override
  Future<void> save(Session session) async {
    value = session;
  }

  @override
  Future<void> clear() async {
    value = null;
  }
}

const session = Session(
  userId: 7,
  email: 'ana@example.com',
  role: 'user',
  accessToken: 'old',
  refreshToken: 'refresh',
);

class TestAdapter implements HttpClientAdapter {
  TestAdapter(this.respond);
  final Future<ResponseBody> Function(RequestOptions) respond;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) => respond(options);
  @override
  void close({bool force = false}) {}
}

ResponseBody jsonResponse(Object body, [int status = 200]) =>
    ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
ResponseBody notesResponse([List<Map<String, dynamic>> notes = const []]) =>
    jsonResponse({
      'success': true,
      'data': notes,
      'pagination': {'page': 1, 'limit': 50, 'total': notes.length},
    });
