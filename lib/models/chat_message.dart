enum MessageAuthor { user, character, system }

class ReplyVariant {
  const ReplyVariant({
    required this.id,
    required this.text,
    required this.generatedAt,
    this.providerId = '',
    this.modelId = '',
    this.reasoning = '',
    this.isLiked = false,
  });

  final String id;
  final String text;
  final DateTime generatedAt;
  final String providerId;
  final String modelId;
  final String reasoning;
  final bool isLiked;

  ReplyVariant copyWith({
    String? text,
    String? reasoning,
    bool? isLiked,
  }) {
    return ReplyVariant(
      id: id,
      text: text ?? this.text,
      generatedAt: generatedAt,
      providerId: providerId,
      modelId: modelId,
      reasoning: reasoning ?? this.reasoning,
      isLiked: isLiked ?? this.isLiked,
    );
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'text': text,
        'generatedAt': generatedAt.toIso8601String(),
        'providerId': providerId,
        'modelId': modelId,
        'reasoning': reasoning,
        'isLiked': isLiked,
      };

  factory ReplyVariant.fromJson(Map<String, Object?> json) {
    return ReplyVariant(
      id: json['id'] as String? ?? '',
      text: json['text'] as String? ?? '',
      generatedAt:
          DateTime.tryParse(json['generatedAt'] as String? ?? '') ??
              DateTime.now(),
      providerId: json['providerId'] as String? ?? '',
      modelId: json['modelId'] as String? ?? '',
      reasoning: json['reasoning'] as String? ?? '',
      isLiked: json['isLiked'] as bool? ?? false,
    );
  }
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.author,
    required String text,
    required this.sentAt,
    this.isRetracted = false,
    this.replyVariants = const [],
    this.activeVariantIndex = 0,
  }) : _text = text;

  final String id;
  final MessageAuthor author;
  final String _text;
  final DateTime sentAt;
  final bool isRetracted;
  final List<ReplyVariant> replyVariants;
  final int activeVariantIndex;

  int get _safeVariantIndex {
    if (replyVariants.isEmpty || activeVariantIndex < 0) return 0;
    if (activeVariantIndex >= replyVariants.length) {
      return replyVariants.length - 1;
    }
    return activeVariantIndex;
  }

  ReplyVariant? get activeVariant =>
      replyVariants.isEmpty ? null : replyVariants[_safeVariantIndex];

  String get text => activeVariant?.text ?? _text;
  String get reasoning => activeVariant?.reasoning ?? '';
  bool get isLiked => activeVariant?.isLiked ?? false;
  int get variantCount => replyVariants.isEmpty ? 1 : replyVariants.length;
  int get variantNumber => replyVariants.isEmpty ? 1 : _safeVariantIndex + 1;

  ChatMessage copyWith({
    String? text,
    bool? isRetracted,
    List<ReplyVariant>? replyVariants,
    int? activeVariantIndex,
  }) {
    return ChatMessage(
      id: id,
      author: author,
      text: text ?? _text,
      sentAt: sentAt,
      isRetracted: isRetracted ?? this.isRetracted,
      replyVariants: replyVariants ?? this.replyVariants,
      activeVariantIndex: activeVariantIndex ?? this.activeVariantIndex,
    );
  }

  ChatMessage selectVariant(int index) {
    if (replyVariants.isEmpty) return this;
    final selected = index < 0
        ? 0
        : (index >= replyVariants.length ? replyVariants.length - 1 : index);
    return copyWith(activeVariantIndex: selected);
  }

  ChatMessage addVariant(ReplyVariant variant) {
    final variants = [...replyVariants, variant];
    return copyWith(
      replyVariants: variants,
      activeVariantIndex: variants.length - 1,
    );
  }

  ChatMessage toggleLike() {
    final variants = replyVariants.isEmpty
        ? [
            ReplyVariant(
              id: 'legacy-$id',
              text: _text,
              generatedAt: sentAt,
              isLiked: true,
            ),
          ]
        : [...replyVariants];
    if (replyVariants.isNotEmpty) {
      final index = _safeVariantIndex;
      variants[index] = variants[index].copyWith(
        isLiked: !variants[index].isLiked,
      );
    }
    return copyWith(
      replyVariants: variants,
      activeVariantIndex: replyVariants.isEmpty ? 0 : _safeVariantIndex,
    );
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'author': author.name,
        'text': text,
        'sentAt': sentAt.toIso8601String(),
        'isRetracted': isRetracted,
        'replyVariants':
            replyVariants.map((variant) => variant.toJson()).toList(),
        'activeVariantIndex': activeVariantIndex,
      };

  factory ChatMessage.fromJson(Map<String, Object?> json) {
    final variants = (json['replyVariants'] as List<dynamic>? ?? const [])
        .map(
          (item) => ReplyVariant.fromJson(
            Map<String, Object?>.from(item as Map),
          ),
        )
        .toList();
    return ChatMessage(
      id: json['id']! as String,
      author: MessageAuthor.values.firstWhere(
        (value) => value.name == json['author'],
        orElse: () => MessageAuthor.system,
      ),
      text: json['text'] as String? ?? '',
      sentAt: DateTime.parse(json['sentAt']! as String),
      isRetracted: json['isRetracted'] as bool? ?? false,
      replyVariants: variants,
      activeVariantIndex: json['activeVariantIndex'] as int? ?? 0,
    );
  }
}
