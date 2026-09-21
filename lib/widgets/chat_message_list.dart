import 'dart:async';

import 'package:flutter/material.dart';

import '../models/chat_message.dart';
import '../models/provider_profile.dart';
import 'message_bubble.dart';

class ChatMessageList extends StatefulWidget {
  const ChatMessageList({
    super.key,
    required this.controller,
    required this.messages,
    required this.visibleMessageIndices,
    required this.generating,
    required this.activeRetryIndex,
    required this.activeReplyId,
    required this.reasoningExpanded,
    required this.providers,
    required this.speakerName,
    required this.followStreamingOutput,
    required this.targetMessageId,
    required this.targetRequest,
    required this.onPointerHoldingChanged,
    required this.onScrollActivity,
    required this.onResumeStreamingFollow,
    required this.onEdit,
    this.onSendEdited,
    required this.onMoveVariant,
    required this.onLike,
    required this.onLearnStyle,
    required this.onRetryWithModel,
  });

  final ScrollController controller;
  final List<ChatMessage> messages;
  final List<int> visibleMessageIndices;
  final bool generating;
  final int? activeRetryIndex;
  final String? activeReplyId;
  final bool reasoningExpanded;
  final List<ProviderProfile> providers;
  final String Function(ChatMessage message) speakerName;
  final bool followStreamingOutput;
  final String? targetMessageId;
  final int targetRequest;
  final ValueChanged<bool> onPointerHoldingChanged;
  final VoidCallback onScrollActivity;
  final VoidCallback onResumeStreamingFollow;
  final Future<void> Function(int index) onEdit;
  final Future<void> Function(int index)? onSendEdited;
  final Future<void> Function(int index, int delta) onMoveVariant;
  final Future<void> Function(int index) onLike;
  final Future<void> Function(int index, ChatMessage message) onLearnStyle;
  final Future<void> Function(int index, RetryModelOption option)
  onRetryWithModel;

  @override
  State<ChatMessageList> createState() => _ChatMessageListState();
}

class _ChatMessageListState extends State<ChatMessageList> {
  final Map<String, GlobalKey> _messageKeys = {};
  String? _highlightedMessageId;
  int _highlightGeneration = 0;
  Timer? _highlightTimer;

  GlobalKey _keyFor(String messageId) {
    return _messageKeys.putIfAbsent(messageId, GlobalKey.new);
  }

