import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:convert';
import 'package:biosyn_report_flutter/models/coaching_report.dart';
import 'package:biosyn_report_flutter/models/plan.dart';

/// Local Database Service using sqflite
class DatabaseService {
  static Database? _database;
  static const String _databaseName = 'biosyn_coaching.db';
  static const int _databaseVersion = 1;

  /// Get database instance
  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  /// Initialize database
  static Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _databaseName);

    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  /// Create tables
  static Future<void> _onCreate(Database db, int version) async {
    // Reports table
    await db.execute('''
      CREATE TABLE reports (
        id TEXT PRIMARY KEY,
        date TEXT NOT NULL,
        dm_id TEXT NOT NULL,
        dm_name TEXT NOT NULL,
        mr_id TEXT NOT NULL,
        mr_name TEXT NOT NULL,
        data TEXT NOT NULL,
        synced INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // Plans table
    await db.execute('''
      CREATE TABLE plans (
        id TEXT PRIMARY KEY,
        dm_id TEXT NOT NULL,
        dm_name TEXT NOT NULL,
        date TEXT NOT NULL,
        mr_id TEXT NOT NULL,
        mr_name TEXT NOT NULL,
        status TEXT DEFAULT 'pending',
        synced INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // Users table
    await db.execute('''
      CREATE TABLE users (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        email TEXT,
        role TEXT NOT NULL,
        synced INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // Sync queue table
    await db.execute('''
      CREATE TABLE sync_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        table_name TEXT NOT NULL,
        record_id TEXT NOT NULL,
        operation TEXT NOT NULL,
        data TEXT NOT NULL,
        retry_count INTEGER DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');

    // Create indexes
    await db.execute('CREATE INDEX idx_reports_dm_id ON reports(dm_id)');
    await db.execute('CREATE INDEX idx_reports_date ON reports(date)');
    await db.execute('CREATE INDEX idx_reports_synced ON reports(synced)');
    await db.execute('CREATE INDEX idx_plans_dm_id ON plans(dm_id)');
    await db.execute('CREATE INDEX idx_plans_date ON plans(date)');
    await db.execute('CREATE INDEX idx_plans_synced ON plans(synced)');
    await db.execute('CREATE INDEX idx_sync_queue_table ON sync_queue(table_name)');
  }

  /// Upgrade database
  static Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Handle database migrations here
  }

  // ==================== Reports Operations ====================

  /// Save report
  /// Note: reportId now includes coachRole to allow multiple reports with same MR and date but different coach roles
  static Future<void> saveReport(CoachingReport report, {bool synced = false}) async {
    final db = await database;
    // Include coachRole in reportId to differentiate between DM/FT/PM/MSL reports with same MR and date
    final reportId = '${report.mrId}_${report.date}_${report.coachRole ?? 'null'}';
    
    await db.insert(
      'reports',
      {
        'id': reportId,
        'date': report.date,
        'dm_id': report.dmId,
        'dm_name': report.dmName,
        'mr_id': report.mrId,
        'mr_name': report.mrName,
        'data': json.encode(report.toJson()),
        'synced': synced ? 1 : 0,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Get all reports
  static Future<List<CoachingReport>> getReports({String? dmId}) async {
    final db = await database;
    List<Map<String, dynamic>> maps;

    if (dmId != null) {
      maps = await db.query(
        'reports',
        where: 'dm_id = ?',
        whereArgs: [dmId],
        orderBy: 'date DESC',
      );
    } else {
      maps = await db.query('reports', orderBy: 'date DESC');
    }

    return maps.map((map) {
      final data = json.decode(map['data'] as String) as Map<String, dynamic>;
      return CoachingReport.fromJson(data);
    }).toList();
  }

  /// Get unsynced reports
  static Future<List<Map<String, dynamic>>> getUnsyncedReports() async {
    final db = await database;
    return await db.query(
      'reports',
      where: 'synced = ?',
      whereArgs: [0],
      orderBy: 'created_at ASC',
    );
  }

  /// Mark report as synced
  static Future<void> markReportAsSynced(String reportId) async {
    final db = await database;
    await db.update(
      'reports',
      {
        'synced': 1,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [reportId],
    );
  }

  /// Delete report
  static Future<void> deleteReport(String reportId) async {
    final db = await database;
    await db.delete(
      'reports',
      where: 'id = ?',
      whereArgs: [reportId],
    );
  }

  // ==================== Plans Operations ====================

  /// Save plan
  static Future<void> savePlan(Plan plan, {bool synced = false}) async {
    final db = await database;
    
    await db.insert(
      'plans',
      {
        'id': plan.id,
        'dm_id': plan.dmId,
        'dm_name': plan.dmName,
        'date': plan.date,
        'mr_id': plan.mrId,
        'mr_name': plan.mrName,
        'status': plan.status,
        'synced': synced ? 1 : 0,
        'created_at': plan.createdAt.toIso8601String(),
        'updated_at': plan.updatedAt.toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Get all plans
  static Future<List<Plan>> getPlans({String? dmId}) async {
    final db = await database;
    List<Map<String, dynamic>> maps;

    if (dmId != null) {
      maps = await db.query(
        'plans',
        where: 'dm_id = ?',
        whereArgs: [dmId],
        orderBy: 'date ASC',
      );
    } else {
      maps = await db.query('plans', orderBy: 'date ASC');
    }

    return maps.map((map) {
      return Plan(
        id: map['id'] as String,
        dmId: map['dm_id'] as String,
        dmName: map['dm_name'] as String,
        date: map['date'] as String,
        mrId: map['mr_id'] as String,
        mrName: map['mr_name'] as String,
        status: map['status'] as String,
        createdAt: DateTime.parse(map['created_at'] as String),
        updatedAt: DateTime.parse(map['updated_at'] as String),
      );
    }).toList();
  }

  /// Get plan by date
  static Future<Plan?> getPlanByDate(String dmId, String date) async {
    final db = await database;
    final maps = await db.query(
      'plans',
      where: 'dm_id = ? AND date = ?',
      whereArgs: [dmId, date],
      limit: 1,
    );

    if (maps.isEmpty) return null;

    final map = maps.first;
    return Plan(
      id: map['id'] as String,
      dmId: map['dm_id'] as String,
      dmName: map['dm_name'] as String,
      date: map['date'] as String,
      mrId: map['mr_id'] as String,
      mrName: map['mr_name'] as String,
      status: map['status'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  /// Get unsynced plans
  static Future<List<Map<String, dynamic>>> getUnsyncedPlans() async {
    final db = await database;
    return await db.query(
      'plans',
      where: 'synced = ?',
      whereArgs: [0],
      orderBy: 'created_at ASC',
    );
  }

  /// Mark plan as synced
  static Future<void> markPlanAsSynced(String planId) async {
    final db = await database;
    await db.update(
      'plans',
      {
        'synced': 1,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [planId],
    );
  }

  /// Delete plan
  static Future<void> deletePlan(String planId) async {
    final db = await database;
    await db.delete(
      'plans',
      where: 'id = ?',
      whereArgs: [planId],
    );
  }

  // ==================== Sync Queue Operations ====================

  /// Add to sync queue
  static Future<void> addToSyncQueue(
    String tableName,
    String recordId,
    String operation,
    Map<String, dynamic> data,
  ) async {
    final db = await database;
    await db.insert(
      'sync_queue',
      {
        'table_name': tableName,
        'record_id': recordId,
        'operation': operation, // 'insert', 'update', 'delete'
        'data': json.encode(data),
        'retry_count': 0,
        'created_at': DateTime.now().toIso8601String(),
      },
    );
  }

  /// Get sync queue items
  static Future<List<Map<String, dynamic>>> getSyncQueue({int? limit}) async {
    final db = await database;
    return await db.query(
      'sync_queue',
      orderBy: 'created_at ASC',
      limit: limit,
    );
  }

  /// Increment retry count
  static Future<void> incrementRetryCount(int queueId) async {
    final db = await database;
    final result = await db.query(
      'sync_queue',
      where: 'id = ?',
      whereArgs: [queueId],
      limit: 1,
    );
    if (result.isNotEmpty) {
      final currentRetry = result.first['retry_count'] as int;
      await db.update(
        'sync_queue',
        {
          'retry_count': currentRetry + 1,
        },
        where: 'id = ?',
        whereArgs: [queueId],
      );
    }
  }

  /// Remove from sync queue
  static Future<void> removeFromSyncQueue(int queueId) async {
    final db = await database;
    await db.delete(
      'sync_queue',
      where: 'id = ?',
      whereArgs: [queueId],
    );
  }

  /// Clear sync queue
  static Future<void> clearSyncQueue() async {
    final db = await database;
    await db.delete('sync_queue');
  }

  // ==================== Utility ====================

  /// Clear all data (for testing/reset)
  static Future<void> clearAllData() async {
    final db = await database;
    await db.delete('reports');
    await db.delete('plans');
    await db.delete('users');
    await db.delete('sync_queue');
  }

  /// Close database
  static Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }
}

