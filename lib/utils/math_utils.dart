import 'dart:math' show log;

double dotProduct(List<double> a, List<double> b) {
  double sum = 0.0;
  for (int i = 0; i < a.length; i++) {
    sum += a[i] * b[i];
  }
  return sum;
}

Map<String, double> computeIdf(List<String> documents) {
  return computeIdfFromTokens(documents.map(tokenize).toList());
}

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
        termFreq *
        (k1 + 1) /
        (termFreq + k1 * (1 - b + b * docLen / avgDocLen));
    score += idf * normTf;
  }
  return score;
}

List<String> tokenize(String text) {
  const stopWords = {
    'the',
    'a',
    'an',
    'is',
    'are',
    'was',
    'were',
    'be',
    'been',
    'being',
    'have',
    'has',
    'had',
    'do',
    'does',
    'did',
    'will',
    'would',
    'could',
    'should',
    'may',
    'might',
    'shall',
    'can',
    'to',
    'of',
    'in',
    'for',
    'on',
    'with',
    'at',
    'by',
    'from',
    'and',
    'or',
    'but',
    'not',
    'so',
    'as',
    'if',
    'than',
    'that',
    'this',
    'these',
    'those',
    'it',
    'its',
    'he',
    'she',
    'we',
    'they',
    'you',
    'me',
    'him',
    'her',
    'us',
    'them',
    'my',
    'our',
    'your',
    'his',
    'their',
  };

  return text
      .toLowerCase()
      .split(RegExp(r'[^\w]+'))
      .where((t) => t.length >= 3 && !stopWords.contains(t))
      .toList();
}
