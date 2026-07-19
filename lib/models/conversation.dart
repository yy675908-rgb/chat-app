class Conversation {
  const Conversation({
    required this.id,
    required this.characterId,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    this.branchSummaries = const {},
    this.summarizedThroughMessageIds = const {},
  });

  final String id;
  final String characterId;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, String> branchSummaries;
  final Map<String, String> summarizedThroughMessageIds;

  Conversation copyWith({
    String? title,
    DateTime? updatedAt,
    Map<String, String>? branchSummaries,
    Map<String, String>? summarizedThroughMessageIds,
  }) => Conversation(
        id: id,
        characterId: characterId,
        title: title ?? this.title,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        branchSummaries: branchSummaries ?? this.branchSummaries,
        summarizedThroughMessageIds:
            summarizedThroughMessageIds ?? this.summarizedThroughMessageIds,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'characterId': characterId,
        'title': title,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'branchSummaries': branchSummaries,
        'summarizedThroughMessageIds': summarizedThroughMessageIds,
      };

  factory Conversation.fromJson(Map<String, Object?> json) => Conversation(
        id: json['id'] as String,
        characterId: json['characterId'] as String? ?? 'character-lin',
        title: json['title'] as String? ?? '新对话',
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
        branchSummaries: (json['branchSummaries'] as Map?)?.map(
              (key, value) => MapEntry(key.toString(), value.toString()),
            ) ??
            const {},
        summarizedThroughMessageIds:
            (json['summarizedThroughMessageIds'] as Map?)?.map(
                  (key, value) => MapEntry(
                    key.toString(),
                    value.toString(),
                  ),
                ) ??
                const {},
      );
}