  @override
  void didUpdateWidget(covariant ChatMessageList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.messages.length < oldWidget.messages.length) {
      final liveIds = widget.messages.map((message) => message.id).toSet();
      _messageKeys.removeWhere((messageId, _) => !liveIds.contains(messageId));
    }
    if (widget.targetMessageId != null &&
        (widget.targetRequest != oldWidget.targetRequest ||
            widget.targetMessageId != oldWidget.targetMessageId)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _locateTarget();
      });
    }
  }

  Future<void> _waitForNextFrame() {
    final completer = Completer<void>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!completer.isCompleted) completer.complete();
    });
    WidgetsBinding.instance.scheduleFrame();
    return completer.future;
  }

  Future<void> _locateTarget() async {
    final targetId = widget.targetMessageId;
    final request = widget.targetRequest;
    if (targetId == null || targetId.isEmpty) return;

    final targetVisibleIndex = widget.visibleMessageIndices.indexWhere(
      (messageIndex) =>
          messageIndex >= 0 &&
          messageIndex < widget.messages.length &&
          widget.messages[messageIndex].id == targetId,
    );
    if (targetVisibleIndex < 0) return;

    final targetKey = _keyFor(targetId);

    for (var attempt = 0; attempt < 24; attempt++) {
      if (!mounted ||
          request != widget.targetRequest ||
          targetId != widget.targetMessageId) {
        return;
      }

      final targetContext = targetKey.currentContext;
      if (targetContext != null && targetContext.mounted) {
        await Scrollable.ensureVisible(
          targetContext,
          alignment: 0.32,
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
        );
        if (!mounted || request != widget.targetRequest) return;
        _showTargetHighlight(targetId);
        return;
      }

      if (!widget.controller.hasClients) {
        await _waitForNextFrame();
        continue;
      }

      final built = <_BuiltMessageAnchor>[];
      for (
        var visibleIndex = 0;
        visibleIndex < widget.visibleMessageIndices.length;
        visibleIndex++
      ) {
        final messageIndex = widget.visibleMessageIndices[visibleIndex];
        if (messageIndex < 0 || messageIndex >= widget.messages.length) {
          continue;
        }
        final messageId = widget.messages[messageIndex].id;
        final context = _messageKeys[messageId]?.currentContext;
        final renderObject = context?.findRenderObject();
        if (renderObject is RenderBox && renderObject.hasSize) {
          built.add(
            _BuiltMessageAnchor(
              index: visibleIndex,
              height: renderObject.size.height,
            ),
          );
        }
      }

      final position = widget.controller.position;
      final maxExtent = position.maxScrollExtent;
      final currentOffset = position.pixels;
      double desiredOffset;

      if (built.isEmpty) {
        final denominator = widget.visibleMessageIndices.length > 1
            ? widget.visibleMessageIndices.length - 1
            : 1;
        desiredOffset = maxExtent * targetVisibleIndex / denominator;
      } else {
        var nearest = built.first;
        var nearestDistance = (nearest.index - targetVisibleIndex).abs();
        var minBuiltIndex = built.first.index;
        var maxBuiltIndex = built.first.index;
        var totalHeight = 0.0;
        for (final item in built) {
          totalHeight += item.height.clamp(24.0, 1200.0).toDouble();
          if (item.index < minBuiltIndex) minBuiltIndex = item.index;
          if (item.index > maxBuiltIndex) maxBuiltIndex = item.index;
          final distance = (item.index - targetVisibleIndex).abs();
          if (distance < nearestDistance) {
            nearest = item;
            nearestDistance = distance;
          }
        }
        final averageHeight = (totalHeight / built.length)
            .clamp(40.0, 420.0)
            .toDouble();
        desiredOffset =
            currentOffset +
            (targetVisibleIndex - nearest.index) * averageHeight;

        final viewportStep = position.viewportDimension * 0.82;
        if (targetVisibleIndex > maxBuiltIndex) {
          desiredOffset = desiredOffset > currentOffset + viewportStep
              ? currentOffset + viewportStep
              : desiredOffset;
        } else if (targetVisibleIndex < minBuiltIndex) {
          desiredOffset = desiredOffset < currentOffset - viewportStep
              ? currentOffset - viewportStep
              : desiredOffset;
        }
      }

      desiredOffset = desiredOffset.clamp(0.0, maxExtent).toDouble();
      if ((desiredOffset - currentOffset).abs() < 1) {
        final builtIndexes = built.map((item) => item.index);
        final maxBuilt = builtIndexes.isEmpty
            ? -1
            : builtIndexes.reduce((a, b) => a > b ? a : b);
        final minBuilt = builtIndexes.isEmpty
            ? widget.visibleMessageIndices.length
            : builtIndexes.reduce((a, b) => a < b ? a : b);
        final direction = targetVisibleIndex > maxBuilt
            ? 1.0
            : (targetVisibleIndex < minBuilt ? -1.0 : 0.0);
        if (direction == 0) break;
        final fallback = (currentOffset +
                direction * position.viewportDimension * 0.75)
            .clamp(0.0, maxExtent)
            .toDouble();
        if ((fallback - currentOffset).abs() < 1) break;
        widget.controller.jumpTo(fallback);
      } else {
        widget.controller.jumpTo(desiredOffset);
      }
      await _waitForNextFrame();
    }

    final finalContext = targetKey.currentContext;
    if (finalContext != null && finalContext.mounted && mounted) {
      await Scrollable.ensureVisible(
        finalContext,
        alignment: 0.32,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
      if (mounted) _showTargetHighlight(targetId);
    }
  }

  void _showTargetHighlight(String messageId) {
    final generation = ++_highlightGeneration;
    _highlightTimer?.cancel();
    setState(() => _highlightedMessageId = messageId);
    _highlightTimer = Timer(const Duration(milliseconds: 1800), () {
      if (!mounted || generation != _highlightGeneration) return;
      setState(() => _highlightedMessageId = null);
    });
  }

  @override
  void dispose() {
    _highlightTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final retryModels = [
      for (final provider in widget.providers)
        for (final model in provider.models)
          RetryModelOption(
            providerId: provider.id,
            providerName: provider.name,
            modelId: model,
          ),
    ];
    return Stack(
      children: [
        Positioned.fill(
          child: Listener(
            onPointerDown: (_) => widget.onPointerHoldingChanged(true),
            onPointerUp: (_) {
              widget.onPointerHoldingChanged(false);
              widget.onScrollActivity();
            },
            onPointerCancel: (_) {
              widget.onPointerHoldingChanged(false);
              widget.onScrollActivity();
            },
            child: NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                if (notification is ScrollUpdateNotification &&
                    notification.dragDetails != null) {
                  widget.onScrollActivity();
                } else if (notification is ScrollEndNotification) {
                  widget.onScrollActivity();
                }
                return false;
              },
              child: ListView.builder(
                controller: widget.controller,
                addAutomaticKeepAlives: false,
                addRepaintBoundaries: false,
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 18),
                itemCount: widget.visibleMessageIndices.length,
                itemBuilder: (context, visibleIndex) {
                  final index = widget.visibleMessageIndices[visibleIndex];
                  final message = widget.messages[index];
                  final isHighlighted = message.id == _highlightedMessageId;
                  final key = _keyFor(message.id);

                  Widget child;
                  if (widget.generating &&
                      widget.activeRetryIndex == null &&
                      message.id == widget.activeReplyId &&
                      message.author == MessageAuthor.character &&
                      message.text.isEmpty &&
                      message.reasoning.isEmpty) {
                    child = _ThinkingRow(name: widget.speakerName(message));
                  } else {
                    final isActiveReply =
                        widget.generating &&
                        message.id == widget.activeReplyId;
                    final canUseCharacterActions =
                        message.author == MessageAuthor.character &&
                        message.text.isNotEmpty &&
                        !isActiveReply;
                    final canEdit =
                        message.author != MessageAuthor.system &&
                        message.text.isNotEmpty &&
                        !isActiveReply;
                    final showActions =
                        message.author == MessageAuthor.character
                        ? message.text.isNotEmpty && !isActiveReply
                        : canEdit;
                    child = MessageBubble(
                      message: message,
                      characterName: widget.speakerName(message),
                      reasoningInitiallyExpanded: widget.reasoningExpanded,
                      showActions: showActions,
                      streaming:
                          widget.generating &&
                          message.id == widget.activeReplyId,
                      onEdit: canEdit ? () => widget.onEdit(index) : null,
                      onSendEdited: message.author == MessageAuthor.user && canEdit
                          ? () => widget.onSendEdited?.call(index)
                          : null,
                      onPreviousVariant:
                          canUseCharacterActions &&
                              message.activeVariantIndex > 0
                          ? () => widget.onMoveVariant(index, -1)
                          : null,
                      onNextVariant:
                          canUseCharacterActions &&
                              message.activeVariantIndex <
                                  message.replyVariants.length - 1
                          ? () => widget.onMoveVariant(index, 1)
                          : null,
                      onLike: canUseCharacterActions
                          ? () => widget.onLike(index)
                          : null,
                      onLearnStyle: canUseCharacterActions
                          ? () => widget.onLearnStyle(index, message)
                          : null,
                      retryModels: retryModels,
                      onRetryWithModel: canUseCharacterActions
                          ? (option) => widget.onRetryWithModel(index, option)
                          : null,
                    );
                  }

                  final anchoredChild = Container(
                    key: key,
                    decoration: BoxDecoration(
                      color: isHighlighted
                          ? scheme.primaryContainer.withValues(alpha: 0.42)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: RepaintBoundary(child: child),
                  );
                  final isFreshMessage =
                      visibleIndex == widget.visibleMessageIndices.length - 1 &&
                      message.sentAt
                              .isAfter(
                                DateTime.now().subtract(
                                  const Duration(milliseconds: 700),
                                ),
                              );
                  return KeyedSubtree(
                    key: ValueKey<String>('chat-message-${message.id}'),
                    child: isFreshMessage
                        ? TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0, end: 1),
                            duration: const Duration(milliseconds: 160),
                            curve: Curves.easeOutCubic,
                            builder: (context, value, child) => Opacity(
                              opacity: value,
                              child: Transform.translate(
                                offset: Offset(0, 5 * (1 - value)),
                                child: child,
                              ),
                            ),
                            child: anchoredChild,
                          )
                        : anchoredChild,
                  );
                },
              ),
            ),
          ),
        ),
        if (!widget.followStreamingOutput)
          Positioned(
            right: 14,
            bottom: 12,
            child: IconButton.filledTonal(
              tooltip: '回到最新消息',
              onPressed: widget.onResumeStreamingFollow,
              icon: const Icon(Icons.keyboard_arrow_down_rounded),
            ),
          ),
      ],
    );
  }
}

class _BuiltMessageAnchor {
  const _BuiltMessageAnchor({required this.index, required this.height});

  final int index;
  final double height;
}

class _ThinkingRow extends StatelessWidget {
  const _ThinkingRow({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: scheme.secondaryContainer,
            child: Text(
              name.isEmpty ? '林' : name.characters.first,
              style: TextStyle(
                color: scheme.onSecondaryContainer,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 11),
          const SizedBox(
            width: 15,
            height: 15,
            child: CircularProgressIndicator(strokeWidth: 1.8),
          ),
          const SizedBox(width: 9),
          Text(
            '$name 正在想…',
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
