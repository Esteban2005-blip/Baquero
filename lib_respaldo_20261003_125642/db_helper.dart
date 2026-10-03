import 'dart:convert';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'note.dart';

class PendingOperation {
  const PendingOperation({
    required this.operationId,
    required this.type,
    required this.note,
    this.error,
  });
  final String operationId;
  final String type;
  final Note note;
  final String? error;
}

/// Local source. Cache identity and server identity are separate; SQLite never
/// assigns a server ID to an offline note. Every query is scoped to its account.
class DBHelper {
  DBHelper({Database? database})
    : _opened = database == null ? null : Future.value(database);
  static final instance = DBHelper();
  Future<Database>? _opened;
  Future<Database> get database => _opened ??= _open();
  Future<Database> _open() async => openDatabase(
    join(await getDatabasesPath(), 'app_db.db'),
    version: 4,
    onCreate: createSchema,
    onUpgrade: (db, old, version) async {
      await createSchema(db, version);
      // Keep the v3 tables as a migration backup. The old auto-increment `id`
      // cannot distinguish a real server ID from an offline-only local ID.
      if (old == 3) {
        final pending = await db.query('pending_operations');
        final localClients = <String>{};
        for (final row in pending) {
          if (row['type'] == 'create') {
            localClients.add(
              (jsonDecode(row['payload'] as String) as Map)['client_id']
                  as String,
            );
          }
        }
        for (final row in await db.query('notes')) {
          final data = Map<String, dynamic>.from(row);
          data['client_id'] ??= 'remote-${data['id']}';
          if (localClients.contains(data['client_id'])) data['id'] = null;
          final note = Note.fromJson(data);
          await _put(db, data['user_id'] as int, note);
        }
        for (final row in pending) {
          final data =
              jsonDecode(row['payload'] as String) as Map<String, dynamic>;
          if (localClients.contains(data['client_id'])) data['id'] = null;
          await db.insert('outbox', {
            'operation_id': row['operation_id'],
            'owner_id': row['user_id'],
            'type': row['type'],
            'payload': jsonEncode(data),
            'created_at': row['created_at'],
            'error':
                'Operación anterior a Semana 13: revisa antes de reenviar para evitar duplicados.',
          });
        }
      }
    },
  );

  static Future<void> createSchema(Database db, int version) async {
    await db.execute('''CREATE TABLE IF NOT EXISTS note_cache (
      owner_id INTEGER NOT NULL, client_id TEXT NOT NULL, payload TEXT NOT NULL,
      PRIMARY KEY(owner_id,client_id))''');
    await db.execute('''CREATE TABLE IF NOT EXISTS cache_metadata (
      owner_id INTEGER PRIMARY KEY, cached_at INTEGER NOT NULL)''');
    await db.execute('''CREATE TABLE IF NOT EXISTS outbox (
      sequence INTEGER PRIMARY KEY AUTOINCREMENT, operation_id TEXT UNIQUE NOT NULL,
      owner_id INTEGER NOT NULL, type TEXT NOT NULL, payload TEXT NOT NULL,
      created_at INTEGER NOT NULL, error TEXT)''');
  }

