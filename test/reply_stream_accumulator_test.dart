import 'package:flutter_test/flutter_test.dart';

import 'package:character_chat_app/services/ai_chat_service.dart';
import 'package:character_chat_app/services/reply_stream_accumulator.dart';

void main() {
  group('ReplyStreamAccumulator', () {
    test('accumulates content and reasoning in arrival order', () {
      final state = ReplyStreamAccumulator();
      final t0 = DateTime.utc(2026, 9, 18, 1, 0, 0);

      state.add(
        const AiStreamEvent(
          kind: AiStreamEventKind.reasoning,
          text: '先想',
        ),
        now: t0,
      );
      state.add(
        const AiStreamEvent(
          kind: AiStreamEventKind.reasoning,
          text: '一下',
        ),
        now: t0.add(const Duration(milliseconds: 100)),
      );
      state.add(
        const AiStreamEvent(
          kind: AiStreamEventKind.content,
          text: '回答',
        ),
        now: t0.add(const Duration(milliseconds: 750)),
      );
      state.add(
        const AiStreamEvent(
          kind: AiStreamEventKind.content,
          text: '完成',
        ),
        now: t0.add(const Duration(milliseconds: 900)),
      );

      expect(state.fullReasoning, '先想一下');
      expect(state.fullReply, '回答完成');
      expect(state.reasoningStartedAt, t0);
      expect(
        state.answerStartedAt,
        t0.add(const Duration(milliseconds: 750)),
      );
      expect(state.reasoningDurationMs(), 750);
    });

    test('reasoning duration uses current time before answer starts', () {
      final state = ReplyStreamAccumulator();
      final started = DateTime.utc(2026, 9, 18, 2, 0, 0);
      state.add(
        const AiStreamEvent(
          kind: AiStreamEventKind.reasoning,
          text: '思考中',
        ),
        now: started,
      );

      expect(
        state.reasoningDurationMs(
          now: started.add(const Duration(milliseconds: 420)),
        ),
        420,
      );
    });

    test('merges usage events with existing usage values', () {
      final state = ReplyStreamAccumulator();
      state.add(
        const AiStreamEvent(
          kind: AiStreamEventKind.usage,
          usage: AiTokenUsage(
            promptTokens: 120,
            completionTokens: 20,
          ),
        ),
      );
      state.add(
        const AiStreamEvent(
          kind: AiStreamEventKind.usage,
          usage: AiTokenUsage(
            completionTokens: 45,
            reasoningTokens: 12,
            reportedTotalTokens: 177,
          ),
        ),
      );

      expect(state.usage.promptTokens, 120);
      expect(state.usage.completionTokens, 45);
      expect(state.usage.reasoningTokens, 12);
      expect(state.usage.totalTokens, 177);
    });

    test('no reasoning reports zero duration', () {
      final state = ReplyStreamAccumulator();
      state.add(
        const AiStreamEvent(
          kind: AiStreamEventKind.content,
          text: '直接回答',
        ),
        now: DateTime.utc(2026, 9, 18),
      );

      expect(state.reasoningDurationMs(), 0);
    });
  });
}
