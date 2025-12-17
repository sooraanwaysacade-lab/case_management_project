// lib/helpers/local_database_helper.dart
import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class LocalDatabaseHelper {
  LocalDatabaseHelper._privateConstructor();
  static final LocalDatabaseHelper instance =
  LocalDatabaseHelper._privateConstructor();

  static Database? _database;
  Future<Database> get database async => _database ??= await _initDB();

  Future<Database> _initDB() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'case_management_local.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  FutureOr<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE appeals (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        caseId TEXT,
        studentId TEXT,
        studentName TEXT,
        reason TEXT,
        filePath TEXT,     -- path to local evidence file (optional)
        createdAt TEXT,
        isSynced INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE evidences (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        caseId TEXT,
        originalName TEXT,
        localPath TEXT,
        mimeType TEXT,
        createdAt TEXT,
        isSynced INTEGER DEFAULT 0
      )
    ''');
  }

  // === Appeals ===
  Future<int> insertAppeal(Map<String, dynamic> row) async {
    final db = await database;
    return await db.insert('appeals', row);
  }

  Future<List<Map<String, dynamic>>> getAllAppeals() async {
    final db = await database;
    return await db.query('appeals', orderBy: 'createdAt DESC');
  }

  Future<List<Map<String, dynamic>>> getUnsyncedAppeals() async {
    final db = await database;
    return await db.query('appeals', where: 'isSynced = ?', whereArgs: [0]);
  }

  Future<int> markAppealSynced(int id) async {
    final db = await database;
    return await db.update('appeals', {'isSynced': 1}, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteAppeal(int id) async {
    final db = await database;
    return await db.delete('appeals', where: 'id = ?', whereArgs: [id]);
  }

  // === Evidences ===
  Future<int> insertEvidence(Map<String, dynamic> row) async {
    final db = await database;
    return await db.insert('evidences', row);
  }

  Future<List<Map<String, dynamic>>> getAllEvidences() async {
    final db = await database;
    return await db.query('evidences', orderBy: 'createdAt DESC');
  }

  Future<List<Map<String, dynamic>>> getUnsyncedEvidences() async {
    final db = await database;
    return await db.query('evidences', where: 'isSynced = ?', whereArgs: [0]);
  }

  Future<int> markEvidenceSynced(int id) async {
    final db = await database;
    return await db.update('evidences', {'isSynced': 1}, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteEvidence(int id) async {
    final db = await database;
    return await db.delete('evidences', where: 'id = ?', whereArgs: [id]);
  }
}
