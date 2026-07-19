class CharacterProfile {
  const CharacterProfile({
    required this.id,
    required this.name,
    required this.status,
    required this.firstMetAt,
    required this.greeting,
    required this.systemPrompt,
  });

  final String id;
  final String name;
  final String status;
  final DateTime firstMetAt;
  final String greeting;
  final String systemPrompt;

  factory CharacterProfile.lin(DateTime firstMetAt) {
    return CharacterProfile(
      id: 'character-lin',
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

  factory CharacterProfile.newCharacter(DateTime createdAt) {
    return CharacterProfile(
      id: 'character-${createdAt.microsecondsSinceEpoch}',
      name: '新角色',
      status: '',
      firstMetAt: createdAt,
      greeting: '你好。',
      systemPrompt: '你是一个有独立性格的真实聊天对象。请用自然、简洁的方式与用户交流。',
    );
  }

  CharacterProfile copyWith({
    String? name,
    String? status,
    String? greeting,
    String? systemPrompt,
  }) {
    return CharacterProfile(
      id: id,
      name: name ?? this.name,
      status: status ?? this.status,
      firstMetAt: firstMetAt,
      greeting: greeting ?? this.greeting,
      systemPrompt: systemPrompt ?? this.systemPrompt,
    );
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'status': status,
        'firstMetAt': firstMetAt.toIso8601String(),
        'greeting': greeting,
        'systemPrompt': systemPrompt,
      };

  factory CharacterProfile.fromJson(Map<String, Object?> json) {
    final firstMetAt = DateTime.tryParse(json['firstMetAt'] as String? ?? '') ??
        DateTime.now();
    final fallback = CharacterProfile.lin(firstMetAt);
    return CharacterProfile(
      id: json['id'] as String? ?? fallback.id,
      name: json['name'] as String? ?? fallback.name,
      status: json['status'] as String? ?? fallback.status,
      firstMetAt: firstMetAt,
      greeting: json['greeting'] as String? ?? fallback.greeting,
      systemPrompt: json['systemPrompt'] as String? ?? fallback.systemPrompt,
    );
  }

  int get daysTogether {
    final now = DateTime.now();
    final start = DateTime(firstMetAt.year, firstMetAt.month, firstMetAt.day);
    final today = DateTime(now.year, now.month, now.day);
    return today.difference(start).inDays + 1;
  }
}
