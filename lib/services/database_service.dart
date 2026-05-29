import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class DatabaseService {
  DatabaseService._();
  static final DatabaseService instance = DatabaseService._();

  Database? _db;

  static void initializeFfi() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  Future<Database> openForVault(String vaultPath) async {
    if (_db != null) {
      await _db!.close();
      _db = null;
    }

    final dir = Directory(p.join(vaultPath, '.paper2obsidian'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    _db = await databaseFactoryFfi.openDatabase(
      p.join(dir.path, 'paper2obsidian.db'),
      options: OpenDatabaseOptions(
        version: 2,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      ),
    );
    return _db!;
  }

  Database? get database => _db;

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE papers (
        id                INTEGER PRIMARY KEY AUTOINCREMENT,
        title             TEXT NOT NULL DEFAULT '',
        authors           TEXT NOT NULL DEFAULT '',
        venue             TEXT NOT NULL DEFAULT '',
        year              TEXT NOT NULL DEFAULT '',
        doi               TEXT NULL,
        keywords          TEXT NOT NULL DEFAULT '',
        dataset           TEXT NOT NULL DEFAULT '',
        problem_statement TEXT NOT NULL DEFAULT '',
        limitation        TEXT NOT NULL DEFAULT '',
        summary           TEXT NOT NULL DEFAULT '',
        abstract          TEXT NOT NULL DEFAULT '',
        citations         TEXT NOT NULL DEFAULT '[]',
        full_pdf_text     TEXT NOT NULL DEFAULT '',
        resolved_pdf_path TEXT NULL,
        dedup_key         TEXT NOT NULL UNIQUE,
        zotero_item_key   TEXT NULL
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute(
          'ALTER TABLE papers ADD COLUMN zotero_item_key TEXT NULL');
    }
  }
}
