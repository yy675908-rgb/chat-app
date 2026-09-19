import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ChatComposer extends StatelessWidget {
  const ChatComposer({
    super.key,
    required this.controller,
    required this.enabled,
    required this.generating,
    required this.onSend,
    required this.onStop,
    required this.onNewConversation,
  });

  final TextEditingController controller;
  final bool enabled;
  final bool generating;
  final VoidCallback onSend;
  final VoidCallback onStop;
  final VoidCallback onNewConversation;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 6, 18, 9),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            IconButton(
              tooltip: '新对话',
              style: IconButton.styleFrom(
                minimumSize: const Size(40, 40),
                backgroundColor: scheme.surfaceContainerLow,
              ),
              onPressed: enabled && !generating ? onNewConversation : null,
              icon: const Icon(Icons.add_comment_outlined, size: 20),
            ),
            const SizedBox(width: 7),
            Expanded(
              child: Material(
                color: scheme.surfaceContainer,
                borderRadius: BorderRadius.circular(24),
                clipBehavior: Clip.antiAlias,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(15, 2, 5, 2),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: controller,
                          autofocus: false,
                          enabled: enabled,
                          minLines: 1,
                          maxLines: 6,
                          textInputAction: TextInputAction.newline,
                          onTapOutside: (_) => FocusScope.of(context).unfocus(),
                          decoration: InputDecoration(
                            hintText: generating ? '可以继续说…' : '说点什么…',
                            hintStyle: TextStyle(
                              color: scheme.onSurfaceVariant.withValues(alpha: 0.68),
                            ),
                            border: InputBorder.none,
                            filled: false,
                            contentPadding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 120),
                        switchInCurve: Curves.easeOut,
                        switchOutCurve: Curves.easeIn,
                        child: generating
                            ? Padding(
                                key: const ValueKey('stop'),
                                padding: const EdgeInsets.only(bottom: 2),
                                child: IconButton(
                                  tooltip: '停止当前回复',
                                  style: IconButton.styleFrom(
                                    backgroundColor: scheme.surfaceContainerHighest,
                                    minimumSize: const Size(40, 40),
                                  ),
                                  onPressed: () {
                                    HapticFeedback.selectionClick();
                                    onStop();
                                  },
                                  icon: const Icon(Icons.stop_rounded, size: 19),
                                ),
                              )
                            : const SizedBox.shrink(key: ValueKey('idle')),
                      ),
                      const SizedBox(width: 3),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: ValueListenableBuilder<TextEditingValue>(
                          valueListenable: controller,
                          builder: (context, value, _) {
                            final canSend = enabled && value.text.trim().isNotEmpty;
                            return IconButton.filled(
                              tooltip: '发送',
                              style: IconButton.styleFrom(
                                minimumSize: const Size(40, 40),
                              ),
                              onPressed: canSend
                                  ? () {
                                      HapticFeedback.selectionClick();
                                      onSend();
                                    }
                                  : null,
                              icon: const Icon(Icons.arrow_upward_rounded, size: 20),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
