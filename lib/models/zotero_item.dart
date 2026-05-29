class ZoteroItem {
  const ZoteroItem({
    required this.key,
    required this.title,
    required this.authors,
    this.year,
    this.doi,
  });

  final String key;
  final String title;
  final String authors;
  final String? year;
  final String? doi;

  factory ZoteroItem.fromJson(Map<String, dynamic> json) {
    final data = (json['data'] as Map<String, dynamic>?) ?? json;
    final creatorsRaw = data['creators'] as List? ?? [];
    final authors = creatorsRaw
        .where((c) => (c['creatorType'] as String?) == 'author')
        .map((c) {
          final last = c['lastName'] as String? ?? '';
          final first = c['firstName'] as String? ?? '';
          return first.isNotEmpty ? '$last, $first' : last;
        })
        .where((s) => s.isNotEmpty)
        .join('; ');

    return ZoteroItem(
      key: json['key'] as String? ?? data['key'] as String? ?? '',
      title: data['title'] as String? ?? 'Untitled',
      authors: authors.isNotEmpty ? authors : 'Unknown',
      year: data['date'] as String?,
      doi: data['DOI'] as String?,
    );
  }

  @override
  String toString() => title;
}

class ZoteroCollection {
  const ZoteroCollection({
    required this.key,
    required this.name,
    this.parentKey,
  });

  final String key;
  final String name;
  final String? parentKey;

  factory ZoteroCollection.fromJson(Map<String, dynamic> json) {
    final data = (json['data'] as Map<String, dynamic>?) ?? json;
    return ZoteroCollection(
      key: json['key'] as String? ?? data['key'] as String? ?? '',
      name: data['name'] as String? ?? 'Unnamed',
      parentKey: data['parentCollection'] is String
          ? data['parentCollection'] as String
          : null,
    );
  }
}
