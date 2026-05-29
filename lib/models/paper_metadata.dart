import 'dart:convert';
import 'dart:io';

enum PaperStatus {
  idle,
  uploaded,
  extracting,
  done,
  error,
}

class PaperMetadata {
  const PaperMetadata({
    this.title = '',
    this.authors = '',
    this.venue = '',
    this.year = '',
    this.doi = '',
    this.keywords = '',
    this.dataset = '',
    this.problemStatement = '',
    this.limitation = '',
    this.summary = '',
    this.abstract = '',
    this.citations = const [],
    this.fullPdfText = '',
    this.resolvedPdf,
    this.zoteroItemKey,
  });

  factory PaperMetadata.empty() => const PaperMetadata();

  final String title;
  final String authors;
  final String venue;
  final String year;
  final String doi;
  final String keywords;
  final String dataset;
  final String problemStatement;
  final String limitation;
  final String summary;

  final String abstract;

  final List<String> citations;

  final String fullPdfText;

  final File? resolvedPdf;

  /// Non-null when this paper was imported from Zotero. Prevents re-export.
  final String? zoteroItemKey;

  String get dedupKey {
    final d = doi.trim();
    if (d.isNotEmpty) return d;
    final t = title.trim().toLowerCase();
    final y = year.trim();
    return '$t|$y';
  }

  Map<String, Object?> toMap() => {
    'title': title,
    'authors': authors,
    'venue': venue,
    'year': year,
    'doi': doi.trim().isEmpty ? null : doi.trim(),
    'keywords': keywords,
    'dataset': dataset,
    'problem_statement': problemStatement,
    'limitation': limitation,
    'summary': summary,
    'abstract': abstract,
    'citations': jsonEncode(citations),
    'full_pdf_text': fullPdfText,
    'resolved_pdf_path': resolvedPdf?.path,
    'dedup_key': dedupKey,
    'zotero_item_key': zoteroItemKey,
  };

  factory PaperMetadata.fromMap(Map<String, Object?> map) {
    final citationsRaw = map['citations'] as String?;
    List<String> citations = [];
    if (citationsRaw != null && citationsRaw.isNotEmpty) {
      try {
        citations = (jsonDecode(citationsRaw) as List)
            .map((e) => e.toString())
            .toList();
      } catch (_) {}
    }

    final pdfPath = map['resolved_pdf_path'] as String?;
    File? resolvedPdf;
    if (pdfPath != null && pdfPath.isNotEmpty) {
      final f = File(pdfPath);
      resolvedPdf = f.existsSync() ? f : null;
    }

    return PaperMetadata(
      title: (map['title'] as String?) ?? '',
      authors: (map['authors'] as String?) ?? '',
      venue: (map['venue'] as String?) ?? '',
      year: (map['year'] as String?) ?? '',
      doi: (map['doi'] as String?) ?? '',
      keywords: (map['keywords'] as String?) ?? '',
      dataset: (map['dataset'] as String?) ?? '',
      problemStatement: (map['problem_statement'] as String?) ?? '',
      limitation: (map['limitation'] as String?) ?? '',
      summary: (map['summary'] as String?) ?? '',
      abstract: (map['abstract'] as String?) ?? '',
      citations: citations,
      fullPdfText: (map['full_pdf_text'] as String?) ?? '',
      resolvedPdf: resolvedPdf,
      zoteroItemKey: map['zotero_item_key'] as String?,
    );
  }

  PaperMetadata copyWith({
    String? title,
    String? authors,
    String? venue,
    String? year,
    String? doi,
    String? keywords,
    String? dataset,
    String? problemStatement,
    String? limitation,
    String? summary,
    String? abstract,
    List<String>? citations,
    String? fullPdfText,
    File? resolvedPdf,
    Object? zoteroItemKey = _sentinel,
  }) => PaperMetadata(
    title: title ?? this.title,
    authors: authors ?? this.authors,
    venue: venue ?? this.venue,
    year: year ?? this.year,
    doi: doi ?? this.doi,
    keywords: keywords ?? this.keywords,
    dataset: dataset ?? this.dataset,
    problemStatement: problemStatement ?? this.problemStatement,
    limitation: limitation ?? this.limitation,
    summary: summary ?? this.summary,
    abstract: abstract ?? this.abstract,
    citations: citations ?? this.citations,
    fullPdfText: fullPdfText ?? this.fullPdfText,
    resolvedPdf: resolvedPdf ?? this.resolvedPdf,
    zoteroItemKey: zoteroItemKey == _sentinel
        ? this.zoteroItemKey
        : zoteroItemKey as String?,
  );
}

const Object _sentinel = Object();
