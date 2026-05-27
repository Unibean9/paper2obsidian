import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/paper_metadata.dart';
import '../services/bedrock_client.dart';
import '../services/logger_service.dart';
import '../utils/math_utils.dart';

// ---------------------------------------------------------------------------
// Public data models
// ---------------------------------------------------------------------------

/// A single text chunk extracted from a paper note, with its embedding.
class ChunkRecord {
  const ChunkRecord({
    required this.id,
    required this.paperTitle,
    required this.section,
    required this.text,
    required this.embedding,
  });

  final String id;
  final String paperTitle;
  final String section;
  final String text;
  final List<double> embedding;

  Map<String, dynamic> toJson() => {
        'id': id,
        'paperTitle': paperTitle,
        'section': section,
        'text': text,
        'embedding': embedding,
      };

  factory ChunkRecord.fromJson(Map<String, dynamic> json) {
    final raw = (json['embedding'] as List<dynamic>)
        .map((e) => (e as num).toDouble())
        .toList();
    // Allow empty embeddings (BM25-only chunks stored when AWS is unconfigured).
    if (raw.isNotEmpty && raw.length != 1024) {
      throw FormatException(
        'ChunkRecord: expected 1024-dim embedding, got ${raw.length} '
        '(id: ${json['id']}). Index may be from a different model — rebuild.',
      );
    }
    return ChunkRecord(
      id: json['id'] as String,
      paperTitle: json['paperTitle'] as String,
      section: json['section'] as String,
      text: json['text'] as String,
      embedding: raw,
    );
  }
}

/// Return type for [VaultIndexService.query].
///
/// [usedFallback] is `true` when BM25 keyword search was used instead of
/// Bedrock semantic search (AWS credentials are absent or unconfigured).
class QueryResult {
  const QueryResult({required this.chunks, required this.usedFallback});

  final List<ChunkRecord> chunks;
  final bool usedFallback;
}

// ---------------------------------------------------------------------------
// VaultIndexService
// ---------------------------------------------------------------------------

/// Manages the vault's semantic search index.
///
/// Call [loadIndex] once at app start after the vault path is confirmed.
/// Call [indexVault] to rebuild the full index; [indexPaper] for incremental.
/// Call [query] to retrieve top-k relevant chunks by semantic or BM25 search.
class VaultIndexService {
  VaultIndexService({required this.bedrockClient});

  final BedrockClient bedrockClient;

  List<ChunkRecord> _chunks = [];
  Map<String, List<String>> _tokenCache = {}; // chunk.id → tokens
  Map<String, double> _idfCache = {};
  double _avgDocLen = 0.0;
  int _paperCount = 0;
  bool _indexingInProgress = false;

  // ─── Path helpers ──────────────────────────────────────────────────────────

  static String _indexDir(String vaultPath) =>
      p.join(vaultPath, '.paper2obsidian');

  static String _indexPath(String vaultPath) =>
      p.join(_indexDir(vaultPath), 'vault_index.json');

  // ─── Public status ─────────────────────────────────────────────────────────

  bool indexExists(String vaultPath) =>
      File(_indexPath(vaultPath)).existsSync();

  /// Number of distinct papers currently loaded in memory.
  int loadedPaperCount() => _paperCount;

  // ─── Load ──────────────────────────────────────────────────────────────────

  /// Loads the persisted index into memory.
  ///
  /// No-ops if [vaultPath] is empty. Treats a missing, corrupt, or
  /// dimension-mismatched index file as an absent index (safe empty state).
  Future<void> loadIndex(String vaultPath) async {
    if (vaultPath.trim().isEmpty) return;

    try {
      final content = await File(_indexPath(vaultPath)).readAsString();
      final data = jsonDecode(content) as Map<String, dynamic>;

      // Reject indexes built with a different embedding dimension.
      final int dims = (data['embeddingDimensions'] as num?)?.toInt() ?? 0;
      if (dims != 0 && dims != 1024) {
        AppLogger.log(
          'VaultIndexService: dimension mismatch ($dims ≠ 1024) — treating as absent',
          category: LogCategory.other,
        );
        _resetState();
        return;
      }

      final rawChunks = data['chunks'] as List<dynamic>? ?? [];
      _chunks = rawChunks
          .map((c) => ChunkRecord.fromJson(c as Map<String, dynamic>))
          .toList();
      _rebuildCaches();
    } on FileSystemException {
      _resetState(); // Index does not exist yet — begin with empty state
    } on FormatException catch (e) {
      AppLogger.log(
        'VaultIndexService: corrupt index — treating as absent',
        category: LogCategory.other,
        error: e,
      );
      _resetState();
    }
  }

