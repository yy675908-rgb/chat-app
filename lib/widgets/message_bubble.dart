import 'package:flutter/material.dart';

import '../models/chat_message.dart';

class MessageBubble extends StatelessWidget {
  const MessageBubble({
    required this.message,
    required this.characterName,
    super.key,
  });

  final ChatMessage message;
  final String characterName;

  @override
  Widget build(BuildContext context) {
    if (message.author == MessageAuthor.system) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Text(
          message.text,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 12,
          ),
        ),
      );
    }

    final isUser = message.author == MessageAuthor.user;
    final colors = Theme.of(context).colorScheme;

    final time = MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay.fromDateTime(message.sentAt),
      alwaysUse24HourFormat: true,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment:
            isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 4),
              child: Text(
                characterName,
                style: const TextStyle(
                  color: Color(0xFF6E756F),
                  fontSize: 11,
                ),
              ),
            ),
          ],
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.sizeOf(context).width * 0.78,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
            decoration: BoxDecoration(
              color: isUser ? const Color(0xFF31594B) : const Color(0xFFFFFCF7),
              border: isUser
                  ? null
                  : Border.all(color: const Color(0x12000000)),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(17),
                topRight: const Radius.circular(17),
                bottomLeft: Radius.circular(isUser ? 17 : 4),
                bottomRight: Radius.circular(isUser ? 4 : 17),
              ),
            ),
            child: Text(
              message.isRetracted ? '撤回了一句话' : message.text,
              style: TextStyle(
                color: isUser ? colors.onPrimary : const Color(0xFF202522),
                fontSize: 15.5,
                height: 1.45,
                fontStyle: message.isRetracted ? FontStyle.italic : null,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            time,
            style: const TextStyle(
              color: Color(0xFF8B8C87),
              fontSize: 10.5,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
