import 'ai_chat_service.dart';

class ReplyStreamAccumulator {
  String fullReply = '';
  String fullReasoning = '';
  AiTokenUsage usage = const AiTokenUsage();
  DateTime? reasoningStartedAt;
  DateTime? answerStartedAt;

  void add(AiStreamEvent event, {DateTime? now}) {
    if (event.kind == AiStreamEventKind.content) {
      answerStartedAt ??= now ?? DateTime.now();
      fullReply += event.text;
    } else if (event.kind == AiStreamEventKind.reasoning) {
      reasoningStartedAt ??= now ?? DateTime.now();
      fullReasoning += event.text;
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
