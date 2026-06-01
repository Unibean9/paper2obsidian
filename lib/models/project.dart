import 'package:uuid/uuid.dart';

class Project {
  Project({
    String? id,
    required this.name,
    required this.vaultPath,
    this.locale,
    this.zoteroCollectionKey,
    DateTime? createdAt,
    DateTime? lastOpenedAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        lastOpenedAt = lastOpenedAt ?? DateTime.now();

  final String id;
  final String name;
  final String vaultPath;
  final String? locale;
  final String? zoteroCollectionKey;
  final DateTime createdAt;
  final DateTime lastOpenedAt;

  Project copyWith({
    String? name,
    String? vaultPath,
    Object? locale = _sentinel,
    Object? zoteroCollectionKey = _sentinel,
    DateTime? lastOpenedAt,
  }) {
    return Project(
      id: id,
      name: name ?? this.name,
      vaultPath: vaultPath ?? this.vaultPath,
      locale: locale == _sentinel ? this.locale : locale as String?,
      zoteroCollectionKey: zoteroCollectionKey == _sentinel
          ? this.zoteroCollectionKey
          : zoteroCollectionKey as String?,
      createdAt: createdAt,
      lastOpenedAt: lastOpenedAt ?? this.lastOpenedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'vaultPath': vaultPath,
        'locale': locale,
        'zoteroCollectionKey': zoteroCollectionKey,
        'createdAt': createdAt.toIso8601String(),
        'lastOpenedAt': lastOpenedAt.toIso8601String(),
      };

  factory Project.fromJson(Map<String, dynamic> json) => Project(
        id: json['id'] as String,
        name: json['name'] as String,
        vaultPath: json['vaultPath'] as String,
        locale: json['locale'] as String?,
        zoteroCollectionKey: json['zoteroCollectionKey'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
        lastOpenedAt: DateTime.parse(json['lastOpenedAt'] as String),
      );

  @override
  bool operator ==(Object other) => other is Project && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

// Sentinel for copyWith optional-null fields
const _sentinel = Object();
