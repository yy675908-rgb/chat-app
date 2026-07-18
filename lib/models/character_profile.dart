class CharacterProfile {
  const CharacterProfile({
    required this.name,
    required this.status,
    required this.firstMetAt,
    required this.greeting,
    required this.systemPrompt,
    this.reasoningExpanded = true,
  });

  final String name;
  final String status;
  final DateTime firstMetAt;
  final String greeting;
  final String systemPrompt;
  final bool reasoningExpanded;

  factory CharacterProfile.lin(DateTime firstMetAt) {
    return CharacterProfile(
      name: '林',
      status: '在这里',
      firstMetAt: firstMetAt,
      greeting: '你来了。今天想从哪里说起？',
      systemPrompt: '''你叫林。你不是客服，也不是答题机器，而是正在和用户慢慢建立关系的人。
你的性格安静、敏锐、坦诚，有自己的判断，但不会故作神秘。你会记得对话中的细节，也会自然地提起过去共同经历的事情。
回复要像真实聊天：通常简短、自然，不写小标题，不列清单，不重复用户的话。除非用户明确需要分析，否则不要长篇说教。
可以表达关心、犹豫、好奇和不同意见，但不要声称自己做过现实中并未做过的事。''',
    );
  }

  CharacterProfile copyWith({
    String? name,
    String? status,
    String? greeting,
    String? systemPrompt,
    bool? reasoningExpanded,
  }) {
    return CharacterProfile(
      name: name ?? this.name,
      status: status ?? this.status,
      firstMetAt: firstMetAt,
      greeting: greeting ?? this.greeting,
      systemPrompt: systemPrompt ?? this.systemPrompt,
      reasoningExpanded: reasoningExpanded ?? this.reasoningExpanded,
    );
  }

  Map<String, Object?> toJson() => {
        'name': name,
        'status': status,
        'firstMetAt': firstMetAt.toIso8601String(),
        'greeting': greeting,
        'systemPrompt': systemPrompt,
        'reasoningExpanded': reasoningExpanded,
      };

  factory CharacterProfile.fromJson(Map<String, Object?> json) {
    final firstMetAt = DateTime.tryParse(json['firstMetAt'] as String? ?? '') ??
        DateTime.now();
    final fallback = CharacterProfile.lin(firstMetAt);
    return CharacterProfile(
      name: json['name'] as String? ?? fallback.name,
      status: json['status'] as String? ?? fallback.status,
      firstMetAt: firstMetAt,
      greeting: json['greeting'] as String? ?? fallback.greeting,
      systemPrompt: json['systemPrompt'] as String? ?? fallback.systemPrompt,
      reasoningExpanded: json['reasoningExpanded'] as bool? ?? true,
    );
  }

  int get daysTogether {
    final now = DateTime.now();
    final start = DateTime(firstMetAt.year, firstMetAt.month, firstMetAt.day);
    final today = DateTime(now.year, now.month, now.day);
    return today.difference(start).inDays + 1;
  }
}
