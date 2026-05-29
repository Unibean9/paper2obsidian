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
  );
}
