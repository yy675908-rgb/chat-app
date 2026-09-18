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
  });

  final TextEditingController controller;
  final bool enabled;
  final bool generating;
  final VoidCallback onSend;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 7, 10, 10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(25),
            border: Border.all(
              color: generating
                  ? scheme.primary.withValues(alpha: 0.3)
                  : scheme.outlineVariant.withValues(alpha: 0.55),
            ),
            boxShadow: [
              BoxShadow(
                color: scheme.shadow.withValues(alpha: 0.07),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(15, 3, 6, 3),
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
                      contentPadding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                  ),
                ),
                const SizedBox(width: 5),
                if (generating)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: IconButton(
                      tooltip: '停止当前回复',
                      style: IconButton.styleFrom(
                        backgroundColor: scheme.surfaceContainerHighest,
                        minimumSize: const Size(42, 42),
                      ),
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        onStop();
                      },
                      icon: const Icon(Icons.stop_rounded, size: 20),
                    ),
                  ),
                const SizedBox(width: 4),
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: ValueListenableBuilder<TextEditingValue>(
                    valueListenable: controller,
                    builder: (context, value, _) {
                      final canSend = enabled && value.text.trim().isNotEmpty;
                      return IconButton.filled(
                        tooltip: '发送',
                        style: IconButton.styleFrom(
                          minimumSize: const Size(42, 42),
                        ),
                        onPressed: canSend
                            ? () {
                                HapticFeedback.selectionClick();
                                onSend();
                              }
                            : null,
                        icon: const Icon(Icons.arrow_upward_rounded, size: 21),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
