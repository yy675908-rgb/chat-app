import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../models/chat_message.dart';

class RetryModelOption {
  const RetryModelOption({
    required this.providerId,
    required this.providerName,
    required this.modelId,
  });

  final String providerId;
  final String providerName;
  final String modelId;
}

class MessageBubble extends StatelessWidget {
  const MessageBubble({
    required this.message,
    required this.characterName,
    this.showActions = false,
    this.reasoningInitiallyExpanded = true,
    this.onPreviousVariant,
    this.onNextVariant,
    this.onLike,
    this.retryModels = const [],
    this.onRetryWithModel,
    super.key,
  });

  final ChatMessage message;
  final String characterName;
  final bool showActions;
  final bool reasoningInitiallyExpanded;
  final VoidCallback? onPreviousVariant;
  final VoidCallback? onNextVariant;
  final VoidCallback? onLike;
  final List<RetryModelOption> retryModels;
  final ValueChanged<RetryModelOption>? onRetryWithModel;

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
        padding: const EdgeInsets.fromLTRB(58, 7, 2, 7),
        child: Align(
          alignment: Alignment.centerRight,
          child: Material(
            color: scheme.primaryContainer,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(22),
              topRight: Radius.circular(22),
              bottomLeft: Radius.circular(22),
              bottomRight: Radius.circular(7),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onLongPress: () => _copy(context),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 11,
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
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 11, 6, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: scheme.secondaryContainer,
              shape: BoxShape.circle,
              border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: 0.45),
              ),
            ),
            child: Text(
              characterName.isEmpty ? '林' : characterName.characters.first,
              style: TextStyle(
                color: scheme.onSecondaryContainer,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: GestureDetector(
              onLongPress: () => _copy(context),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          characterName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: scheme.onSurfaceVariant,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        time,
                        style: TextStyle(
                          color: scheme.onSurfaceVariant.withValues(alpha: 0.68),
                          fontSize: 10.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  if (message.reasoning.trim().isNotEmpty) ...[
                    _ReasoningPanel(
                      key: ValueKey(
                        'reasoning-${message.activeVariant?.id ?? message.id}',
                      ),
                      reasoning: message.reasoning,
                      reasoningDurationMs: message.usedReasoningDurationMs,
                      initiallyExpanded: reasoningInitiallyExpanded,
                    ),
                    const SizedBox(height: 9),
                  ],
                  MarkdownBody(
                    data: message.text,
                    selectable: true,
                    styleSheet: MarkdownStyleSheet(
                      p: TextStyle(
                        color: scheme.onSurface,
                        fontSize: 15.5,
                        height: 1.56,
                      ),
                      code: TextStyle(
                        color: scheme.onSurface,
                        backgroundColor: scheme.surfaceContainerHighest,
                        fontSize: 13,
                      ),
                      codeblockPadding: const EdgeInsets.all(12),
                      codeblockDecoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      blockquotePadding: const EdgeInsets.fromLTRB(12, 7, 10, 7),
                      blockquoteDecoration: BoxDecoration(
                        color: scheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(8),
                        border: Border(
                          left: BorderSide(color: scheme.primary, width: 3),
                        ),
                      ),
                    ),
                  ),
                  if (message.usedTotalTokens > 0) ...[
                    const SizedBox(height: 8),
                    _TokenUsage(message: message),
                  ],
                  if (showActions) ...[
                    const SizedBox(height: 9),
                    Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (message.variantCount > 1)
                          _VersionControl(
                            current: message.variantNumber,
                            total: message.variantCount,
                            onPrevious: onPreviousVariant,
                            onNext: onNextVariant,
                          ),
                        _BubbleAction(
                          tooltip: '复制',
                          icon: Icons.copy_rounded,
                          onPressed: () => _copy(context),
                        ),
                        _BubbleAction(
                          tooltip: message.isLiked ? '取消喜欢' : '喜欢并收藏',
                          icon: message.isLiked
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          selected: message.isLiked,
                          onPressed: onLike,
                        ),
                        _RetryPicker(
                          options: retryModels,
                          onSelected: onRetryWithModel,
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

class _TokenUsage extends StatelessWidget {
  const _TokenUsage({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final details = <String>[
      '输入 ${message.usedPromptTokens}',
      '输出 ${message.usedCompletionTokens}',
      if (message.usedReasoningTokens > 0)
        '思考 ${message.usedReasoningTokens}',
    ].join(' · ');
    return Wrap(
      spacing: 5,
      runSpacing: 3,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Icon(
          Icons.data_usage_rounded,
          size: 12,
          color: scheme.onSurfaceVariant.withValues(alpha: 0.72),
        ),
        Text(
          '${message.usedTotalTokens} tokens',
          style: TextStyle(
            color: scheme.onSurfaceVariant,
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          '· $details',
          style: TextStyle(
            color: scheme.onSurfaceVariant.withValues(alpha: 0.72),
            fontSize: 10.5,
          ),
        ),
      ],
    );
  }
}

class _BubbleAction extends StatelessWidget {
  const _BubbleAction({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.selected = false,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final enabled = onPressed != null;
    final background = selected
        ? scheme.secondaryContainer
        : scheme.surfaceContainerLow;
    final foreground = !enabled
        ? scheme.onSurface.withValues(alpha: 0.3)
        : selected
            ? scheme.primary
            : scheme.onSurfaceVariant;

    return Tooltip(
      message: tooltip,
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(11),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: SizedBox(
            width: 36,
            height: 34,
            child: Icon(icon, size: 17, color: foreground),
          ),
        ),
      ),
    );
  }
}

class _RetryPicker extends StatelessWidget {
  const _RetryPicker({required this.options, required this.onSelected});

  final List<RetryModelOption> options;
  final ValueChanged<RetryModelOption>? onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final enabled = onSelected != null && options.isNotEmpty;
    return PopupMenuButton<RetryModelOption>(
      tooltip: '选择模型重新生成',
      enabled: enabled,
      position: PopupMenuPosition.over,
      offset: const Offset(0, 38),
      constraints: const BoxConstraints(minWidth: 190, maxWidth: 260),
      onSelected: onSelected,
      itemBuilder: (context) => [
        for (final option in options)
          PopupMenuItem<RetryModelOption>(
            value: option,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  option.modelId,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  option.providerName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
      ],
      child: Material(
        color: enabled
            ? scheme.primaryContainer.withValues(alpha: 0.78)
            : scheme.primaryContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(11),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          width: 40,
          height: 34,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.refresh_rounded,
                size: 19,
                color: enabled
                    ? scheme.onPrimaryContainer
                    : scheme.onSurface.withValues(alpha: 0.3),
              ),
              Icon(
                Icons.arrow_drop_down_rounded,
                size: 13,
                color: enabled
                    ? scheme.onPrimaryContainer
                    : scheme.onSurface.withValues(alpha: 0.3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VersionControl extends StatelessWidget {
  const _VersionControl({
    required this.current,
    required this.total,
    required this.onPrevious,
    required this.onNext,
  });

  final int current;
  final int total;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: 34,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _CompactArrow(
            tooltip: '上一版',
            icon: Icons.chevron_left_rounded,
            onPressed: onPrevious,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Text(
              '$current/$total',
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          _CompactArrow(
            tooltip: '下一版',
            icon: Icons.chevron_right_rounded,
            onPressed: onNext,
          ),
        ],
      ),
    );
  }
}

class _CompactArrow extends StatelessWidget {
  const _CompactArrow({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: 30,
          height: 34,
          child: Icon(
            icon,
            size: 19,
            color: onPressed == null
                ? scheme.onSurface.withValues(alpha: 0.25)
                : scheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _ReasoningPanel extends StatelessWidget {
  const _ReasoningPanel({
    required this.reasoning,
    required this.reasoningDurationMs,
    required this.initiallyExpanded,
    super.key,
  });

  final String reasoning;
  final int reasoningDurationMs;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Material(
        color: scheme.surfaceContainerLow,
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          maintainState: true,
          dense: true,
          visualDensity: VisualDensity.compact,
          tilePadding: const EdgeInsets.symmetric(horizontal: 12),
          childrenPadding: const EdgeInsets.fromLTRB(13, 0, 13, 13),
          leading: Icon(
            Icons.psychology_outlined,
            size: 17,
            color: scheme.primary,
          ),
          title: Text(
            reasoningDurationMs > 0
                ? '思考过程 · ${_formatDuration(reasoningDurationMs)}'
                : '思考过程',
            style: TextStyle(
              color: scheme.onSurfaceVariant,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 250),
              child: SingleChildScrollView(
                primary: false,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: SelectableText(
                    reasoning.trim(),
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 12.5,
                      height: 1.55,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(int milliseconds) {
    final seconds = milliseconds / 1000;
    return seconds < 10
        ? '${seconds.toStringAsFixed(1)} 秒'
        : '${seconds.round()} 秒';
  }
}
