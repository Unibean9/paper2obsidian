import 'dart:math' show log;

/// Dot product of two equal-length vectors.
/// For unit-normalised vectors (Titan with `normalize: true`) this equals cosine similarity.
double dotProduct(List<double> a, List<double> b) {
  double sum = 0.0;
  for (int i = 0; i < a.length; i++) {
    sum += a[i] * b[i];
  }
  return sum;
}

/// Precomputes BM25 IDF values for each unique term across [documents].
///
/// Lucene-style formula with smoothing:
///   IDF(t) = ln( (N − df(t) + 0.5) / (df(t) + 0.5) + 1 )
///
/// Returns an empty map when [documents] is empty.
Map<String, double> computeIdf(List<String> documents) {
  return computeIdfFromTokens(documents.map(tokenize).toList());
}

/// Token-first variant of [computeIdf] — accepts already-tokenised docs.
/// Prefer this when tokens are cached to avoid re-tokenising the corpus.
Map<String, double> computeIdfFromTokens(List<List<String>> tokenizedDocs) {
  final int n = tokenizedDocs.length;
  if (n == 0) return {};

  final Map<String, int> df = {};
  for (final tokens in tokenizedDocs) {
    for (final term in tokens.toSet()) {
      df[term] = (df[term] ?? 0) + 1;
    }
  }

  return {
    for (final e in df.entries)
      e.key: log((n - e.value + 0.5) / (e.value + 0.5) + 1),
  };
}

/// BM25 relevance score for a raw [query]–[document] string pair.
///
/// [idfMap] must be pre-computed with [computeIdf] over the full corpus.
/// [avgDocLen] is the mean token count across all corpus documents.
double bm25Score(
  String query,
  String document,
  Map<String, double> idfMap,
  double avgDocLen, {
  double k1 = 1.5,
  double b = 0.75,
}) {
  return bm25ScoreFromTokens(
    tokenize(query),
    tokenize(document),
    idfMap,
    avgDocLen,
    k1: k1,
    b: b,
  );
}

/// Token-first variant of [bm25Score] — accepts pre-tokenised query and doc.
/// Prefer this when document tokens are cached to avoid re-tokenising per query.
double bm25ScoreFromTokens(
  List<String> queryTerms,
  List<String> docTokens,
  Map<String, double> idfMap,
  double avgDocLen, {
  double k1 = 1.5,
  double b = 0.75,
}) {
  if (avgDocLen == 0 || docTokens.isEmpty) return 0.0;

  final int docLen = docTokens.length;
  final Map<String, int> tf = {};
  for (final term in docTokens) {
    tf[term] = (tf[term] ?? 0) + 1;
  }

  double score = 0.0;
  for (final term in queryTerms) {
    final double idf = idfMap[term] ?? 0.0;
    if (idf == 0.0) continue;
    final int termFreq = tf[term] ?? 0;
    if (termFreq == 0) continue;
    final double normTf =
        termFreq * (k1 + 1) / (termFreq + k1 * (1 - b + b * docLen / avgDocLen));
    score += idf * normTf;
  }
  return score;
}

/// Tokenises [text] into lowercase alphabetic tokens, stripping stop words
/// and tokens shorter than 3 characters.
List<String> tokenize(String text) {
  const stopWords = {
    'the', 'a', 'an', 'is', 'are', 'was', 'were', 'be', 'been', 'being',
    'have', 'has', 'had', 'do', 'does', 'did', 'will', 'would', 'could',
    'should', 'may', 'might', 'shall', 'can', 'to', 'of', 'in', 'for',
    'on', 'with', 'at', 'by', 'from', 'and', 'or', 'but', 'not', 'so',
    'as', 'if', 'than', 'that', 'this', 'these', 'those', 'it', 'its',
    'he', 'she', 'we', 'they', 'you', 'me', 'him', 'her', 'us', 'them',
    'my', 'our', 'your', 'his', 'their',
  };

  return text
      .toLowerCase()
      .split(RegExp(r'[^\w]+'))
      .where((t) => t.length >= 3 && !stopWords.contains(t))
      .toList();
}
