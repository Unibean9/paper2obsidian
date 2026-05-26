import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:http/http.dart' as http;
import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../models/paper_metadata.dart';
import '../services/api_service.dart';
import '../utils/title_inference.dart';

/// Plain Dart class that owns all business logic for the paper processing pipeline.
/// Does NOT import any Flutter widgets or call setState.
/// All methods return `Future<PaperMetadata>` or `Future<T>` — the screen calls setState after each await.
class PaperController {
  PaperController({
    required this.apiService,
    required this.onLog,
  });

  final ResearchApiService apiService;

  /// Callback for progress log messages — called during async pipelines.
  final void Function(String message) onLog;

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
    onLog('⏳ Step 1/4: Extracting text from PDF...');

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

    onLog('✅ Text extracted (${fullPdfText.length} chars).');

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
    onLog('⏳ Step 2/4: Parsing structure with Grobid...');
    Map<String, dynamic> grobidData = {};

    try {
      final String grobidXml = await apiService.processPdfWithGrobid(pdf);
      grobidData = ResearchApiService.parseGrobidXml(grobidXml);

      final String foundTitle = grobidData['title'] ?? '';
      if (foundTitle.isNotEmpty) {
        onLog(
          '✅ Grobid success: Found Title & ${grobidData['authors'].toString().split(';').length} authors.',
        );
      } else {
        onLog('ℹ️ Grobid: no title in PDF structure (will infer from text).');
      }
    } catch (e) {
      onLog('ℹ️ Grobid unavailable — continuing with text/Bedrock only.');
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
      onLog('ℹ️ Title for search: $searchTitle');
    }

    if (isCancelled) return PaperMetadata.empty();

    // --- STEP 3: OPENALEX ---
    onLog('⏳ Step 3/4: Fetching precise OpenAlex metadata...');
    Map<String, dynamic> openalexData = {};
    if (searchTitle.isNotEmpty &&
        !TitleInference.looksLikeFilename(searchTitle)) {
      try {
        openalexData = await apiService.fetchOpenAlexMetadata(searchTitle);
        if (openalexData.isNotEmpty &&
            (openalexData['doi']?.toString() ?? '').isNotEmpty &&
            openalexData['doi'] != 'Not Given') {
          onLog(
            '✅ OpenAlex success: Found DOI (${openalexData['doi']}) and Venue.',
          );
        } else {
          onLog(
            'ℹ️ OpenAlex: no match for this title (non-academic PDF is OK).',
          );
        }
      } catch (e) {
        onLog('ℹ️ OpenAlex skipped: $e');
        openalexData = {};
      }
    } else {
      onLog('ℹ️ OpenAlex skipped (title not suitable for academic search).');
    }

    if (isCancelled) return PaperMetadata.empty();

    // --- STEP 4: AWS BEDROCK ---
    onLog('⏳ Step 4/4: Extracting metadata & summary with AWS Bedrock...');
    String summary = 'Not Given';
    Map<String, dynamic> extraData = {};
    try {
      final result =
          await apiService.extractPaperMetadataWithBedrock(fullPdfText);
      summary = result.summary;
      extraData = result.extraData;
      onLog('✅ Bedrock success: Extracted extra details.');

      // Retry OpenAlex if Bedrock found a better title
      final String bedrockTitle =
          extraData['title']?.toString().trim() ?? '';
      if (openalexData.isEmpty &&
          bedrockTitle.isNotEmpty &&
          bedrockTitle != 'Not Given' &&
          !TitleInference.looksLikeFilename(bedrockTitle)) {
        onLog('ℹ️ Retrying OpenAlex with Bedrock title…');
        try {
          final retry = await apiService.fetchOpenAlexMetadata(bedrockTitle);
          if (retry.isNotEmpty &&
              (retry['doi']?.toString() ?? '').isNotEmpty &&
              retry['doi'] != 'Not Given') {
            openalexData = retry;
            grobidData['title'] = bedrockTitle;
            onLog('✅ OpenAlex matched after Bedrock title.');
          }
        } catch (_) {}
      } else if (bedrockTitle.isNotEmpty && bedrockTitle != 'Not Given') {
        grobidData['title'] = bedrockTitle;
      }
    } catch (e) {
      onLog('⚠️ Bedrock error: $e');
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

    onLog('🎉 Success! All data extracted and merged.');
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
        (openalexData['venue'] as String?) ??
        (grobidData['abstract']?.toString().split('\n').first ?? '');

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

    // Obsidian wiki-link for internal navigation
    final String pdfLink = '[[Papers/$pdfFileName]]';
    // file:// URI written into the markdown so openPaperFromLibrary can locate the PDF on disk.
    // The regex in openPaperFromLibrary looks for <file:///path> — this must stay in sync.
    final String encodedPdfPath =
        Uri.encodeFull(destPdf.path.replaceAll(r'\', '/'));
    final String pdfFileUri = '<file:///$encodedPdfPath>';

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
      debugPrint('Error creating internal notes: $e');
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

            // Parse năm từ YAML cơ bản bằng Regex
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
      debugPrint('Lỗi tải thư viện: $e');
    }
    return papers;
  }

  /// Opens a paper from the library by reading its Markdown file,
  /// locating the original PDF, and extracting text for AI chat.
  /// Returns PaperMetadata with resolvedPdf and fullPdfText set.
  Future<PaperMetadata> openPaperFromLibrary(String mdPath) async {
    final File mdFile = File(mdPath);
    final String content = await mdFile.readAsString();

    // Trích xuất đường dẫn file PDF gốc từ file Markdown
    // Định dạng mẫu: **Source PDF:** [Open Paper](<file:///D:/path/file.pdf>)
    final RegExp pdfPathRegex = RegExp(r'\<file:\/\/\/(.*?)\>');
    final RegExpMatch? match = pdfPathRegex.firstMatch(content);

    if (match == null || match.groupCount < 1) {
      throw Exception('Cannot extract PDF path from markdown metadata.');
    }

    String decodedPdfPath = Uri.decodeFull(match.group(1)!);
    // Sửa lại dấu gạch chéo cho hệ điều hành Windows nếu cần
    if (Platform.isWindows) {
      decodedPdfPath = decodedPdfPath.replaceAll('/', '\\');
    }

    final File pdfFile = File(decodedPdfPath);
    if (!await pdfFile.exists()) {
      throw Exception('Original PDF file not found at $decodedPdfPath');
    }

    onLog('✅ PDF found: ${p.basename(pdfFile.path)}');

    // Trích xuất lại văn bản để phục vụ Chat RAG
    final PdfDocument document = PdfDocument(
      inputBytes: pdfFile.readAsBytesSync(),
    );
    final int maxPages =
        document.pages.count > 10 ? 10 : document.pages.count;
    final String fullPdfText = PdfTextExtractor(
      document,
    ).extractText(startPageIndex: 0, endPageIndex: maxPages - 1);
    document.dispose();

    // Simple parsing of YAML frontmatter if possible
    final RegExpMatch? doiMatch =
        RegExp(r'doi:\s*"(.*?)"').firstMatch(content);
    final String doi = doiMatch?.group(1) ?? '';

    final RegExpMatch? summaryMatch =
        RegExp(r'## 1\. Summary\n([\s\S]*?)\n## 2\.').firstMatch(content);
    final String summary = summaryMatch?.group(1)?.trim() ?? '';

    return PaperMetadata(
      title: p.basenameWithoutExtension(mdPath),
      doi: doi,
      summary: summary,
      fullPdfText: fullPdfText,
      resolvedPdf: pdfFile,
    );
  }
}
