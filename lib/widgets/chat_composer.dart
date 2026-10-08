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

class _ChatComposerState extends State<ChatComposer>
    with WidgetsBindingObserver {
  late final FocusNode _focusNode;
  double _keyboardInset = 0;
  bool _directFocusRequest = false;
  bool _hadFocus = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _focusNode = FocusNode(
      debugLabel: 'chat-composer',
      skipTraversal: true,
      canRequestFocus: false,
    )..addListener(_guardFocus);
  }

  void _guardFocus() {
    final previouslyFocused = _hadFocus;
    _hadFocus = _focusNode.hasFocus;
    if ((_hadFocus && !_directFocusRequest) ||
        (!_hadFocus && previouslyFocused)) {
      _dismissFocus();
    }
  }

  void _dismissFocus() {
    if (_directFocusRequest) {
      setState(() => _directFocusRequest = false);
    }
    _focusNode.canRequestFocus = false;
    _focusNode.unfocus();
  }

  @override
  void didChangeMetrics() {
    final inset = View.of(context).viewInsets.bottom;
    if (_keyboardInset > 0 && inset == 0) _dismissFocus();
    _keyboardInset = inset;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _dismissFocus();
  }

  @override
  void didUpdateWidget(covariant ChatComposer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled) {
      _directFocusRequest = false;
      _dismissFocus();
    }
  }

  void _allowDirectFocus() {
    if (!widget.enabled) return;
    setState(() => _directFocusRequest = true);
    _focusNode.canRequestFocus = true;
  }

  void _finishDirectFocusRequest() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_focusNode.hasFocus) {
        _dismissFocus();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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
                            onPointerUp: (_) => _finishDirectFocusRequest(),
                            onPointerCancel: (_) => _finishDirectFocusRequest(),
                            child: TextField(
                              controller: widget.controller,
                              focusNode: _focusNode,
                              autofocus: false,
                              canRequestFocus: _directFocusRequest,
                              enabled: widget.enabled,
                              minLines: 1,
                              maxLines: 6,
                              textInputAction: TextInputAction.newline,
                              onTapOutside: (_) => _dismissFocus(),
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
                                  icon: const Icon(
                                    Icons.stop_rounded,
                                    size: 20,
                                  ),
                                )
                              : const SizedBox.shrink(key: ValueKey('idle')),
                        ),
                        ValueListenableBuilder<TextEditingValue>(
                          valueListenable: widget.controller,
                          builder: (context, value, _) {
                            final canSend =
                                widget.enabled && value.text.trim().isNotEmpty;
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
