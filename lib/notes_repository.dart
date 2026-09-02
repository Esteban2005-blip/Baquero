import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:connectivity_plus/connectivity_plus.dart';

import 'api_service.dart';
import 'db_helper.dart';
import 'note.dart';
import 'session.dart';

class LocalNotes {
  const LocalNotes({required this.notes, required this.cachedAt});

  final List<Note> notes;
  final DateTime? cachedAt;

  String get ageLabel {
    if (cachedAt == null) return 'Sin caché local';
    final minutes = DateTime.now().difference(cachedAt!).inMinutes;
    if (minutes < 1) return 'Actualizado hace menos de un minuto';
    if (minutes < 60) return 'Actualizado hace $minutes min';
    final hours = minutes ~/ 60;
    return 'Actualizado hace $hours h';
  }
}

class NotesRepository {
  NotesRepository(
      {required this.api, DBHelper? database, Connectivity? connectivity})
      : _database = database ?? DBHelper.instance,
        _connectivity = connectivity ?? Connectivity();

  final ApiService api;
  final DBHelper _database;
  final Connectivity _connectivity;
  final Random _random = Random();

  Future<LocalNotes> local(Session session) async {
    final notes = await _database.getCachedNotes(session.userId);
    return LocalNotes(
        notes: notes,
        cachedAt: await _database.getNotesCachedAt(session.userId));
  }

  Future<LocalNotes> load(Session session) async {
    final cached = await local(session);
    if (!await _hasConnection()) return cached;
    try {
      await sync(session);
      final remote = await api.getNotes(session.accessToken);
      final now = DateTime.now();
      await _database.replaceCachedNotes(session.userId, remote, now);
      for (final operation
          in await _database.pendingOperations(session.userId)) {
        if (operation.type != 'delete') {
          final pendingNote = Note.fromMap(
              jsonDecode(operation.payload) as Map<String, dynamic>);
          await _database.upsertCachedNote(pendingNote, now);
        }
      }
      return LocalNotes(
          notes: await _database.getCachedNotes(session.userId), cachedAt: now);
    } on ApiException {
      return cached;
    }
  }

  Future<void> save(Session session,
      {Note? existing, required String title, required String content}) async {
    final operationId = _newId();
    final note = Note(
      id: existing?.id,
      clientId: existing?.clientId ?? operationId,
      userId: session.userId,
      title: title,
      content: content,
      createdAt: existing?.createdAt ?? DateTime.now().millisecondsSinceEpoch,
    );
    await _database.upsertCachedNote(note, DateTime.now());
    await _database.addPendingOperation(
      operationId: operationId,
      userId: session.userId,
      type: existing == null ? 'create' : 'update',
      note: note,
    );
    await sync(session);
  }

  Future<void> delete(Session session, Note note) async {
    if (note.id == null) {
      await _database.removePendingOperationsForClient(note.clientId!);
      await _database.deleteCachedNote(note.clientId!);
    } else {
      await _database.addPendingOperation(
        operationId: _newId(),
        userId: session.userId,
        type: 'delete',
        note: note,
      );
      await _database.deleteCachedNote(note.clientId!);
    }
    await sync(session);
  }

  Future<void> sync(Session session) async {
    if (!await _hasConnection()) return;
    final operations = await _database.pendingOperations(session.userId);
    for (final operation in operations) {
      var completed = false;
      for (var attempt = 0; attempt < 3 && !completed; attempt++) {
        try {
          final note = Note.fromMap(
              jsonDecode(operation.payload) as Map<String, dynamic>);
          switch (operation.type) {
            case 'create':
              final remote = await api.createNote(session.accessToken,
                  title: note.title, content: note.content);
              await _database.replaceLocalId(note.clientId!, remote.id);
              break;
            case 'update':
              final current = note.id == null
                  ? await _database.getCachedNote(note.clientId!)
                  : note;
              if (current?.id != null) {
                await api.updateNote(session.accessToken, current!.id!,
                    title: note.title, content: note.content);
              }
              break;
            case 'delete':
              if (note.id != null) {
                await api.deleteNote(session.accessToken, note.id!);
              }
              break;
          }
          await _database.removePendingOperation(operation.operationId);
          completed = true;
        } on ApiException catch (error) {
          if (error.statusCode != null &&
              error.statusCode! >= 400 &&
              error.statusCode! < 500) {
            break;
          }
          if (attempt < 2) {
            await Future<void>.delayed(Duration(seconds: 1 << attempt));
          }
        }
      }
    }
  }

  Future<bool> _hasConnection() async {
    final results = await _connectivity.checkConnectivity();
    return results.any((result) => result != ConnectivityResult.none);
  }

  String _newId() =>
      '${DateTime.now().microsecondsSinceEpoch}-${_random.nextInt(1 << 32)}';
}
