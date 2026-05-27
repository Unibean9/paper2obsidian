import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:http/http.dart' as http;
import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../constants/messages.dart';
import '../models/paper_metadata.dart';
import '../services/api_service.dart';
import '../services/logger_service.dart';
import '../services/vault_index_service.dart';
import '../utils/title_inference.dart';

/// Plain Dart class that owns all business logic for the paper processing pipeline.
/// Does NOT import any Flutter widgets or call setState.
/// All methods return `Future<PaperMetadata>` or `Future<T>` — the screen calls
/// setState after each await.
class PaperController {
  PaperController({
    required this.apiService,
    required this.onLog,
    this.vaultIndexService,
    this.onIndexingStatus,
  });

  final ResearchApiService apiService;

  /// Callback for progress log messages — called during async pipelines.
  final void Function(String message) onLog;

  /// Optional vault index service — when set, triggers background indexing after save.
  final VaultIndexService? vaultIndexService;

  /// Called with a status string when background indexing starts, and with
  /// `null` when it completes (or fails) — used to drive a progress indicator.
  final void Function(String? message)? onIndexingStatus;

  /// Cooperative cancellation flag — set to true by cancel(), checked by async pipelines.
  bool isCancelled = false;

  // TODO: _client is preserved from the original but is never assigned during API calls —
  // _client?.close() in cancel() is currently dead code. Not fixed in this refactor.
  http.Client? _client;

  // =========================================================================
  // CANCEL
  // =========================================================================

  /// Stops the processing pipeline. The screen is responsible for resetting
  /// isLoading and statusText in its own onCancel handler.
  void cancel() {
    isCancelled = true;
    if (_client != null) {
      _client!.close();
      _client = null;
    }
  }

  // =========================================================================
  // PDF PROCESSING PIPELINE
  // =========================================================================

