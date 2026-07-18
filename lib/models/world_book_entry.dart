class WorldBookEntry {
  const WorldBookEntry({
    required this.id,
    required this.title,
    required this.keywords,
    required this.content,
    this.enabled = true,
  });

  final String id;
  final String title;
  final List<String> keywords;
  final String content;
  final bool enabled;

  WorldBookEntry copyWith({
    String? title,
    List<String>? keywords,
    String? content,
    bool? enabled,
  }) {
    return WorldBookEntry(
      id: id,
      title: title ?? this.title,
      keywords: keywords ?? this.keywords,
      content: content ?? this.content,
      enabled: enabled ?? this.enabled,
    );
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'title': title,
        'keywords': keywords,
        'content': content,
        'enabled': enabled,
      };

  factory WorldBookEntry.fromJson(Map<String, Object?> json) {
    return WorldBookEntry(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '未命名条目',
      keywords: (json['keywords'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .where((item) => item.trim().isNotEmpty)
          .toList(),
      content: json['content'] as String? ?? '',
      enabled: json['enabled'] as bool? ?? true,
    );
  }
}
