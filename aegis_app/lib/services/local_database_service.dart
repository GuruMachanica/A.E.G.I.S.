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
      version: 1,
      singleInstance: !isTestEnv,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE call_records(
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
          CREATE TABLE app_events(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            type TEXT,
            message TEXT,
            created_at TEXT
          )
        ''');
      },
    );
    return _db!;
  }

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
