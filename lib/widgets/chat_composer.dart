import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ChatComposer extends StatefulWidget {
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
  State<ChatComposer> createState() => _ChatComposerState();
}

class _ChatComposerState extends State<ChatComposer> {
  late final FocusNode _focusNode;
  bool _directFocusRequest = false;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode(
      debugLabel: 'chat-composer',
      skipTraversal: true,
    )..addListener(_guardFocus);
  }

  void _guardFocus() {
    if (_focusNode.hasFocus && !_directFocusRequest) {
      _focusNode.unfocus();
    } else if (!_focusNode.hasFocus) {
      _directFocusRequest = false;
    }
  }

  void _allowDirectFocus() {
    if (!widget.enabled) return;
    _directFocusRequest = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_focusNode.hasFocus) {
        _directFocusRequest = false;
      }
    });
  }

  @override
  void dispose() {
    _focusNode.removeListener(_guardFocus);
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Material(
        color: scheme.surface,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 5, 10, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              IconButton(
                tooltip: '新对话',
                onPressed: widget.enabled && !widget.generating
                    ? widget.onNewConversation
                    : null,
                icon: const Icon(Icons.add_comment_outlined, size: 21),
              ),
              const SizedBox(width: 2),
              Expanded(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.only(left: 15, right: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Listener(
                            onPointerDown: (_) => _allowDirectFocus(),
                            child: TextField(
                              controller: widget.controller,
                              focusNode: _focusNode,
                              autofocus: false,
                              enabled: widget.enabled,
                              minLines: 1,
                              maxLines: 6,
                              textInputAction: TextInputAction.newline,
                              onTapOutside: (_) => _focusNode.unfocus(),
                              decoration: InputDecoration(
                                hintText: widget.generating
                                    ? '可以继续说…'
                                    : '说点什么…',
                                hintStyle: TextStyle(
                                  color: scheme.onSurfaceVariant.withValues(
                                    alpha: 0.62,
                                  ),
                                ),
                                border: InputBorder.none,
                                filled: false,
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 11,
                                ),
                              ),
                            ),
                          ),
                        ),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 120),
                          child: widget.generating
                              ? IconButton(
                                  key: const ValueKey('stop'),
                                  tooltip: '停止当前回复',
                                  onPressed: () {
                                    HapticFeedback.selectionClick();
                                    widget.onStop();
                                  },
                                  icon: const Icon(Icons.stop_rounded, size: 20),
                                )
                              : const SizedBox.shrink(key: ValueKey('idle')),
                        ),
                        ValueListenableBuilder<TextEditingValue>(
                          valueListenable: widget.controller,
                          builder: (context, value, _) {
                            final canSend =
                                widget.enabled &&
                                value.text.trim().isNotEmpty;
                            return IconButton(
                              tooltip: '发送',
                              onPressed: canSend
                                  ? () {
                                      HapticFeedback.selectionClick();
                                      widget.onSend();
                                    }
                                  : null,
                              icon: Icon(
                                Icons.arrow_upward_rounded,
                                size: 23,
                                color: canSend ? scheme.primary : null,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
