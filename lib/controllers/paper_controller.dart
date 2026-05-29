import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:http/http.dart' as http;
import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../config/env_config.dart';
import '../constants/messages.dart';
import '../exceptions/user_facing_exception.dart';
import '../models/paper_metadata.dart';
import '../models/zotero_item.dart';
import '../services/api_service.dart';
import '../services/logger_service.dart';
import '../services/paper_repository.dart';
import '../services/vault_index_service.dart';
import '../services/zotero_service.dart';
import '../utils/title_inference.dart';

class PaperController {
  PaperController({
    required this.apiService,
    required this.onLog,
    this.vaultIndexService,
    this.onIndexingStatus,
    this.paperRepository,
  });

  final ResearchApiService apiService;

  final void Function(String message) onLog;

  final VaultIndexService? vaultIndexService;

  final void Function(String? message)? onIndexingStatus;

  final PaperRepository? paperRepository;

  bool isCancelled = false;

  http.Client? _client;

  void cancel() {
    isCancelled = true;
    if (_client != null) {
      _client!.close();
      _client = null;
    }
  }

  Future<PaperMetadata> processPdf(File pdf) async {
    isCancelled = false;
    onLog(AppMessages.get(MessageKey.statusStep1Extracting));

    final PdfDocument document = PdfDocument(inputBytes: pdf.readAsBytesSync());
    final String extractedTextPage0 = PdfTextExtractor(
      document,
    ).extractText(startPageIndex: 0, endPageIndex: 0);

    final int maxPagesForContext = document.pages.count > 10
        ? 10
        : document.pages.count;
    final String fullPdfText = PdfTextExtractor(
      document,
    ).extractText(startPageIndex: 0, endPageIndex: maxPagesForContext - 1);
    document.dispose();

    onLog(AppMessages.statusTextExtracted(fullPdfText.length));

    final PaperMetadata meta = await _processWithGrobidAndOpenAlex(
      pdf: pdf,
      firstPageText: extractedTextPage0,
      fullPdfText: fullPdfText,
    );

    return meta;
  }

