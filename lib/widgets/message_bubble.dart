import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../models/chat_message.dart';

class MessageBubble extends StatelessWidget {
  const MessageBubble({
    required this.message,
    required this.characterName,
    this.showActions = false,
    this.onRetry,
    super.key,
  });

  final ChatMessage message;
  final String characterName;
  final bool showActions;
  final VoidCallback? onRetry;

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: message.text));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('已复制'),
        duration: Duration(milliseconds: 900),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (message.author == MessageAuthor.system) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
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
    final scheme = Theme.of(context).colorScheme;
    final time = MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay.fromDateTime(message.sentAt),
      alwaysUse24HourFormat: true,
    );

    if (isUser) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(44, 7, 0, 7),
        child: Align(
          alignment: Alignment.centerRight,
          child: GestureDetector(
            onLongPress: () => _copy(context),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 15,
                    vertical: 11,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                      bottomLeft: Radius.circular(20),
                      bottomRight: Radius.circular(6),
                    ),
                  ),
                  child: SelectableText(
                    message.isRetracted ? '撤回了一句话' : message.text,
                    style: TextStyle(
                      color: scheme.onPrimaryContainer,
                      fontSize: 15.5,
                      height: 1.45,
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  time,
                  style: TextStyle(
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.72),
                    fontSize: 10.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 10, 18, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: scheme.secondaryContainer,
            child: Text(
              characterName.isEmpty ? '林' : characterName.characters.first,
              style: TextStyle(
                color: scheme.onSecondaryContainer,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: GestureDetector(
              onLongPress: () => _copy(context),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        characterName,
                        style: TextStyle(
                          color: scheme.onSurfaceVariant,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        time,
                        style: TextStyle(
                          color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
                          fontSize: 10.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  MarkdownBody(
                    data: message.text,
                    selectable: true,
                    styleSheet: MarkdownStyleSheet(
                      p: TextStyle(
                        color: scheme.onSurface,
                        fontSize: 15.5,
                        height: 1.52,
                      ),
                      code: TextStyle(
                        color: scheme.onSurface,
                        backgroundColor: scheme.surfaceContainerHighest,
                        fontSize: 13,
                      ),
                      codeblockDecoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      blockquoteDecoration: BoxDecoration(
                        color: scheme.surfaceContainerLow,
                        border: Border(
                          left: BorderSide(color: scheme.primary, width: 3),
                        ),
                      ),
                    ),
                  ),
                  if (showActions) ...[
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        IconButton(
                          tooltip: '复制',
                          visualDensity: VisualDensity.compact,
                          onPressed: () => _copy(context),
                          icon: const Icon(Icons.copy_rounded, size: 17),
                        ),
                        if (onRetry != null)
                          IconButton(
                            tooltip: '重新生成',
                            visualDensity: VisualDensity.compact,
                            onPressed: onRetry,
                            icon: const Icon(Icons.refresh_rounded, size: 19),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
