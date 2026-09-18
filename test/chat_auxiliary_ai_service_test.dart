import 'package:flutter_test/flutter_test.dart';

import 'package:character_chat_app/services/chat_auxiliary_ai_service.dart';

void main() {
  group('ChatAuxiliaryAiService normalization', () {
    test('normalizes relationship memory candidates', () {
      expect(
        ChatAuxiliaryAiService.normalizeMemoryCandidate('  NONE\n'),
        isEmpty,
      );
      expect(
        ChatAuxiliaryAiService.normalizeMemoryCandidate(
          '“用户  喜欢\n周末去看展”',
        ),
        '用户 喜欢 周末去看展',
      );

      final long = List.filled(70, '记').join();
      expect(
        ChatAuxiliaryAiService.normalizeMemoryCandidate(long).length,
        60,
      );
    });

    test('normalizes reusable style preferences', () {
      expect(
        ChatAuxiliaryAiService.normalizeStylePreference(
          '  - “当用户焦虑时：先简短回应，再给具体做法”  ',
        ),
        '当用户焦虑时：先简短回应，再给具体做法',
      );
      expect(
        ChatAuxiliaryAiService.normalizeStylePreference('• 当提问直接时：少解释   多给结论'),
        '当提问直接时：少解释 多给结论',
      );
    });

    test('summary normalization strips hidden mood metadata', () {
      expect(
        ChatAuxiliaryAiService.normalizeSummaryResponse(
          '用户已经确定周末去看展。\n[[心绪:期待]]',
        ),
        '用户已经确定周末去看展。',
      );
    });
  });
}