  static Future<void> _put(DatabaseExecutor db, int owner, Note note) async {
    await db.insert('note_cache', {
      'owner_id': owner,
      'client_id': note.clientId ?? 'remote-${note.id}',
      'payload': jsonEncode(note.toJson()),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Note>> getCachedNotes(int owner) async {
    final rows = await (await database).query(
      'note_cache',
      where: 'owner_id=?',
      whereArgs: [owner],
    );
    return rows
        .map(
          (r) => Note.fromJson(
            jsonDecode(r['payload'] as String) as Map<String, dynamic>,
          ),
        )
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<Note?> getCachedNote(int owner, String clientId) async {
    final rows = await (await database).query(
      'note_cache',
      where: 'owner_id=? AND client_id=?',
      whereArgs: [owner, clientId],
    );
    return rows.isEmpty
        ? null
        : Note.fromJson(
            jsonDecode(rows.first['payload'] as String) as Map<String, dynamic>,
          );
  }

  Future<DateTime?> getNotesCachedAt(int owner) async {
    final rows = await (await database).query(
      'cache_metadata',
      where: 'owner_id=?',
      whereArgs: [owner],
    );
    return rows.isEmpty
        ? null
        : DateTime.fromMillisecondsSinceEpoch(rows.first['cached_at'] as int);
  }

  Future<List<PendingOperation>> pendingOperations(int owner) async {
    final rows = await (await database).query(
      'outbox',
      where: 'owner_id=?',
      whereArgs: [owner],
      orderBy: 'sequence',
    );
    return rows
        .map(
          (r) => PendingOperation(
            operationId: r['operation_id'] as String,
            type: r['type'] as String,
            note: Note.fromJson(
              jsonDecode(r['payload'] as String) as Map<String, dynamic>,
            ),
            error: r['error'] as String?,
          ),
        )
        .toList();
  }

  Future<void> enqueue(
    int owner,
    String operationId,
    String type,
    Note note,
  ) async {
    await (await database).transaction((txn) async {
      // Explicit edits replace rejected operations; uncertain operations keep
      // their immutable payload and idempotency key until acknowledged.
      final rejected = await txn.query(
        'outbox',
        where: 'owner_id=? AND error IS NOT NULL',
        whereArgs: [owner],
      );
      for (final row in rejected) {
        final data = jsonDecode(row['payload'] as String) as Map;
        if (data['client_id'] == note.clientId) {
          await txn.delete(
            'outbox',
            where: 'operation_id=?',
            whereArgs: [row['operation_id']],
          );
        }
      }
      await txn.insert('outbox', {
        'operation_id': operationId,
        'owner_id': owner,
        'type': type,
        'payload': jsonEncode(note.toJson()),
        'created_at': DateTime.now().millisecondsSinceEpoch,
      });
      if (type == 'delete') {
        await txn.delete(
          'note_cache',
          where: 'owner_id=? AND client_id=?',
          whereArgs: [owner, note.clientId],
        );
      } else {
        await _put(txn, owner, note);
      }
    });
  }

  Future<void> complete(int owner, PendingOperation op, Note? remote) async {
    await (await database).transaction((txn) async {
      if (remote != null) {
        final remaining = await txn.query(
          'outbox',
          where: 'owner_id=? AND operation_id!=?',
          whereArgs: [owner, op.operationId],
        );
        Note latest = remote.withIdentity(clientId: op.note.clientId);
        var deleted = false;
        for (final row in remaining) {
          final next = Note.fromJson(
            jsonDecode(row['payload'] as String) as Map<String, dynamic>,
          );
          if (next.clientId == op.note.clientId) {
            latest = next.withIdentity(id: remote.id);
            deleted = row['type'] == 'delete';
            await txn.update(
              'outbox',
              {'payload': jsonEncode(latest.toJson())},
              where: 'operation_id=?',
              whereArgs: [row['operation_id']],
            );
          }
        }
        if (!deleted) await _put(txn, owner, latest);
      }
      await txn.delete(
        'outbox',
        where: 'owner_id=? AND operation_id=?',
        whereArgs: [owner, op.operationId],
      );
    });
  }

  Future<void> reject(int owner, String operationId, String message) async =>
      (await database).update(
        'outbox',
        {'error': message},
        where: 'owner_id=? AND operation_id=?',
        whereArgs: [owner, operationId],
      );
  Future<void> replaceCachedNotes(
    int owner,
    List<Note> remote,
    DateTime now,
  ) async {
    await (await database).transaction((txn) async {
      final old = await txn.query(
        'note_cache',
        where: 'owner_id=?',
        whereArgs: [owner],
      );
      final identities = <int, String>{};
      for (final row in old) {
        final note = Note.fromJson(
          jsonDecode(row['payload'] as String) as Map<String, dynamic>,
        );
        if (note.id != null) identities[note.id!] = row['client_id'] as String;
      }
      final overlay = <String, Note>{};
      for (final note in remote) {
        final clientId = identities[note.id] ?? 'remote-${note.id}';
        overlay[clientId] = note.withIdentity(clientId: clientId);
      }
      for (final row in await txn.query(
        'outbox',
        where: 'owner_id=?',
        whereArgs: [owner],
        orderBy: 'sequence',
      )) {
        final note = Note.fromJson(
          jsonDecode(row['payload'] as String) as Map<String, dynamic>,
        );
        if (row['type'] == 'delete') {
          overlay.remove(note.clientId);
        } else {
          overlay[note.clientId!] = note;
        }
      }
      await txn.delete('note_cache', where: 'owner_id=?', whereArgs: [owner]);
      for (final note in overlay.values) {
        await _put(txn, owner, note);
      }
      await txn.insert('cache_metadata', {
        'owner_id': owner,
        'cached_at': now.millisecondsSinceEpoch,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  Future<void> clearUser(int owner) async {
    await (await database).transaction((txn) async {
      for (final table in ['note_cache', 'outbox', 'cache_metadata']) {
        await txn.delete(table, where: 'owner_id=?', whereArgs: [owner]);
      }
    });
  }

  Future<void> close() async {
    if (_opened != null) await (await _opened!).close();
    _opened = null;
  }
}
