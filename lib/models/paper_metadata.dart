import 'dart:io';

/// Status of the paper workflow.
///
/// Transitions: idle → uploaded → extracting → done (or error → uploaded to retry).
/// The [ActionsPanel] renders different buttons based on this value.
/// The [_extractPaper] `finally` block is the single owner of cancel-path transitions.
enum PaperStatus { idle, uploaded, extracting, done, error }

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
    this.abstract = '',
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

  /// Abstract text extracted from Grobid XML, or empty if unavailable.
  final String abstract;

  final List<String> citations;

  /// Full extracted PDF text (≤10 pages), used for Bedrock summarization and AI chat.
  final String fullPdfText;

  /// The actual PDF File resolved during processing or library open (may be null before processing).
  final File? resolvedPdf;
}
