import 'dart:async';
import 'package:uuid/uuid.dart';
import 'api_service.dart';
import 'db_helper.dart';
import 'note.dart';
import 'session.dart';

class LocalNotes {
  const LocalNotes({
    required this.notes,
    required this.cachedAt,
    this.offline = false,
    this.pending = 0,
    this.warning,
  });
  final List<Note> notes;
  final DateTime? cachedAt;
  final bool offline;
  final int pending;
  final String? warning;
  String get ageLabel {
    final age = cachedAt == null
        ? 'Sin consulta previa al servidor'
        : 'Última consulta hace ${DateTime.now().difference(cachedAt!).inMinutes} min';
    return '${offline ? "Sin conexión · " : ""}$age · $pending cambios pendientes'
        '${warning == null ? "" : "\n$warning"}';
  }
}

/// The presentation layer only asks this repository for data and mutations.
/// All work is serialized, including reconnect and editor actions.
class NotesRepository {
  NotesRepository({required this.api, DBHelper? database})
    : _database = database ?? DBHelper.instance;
  final ApiService api;
  final DBHelper _database;
  Future<void> _tail = Future.value();
  Future<T> _exclusive<T>(Future<T> Function() action) {
    final result = _tail.then((_) => action());
    _tail = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  Future<LocalNotes> _local(
    Session session, {
    bool offline = false,
    String? warning,
  }) async {
    final operations = await _database.pendingOperations(session.userId);
    final failures = operations.where((op) => op.error != null);
    return LocalNotes(
      notes: await _database.getCachedNotes(session.userId),
      cachedAt: await _database.getNotesCachedAt(session.userId),
      offline: offline,
      pending: operations.length,
      warning: warning ?? (failures.isEmpty ? null : failures.first.error),
    );
  }

  Future<LocalNotes> load(Session session) => _exclusive(() async {
    try {
      await _sync(session);
      final remote = await api.getNotes();
      await _database.replaceCachedNotes(
        session.userId,
        remote,
        DateTime.now(),
      );
      return await _local(session);
    } on ApiException catch (e) {
      if (!e.transient) rethrow;
      return _local(session, offline: true, warning: e.message);
    }
  });
  Future<void> save(
    Session session, {
    Note? existing,
    required String title,
    required String content,
  }) => _exclusive(() async {
    final operationId = const Uuid().v4();
    final clientId = existing?.clientId ?? const Uuid().v4();
    final queue = await _database.pendingOperations(session.userId);
    final pendingCreate = queue.any(
      (op) =>
          op.note.clientId == clientId &&
          op.type == 'create' &&
          op.error == null,
    );
    final note = Note(
      id: existing?.id,
      clientId: clientId,
      userId: existing?.userId ?? session.userId,
      title: title,
      content: content,
      createdAt: existing?.createdAt ?? DateTime.now().millisecondsSinceEpoch,
    );
    await _database.enqueue(
      session.userId,
      operationId,
      note.id == null && !pendingCreate ? 'create' : 'update',
      note,
    );
    try {
      await _sync(session, reportOperation: operationId);
    } on ApiException catch (e) {
      if (!e.transient) {
        throw ApiException(
          e.message,
          code: e.code,
          statusCode: e.statusCode,
          family: e.family,
          fields: e.fields,
          draft: note,
        );
      }
    }
  });
  Future<void> delete(Session session, Note note) => _exclusive(() async {
    final operationId = const Uuid().v4();
    await _database.enqueue(session.userId, operationId, 'delete', note);
    try {
      await _sync(session, reportOperation: operationId);
    } on ApiException catch (e) {
      if (!e.transient) rethrow;
    }
  });
  Future<void> sync(Session session) => _exclusive(() => _sync(session));
  Future<void> _sync(Session session, {String? reportOperation}) async {
    final blocked = <String>{};
    // Re-read after every acknowledgment: it assigns server IDs to later edits.
    for (final initial in await _database.pendingOperations(session.userId)) {
      final current = await _database.pendingOperations(session.userId);
      final matches = current.where(
        (op) => op.operationId == initial.operationId,
      );
      if (matches.isEmpty) continue;
      final op = matches.first;
      if (op.error != null || blocked.contains(op.note.clientId)) {
        blocked.add(op.note.clientId!);
        continue;
      }
      try {
        Note? remote;
        switch (op.type) {
          case 'create':
            remote = await api.createNote(
              title: op.note.title,
              content: op.note.content,
              operationId: op.operationId,
              createdAt: op.note.createdAt,
            );
            break;
          case 'update':
            if (op.note.id == null) {
              throw const ApiException(
                'No se pudo identificar la nota. Revisa el cambio pendiente.',
                code: 'MISSING_ID',
                family: FailureFamily.client,
              );
            }
            remote = await api.updateNote(
              op.note.id!,
              title: op.note.title,
              content: op.note.content,
            );
            break;
          case 'delete':
            if (op.note.id != null) await api.deleteNote(op.note.id!);
            break;
        }
        await _database.complete(session.userId, op, remote);
      } on ApiException catch (e) {
        if (e.statusCode == 401 || e.transient) rethrow;
        await _database.reject(
          session.userId,
          op.operationId,
          '${op.note.title}: ${e.message}',
        );
        blocked.add(op.note.clientId!);
        if (op.operationId == reportOperation) rethrow;
      }
    }
  }

  Future<void> logout(Session session) => _exclusive(() async {
    try {
      await api.logout();
    } finally {
      await _database.clearUser(session.userId);
    }
  });
}
