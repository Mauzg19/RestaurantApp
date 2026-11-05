import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:sqflite/sqflite.dart';

class PendingOperation {
  const PendingOperation({
    required this.id,
    required this.ownerEmail,
    required this.entityType,
    required this.entityId,
    required this.operationType,
    required this.payload,
    required this.createdAt,
    required this.attempts,
  });

  final String id;
  final String ownerEmail;
  final String entityType;
  final String entityId;
  final String operationType;
  final Map<String, dynamic> payload;
  final DateTime createdAt;
  final int attempts;

  factory PendingOperation.fromRow(Map<String, Object?> row) =>
      PendingOperation(
        id: row['operation_id']! as String,
        ownerEmail: row['owner_email']! as String,
        entityType: row['entity_type']! as String,
        entityId: row['entity_id']! as String,
        operationType: row['operation_type']! as String,
        payload: Map<String, dynamic>.from(
          jsonDecode(row['payload']! as String) as Map,
        ),
        createdAt: DateTime.parse(row['created_at']! as String),
        attempts: row['attempts']! as int,
      );
}

class OfflineDatabase {
  OfflineDatabase(this._database);

  final Database _database;

  static Future<OfflineDatabase> open({String? databasePath}) async {
    final path = databasePath ??
        '${await getDatabasesPath()}${Platform.pathSeparator}restaurantapp_offline.db';
    final database = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE cached_records (
            scope TEXT NOT NULL,
            owner_email TEXT NOT NULL,
            record_id TEXT NOT NULL,
            payload TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            PRIMARY KEY (scope, owner_email, record_id)
          )
        ''');
        await db.execute('''
          CREATE TABLE pending_operations (
            operation_id TEXT PRIMARY KEY,
            owner_email TEXT NOT NULL,
            entity_type TEXT NOT NULL,
            entity_id TEXT NOT NULL,
            operation_type TEXT NOT NULL,
            payload TEXT NOT NULL,
            created_at TEXT NOT NULL,
            attempts INTEGER NOT NULL DEFAULT 0,
            next_attempt_at TEXT NOT NULL,
            status TEXT NOT NULL DEFAULT 'pending',
            last_error TEXT
          )
        ''');
        await db.execute('''
          CREATE INDEX pending_operations_ready
          ON pending_operations(owner_email, status, next_attempt_at, created_at)
        ''');
        await db.execute('''
          CREATE UNIQUE INDEX pending_operations_entity
          ON pending_operations(owner_email, entity_type, entity_id)
          WHERE status = 'pending'
        ''');
      },
    );
    await database.update(
      'pending_operations',
      const {'status': 'pending'},
      where: "status = 'in_flight'",
    );
    return OfflineDatabase(database);
  }

  Future<void> cacheRecord({
    required String scope,
    required String ownerEmail,
    required String recordId,
    required Map<String, dynamic> payload,
  }) async {
    await _database.insert(
      'cached_records',
      {
        'scope': scope,
        'owner_email': _normalizeOwner(ownerEmail),
        'record_id': recordId,
        'payload': jsonEncode(payload),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> readRecords({
    required String scope,
    required String ownerEmail,
  }) async {
    final rows = await _database.query(
      'cached_records',
      columns: const ['record_id', 'payload'],
      where: 'scope = ? AND owner_email = ?',
      whereArgs: [scope, _normalizeOwner(ownerEmail)],
      orderBy: 'record_id',
    );
    return rows
        .map(
          (row) => {
            'recordId': row['record_id']! as String,
            ...Map<String, dynamic>.from(
              jsonDecode(row['payload']! as String) as Map,
            ),
          },
        )
        .toList();
  }

  Future<void> replaceRecords({
    required String scope,
    required String ownerEmail,
    required List<Map<String, dynamic>> records,
    Set<String> preserveIds = const {},
  }) async {
    final owner = _normalizeOwner(ownerEmail);
    final incomingIds = records
        .map((record) => record['recordId']?.toString())
        .whereType<String>()
        .toSet();
    await _database.transaction((transaction) async {
      final existing = await transaction.query(
        'cached_records',
        columns: const ['record_id'],
        where: 'scope = ? AND owner_email = ?',
        whereArgs: [scope, owner],
      );
      for (final row in existing) {
        final id = row['record_id']! as String;
        if (!incomingIds.contains(id) && !preserveIds.contains(id)) {
          await transaction.delete(
            'cached_records',
            where: 'scope = ? AND owner_email = ? AND record_id = ?',
            whereArgs: [scope, owner, id],
          );
        }
      }
      for (final record in records) {
        final id = record['recordId']?.toString();
        if (id == null || id.isEmpty) {
          throw const FormatException('El registro local requiere un id.');
        }
        final payload = Map<String, dynamic>.from(record)..remove('recordId');
        await transaction.insert(
          'cached_records',
          {
            'scope': scope,
            'owner_email': owner,
            'record_id': id,
            'payload': jsonEncode(payload),
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  Future<void> deleteRecord({
    required String scope,
    required String ownerEmail,
    required String recordId,
  }) async {
    await _database.delete(
      'cached_records',
      where: 'scope = ? AND owner_email = ? AND record_id = ?',
      whereArgs: [scope, _normalizeOwner(ownerEmail), recordId],
    );
  }

  Future<String?> enqueueOperation({
    required String ownerEmail,
    required String entityType,
    required String entityId,
    required String operationType,
    required Map<String, dynamic> payload,
    String? operationId,
  }) async {
    final owner = _normalizeOwner(ownerEmail);
    return _database.transaction((transaction) async {
      final existing = await transaction.query(
        'pending_operations',
        where:
            "owner_email = ? AND entity_type = ? AND entity_id = ? AND status = 'pending'",
        whereArgs: [owner, entityType, entityId],
        limit: 1,
      );
      if (existing.isNotEmpty) {
        final previous = existing.single;
        final previousId = previous['operation_id']! as String;
        final previousType = previous['operation_type']! as String;
        if (previousType == 'CREATE' && operationType == 'DELETE') {
          await transaction.delete(
            'pending_operations',
            where: 'operation_id = ?',
            whereArgs: [previousId],
          );
          return null;
        }
        final effectiveType = previousType == 'CREATE'
            ? 'CREATE'
            : operationType;
        final updatedPayload = <String, dynamic>{
          ...Map<String, dynamic>.from(
            jsonDecode(previous['payload']! as String) as Map,
          ),
          ...payload,
        };
        if (effectiveType == 'CREATE' && entityType == 'product') {
          updatedPayload['clientOperationId'] = previousId;
        }
        if (entityType == 'settings') {
          updatedPayload['clientOperationId'] = previousId;
        }
        await transaction.update(
          'pending_operations',
          {
            'operation_type': effectiveType,
            'payload': jsonEncode(updatedPayload),
            'next_attempt_at': DateTime.now().toUtc().toIso8601String(),
            'last_error': null,
          },
          where: 'operation_id = ?',
          whereArgs: [previousId],
        );
        return previousId;
      }

      final id = operationId ?? newOperationId();
      final storedPayload = Map<String, dynamic>.from(payload);
      if (operationType == 'CREATE' && entityType == 'product') {
        storedPayload['clientOperationId'] = id;
      }
      final now = DateTime.now().toUtc().toIso8601String();
      await transaction.insert('pending_operations', {
        'operation_id': id,
        'owner_email': owner,
        'entity_type': entityType,
        'entity_id': entityId,
        'operation_type': operationType,
        'payload': jsonEncode(storedPayload),
        'created_at': now,
        'next_attempt_at': now,
      });
      return id;
    });
  }

  Future<List<PendingOperation>> getReadyOperations(String ownerEmail) async {
    final rows = await _database.query(
      'pending_operations',
      where: "owner_email = ? AND status = 'pending' AND next_attempt_at <= ?",
      whereArgs: [
        _normalizeOwner(ownerEmail),
        DateTime.now().toUtc().toIso8601String(),
      ],
      orderBy: 'created_at, operation_id',
    );
    return rows.map(PendingOperation.fromRow).toList();
  }

  Future<List<PendingOperation>> getPendingOperations(
    String ownerEmail, {
    String? entityType,
  }) async {
    final rows = await _database.query(
      'pending_operations',
      where: entityType == null
          ? "owner_email = ? AND status IN ('pending', 'in_flight')"
          : "owner_email = ? AND entity_type = ? AND status IN ('pending', 'in_flight')",
      whereArgs: entityType == null
          ? [_normalizeOwner(ownerEmail)]
          : [_normalizeOwner(ownerEmail), entityType],
      orderBy: 'created_at, operation_id',
    );
    return rows.map(PendingOperation.fromRow).toList();
  }

  Future<void> cancelPendingOperations({
    required String ownerEmail,
    required String entityType,
    required String entityId,
  }) async {
    await _database.delete(
      'pending_operations',
      where:
          "owner_email = ? AND entity_type = ? AND entity_id = ? AND status = 'pending'",
      whereArgs: [_normalizeOwner(ownerEmail), entityType, entityId],
    );
  }

  Future<void> markOperationInFlight(String operationId) async {
    await _database.update(
      'pending_operations',
      const {'status': 'in_flight'},
      where: "operation_id = ? AND status = 'pending'",
      whereArgs: [operationId],
    );
  }

  Future<void> completeOperation(String operationId) async {
    await _database.update(
      'pending_operations',
      const {'status': 'completed', 'last_error': null},
      where: 'operation_id = ?',
      whereArgs: [operationId],
    );
  }

  Future<void> markOperationFailed(String operationId, Object error) async {
    final rows = await _database.query(
      'pending_operations',
      columns: const ['attempts'],
      where: 'operation_id = ?',
      whereArgs: [operationId],
      limit: 1,
    );
    if (rows.isEmpty) return;
    final attempts = (rows.single['attempts']! as int) + 1;
    final delaySeconds = min(3600, 2 * pow(2, min(attempts - 1, 10)).toInt());
    await _database.update(
      'pending_operations',
      {
        'status': 'pending',
        'attempts': attempts,
        'next_attempt_at': DateTime.now()
            .toUtc()
            .add(Duration(seconds: delaySeconds))
            .toIso8601String(),
        'last_error': error.toString(),
      },
      where: 'operation_id = ?',
      whereArgs: [operationId],
    );
  }

  Future<void> remapPendingEntity({
    required String ownerEmail,
    required String entityType,
    required String oldId,
    required String newId,
  }) async {
    await _database.update(
      'pending_operations',
      {'entity_id': newId},
      where:
          "owner_email = ? AND entity_type = ? AND entity_id = ? AND status = 'pending'",
      whereArgs: [_normalizeOwner(ownerEmail), entityType, oldId],
    );
  }

  Future<int> pendingCount(String ownerEmail) async {
    final result = await _database.rawQuery(
      "SELECT COUNT(*) AS count FROM pending_operations WHERE owner_email = ? AND status = 'pending'",
      [_normalizeOwner(ownerEmail)],
    );
    return result.single['count']! as int;
  }

  Future<void> close() => _database.close();

  static String newOperationId() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  static String _normalizeOwner(String ownerEmail) =>
      ownerEmail.trim().toLowerCase();
}
