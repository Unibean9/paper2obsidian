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
}
