import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import 'note.dart';

class PendingOperation {
  const PendingOperation(
      {required this.operationId, required this.type, required this.payload});

  final String operationId;
  final String type;
  final String payload;
}

class DBHelper {
  static final DBHelper instance = DBHelper._init();

  static Database? _database;

  DBHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('app_db.db');
    return _database!;
  }

  Future<Database> _initDB(String fileName) async {
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    final path = join(documentsDirectory.path, fileName);
    return await openDatabase(
      path,
      version: 3,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE notes(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        client_id TEXT NOT NULL UNIQUE,
        user_id INTEGER NOT NULL,
        title TEXT NOT NULL,
        content TEXT NOT NULL,
        createdAt INTEGER NOT NULL,
        cached_at INTEGER NOT NULL
      )
    ''');
    await _createQueue(db);
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 3) {
      await db.execute('DROP TABLE IF EXISTS users');
      await db.execute('DROP TABLE IF EXISTS notes');
      await _createDB(db, newVersion);
    }
  }

  Future<void> _createQueue(Database db) async {
    await db.execute('''
      CREATE TABLE pending_operations(
        operation_id TEXT PRIMARY KEY,
        user_id INTEGER NOT NULL,
        type TEXT NOT NULL,
        payload TEXT NOT NULL,
        created_at INTEGER NOT NULL
      )
    ''');
  }

  Future<List<Note>> getCachedNotes(int userId) async {
    final db = await database;
    final result = await db.query(
      'notes',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'createdAt DESC',
    );
    return result.map(Note.fromMap).toList();
  }

  Future<DateTime?> getNotesCachedAt(int userId) async {
    final db = await database;
    final result = await db.rawQuery(
        'SELECT MAX(cached_at) AS value FROM notes WHERE user_id = ?',
        [userId]);
    final value = result.first['value'];
    return value is int ? DateTime.fromMillisecondsSinceEpoch(value) : null;
  }

  Future<void> replaceCachedNotes(
      int userId, List<Note> notes, DateTime cachedAt) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('notes', where: 'user_id = ?', whereArgs: [userId]);
      for (final note in notes) {
        await txn.insert('notes', {
          ...note.toMap(),
          'client_id': note.clientId ?? 'remote-${note.id}',
          'user_id': userId,
          'cached_at': cachedAt.millisecondsSinceEpoch,
        });
      }
    });
  }

  Future<void> upsertCachedNote(Note note, DateTime cachedAt) async {
    final db = await database;
    await db.insert(
        'notes',
        {
          ...note.toMap(),
          'client_id': note.clientId,
          'user_id': note.userId,
          'cached_at': cachedAt.millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteCachedNote(String clientId) async {
    final db = await database;
    await db.delete('notes', where: 'client_id = ?', whereArgs: [clientId]);
  }

  Future<void> replaceLocalId(String clientId, int? id) async {
    final db = await database;
    await db.update(
      'notes',
      {'id': id},
      where: 'client_id = ?',
      whereArgs: [clientId],
    );
  }

  Future<Note?> getCachedNote(String clientId) async {
    final db = await database;
    final rows = await db.query('notes',
        where: 'client_id = ?', whereArgs: [clientId], limit: 1);
    return rows.isEmpty ? null : Note.fromMap(rows.first);
  }

  Future<void> addPendingOperation(
      {required String operationId,
      required int userId,
      required String type,
      required Note note}) async {
    final db = await database;
    await db.insert('pending_operations', {
      'operation_id': operationId,
      'user_id': userId,
      'type': type,
      'payload': jsonEncode(note.toMap()),
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<List<PendingOperation>> pendingOperations(int userId) async {
    final db = await database;
    final rows = await db.query('pending_operations',
        where: 'user_id = ?', whereArgs: [userId], orderBy: 'created_at ASC');
    return rows
        .map((row) => PendingOperation(
              operationId: row['operation_id'] as String,
              type: row['type'] as String,
              payload: row['payload'] as String,
            ))
        .toList();
  }

  Future<void> removePendingOperation(String operationId) async {
    final db = await database;
    await db.delete('pending_operations',
        where: 'operation_id = ?', whereArgs: [operationId]);
  }

  Future<void> removePendingOperationsForClient(String clientId) async {
    final db = await database;
    final rows = await db.query('pending_operations');
    for (final row in rows) {
      final payload =
          jsonDecode(row['payload'] as String) as Map<String, dynamic>;
      if (payload['client_id'] == clientId) {
        await db.delete('pending_operations',
            where: 'operation_id = ?', whereArgs: [row['operation_id']]);
      }
    }
  }

  Future<void> clearAll() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('notes');
      await txn.delete('pending_operations');
    });
  }

  Future<void> close() async {
    final db = await database;
    db.close();
  }
}
