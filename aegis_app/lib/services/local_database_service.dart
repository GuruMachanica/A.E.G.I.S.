import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/call_record.dart';
import '../models/risk_level.dart';

class LocalDatabaseService {
  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    final isTestEnv = Platform.environment.containsKey('FLUTTER_TEST');
    final dbPath = isTestEnv
        ? inMemoryDatabasePath
        : join(await getDatabasesPath(), 'aegis_local.db');
    _db = await openDatabase(
      dbPath,
      version: 2,
      singleInstance: !isTestEnv,
      onCreate: (db, version) async {
        await _createTables(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS blocked_callers(
              phone_number TEXT PRIMARY KEY,
              reason TEXT,
              created_at TEXT
            )
          ''');
          await db.execute('''
            CREATE TABLE IF NOT EXISTS guardian_contacts(
              id TEXT PRIMARY KEY,
              name TEXT,
              phone TEXT,
              email TEXT,
              is_active INTEGER
            )
          ''');
          await db.execute('''
            CREATE TABLE IF NOT EXISTS threat_audit_logs(
              id TEXT PRIMARY KEY,
              call_id TEXT,
              threat_type TEXT,
              description TEXT,
              timestamp TEXT
            )
          ''');
        }
      },
    );
    return _db!;
  }

  Future<void> _createTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS call_records(
        id TEXT PRIMARY KEY,
        caller_name TEXT,
        phone_number TEXT,
        call_time TEXT,
        risk_level TEXT,
        risk_score INTEGER,
        synthetic_score INTEGER,
        intent_score INTEGER,
        is_suspended INTEGER,
        avatar_asset TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS app_events(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT,
        message TEXT,
        created_at TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS blocked_callers(
        phone_number TEXT PRIMARY KEY,
        reason TEXT,
        created_at TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS guardian_contacts(
        id TEXT PRIMARY KEY,
        name TEXT,
        phone TEXT,
        email TEXT,
        is_active INTEGER
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS threat_audit_logs(
        id TEXT PRIMARY KEY,
        call_id TEXT,
        threat_type TEXT,
        description TEXT,
        timestamp TEXT
      )
    ''');
  }

  // ── Call Records ─────────────────────────────────────────────────────────────
  Future<List<CallRecord>> loadCallRecords() async {
    final db = await database;
    final rows = await db.query('call_records', orderBy: 'call_time DESC');
    return rows.map((row) {
      final level = RiskLevel.values.firstWhere(
        (e) => e.name == (row['risk_level']?.toString() ?? 'safe'),
        orElse: () => RiskLevel.safe,
      );
      return CallRecord(
        id: row['id']?.toString() ?? '',
        callerName: row['caller_name']?.toString() ?? '',
        phoneNumber: row['phone_number']?.toString() ?? '',
        callTime: DateTime.tryParse(row['call_time']?.toString() ?? '') ??
            DateTime.now(),
        riskLevel: level,
        riskScore: (row['risk_score'] as int?) ?? 0,
        syntheticScore: (row['synthetic_score'] as int?) ?? 0,
        intentScore: (row['intent_score'] as int?) ?? 0,
        isSuspended: (row['is_suspended'] as int? ?? 0) == 1,
        avatarAsset: row['avatar_asset']?.toString(),
      );
    }).toList();
  }

  Future<void> insertCallRecord(CallRecord record) async {
    final db = await database;
    await db.insert(
      'call_records',
      {
        'id': record.id,
        'caller_name': record.callerName,
        'phone_number': record.phoneNumber,
        'call_time': record.callTime.toIso8601String(),
        'risk_level': record.riskLevel.name,
        'risk_score': record.riskScore,
        'synthetic_score': record.syntheticScore,
        'intent_score': record.intentScore,
        'is_suspended': record.isSuspended ? 1 : 0,
        'avatar_asset': record.avatarAsset,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> clearCallRecords() async {
    final db = await database;
    await db.delete('call_records');
  }

  // ── Blocked Callers ──────────────────────────────────────────────────────────
  Future<List<Map<String, String>>> loadBlockedCallers() async {
    final db = await database;
    final rows = await db.query('blocked_callers', orderBy: 'created_at DESC');
    return rows
        .map((r) => {
              'phone_number': r['phone_number']?.toString() ?? '',
              'reason': r['reason']?.toString() ?? '',
              'created_at': r['created_at']?.toString() ?? '',
            })
        .toList();
  }

  Future<bool> isNumberBlocked(String phoneNumber) async {
    final db = await database;
    final clean = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
    final rows = await db.query(
      'blocked_callers',
      where: 'phone_number = ?',
      whereArgs: [clean],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<void> blockCaller(String phoneNumber, String reason) async {
    final db = await database;
    final clean = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
    await db.insert(
      'blocked_callers',
      {
        'phone_number': clean,
        'reason': reason,
        'created_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> unblockCaller(String phoneNumber) async {
    final db = await database;
    final clean = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
    await db.delete(
      'blocked_callers',
      where: 'phone_number = ?',
      whereArgs: [clean],
    );
  }

  // ── Guardian Contacts ────────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> loadGuardianContacts() async {
    final db = await database;
    return await db.query('guardian_contacts', orderBy: 'name ASC');
  }

  Future<void> saveGuardianContact({
    required String id,
    required String name,
    required String phone,
    required String email,
    bool isActive = true,
  }) async {
    final db = await database;
    await db.insert(
      'guardian_contacts',
      {
        'id': id,
        'name': name,
        'phone': phone,
        'email': email,
        'is_active': isActive ? 1 : 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // ── Threat Audit Logs ────────────────────────────────────────────────────────
  Future<void> logThreatAudit({
    required String id,
    required String callId,
    required String threatType,
    required String description,
  }) async {
    final db = await database;
    await db.insert(
      'threat_audit_logs',
      {
        'id': id,
        'call_id': callId,
        'threat_type': threatType,
        'description': description,
        'timestamp': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> loadThreatAudits() async {
    final db = await database;
    return await db.query('threat_audit_logs', orderBy: 'timestamp DESC');
  }

  // ── App Events ───────────────────────────────────────────────────────────────
  Future<void> logEvent(String type, String message) async {
    final db = await database;
    await db.insert('app_events', {
      'type': type,
      'message': message,
      'created_at': DateTime.now().toIso8601String(),
    });
  }
}

final localDatabaseProvider = Provider<LocalDatabaseService>((ref) {
  return LocalDatabaseService();
});