  // ─── Full vault index ──────────────────────────────────────────────────────

  /// Indexes all `.md` papers in `{vaultPath}/Papers/`.
  ///
  /// Skips (with a log) if another indexing operation is in progress.
  /// File reads are parallelised; embed calls are sequential (API rate limits).
  /// Writes atomically then updates the vault `.gitignore` if needed.
  Future<void> indexVault(String vaultPath) =>
      _withMutex('indexVault', () => _indexVaultImpl(vaultPath));

  Future<void> _indexVaultImpl(String vaultPath) async {
    final paperDir = Directory(p.join(vaultPath, 'Papers'));
    if (!await paperDir.exists()) {
      _resetState();
      await _saveIndex(vaultPath, paperCount: 0);
      return;
    }

    final mdFiles = paperDir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.md'))
        .toList();

    // Parallel file reads — embed calls stay sequential below.
    final fileContents = await Future.wait(
      mdFiles.map((file) async => MapEntry(
            p.basenameWithoutExtension(file.path),
            await file.readAsString(),
          )),
    );

    final List<ChunkRecord> allChunks = [];
    for (final entry in fileContents) {
      allChunks.addAll(await _chunkAndEmbed(entry.key, entry.value));
    }

    _chunks = allChunks;
    _rebuildCaches();
    await _saveIndex(vaultPath, paperCount: mdFiles.length);
    await _ensureVaultGitignore(vaultPath);
  }

  // ─── Incremental index ─────────────────────────────────────────────────────

  /// Incrementally re-indexes one paper after it has been saved to the vault.
  ///
  /// Replaces prior chunks for [meta.title] and re-saves the index.
  /// Skips (with a log) if another indexing operation is in progress.
  Future<void> indexPaper(PaperMetadata meta, String vaultPath) =>
      _withMutex('indexPaper', () => _indexPaperImpl(meta, vaultPath));

  Future<void> _indexPaperImpl(PaperMetadata meta, String vaultPath) async {
    final safeTitle =
        meta.title.trim().replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final mdFile = File(p.join(vaultPath, 'Papers', '$safeTitle.md'));
    if (!await mdFile.exists()) {
      AppLogger.log(
        'VaultIndexService: note file not found: ${mdFile.path}',
        category: LogCategory.other,
      );
      return;
    }

    final content = await mdFile.readAsString();
    final newChunks = await _chunkAndEmbed(meta.title, content);

    _chunks
      ..removeWhere((c) => c.paperTitle == meta.title)
      ..addAll(newChunks);
    _rebuildCaches();

    await _saveIndex(
      vaultPath,
      paperCount: _chunks.map((c) => c.paperTitle).toSet().length,
    );
  }

  // ─── Query ─────────────────────────────────────────────────────────────────

  /// Returns the top-[topK] most relevant [ChunkRecord]s for [question].
  ///
  /// Semantic (cosine) search when AWS is configured;
  /// BM25 fallback when [BedrockUnconfiguredException] is thrown.
  /// Returns an empty result — never throws — when the index has no chunks.
  Future<QueryResult> query(String question, {int topK = 5}) async {
    if (_chunks.isEmpty) {
      AppLogger.log(
        'RAG query: index empty — no papers indexed yet',
        category: LogCategory.other,
      );
      return const QueryResult(chunks: [], usedFallback: false);
    }

    try {
      final queryVec = await bedrockClient.embed(question);
      // Only cosine-score chunks that have a real embedding vector.
      // BM25-only chunks (empty embedding) are excluded from the semantic path
      // but remain searchable via the BM25 fallback.
      final embeddable = _chunks.where((c) => c.embedding.isNotEmpty).toList();
      if (embeddable.isEmpty) {
        return _bm25Query(question, topK: topK);
      }
      final scored = embeddable
          .map((c) => _Scored(dotProduct(queryVec, c.embedding), c))
          .toList()
        ..sort((a, b) => b.score.compareTo(a.score));

      final topChunks = scored.take(topK).toList();
      _logQueryResult(
        question: question,
        mode: 'semantic',
        scored: topChunks,
      );

      return QueryResult(
        chunks: topChunks.map((s) => s.chunk).toList(),
        usedFallback: false,
      );
    } on BedrockUnconfiguredException {
      return _bm25Query(question, topK: topK);
    }
  }

