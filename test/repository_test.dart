import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:aplicacion_moviles/api_service.dart';
import 'package:aplicacion_moviles/db_helper.dart';
import 'package:aplicacion_moviles/note.dart';
import 'package:aplicacion_moviles/notes_repository.dart';
import 'support.dart';

void main() {
  late DBHelper database;
  late NotesRepository repository;
  late Map<int, Map<String, dynamic>> server;
  late Map<String, Map<String, dynamic>> receipts;
  late bool offline;
  late bool loseResponse;
  late int nextId;
  setUp(() async {
    sqfliteFfiInit();
    final db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(version: 4, onCreate: DBHelper.createSchema),
    );
    database = DBHelper(database: db);
    server = {};
    receipts = {};
    offline = false;
    loseResponse = false;
    nextId = 100;
    final dio = Dio();
    dio.httpClientAdapter = TestAdapter((r) async {
      if (offline) {
        throw DioException(
          requestOptions: r,
          type: DioExceptionType.connectionError,
        );
      }
      final path = r.uri.path;
      if (r.method == 'GET') return notesResponse(server.values.toList());
      final body = r.data is String
          ? jsonDecode(r.data as String) as Map
          : r.data as Map?;
      if (r.method == 'POST') {
        final key = r.headers['Idempotency-Key'] as String;
        if (body!['title'] == 'Rejected') {
          return jsonResponse({
            'error': {
              'code': 'VALIDATION_ERROR',
              'message': 'Título rechazado',
              'fields': {
                'title': ['Título rechazado'],
              },
            },
          }, 422);
        }
        final note = receipts.putIfAbsent(key, () {
          final id = nextId++;
          return server[id] = {
            'id': id,
            'user_id': 7,
            ...Map<String, dynamic>.from(body),
          };
        });
        if (loseResponse) {
          offline = true;
          throw DioException(
            requestOptions: r,
            type: DioExceptionType.receiveTimeout,
          );
        }
        return jsonResponse({'data': note}, 201);
      }
      final id = int.parse(path.split('/').last);
      if (r.method == 'DELETE') {
        server.remove(id);
        return jsonResponse({'success': true});
      }
      server[id] = {...server[id]!, ...Map<String, dynamic>.from(body!)};
      return jsonResponse({'data': server[id]});
    });
    repository = NotesRepository(
      database: database,
      api: ApiService(
        dio: dio,
        storage: MemoryStorage()..value = session,
        retryDelay: Duration.zero,
        logger: (_) {},
      ),
    );
  });
  tearDown(() async => database.close());
  test(
    'offline create has no fake server ID; later sync inserts once',
    () async {
      offline = true;
      await repository.save(session, title: 'Offline', content: 'Body');
      var result = await repository.load(session);
      expect(result.offline, true);
      expect(result.pending, 1);
      expect(result.notes.single.id, isNull);
      offline = false;
      result = await repository.load(session);
      expect(result.pending, 0);
      expect(result.notes.single.id, 100);
      expect(server.length, 1);
    },
  );
  test(
    'lost create response followed by edit recovers identity and never duplicates',
    () async {
      loseResponse = true;
      await repository.save(session, title: 'Original', content: 'Body');
      final draft = (await repository.load(session)).notes.single;
      await repository.save(
        session,
        existing: draft,
        title: 'Edited',
        content: 'New',
      );
      expect((await database.pendingOperations(7)).length, 2);
      offline = false;
      loseResponse = false;
      final result = await repository.load(session);
      expect(server.length, 1);
      expect(server.values.single['title'], 'Edited');
      expect(result.pending, 0);
      expect(result.notes.single.title, 'Edited');
    },
  );
  test(
    'offline delete stays deleted after uncertain create is acknowledged',
    () async {
      loseResponse = true;
      await repository.save(session, title: 'Delete me', content: 'Body');
      final draft = (await repository.load(session)).notes.single;
      await repository.delete(session, draft);
      expect((await repository.load(session)).notes, isEmpty);
      offline = false;
      loseResponse = false;
      final result = await repository.load(session);
      expect(result.notes, isEmpty);
      expect(result.pending, 0);
      expect(server, isEmpty);
    },
  );
  test(
    '422 is shown and rejected draft can be corrected without another record',
    () async {
      await expectLater(
        repository.save(session, title: 'Rejected', content: 'Body'),
        throwsA(
          isA<ApiException>().having(
            (e) => e.field('title'),
            'title',
            'Título rechazado',
          ),
        ),
      );
      final result = await repository.load(session);
      expect(result.warning, contains('rechazado'));
      expect(result.pending, 1);
      await repository.save(
        session,
        existing: result.notes.single,
        title: 'Corrected',
        content: 'Body',
      );
      expect((await repository.load(session)).pending, 0);
      expect(server.length, 1);
      expect((await database.getCachedNotes(7)).length, 1);
    },
  );
  test(
    'empty server lists have a cache timestamp and accounts are isolated',
    () async {
      final result = await repository.load(session);
      expect(result.cachedAt, isNotNull);
      expect(result.notes, isEmpty);
      await database.enqueue(
        99,
        'other-operation',
        'create',
        const Note(
          clientId: 'other',
          userId: 99,
          title: 'Private',
          content: 'Body',
          createdAt: 1,
        ),
      );
      expect(await database.getCachedNotes(7), isEmpty);
      expect((await database.getCachedNotes(99)).length, 1);
      await database.clearUser(7);
      expect((await database.pendingOperations(99)).length, 1);
    },
  );
  test('concurrent repository actions serialize the outbox drain', () async {
    await Future.wait([
      repository.save(session, title: 'First', content: 'A'),
      repository.save(session, title: 'Second', content: 'B'),
      repository.load(session),
    ]);
    expect(server.length, 2);
    expect((await database.pendingOperations(7)), isEmpty);
  });
  test('pending deletion overlays a remote snapshot', () async {
    const note = Note(
      id: 1,
      clientId: 'remote-1',
      userId: 7,
      title: 'Delete',
      content: 'Body',
      createdAt: 1,
    );
    await database.enqueue(7, 'delete-operation', 'delete', note);
    await database.replaceCachedNotes(7, [note], DateTime.now());
    expect(await database.getCachedNotes(7), isEmpty);
  });
}