  Future<PaperMetadata> _processWithGrobidAndOpenAlex({
    required File pdf,
    required String firstPageText,
    required String fullPdfText,
  }) async {
    onLog(AppMessages.get(MessageKey.statusStep2Grobid));
    Map<String, dynamic> grobidData = {};

    try {
      final String grobidXml = await apiService.processPdfWithGrobid(pdf);
      grobidData = ResearchApiService.parseGrobidXml(grobidXml);

      final String foundTitle = grobidData['title'] ?? '';
      if (foundTitle.isNotEmpty) {
        final int authorCount = grobidData['authors']
            .toString()
            .split(';')
            .length;
        onLog(AppMessages.statusGrobidSuccess(authorCount));
      } else {
        onLog(AppMessages.get(MessageKey.statusGrobidNoTitle));
      }
    } catch (e) {
      AppLogger.log(
        'Grobid processing failed',
        category: LogCategory.network,
        error: e,
      );
      onLog(AppMessages.get(MessageKey.statusGrobidUnavailable));
      grobidData = {'title': '', 'authors': '', 'year': ''};
    }

    final String pdfBase = p.basenameWithoutExtension(pdf.path);
    final String searchTitle = TitleInference.resolve(
      grobidTitle: grobidData['title']?.toString() ?? '',
      firstPageText: firstPageText,
      pdfBasenameWithoutExt: pdfBase,
    );
    grobidData['title'] = searchTitle;
    if ((grobidData['title']?.toString().trim() ?? '').isNotEmpty) {
      onLog(AppMessages.statusTitleForSearch(searchTitle));
    }

    if (isCancelled) return PaperMetadata.empty();

    onLog(AppMessages.get(MessageKey.statusStep3OpenAlex));
    Map<String, dynamic> openalexData = {};
    if (searchTitle.isNotEmpty &&
        !TitleInference.looksLikeFilename(searchTitle)) {
      try {
        openalexData = await apiService.fetchOpenAlexMetadata(searchTitle);
        if (openalexData.isNotEmpty &&
            (openalexData['doi']?.toString() ?? '').isNotEmpty &&
            openalexData['doi'] != 'Not Given') {
          onLog(
            AppMessages.statusOpenAlexSuccess(openalexData['doi'].toString()),
          );
        } else {
          onLog(AppMessages.get(MessageKey.statusOpenAlexNoMatch));
        }
      } catch (e) {
        AppLogger.log(
          'OpenAlex metadata fetch failed',
          category: LogCategory.network,
          error: e,
        );
        onLog(AppMessages.statusOpenAlexSkippedError(e));
        openalexData = {};
      }
    } else {
      onLog(AppMessages.get(MessageKey.statusOpenAlexSkippedTitle));
    }

    if (isCancelled) return PaperMetadata.empty();

    onLog(AppMessages.get(MessageKey.statusStep4Bedrock));
    String summary = 'Not Given';
    Map<String, dynamic> extraData = {};
    try {
      final result = await apiService.extractPaperMetadataWithBedrock(
        fullPdfText,
      );
      summary = result.summary;
      extraData = result.extraData;
      onLog(AppMessages.statusBedrockSuccess());

      // Retry OpenAlex if Bedrock found a better title
      final String bedrockTitle = extraData['title']?.toString().trim() ?? '';
      if (openalexData.isEmpty &&
          bedrockTitle.isNotEmpty &&
          bedrockTitle != 'Not Given' &&
          !TitleInference.looksLikeFilename(bedrockTitle)) {
        onLog(AppMessages.get(MessageKey.statusBedrockRetryOpenAlex));
        try {
          final retry = await apiService.fetchOpenAlexMetadata(bedrockTitle);
          if (retry.isNotEmpty &&
              (retry['doi']?.toString() ?? '').isNotEmpty &&
              retry['doi'] != 'Not Given') {
            openalexData = retry;
            grobidData['title'] = bedrockTitle;
            onLog(AppMessages.get(MessageKey.statusOpenAlexMatchedBedrock));
          }
        } catch (_) {}
      } else if (bedrockTitle.isNotEmpty && bedrockTitle != 'Not Given') {
        grobidData['title'] = bedrockTitle;
      }
    } catch (e) {
      AppLogger.log(
        'Bedrock metadata extraction failed',
        category: LogCategory.parse,
        error: e,
      );
      onLog(AppMessages.statusBedrockError(e));
    }

    if (isCancelled) return PaperMetadata.empty();

    final PaperMetadata meta = _buildMetadata(
      grobidData: grobidData,
      openalexData: openalexData,
      summary: summary,
      extraData: extraData,
      fullPdfText: fullPdfText,
      resolvedPdf: pdf,
    );

    onLog(AppMessages.get(MessageKey.statusAllDone));
    return meta;
  }

  PaperMetadata _buildMetadata({
    required Map<String, dynamic> grobidData,
    required Map<String, dynamic> openalexData,
    required String summary,
    required Map<String, dynamic> extraData,
    required String fullPdfText,
    required File resolvedPdf,
  }) {
    final String bedrockTitle = extraData['title']?.toString() ?? '';

    final String title =
        (openalexData['title'] as String?) ??
        (bedrockTitle.isNotEmpty && bedrockTitle != 'Not Given'
            ? bedrockTitle
            : null) ??
        (grobidData['title'] as String?) ??
        '';

    final String authors =
        (openalexData['authors'] as String?) ??
        (grobidData['authors'] as String?) ??
        '';

    final String venue = (openalexData['venue'] as String?) ?? '';

    final String year =
        (openalexData['year'] as String?) ??
        (grobidData['year'] as String?) ??
        '';

    final String doi = (openalexData['doi'] as String?) ?? '';

    final String problemStatement =
        extraData['problem_statement']?.toString().isNotEmpty == true &&
            extraData['problem_statement'] != 'Not Given'
        ? extraData['problem_statement']
        : 'Not Given';

    final String keywords =
        extraData['keywords']?.toString().isNotEmpty == true &&
            extraData['keywords'] != 'Not Given'
        ? extraData['keywords']
        : ((grobidData['keywords'] as String?) ?? 'Not Given');

    final String limitation =
        extraData['limitation']?.toString().isNotEmpty == true &&
            extraData['limitation'] != 'Not Given'
        ? extraData['limitation']
        : 'Not Given';

    final String dataset =
        extraData['dataset']?.toString().isNotEmpty == true &&
            extraData['dataset'] != 'Not Given'
        ? extraData['dataset']
        : 'Not Given';

    final List<String> citations =
        grobidData['citations'] != null && grobidData['citations'] is List
        ? List<String>.from(grobidData['citations'])
        : [];

    final String abstract = grobidData['abstract']?.toString().trim() ?? '';

    return PaperMetadata(
      title: title,
      authors: authors,
      venue: venue,
      year: year,
      doi: doi,
      keywords: keywords,
      dataset: dataset,
      problemStatement: problemStatement,
      limitation: limitation,
      summary: summary,
      abstract: abstract,
      citations: citations,
      fullPdfText: fullPdfText,
      resolvedPdf: resolvedPdf,
    );
  }