  // ─── BM25 fallback ─────────────────────────────────────────────────────────

  QueryResult _bm25Query(String question, {int topK = 5}) {
    if (_chunks.isEmpty) {
      return const QueryResult(chunks: [], usedFallback: true);
    }

    final queryTerms = tokenize(question);
    final scored = _chunks
        .map((c) => _Scored(
              bm25ScoreFromTokens(
                queryTerms,
                _tokenCache[c.id] ?? const [],
                _idfCache,
                _avgDocLen,
              ),
              c,
            ))
        .toList()
      ..sort((a, b) => b.score.compareTo(a.score));

    final topChunks = scored.take(topK).toList();
    _logQueryResult(
      question: question,
      mode: 'bm25',
      scored: topChunks,
    );

    return QueryResult(
      chunks: topChunks.map((s) => s.chunk).toList(),
      usedFallback: true,
    );
  }

  // ─── Chunking + embedding ──────────────────────────────────────────────────

  Future<List<ChunkRecord>> _chunkAndEmbed(
    String paperTitle,
    String content,
  ) async {
    final sections = _splitIntoSections(content);
    final List<ChunkRecord> records = [];

    for (int i = 0; i < sections.length; i++) {
      final section = sections[i];
      if (section.text.trim().length < 50) {
        AppLogger.log(
          'VaultIndexService: short chunk skipped '
          '"$paperTitle/${section.heading}" (${section.text.trim().length} chars)',
          category: LogCategory.other,
        );
        continue;
      }

      // Always store the chunk so BM25 can search it.
      // Embedding is optional — only needed for semantic (cosine) search.
      List<double> embedding = [];
      try {
        embedding = await bedrockClient.embed(section.text);
      } on BedrockUnconfiguredException {
        // AWS not configured — store chunk with empty embedding; BM25 still works.
        AppLogger.log(
          'VaultIndexService: AWS unconfigured — storing "$paperTitle/'
          '${section.heading}" as BM25-only chunk',
          category: LogCategory.network,
        );
      } catch (e) {
        AppLogger.log(
          'VaultIndexService: embed failed "$paperTitle/${section.heading}"',
          category: LogCategory.network,
          error: e,
        );
      }
      records.add(ChunkRecord(
        id: '${paperTitle}_${i}_${section.heading.hashCode.abs()}',
        paperTitle: paperTitle,
        section: section.heading,
        text: section.text,
        embedding: embedding,
      ));
    }
    return records;
  }

  // ─── Markdown section splitter ─────────────────────────────────────────────

  // ─── Query logging ─────────────────────────────────────────────────────────

  /// Logs retrieval diagnostics for a completed query.
  ///
  /// Signals to watch:
  /// - `topScore < 0.30` (semantic) → query poorly matched vault content
  /// - `topScore < 1.00` (bm25)     → keyword overlap is low
  /// - `mode: bm25`                 → AWS credentials absent or embed failed
  void _logQueryResult({
    required String question,
    required String mode,
    required List<_Scored> scored,
  }) {
    if (scored.isEmpty) {
      AppLogger.log(
        'RAG [$mode] "${_truncate(question)}" → no results',
        category: LogCategory.other,
      );
      return;
    }

    final topScore = scored.first.score;
    final hits = scored
        .map((s) => '${s.chunk.paperTitle.split(' ').first}/'
            '${s.chunk.section} '
            '(${s.score.toStringAsFixed(2)})')
        .join(', ');

    final quality = mode == 'semantic'
        ? (topScore >= 0.70
            ? '✓ strong'
            : topScore >= 0.45
                ? '~ moderate'
                : '✗ weak — query may not match vault')
        : (topScore >= 5.0
            ? '✓ strong'
            : topScore >= 1.0
                ? '~ moderate'
                : '✗ weak — few keyword matches');

    AppLogger.log(
      'RAG [$mode] "${_truncate(question)}" → '
      'top=${topScore.toStringAsFixed(2)} $quality | $hits',
      category: LogCategory.other,
    );
  }

  static String _truncate(String s, [int max = 60]) =>
      s.length <= max ? s : '${s.substring(0, max)}…';

  // ─── Markdown section splitter ─────────────────────────────────────────────