  /// Step 1: Reads the PDF, extracts text, then runs the full pipeline.
  /// Returns PaperMetadata with fullPdfText and resolvedPdf set.
  Future<PaperMetadata> processPdf(File pdf) async {
    isCancelled = false;
    onLog(AppMessages.get(MessageKey.statusStep1Extracting));

    final PdfDocument document = PdfDocument(
      inputBytes: pdf.readAsBytesSync(),
    );
    final String extractedTextPage0 = PdfTextExtractor(
      document,
    ).extractText(startPageIndex: 0, endPageIndex: 0);

    final int maxPagesForContext =
        document.pages.count > 10 ? 10 : document.pages.count;
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

  /// Steps 2–4: Grobid → OpenAlex → Bedrock.
  /// Returns PaperMetadata with all fields populated.
  Future<PaperMetadata> _processWithGrobidAndOpenAlex({
    required File pdf,
    required String firstPageText,
    required String fullPdfText,
  }) async {
    // --- STEP 2: GROBID ---
    onLog(AppMessages.get(MessageKey.statusStep2Grobid));
    Map<String, dynamic> grobidData = {};

    try {
      final String grobidXml = await apiService.processPdfWithGrobid(pdf);
      grobidData = ResearchApiService.parseGrobidXml(grobidXml);

      final String foundTitle = grobidData['title'] ?? '';
      if (foundTitle.isNotEmpty) {
        final int authorCount =
            grobidData['authors'].toString().split(';').length;
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

    // --- STEP 3: OPENALEX ---
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
            AppMessages.statusOpenAlexSuccess(
              openalexData['doi'].toString(),
            ),
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

    // --- STEP 4: AWS BEDROCK ---
    onLog(AppMessages.get(MessageKey.statusStep4Bedrock));
    String summary = 'Not Given';
    Map<String, dynamic> extraData = {};
    try {
      final result =
          await apiService.extractPaperMetadataWithBedrock(fullPdfText);
      summary = result.summary;
      extraData = result.extraData;
      onLog(AppMessages.statusBedrockSuccess());

      // Retry OpenAlex if Bedrock found a better title
      final String bedrockTitle =
          extraData['title']?.toString().trim() ?? '';
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

  /// Merges data from all sources into a PaperMetadata object.
  /// Priority: OpenAlex > Bedrock > Grobid > fallback.
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

    final String venue =
        (openalexData['venue'] as String?) ?? '';

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

  // =========================================================================
  // AI CHAT
  // =========================================================================

  /// Sends a chat message and returns the assistant's response string.
  Future<String> sendChatMessage(String userText, String fullPdfText) async {
    final String response = await apiService.chatWithPaperContext(
      userText,
      fullPdfText,
    );
    return response.isNotEmpty ? response : 'Sorry, no response.';
  }

  // =========================================================================
  // OBSIDIAN SAVE
  // =========================================================================

  /// Saves the paper metadata as a Markdown note and copies the PDF to the vault.
  /// Throws on any file system error — the screen catches and shows the error.
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

    // Obsidian wiki-link for internal navigation.
    final String pdfLink = '[[Papers/$pdfFileName]]';
    // file:// URI written into the markdown so openPaperFromLibrary can locate
    // the PDF on disk. The regex in openPaperFromLibrary expects <file:///path>
    // — this must stay in sync.
    final String encodedPdfPath =
        Uri.encodeFull(destPdf.path.replaceAll(r'\', '/'));
    final String pdfFileUri = '<file:///$encodedPdfPath>';

    final String abstractText =
        meta.abstract.isNotEmpty ? meta.abstract : '*Abstract not available*';

    final String markdownContent = '''---
title: "${meta.title.replaceAll('"', '\\"')}"
authors:${formatYamlList(meta.authors, "Authors")}
venue: "[[Venues/${meta.venue}]]"
year: "[[Years/${meta.year}]]"
doi: "${meta.doi}"
keywords:${formatYamlList(meta.keywords, "Tags")}
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

    await _createInternalNotes(meta.authors, 'Authors', vaultPath);
    await _createInternalNotes(meta.keywords, 'Tags', vaultPath);
    await _createInternalNotes(meta.dataset, 'Datasets', vaultPath);
    if (meta.year.isNotEmpty) {
      await _createInternalNotes(meta.year, 'Years', vaultPath);
    }
    if (meta.venue.isNotEmpty) {
      await _createInternalNotes(meta.venue, 'Venues', vaultPath);
    }

    // Background indexing — must NOT be awaited so the save returns immediately.
    // Errors are non-fatal: log and clear the progress indicator.
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

  /// Creates stub notes for linked items (Authors, Tags, Datasets, etc.)
  Future<void> _createInternalNotes(
    String input,
    String folderName,
    String vaultPath,
  ) async {
    if (input.trim().isEmpty || input.toLowerCase() == 'not given') return;
    try {
      final Directory directory = Directory(p.join(vaultPath, folderName));
      if (!await directory.exists()) await directory.create(recursive: true);
      final List<String> items =
          input.split(',').map((e) => e.trim()).toList();
      for (final String item in items) {
        if (item.isEmpty || item.toLowerCase() == 'not given') continue;
        final String safeName =
            item.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
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

  // =========================================================================
  // VAULT LIBRARY
  // =========================================================================

  /// Returns a list of paper entries from the vault's Papers directory.
  /// Each entry has keys: title, year, path.
  Future<List<Map<String, String>>> loadVaultLibrary(String vaultPath) async {
    if (vaultPath.isEmpty) return [];

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

            // Parse year from YAML frontmatter using regex.
            final RegExp yearRegex =
                RegExp(r'year:\s*"\[\[Years\/(.*?)\]\]"');
            final RegExpMatch? match = yearRegex.firstMatch(content);
            if (match != null && match.groupCount >= 1) {
              year = match.group(1) ?? 'Not Given';
            }

            papers.add({'title': title, 'year': year, 'path': file.path});
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

  /// Opens a paper from the library by reading its Markdown file,
  /// locating the original PDF, and extracting text for AI chat.
  /// Returns PaperMetadata with resolvedPdf and fullPdfText set.
  Future<PaperMetadata> openPaperFromLibrary(String mdPath) async {
    final File mdFile = File(mdPath);
    final String content = await mdFile.readAsString();

    // Extract original PDF path from the Markdown file.
    // Expected format: **Source PDF:** [Open Paper](<file:///D:/path/file.pdf>)
    final RegExp pdfPathRegex = RegExp(r'\<file:\/\/\/(.*?)\>');
    final RegExpMatch? match = pdfPathRegex.firstMatch(content);

    if (match == null || match.groupCount < 1) {
      throw Exception('Cannot extract PDF path from markdown metadata.');
    }

    String decodedPdfPath = Uri.decodeFull(match.group(1)!);
    // Restore Windows backslashes if needed.
    if (Platform.isWindows) {
      decodedPdfPath = decodedPdfPath.replaceAll('/', '\\');
    }

    final File pdfFile = File(decodedPdfPath);
    if (!await pdfFile.exists()) {
      throw Exception('Original PDF file not found at $decodedPdfPath');
    }

    onLog(AppMessages.statusPdfFound(p.basename(pdfFile.path)));

    // Re-extract text for Chat RAG context.
    // Use async read to avoid blocking the Flutter UI thread (fix: was readAsBytesSync).
    final PdfDocument document = PdfDocument(
      inputBytes: await pdfFile.readAsBytes(),
    );
    final int maxPages =
        document.pages.count > 10 ? 10 : document.pages.count;
    final String fullPdfText = PdfTextExtractor(
      document,
    ).extractText(startPageIndex: 0, endPageIndex: maxPages - 1);
    document.dispose();

    // ── Locate YAML frontmatter block (CRLF-safe) ────────────────────────────
    //
    // Standard YAML frontmatter: opening `---` on line 1, closing `---` on its
    // own line. On Windows, VS Code and git (autocrlf=true) write CRLF endings,
    // so the closing fence may be `\r\n---\r\n` instead of `\n---\n`.
    // Search for the closing fence starting after the opening `---` (offset 3).
    final RegExpMatch? closeFenceMatch =
        RegExp(r'(?:\r?\n)---(?:\r?\n|$)').firstMatch(content.substring(3));
    final int yamlEnd =
        closeFenceMatch != null ? closeFenceMatch.start + 3 : -1;
    final String yamlBlock =
        yamlEnd > 0 ? content.substring(0, yamlEnd) : content;

    // ── Parse YAML frontmatter fields (all scoped to yamlBlock) ──────────────

    final RegExpMatch? doiMatch =
        RegExp(r'doi:\s*"(.*?)"').firstMatch(yamlBlock);
    final String doi = doiMatch?.group(1) ?? '';

    // year: "[[Years/YYYY]]"
    final RegExpMatch? yearMatch =
        RegExp(r'year:\s*"\[\[Years/(.*?)\]\]"').firstMatch(yamlBlock);
    final String year = yearMatch?.group(1) ?? '';

    // venue: "[[Venues/NAME]]"
    final RegExpMatch? venueMatch =
        RegExp(r'venue:\s*"\[\[Venues/(.*?)\]\]"').firstMatch(yamlBlock);
    final String venue = venueMatch?.group(1) ?? '';

    // authors YAML list:  - "[[Authors/Name]]"  (one per line, frontmatter only)
    final List<String> authorList = RegExp(r'"?\[\[Authors/(.*?)\]\]"?')
        .allMatches(yamlBlock)
        .map((m) => m.group(1)!)
        .toList();
    final String authors = authorList.join(', ');

    // keywords YAML list: - "[[Tags/kw]]"  (frontmatter only)
    final List<String> keywordList = RegExp(r'"?\[\[Tags/(.*?)\]\]"?')
        .allMatches(yamlBlock)
        .map((m) => m.group(1)!)
        .toList();
    final String keywords = keywordList.join(', ');

    // ── Parse body sections ───────────────────────────────────────────────────

    final RegExpMatch? summaryMatch =
        RegExp(r'## 1\. Summary\n([\s\S]*?)\n## 2\.').firstMatch(content);
    final String summary = summaryMatch?.group(1)?.trim() ?? '';

    // **Problem Statement:** value (single line)
    final RegExpMatch? problemMatch =
        RegExp(r'\*\*Problem Statement:\*\*\s*(.+)').firstMatch(content);
    final String problemStatement = problemMatch?.group(1)?.trim() ?? '';

    // **Dataset Detail:** value (single line) — original field name in template
    final RegExpMatch? datasetMatch =
        RegExp(r'\*\*Dataset Detail:\*\*\s*(.+)').firstMatch(content);
    final String dataset = datasetMatch?.group(1)?.trim() ?? '';

    // **Limitations:** value (single line)
    final RegExpMatch? limitationMatch =
        RegExp(r'\*\*Limitations:\*\*\s*(.+)').firstMatch(content);
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
    );
  }
}
