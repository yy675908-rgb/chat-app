enum MessageAuthor { user, character, system }

class ReplyVariant {
  const ReplyVariant({
    required this.id,
    required this.text,
    required this.generatedAt,
    this.providerId = '',
    this.modelId = '',
    this.reasoning = '',
    this.promptTokens = 0,
    this.completionTokens = 0,
    this.reasoningTokens = 0,
    this.totalTokens = 0,
    this.isLiked = false,
  });

  final String id;
  final String text;
  final DateTime generatedAt;
  final String providerId;
  final String modelId;
  final String reasoning;
  final int promptTokens;
  final int completionTokens;
  final int reasoningTokens;
  final int totalTokens;
  final bool isLiked;

  ReplyVariant copyWith({
    String? text,
    String? reasoning,
    int? promptTokens,
    int? completionTokens,
    int? reasoningTokens,
    int? totalTokens,
    bool? isLiked,
  }) {
    return ReplyVariant(
      id: id,
      text: text ?? this.text,
      generatedAt: generatedAt,
      providerId: providerId,
      modelId: modelId,
      reasoning: reasoning ?? this.reasoning,
      promptTokens: promptTokens ?? this.promptTokens,
      completionTokens: completionTokens ?? this.completionTokens,
      reasoningTokens: reasoningTokens ?? this.reasoningTokens,
      totalTokens: totalTokens ?? this.totalTokens,
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
        'promptTokens': promptTokens,
        'completionTokens': completionTokens,
        'reasoningTokens': reasoningTokens,
        'totalTokens': totalTokens,
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
      promptTokens: json['promptTokens'] as int? ?? 0,
      completionTokens: json['completionTokens'] as int? ?? 0,
      reasoningTokens: json['reasoningTokens'] as int? ?? 0,
      totalTokens: json['totalTokens'] as int? ?? 0,
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
    String reasoning = '',
    this.promptTokens = 0,
    this.completionTokens = 0,
    this.reasoningTokens = 0,
    this.totalTokens = 0,
    this.isRetracted = false,
    this.replyVariants = const [],
    this.activeVariantIndex = 0,
  })  : _text = text,
        _reasoning = reasoning;

  final String id;
  final MessageAuthor author;
  final String _text;
  final String _reasoning;
  final DateTime sentAt;
  final int promptTokens;
  final int completionTokens;
  final int reasoningTokens;
  final int totalTokens;
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
  String get reasoning => activeVariant?.reasoning ?? _reasoning;
  int get usedPromptTokens => activeVariant?.promptTokens ?? promptTokens;
  int get usedCompletionTokens =>
      activeVariant?.completionTokens ?? completionTokens;
  int get usedReasoningTokens =>
      activeVariant?.reasoningTokens ?? reasoningTokens;
  int get usedTotalTokens => activeVariant?.totalTokens ?? totalTokens;
  bool get isLiked => activeVariant?.isLiked ?? false;
  int get variantCount => replyVariants.isEmpty ? 1 : replyVariants.length;
  int get variantNumber => replyVariants.isEmpty ? 1 : _safeVariantIndex + 1;

  ChatMessage copyWith({
    String? text,
    String? reasoning,
    int? promptTokens,
    int? completionTokens,
    int? reasoningTokens,
    int? totalTokens,
    bool? isRetracted,
    List<ReplyVariant>? replyVariants,
    int? activeVariantIndex,
  }) {
    return ChatMessage(
      id: id,
      author: author,
      text: text ?? _text,
      sentAt: sentAt,
      reasoning: reasoning ?? _reasoning,
      promptTokens: promptTokens ?? this.promptTokens,
      completionTokens: completionTokens ?? this.completionTokens,
      reasoningTokens: reasoningTokens ?? this.reasoningTokens,
      totalTokens: totalTokens ?? this.totalTokens,
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
    final variants = replyVariants.isEmpty
        ? [
            ReplyVariant(
              id: 'original-$id',
              text: _text,
              generatedAt: sentAt,
              reasoning: _reasoning,
              promptTokens: promptTokens,
              completionTokens: completionTokens,
              reasoningTokens: reasoningTokens,
              totalTokens: totalTokens,
            ),
            variant,
          ]
        : [...replyVariants, variant];
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
              reasoning: _reasoning,
              promptTokens: promptTokens,
              completionTokens: completionTokens,
              reasoningTokens: reasoningTokens,
              totalTokens: totalTokens,
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
        'reasoning': reasoning,
        'promptTokens': usedPromptTokens,
        'completionTokens': usedCompletionTokens,
        'reasoningTokens': usedReasoningTokens,
        'totalTokens': usedTotalTokens,
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
      reasoning: json['reasoning'] as String? ?? '',
      promptTokens: json['promptTokens'] as int? ?? 0,
      completionTokens: json['completionTokens'] as int? ?? 0,
      reasoningTokens: json['reasoningTokens'] as int? ?? 0,
      totalTokens: json['totalTokens'] as int? ?? 0,
      isRetracted: json['isRetracted'] as bool? ?? false,
      replyVariants: variants,
      activeVariantIndex: json['activeVariantIndex'] as int? ?? 0,
    );
  }
}