  List<_Section> _splitIntoSections(String content) {
    String body = content;
    if (content.startsWith('---')) {
      final end = content.indexOf('\n---', 3);
      if (end != -1) body = content.substring(end + 4).trim();
    }

    final headingRe = RegExp(r'^#{2,3}\s+(.+)$', multiLine: true);
    final List<_Section> raw = [];
    String heading = 'Introduction';
    final List<String> lines = [];

    for (final line in body.split('\n')) {
      final m = headingRe.firstMatch(line);
      if (m != null) {
        if (lines.isNotEmpty) raw.add(_Section(heading, lines.join('\n').trim()));
        heading = m.group(1)!.trim();
        lines.clear();
      } else {
        lines.add(line);
      }
    }
    if (lines.isNotEmpty) raw.add(_Section(heading, lines.join('\n').trim()));

    // Merge sections shorter than 200 chars into their nearest neighbour.
    final List<_Section> merged = [];
    for (final s in raw) {
      if (s.text.length < 200 && merged.isNotEmpty) {
        final prev = merged.removeLast();
        merged.add(_Section(prev.heading, '${prev.text}\n${s.text}'));
      } else {
        merged.add(s);
      }
    }
    return merged;
  }

  // ─── Cache management ──────────────────────────────────────────────────────

  /// Recomputes all derived caches after `_chunks` changes.
  void _rebuildCaches() {
    _tokenCache = {for (final c in _chunks) c.id: tokenize(c.text)};
    _idfCache = computeIdfFromTokens(_tokenCache.values.toList());
    _avgDocLen = _chunks.isEmpty
        ? 0.0
        : _tokenCache.values.fold<int>(0, (s, t) => s + t.length) /
            _chunks.length;
    _paperCount = _chunks.map((c) => c.paperTitle).toSet().length;
  }

  void _resetState() {
    _chunks = [];
    _tokenCache = {};
    _idfCache = {};
    _avgDocLen = 0.0;
    _paperCount = 0;
  }

  // ─── Mutex helper ──────────────────────────────────────────────────────────

  Future<void> _withMutex(String op, Future<void> Function() fn) async {
    if (_indexingInProgress) {
      AppLogger.log(
        'VaultIndexService.$op: skipped — indexing already in progress',
        category: LogCategory.other,
      );
      return;
    }
    _indexingInProgress = true;
    try {
      await fn();
    } finally {
      _indexingInProgress = false;
    }
  }

  // ─── Atomic save ───────────────────────────────────────────────────────────

  Future<void> _saveIndex(String vaultPath, {required int paperCount}) async {
    final dir = Directory(_indexDir(vaultPath));
    if (!await dir.exists()) await dir.create(recursive: true);

    final indexPath = _indexPath(vaultPath);
    final tmp = File('$indexPath.tmp');
    // Use 0 when all chunks are BM25-only (no embeddings) so loadIndex does
    // not reject the file with a dimension-mismatch error on next startup.
    final hasSemantic = _chunks.any((c) => c.embedding.isNotEmpty);
    await tmp.writeAsString(jsonEncode({
      'version': 1,
      'embeddingDimensions': hasSemantic ? 1024 : 0,
      'paperCount': paperCount,
      'chunks': _chunks.map((c) => c.toJson()).toList(),
    }));
    await tmp.rename(indexPath);
  }

  // ─── Vault .gitignore ──────────────────────────────────────────────────────

  Future<void> _ensureVaultGitignore(String vaultPath) async {
    try {
      if (!await Directory(p.join(vaultPath, '.git')).exists()) return;

      const entry = '.paper2obsidian/';
      final file = File(p.join(vaultPath, '.gitignore'));
      final content = await file.exists() ? await file.readAsString() : '';
      if (content.contains(entry)) return;

      await file.writeAsString(
          content.isEmpty ? '$entry\n' : '$content\n$entry\n');
    } catch (e) {
      AppLogger.log(
        'VaultIndexService: failed to update vault .gitignore',
        category: LogCategory.other,
        error: e,
      );
    }
  }
}

// ---------------------------------------------------------------------------
// Private helpers
// ---------------------------------------------------------------------------

class _Section {
  const _Section(this.heading, this.text);
  final String heading;
  final String text;
}

class _Scored {
  const _Scored(this.score, this.chunk);
  final double score;
  final ChunkRecord chunk;
}