  Future<String> sendChatMessage(String userText, String fullPdfText) async {
    final String response = await apiService.chatWithPaperContext(
      userText,
      fullPdfText,
    );
    return response.isNotEmpty ? response : 'Sorry, no response.';
  }

  Future<void> saveToObsidian({
    required PaperMetadata meta,
    required String vaultPath,
    required File pdf,
  }) async {
    final String paperDirPath = p.join(vaultPath, 'Papers');
    final Directory paperDir = Directory(paperDirPath);
    if (!await paperDir.exists()) {
      await paperDir.create(recursive: true);
    }

    String formatYamlList(String input, String folderName) {
      if (input.trim().isEmpty || input.toLowerCase() == 'not given') return '';
      return input
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .map((e) => '\n  - "[[$folderName/$e]]"')
          .join('');
    }

    String formatDisplayLinks(String input, String folderName) {
      if (input.trim().isEmpty || input.toLowerCase() == 'not given') {
        return 'Not Given';
      }
      return input
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .map((e) => '[[$folderName/$e]]')
          .join(', ');
    }

    final String safeTitle = meta.title.trim().replaceAll(
      RegExp(r'[\\/:*?"<>|]'),
      '_',
    );
    final String baseName = safeTitle.isNotEmpty
        ? safeTitle
        : p.basenameWithoutExtension(pdf.path);
    final String pdfFileName = '$baseName.pdf';
    final File destPdf = File(p.join(paperDirPath, pdfFileName));

    if (pdf.path != destPdf.path) {
      await pdf.copy(destPdf.path);
    }

    final String pdfLink = '[[Papers/$pdfFileName]]';

    final String encodedPdfPath = Uri.encodeFull(
      destPdf.path.replaceAll(r'\', '/'),
    );
    final String pdfFileUri = '<file:///$encodedPdfPath>';

    final String abstractText = meta.abstract.isNotEmpty
        ? meta.abstract
        : '*Abstract not available*';

    final String zoteroKeyLine = meta.zoteroItemKey != null
        ? '\nzotero_item_key: "${meta.zoteroItemKey}"'
        : '';

    final String markdownContent =
        '''---
title: "${meta.title.replaceAll('"', '\\"')}"
authors:${formatYamlList(meta.authors, "Authors")}
venue: "[[Venues/${meta.venue}]]"
year: "[[Years/${meta.year}]]"
doi: "${meta.doi}"
keywords:${formatYamlList(meta.keywords, "Tags")}$zoteroKeyLine
---
# ${meta.title}

**Source PDF:** [Open Paper]($pdfFileUri) $pdfLink

## Abstract
$abstractText

## 1. Summary
${meta.summary}

## 2. Metadata Connections
- **Authors:** ${formatDisplayLinks(meta.authors, "Authors")}
- **Year:** [[Years/${meta.year}]]
- **Venue:** [[Venues/${meta.venue}]]
- **DOI:** ${meta.doi}
- **Datasets:** ${formatDisplayLinks(meta.dataset, "Datasets")}
- **Keywords:** ${formatDisplayLinks(meta.keywords, "Tags")}

## 3. Research Details
- **Problem Statement:** ${meta.problemStatement}
- **Dataset Detail:** ${meta.dataset}
- **Limitations:** ${meta.limitation}
''';

    final String mdFileName = '$baseName.md';
    final File mdFile = File(p.join(paperDirPath, mdFileName));
    await mdFile.writeAsString(markdownContent);

    if (paperRepository != null) {
      try {
        final PaperMetadata metaWithPdf = meta.resolvedPdf == null
            ? meta.copyWith(resolvedPdf: destPdf)
            : (meta.resolvedPdf!.path == destPdf.path
                  ? meta
                  : meta.copyWith(resolvedPdf: destPdf));
        await paperRepository!.insertPaper(metaWithPdf);
      } catch (e) {
        AppLogger.log(
          'DB insert failed after vault write — paper saved to vault but not indexed in DB',
          category: LogCategory.other,
          error: e,
        );
      }
    }

    await _createInternalNotes(meta.authors, 'Authors', vaultPath);
    await _createInternalNotes(meta.keywords, 'Tags', vaultPath);
    await _createInternalNotes(meta.dataset, 'Datasets', vaultPath);
    if (meta.year.isNotEmpty) {
      await _createInternalNotes(meta.year, 'Years', vaultPath);
    }
    if (meta.venue.isNotEmpty) {
      await _createInternalNotes(meta.venue, 'Venues', vaultPath);
    }

    if (vaultIndexService != null) {
      onIndexingStatus?.call('Updating vault index…');
      // Safety timeout: always clear the indicator even if indexing hangs.
      final clearTimer = Timer(const Duration(seconds: 30), () {
        onIndexingStatus?.call(null);
      });
      () async {
        try {
          await vaultIndexService!.indexPaper(meta, vaultPath);
        } catch (e) {
          AppLogger.log(
            'Background indexing failed',
            category: LogCategory.other,
            error: e,
          );
        } finally {
          clearTimer.cancel();
          onIndexingStatus?.call(null);
        }
      }();
    }
  }

  Future<void> deletePaperFromLibrary({
    required String dedupKey,
    required String vaultPath,
  }) async {
    // Look up the paper title BEFORE deleting from DB, since dedupKey may be
    // a bare DOI (no title component) and vault files are named by title.
    String? paperTitle;
    if (paperRepository != null) {
      try {
        final PaperMetadata? paper = await paperRepository!.findByDedupKey(
          dedupKey,
        );
        paperTitle = paper?.title;
        await paperRepository!.deletePaper(dedupKey);
      } catch (e) {
        AppLogger.log(
          'DB delete failed for "$dedupKey"',
          category: LogCategory.other,
          error: e,
        );
      }
    }

    // Derive the vault filename base. saveToObsidian applies safeTitle sanitisation
    // (replaces [\\/:*?"<>|] with _) — use the same transform here so the
    // comparison matches what was actually written to disk.
    String rawTitle = paperTitle?.trim().isNotEmpty == true
        ? paperTitle!.trim()
        : (dedupKey.contains('|') ? dedupKey.split('|').first : '');
    final String titleForMatch = rawTitle.replaceAll(
      RegExp(r'[\\/:*?"<>|]'),
      '_',
    );

    if (titleForMatch.isEmpty) return;

    // Delete .md and PDF from vault
    final String paperDirPath = p.join(vaultPath, 'Papers');
    try {
      final Directory paperDir = Directory(paperDirPath);
      if (!await paperDir.exists()) return;
      final List<FileSystemEntity> files = paperDir.listSync();
      for (final FileSystemEntity file in files) {
        if (file is! File) continue;
        final String name = p.basenameWithoutExtension(file.path);
        final String ext = p.extension(file.path).toLowerCase();
        if (name.toLowerCase() == titleForMatch.toLowerCase() &&
            (ext == '.md' || ext == '.pdf')) {
          try {
            await file.delete();
          } catch (e) {
            AppLogger.log(
              'Failed to delete vault file ${file.path}',
              category: LogCategory.other,
              error: e,
            );
          }
        }
      }
    } catch (e) {
      AppLogger.log(
        'Failed to scan vault for deletion',
        category: LogCategory.other,
        error: e,
      );
    }
  }

  Future<void> _createInternalNotes(
    String input,
    String folderName,
    String vaultPath,
  ) async {
    if (input.trim().isEmpty || input.toLowerCase() == 'not given') return;
    try {
      final Directory directory = Directory(p.join(vaultPath, folderName));
      if (!await directory.exists()) await directory.create(recursive: true);
      final List<String> items = input.split(',').map((e) => e.trim()).toList();
      for (final String item in items) {
        if (item.isEmpty || item.toLowerCase() == 'not given') continue;
        final String safeName = item.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
        final File file = File(p.join(directory.path, '$safeName.md'));
        if (!await file.exists()) {
          await file.writeAsString(
            '# $item\n\n*Generated by Paper to Obsidian*',
          );
        }
      }
    } catch (e) {
      AppLogger.log(
        'Error creating internal notes for $folderName',
        category: LogCategory.other,
        error: e,
      );
    }
  }

  Future<List<Map<String, String>>> loadVaultLibrary(String vaultPath) async {
    if (vaultPath.isEmpty) return [];

    if (paperRepository != null) {
      try {
        final List<PaperMetadata> papers = await paperRepository!
            .getAllPapers();
        return papers
            .map(
              (m) => {
                'title': m.title,
                'year': m.year.isEmpty ? 'Not Given' : m.year,
                'dedup_key': m.dedupKey,
              },
            )
            .toList();
      } catch (e) {
        AppLogger.log(
          'DB load failed, falling back to vault scan',
          category: LogCategory.other,
          error: e,
        );
      }
    }

    // Fallback: scan vault markdown files (used when DB is unavailable)
    final List<Map<String, String>> papers = [];
    try {
      final Directory paperDir = Directory(p.join(vaultPath, 'Papers'));
      if (await paperDir.exists()) {
        final List<FileSystemEntity> files = paperDir.listSync();
        for (final FileSystemEntity file in files) {
          if (file is File && file.path.endsWith('.md')) {
            final String content = await file.readAsString();
            final String title = p.basenameWithoutExtension(file.path);
            String year = 'Not Given';
            final RegExp yearRegex = RegExp(r'year:\s*"\[\[Years\/(.*?)\]\]"');
            final RegExpMatch? match = yearRegex.firstMatch(content);
            if (match != null && match.groupCount >= 1) {
              year = match.group(1) ?? 'Not Given';
            }
            papers.add({'title': title, 'year': year, 'dedup_key': file.path});
          }
        }
      }
    } catch (e) {
      AppLogger.log(
        'Failed to load vault library',
        category: LogCategory.other,
        error: e,
      );
    }
    return papers;
  }

  Future<PaperMetadata> openPaperFromLibrary(String dedupKeyOrPath) async {
    if (paperRepository != null) {
      try {
        final PaperMetadata? found = await paperRepository!.findByDedupKey(
          dedupKeyOrPath,
        );
        if (found != null) {
          onLog(AppMessages.statusPdfFound(found.title));
          if (found.fullPdfText.isNotEmpty) return found;
          // fullPdfText missing — re-extract from PDF if available
          if (found.resolvedPdf != null) {
            final PdfDocument doc = PdfDocument(
              inputBytes: await found.resolvedPdf!.readAsBytes(),
            );
            final int maxPages = doc.pages.count > 10 ? 10 : doc.pages.count;
            final String text = PdfTextExtractor(
              doc,
            ).extractText(startPageIndex: 0, endPageIndex: maxPages - 1);
            doc.dispose();
            return found.copyWith(fullPdfText: text);
          }
          // No fullPdfText and no PDF to re-extract — return with empty context.
          AppLogger.log(
            'Paper "${found.title}" opened with no PDF text — chat context will be empty',
            category: LogCategory.other,
          );
          onLog(
            'Warning: no PDF text available for this paper — chat may not work.',
          );
          return found;
        }
      } catch (e) {
        AppLogger.log(
          'DB lookup failed for "$dedupKeyOrPath", falling back to markdown parse',
          category: LogCategory.other,
          error: e,
        );
      }
    }

    // Fallback: treat arg as an .md file path and parse it
    final String mdPath = dedupKeyOrPath;
    final File mdFile = File(mdPath);
    final String content = await mdFile.readAsString();

    final RegExp pdfPathRegex = RegExp(r'\<file:\/\/\/(.*?)\>');
    final RegExpMatch? match = pdfPathRegex.firstMatch(content);

    if (match == null || match.groupCount < 1) {
      throw Exception('Cannot extract PDF path from markdown metadata.');
    }

    String decodedPdfPath = Uri.decodeFull(match.group(1)!);

    if (Platform.isWindows) {
      decodedPdfPath = decodedPdfPath.replaceAll('/', '\\');
    }

    final File pdfFile = File(decodedPdfPath);
    if (!await pdfFile.exists()) {
      throw Exception('Original PDF file not found at $decodedPdfPath');
    }

    onLog(AppMessages.statusPdfFound(p.basename(pdfFile.path)));

    final PdfDocument document = PdfDocument(
      inputBytes: await pdfFile.readAsBytes(),
    );
    final int maxPages = document.pages.count > 10 ? 10 : document.pages.count;
    final String fullPdfText = PdfTextExtractor(
      document,
    ).extractText(startPageIndex: 0, endPageIndex: maxPages - 1);
    document.dispose();

    final RegExpMatch? closeFenceMatch = RegExp(
      r'(?:\r?\n)---(?:\r?\n|$)',
    ).firstMatch(content.substring(3));
    final int yamlEnd = closeFenceMatch != null
        ? closeFenceMatch.start + 3
        : -1;
    final String yamlBlock = yamlEnd > 0
        ? content.substring(0, yamlEnd)
        : content;

    final RegExpMatch? doiMatch = RegExp(
      r'doi:\s*"(.*?)"',
    ).firstMatch(yamlBlock);
    final String doi = doiMatch?.group(1) ?? '';

    final String? zoteroItemKey = RegExp(
      r'zotero_item_key:\s*"(.*?)"',
    ).firstMatch(yamlBlock)?.group(1);

    final RegExpMatch? yearMatch = RegExp(
      r'year:\s*"\[\[Years/(.*?)\]\]"',
    ).firstMatch(yamlBlock);
    final String year = yearMatch?.group(1) ?? '';

    final RegExpMatch? venueMatch = RegExp(
      r'venue:\s*"\[\[Venues/(.*?)\]\]"',
    ).firstMatch(yamlBlock);
    final String venue = venueMatch?.group(1) ?? '';

    final List<String> authorList = RegExp(
      r'"?\[\[Authors/(.*?)\]\]"?',
    ).allMatches(yamlBlock).map((m) => m.group(1)!).toList();
    final String authors = authorList.join(', ');

    final List<String> keywordList = RegExp(
      r'"?\[\[Tags/(.*?)\]\]"?',
    ).allMatches(yamlBlock).map((m) => m.group(1)!).toList();
    final String keywords = keywordList.join(', ');

    final RegExpMatch? summaryMatch = RegExp(
      r'## 1\. Summary\n([\s\S]*?)\n## 2\.',
    ).firstMatch(content);
    final String summary = summaryMatch?.group(1)?.trim() ?? '';

    final RegExpMatch? problemMatch = RegExp(
      r'\*\*Problem Statement:\*\*\s*(.+)',
    ).firstMatch(content);
    final String problemStatement = problemMatch?.group(1)?.trim() ?? '';

    final RegExpMatch? datasetMatch = RegExp(
      r'\*\*Dataset Detail:\*\*\s*(.+)',
    ).firstMatch(content);
    final String dataset = datasetMatch?.group(1)?.trim() ?? '';

    final RegExpMatch? limitationMatch = RegExp(
      r'\*\*Limitations:\*\*\s*(.+)',
    ).firstMatch(content);
    final String limitation = limitationMatch?.group(1)?.trim() ?? '';

    return PaperMetadata(
      title: p.basenameWithoutExtension(mdPath),
      authors: authors,
      venue: venue,
      year: year,
      doi: doi,
      keywords: keywords,
      dataset: dataset,
      problemStatement: problemStatement,
      limitation: limitation,
      summary: summary,
      fullPdfText: fullPdfText,
      resolvedPdf: pdfFile,
      zoteroItemKey: zoteroItemKey,
    );
  }

  // =========================================================================
  // ZOTERO INTEGRATION
  // =========================================================================

  ZoteroService? _zoteroService;

  /// Returns true when API key is stored AND a numeric userID has been resolved.
  Future<bool> get isZoteroConfigured async {
    final apiKey = await EnvConfig.getZoteroApiKey();
    if (apiKey.isEmpty) return false;
    final userId = await EnvConfig.getResolvedZoteroUserId();
    return userId != null && userId.isNotEmpty;
  }

  /// Lazily builds/refreshes ZoteroService with the current API key + userID.
  Future<ZoteroService> _getZoteroService() async {
    final apiKey = await EnvConfig.getZoteroApiKey();
    if (apiKey.isEmpty) {
      throw const UserFacingException(
        userMessage: 'No Zotero API key configured. Add one in Settings.',
      );
    }
    final userId = await EnvConfig.getResolvedZoteroUserId();
    if (userId == null || userId.isEmpty) {
      throw const UserFacingException(
        userMessage:
            'Zotero user ID not resolved. Click "Resolve User ID" in Settings first.',
      );
    }
    if (_zoteroService == null || _zoteroService!.resolvedUserId != userId) {
      _zoteroService = ZoteroService(apiKey: apiKey);
      _zoteroService!.setResolvedUserId(userId);
    } else {
      _zoteroService!.updateApiKey(apiKey);
      _zoteroService!.setResolvedUserId(userId);
    }
    return _zoteroService!;
  }

  /// Lists items in a Zotero collection. Caller shows the picker dialog.
  Future<List<ZoteroItem>> listZoteroItems(String collectionKey) async {
    final service = await _getZoteroService();
    return service.listCollectionItems(collectionKey);
  }

  /// Returns Zotero collection items enriched with local import status.
  /// Each record: `(item: ZoteroItem, isLocal: bool)`.
  Future<List<({ZoteroItem item, bool isLocal})>> loadZoteroCollectionWithStatus(
      String collectionKey) async {
    final service = await _getZoteroService();
    final items = await service.listCollectionItems(collectionKey);

    Set<String> importedKeys = {};
    if (paperRepository != null) {
      try {
        importedKeys = await paperRepository!.getAllImportedZoteroKeys();
      } catch (_) {}
    }

    return items
        .map((item) => (item: item, isLocal: importedKeys.contains(item.key)))
        .toList();
  }

  /// Downloads the PDF for [item] into a temp file inside the vault's
  /// `.paper2obsidian/` directory, processes it through the existing pipeline,
  /// and returns the extracted [PaperMetadata] with [zoteroItemKey] set.
  Future<PaperMetadata> importFromZotero({
    required String vaultPath,
    required ZoteroItem item,
    required String collectionKey,
  }) async {
    final service = await _getZoteroService();

    onLog('Fetching PDF attachment for "${item.title}"…');
    // Parent items (journalArticle etc.) don't have a direct /file endpoint.
    // We must first find the child PDF attachment key, then download that.
    final attachmentKey = await service.findPdfAttachmentKey(item.key);
    if (attachmentKey == null) {
      throw UserFacingException(
        userMessage:
            'No PDF attachment found for "${item.title}". '
            'Make sure the item has an attached PDF in Zotero.',
      );
    }

    onLog('Downloading PDF from Zotero…');
    Uint8List pdfBytes;
    try {
      pdfBytes = await service.downloadPdf(attachmentKey);
    } catch (e) {
      throw UserFacingException(
        userMessage:
            'Could not download PDF for "${item.title}": $e',
      );
    }

    // Write to temp file for processing.
    final tempDir = Directory(p.join(vaultPath, '.paper2obsidian'));
    if (!tempDir.existsSync()) tempDir.createSync(recursive: true);
    final tempPath = p.join(tempDir.path, 'zotero_import_${item.key}.pdf');
    final tempFile = File(tempPath);
    try {
      await tempFile.writeAsBytes(pdfBytes);
      onLog('Processing downloaded PDF…');
      final meta = await processPdf(tempFile);
      // Tag with Zotero key so the paper cannot be re-exported back.
      return meta.copyWith(zoteroItemKey: item.key);
    } catch (e) {
      if (tempFile.existsSync()) {
        try {
          await tempFile.delete();
        } catch (_) {}
      }
      rethrow;
    }
    // Note: tempFile is left on disk so the caller can use it as `selectedPdf`.
    // The startup scan (cleanupZoteroTempFiles) handles orphans.
  }

  /// Uploads a processed paper's PDF + metadata back to a Zotero collection.
  Future<void> exportToZotero({
    required String collectionKey,
    required PaperMetadata meta,
    required File pdf,
  }) async {
    final service = await _getZoteroService();
    final pdfBytes = await pdf.readAsBytes();
    final filename = p.basename(pdf.path);

    await service.uploadPdf(
      collectionKey: collectionKey,
      title: meta.title.isNotEmpty ? meta.title : filename,
      authors: meta.authors,
      year: meta.year.isNotEmpty ? meta.year : null,
      doi: meta.doi.isNotEmpty ? meta.doi : null,
      pdfBytes: pdfBytes,
      filename: filename,
      onProgress: onLog,
    );
  }

  /// Cleans up any orphaned Zotero import temp files from previous hard crashes.
  Future<void> cleanupZoteroTempFiles(String vaultPath) async {
    final tempDir = Directory(p.join(vaultPath, '.paper2obsidian'));
    if (!tempDir.existsSync()) return;
    try {
      final orphans = tempDir
          .listSync()
          .whereType<File>()
          .where((f) => p.basename(f.path).startsWith('zotero_import_'));
      for (final f in orphans) {
        try {
          await f.delete();
        } catch (_) {}
      }
    } catch (_) {}
  }
}
