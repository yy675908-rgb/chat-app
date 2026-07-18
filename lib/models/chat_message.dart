enum MessageAuthor { user, character, system }

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.author,
    required this.text,
    required this.sentAt,
    this.isRetracted = false,
  });

  final String id;
  final MessageAuthor author;
  final String text;
  final DateTime sentAt;
  final bool isRetracted;

  ChatMessage copyWith({
    String? text,
    bool? isRetracted,
  }) {
    return ChatMessage(
      id: id,
      author: author,
      text: text ?? this.text,
      sentAt: sentAt,
      isRetracted: isRetracted ?? this.isRetracted,
    );
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'author': author.name,
        'text': text,
        'sentAt': sentAt.toIso8601String(),
        'isRetracted': isRetracted,
      };

  factory ChatMessage.fromJson(Map<String, Object?> json) {
    return ChatMessage(
      id: json['id']! as String,
      author: MessageAuthor.values.firstWhere(
        (value) => value.name == json['author'],
        orElse: () => MessageAuthor.system,
      ),
      text: json['text']! as String,
      sentAt: DateTime.parse(json['sentAt']! as String),
      isRetracted: json['isRetracted'] as bool? ?? false,
    );
  }
}
