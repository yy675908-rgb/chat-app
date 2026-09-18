import 'package:flutter/material.dart';

import '../models/chat_message.dart';
import '../models/provider_profile.dart';
import 'message_bubble.dart';

class ChatMessageList extends StatelessWidget {
  const ChatMessageList({
    super.key,
    required this.controller,
    required this.messages,
    required this.visibleMessageIndices,
    required this.generating,
    required this.busy,
    required this.activeRetryIndex,
    required this.activeReplyId,
    required this.reasoningExpanded,
    required this.providers,
    required this.speakerName,
    required this.followStreamingOutput,
    required this.onPointerHoldingChanged,
    required this.onScrollActivity,
    required this.onResumeStreamingFollow,
    required this.onEdit,
    required this.onMoveVariant,
    required this.onLike,
    required this.onLearnStyle,
    required this.onRetryWithModel,
  });

  final ScrollController controller;
  final List<ChatMessage> messages;
  final List<int> visibleMessageIndices;
  final bool generating;
  final bool busy;
  final int? activeRetryIndex;
  final String? activeReplyId;
  final bool reasoningExpanded;
  final List<ProviderProfile> providers;
  final String Function(ChatMessage message) speakerName;
  final bool followStreamingOutput;
  final ValueChanged<bool> onPointerHoldingChanged;
  final VoidCallback onScrollActivity;
  final VoidCallback onResumeStreamingFollow;
  final Future<void> Function(int index) onEdit;
  final Future<void> Function(int index, int delta) onMoveVariant;
  final Future<void> Function(int index) onLike;
  final Future<void> Function(int index, ChatMessage message) onLearnStyle;
  final Future<void> Function(int index, RetryModelOption option)
  onRetryWithModel;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: Listener(
            onPointerDown: (_) => onPointerHoldingChanged(true),
            onPointerUp: (_) {
              onPointerHoldingChanged(false);
              onScrollActivity();
            },
            onPointerCancel: (_) {
              onPointerHoldingChanged(false);
              onScrollActivity();
            },
            child: NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                if (notification is ScrollUpdateNotification &&
                    notification.dragDetails != null) {
                  onScrollActivity();
                } else if (notification is ScrollEndNotification) {
                  onScrollActivity();
                }
                return false;
              },
              child: ListView.builder(
                controller: controller,
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(15, 12, 15, 24),
                itemCount: visibleMessageIndices.length,
                itemBuilder: (context, visibleIndex) {
                  final index = visibleMessageIndices[visibleIndex];
                  final message = messages[index];
                  if (generating &&
                      activeRetryIndex == null &&
                      message.id == activeReplyId &&
                      message.author == MessageAuthor.character &&
                      message.text.isEmpty &&
                      message.reasoning.isEmpty) {
                    return _ThinkingRow(name: speakerName(message));
                  }
                  final canUseCharacterActions =
                      message.author == MessageAuthor.character &&
                      message.text.isNotEmpty &&
                      !busy;
                  final canEdit =
                      message.author != MessageAuthor.system &&
                      message.text.isNotEmpty &&
                      !busy;
                  return MessageBubble(
                    message: message,
                    characterName: speakerName(message),
                    reasoningInitiallyExpanded: reasoningExpanded,
                    showActions: canEdit,
                    onEdit: canEdit ? () => onEdit(index) : null,
                    onPreviousVariant:
                        canUseCharacterActions &&
                            message.activeVariantIndex > 0
                        ? () => onMoveVariant(index, -1)
                        : null,
                    onNextVariant:
                        canUseCharacterActions &&
                            message.activeVariantIndex <
                                message.replyVariants.length - 1
                        ? () => onMoveVariant(index, 1)
                        : null,
                    onLike: canUseCharacterActions
                        ? () => onLike(index)
                        : null,
                    onLearnStyle: canUseCharacterActions
                        ? () => onLearnStyle(index, message)
                        : null,
                    retryModels: [
                      for (final provider in providers)
                        for (final model in provider.models)
                          RetryModelOption(
                            providerId: provider.id,
                            providerName: provider.name,
                            modelId: model,
                          ),
                    ],
                    onRetryWithModel: canUseCharacterActions
                        ? (option) => onRetryWithModel(index, option)
                        : null,
                  );
                },
              ),
            ),
          ),
        ),
        if (!followStreamingOutput)
          Positioned(
            right: 14,
            bottom: 12,
            child: FloatingActionButton.small(
              tooltip: '回到最新消息',
              onPressed: onResumeStreamingFollow,
              child: const Icon(Icons.keyboard_arrow_down_rounded),
            ),
          ),
      ],
    );
  }
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
