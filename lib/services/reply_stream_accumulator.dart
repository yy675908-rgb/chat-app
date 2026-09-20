import 'ai_chat_service.dart';

class ReplyStreamAccumulator {
  final StringBuffer _reply = StringBuffer();
  final StringBuffer _reasoning = StringBuffer();
  String _replySnapshot = '';
  String _reasoningSnapshot = '';
  bool _replyDirty = false;
  bool _reasoningDirty = false;
  AiTokenUsage usage = const AiTokenUsage();
  DateTime? reasoningStartedAt;
  DateTime? answerStartedAt;

  String get fullReply {
    if (_replyDirty) {
      _replySnapshot = _reply.toString();
      _replyDirty = false;
    }
    return _replySnapshot;
  }

  String get fullReasoning {
    if (_reasoningDirty) {
      _reasoningSnapshot = _reasoning.toString();
      _reasoningDirty = false;
    }
    return _reasoningSnapshot;
  }

  void add(AiStreamEvent event, {DateTime? now}) {
    if (event.kind == AiStreamEventKind.content) {
      answerStartedAt ??= now ?? DateTime.now();
      _reply.write(event.text);
      _replyDirty = true;
    } else if (event.kind == AiStreamEventKind.reasoning) {
      reasoningStartedAt ??= now ?? DateTime.now();
      _reasoning.write(event.text);
      _reasoningDirty = true;
    } else if (event.usage != null) {
      usage = usage.merge(event.usage!);
    }
  }

  int reasoningDurationMs({DateTime? now}) {
    final startedAt = reasoningStartedAt;
    if (startedAt == null) return 0;
    return (answerStartedAt ?? now ?? DateTime.now())
        .difference(startedAt)
        .inMilliseconds;
  }
}
