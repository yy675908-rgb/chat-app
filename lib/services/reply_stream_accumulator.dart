import 'ai_chat_service.dart';

class ReplyStreamAccumulator {
  StringBuffer _reply = StringBuffer();
  StringBuffer _reasoning = StringBuffer();
  AiTokenUsage usage = const AiTokenUsage();
  DateTime? reasoningStartedAt;
  DateTime? answerStartedAt;

  String get fullReply => _reply.toString();
  String get fullReasoning => _reasoning.toString();
  bool get hasReply => _reply.length > 0;

  void add(AiStreamEvent event, {DateTime? now}) {
    if (event.kind == AiStreamEventKind.replaceContent) {
      _reply = StringBuffer()..write(event.text);
      _reasoning = StringBuffer();
      reasoningStartedAt = null;
      answerStartedAt = now ?? DateTime.now();
      usage = event.usage ?? const AiTokenUsage();
    } else if (event.kind == AiStreamEventKind.content) {
      answerStartedAt ??= now ?? DateTime.now();
      _reply.write(event.text);
    } else if (event.kind == AiStreamEventKind.reasoning) {
      reasoningStartedAt ??= now ?? DateTime.now();
      _reasoning.write(event.text);
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
