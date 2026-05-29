import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../models/paper_metadata.dart';
import 'database_service.dart';

class PaperRepository {
  PaperRepository(this._dbService);

  final DatabaseService _dbService;

  Database get _db {
    final db = _dbService.database;
    if (db == null) {
      throw StateError('DB not opened — call DatabaseService.openForVault first');
    }
    return db;
  }

  Future<List<PaperMetadata>> getAllPapers() async {
    final rows = await _db.query('papers');
    return rows.map(PaperMetadata.fromMap).toList();
  }

  Future<PaperMetadata?> findByDedupKey(String dedupKey) async {
    final rows = await _db.query(
      'papers',
      where: 'dedup_key = ?',
      whereArgs: [dedupKey],
      limit: 1,
    );
    return rows.isEmpty ? null : PaperMetadata.fromMap(rows.first);
  }

  Future<PaperMetadata?> findByDoi(String doi) async {
    if (doi.trim().isEmpty) return null;
    final rows = await _db.query(
      'papers',
      where: 'doi = ?',
      whereArgs: [doi.trim()],
      limit: 1,
    );
    return rows.isEmpty ? null : PaperMetadata.fromMap(rows.first);
  }

  /// Upserts paper by dedup_key. Returns the row id.
  Future<int> insertPaper(PaperMetadata paper) async {
    final map = paper.toMap();
    return await _db.insert(
      'papers',
      map,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deletePaper(String dedupKey) async {
    await _db.delete('papers', where: 'dedup_key = ?', whereArgs: [dedupKey]);
  }

  Future<PaperMetadata?> findByZoteroKey(String zoteroItemKey) async {
    final rows = await _db.query(
      'papers',
      where: 'zotero_item_key = ?',
      whereArgs: [zoteroItemKey],
      limit: 1,
    );
    return rows.isEmpty ? null : PaperMetadata.fromMap(rows.first);
  }

  /// Returns a Set of all Zotero item keys that have been imported locally.
  Future<Set<String>> getAllImportedZoteroKeys() async {
    final rows = await _db.query(
      'papers',
      columns: ['zotero_item_key'],
      where: 'zotero_item_key IS NOT NULL',
    );
    return rows
        .map((r) => r['zotero_item_key'] as String)
        .toSet();
  }
}
