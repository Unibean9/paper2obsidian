import 'dart:io';

/// Data class holding all extracted metadata for a research paper.
/// Used as the return type for all PaperController pipeline methods.
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
    this.citations = const [],
    this.fullPdfText = '',
    this.resolvedPdf,
  });

  /// Returns an empty PaperMetadata with all default values.
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
  final List<String> citations;

  /// Full extracted PDF text (≤10 pages), used for Bedrock summarization and AI chat.
  final String fullPdfText;

  /// The actual PDF File resolved during processing or library open (may be null before processing).
  final File? resolvedPdf;
}
