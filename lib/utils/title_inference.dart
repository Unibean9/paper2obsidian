/// Heuristics when Grobid cannot extract a clean title.
class TitleInference {
  TitleInference._();

  /// True if title looks like a download filename, not a real paper title.
  static bool looksLikeFilename(String title) {
    final t = title.trim();
    if (t.length < 8) return true;
    if (RegExp(r'^[a-f0-9]{8,}[_-]', caseSensitive: false).hasMatch(t)) {
      return true;
    }
    if (t.contains('_') && !t.contains(' ')) return true;
    if (RegExp(r'\(\d+\)$').hasMatch(t) && t.length > 60) return true;
    return false;
  }

  /// Clean a PDF filename into a readable title guess.
  static String cleanFilename(String filenameWithoutExt) {
    var t = filenameWithoutExt.trim();
    // Drop leading hash/id prefixes: 69fe2a55..._Real-Title
    t = t.replaceFirst(RegExp(r'^[a-f0-9]{8,}[_-]+', caseSensitive: false), '');
    t = t.replaceAll(RegExp(r'[_]+'), ' ');
    t = t.replaceAll(RegExp(r'\s*\(\d+\)\s*$'), '');
    t = t.replaceAll(RegExp(r'\s+v\d+\s*$', caseSensitive: false), '');
    t = t.replaceAll(RegExp(r'\s+\d{6,8}\s*$'), '');
    t = t.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (t.isEmpty) return filenameWithoutExt;
    return t;
  }

  /// First plausible title line from page-one text.
  static String? fromFirstPage(String pageText) {
    final lines = pageText.split('\n');
    for (final raw in lines) {
      var line = raw.trim();
      if (line.isEmpty) continue;
      if (line.length < 12 || line.length > 220) continue;
      final lower = line.toLowerCase();
      if (_skipLine(lower)) continue;
      if (RegExp(r'^\d+$').hasMatch(line)) continue;
      if (line.split(' ').length < 2) continue;
      return line;
    }
    return null;
  }

  static bool _skipLine(String lower) {
    const skip = [
      'abstract',
      'introduction',
      'keywords',
      'contents',
      'table of contents',
      'arxiv',
      'doi:',
      'http',
      'www.',
      'copyright',
      'page ',
    ];
    for (final s in skip) {
      if (lower.startsWith(s)) return true;
    }
    return false;
  }

  /// Best title for OpenAlex search: Grobid → first page → cleaned filename.
  static String resolve({
    required String grobidTitle,
    required String firstPageText,
    required String pdfBasenameWithoutExt,
  }) {
    final g = grobidTitle.trim();
    if (g.isNotEmpty && !looksLikeFilename(g)) return g;

    final fromPage = fromFirstPage(firstPageText);
    if (fromPage != null && fromPage.isNotEmpty) return fromPage;

    return cleanFilename(pdfBasenameWithoutExt);
  }
}
