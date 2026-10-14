import 'package:flutter_test/flutter_test.dart';

import 'package:character_chat_app/models/character_profile.dart';
import 'package:character_chat_app/models/chat_message.dart';
import 'package:character_chat_app/models/provider_profile.dart';
import 'package:character_chat_app/models/user_profile.dart';
import 'package:character_chat_app/services/ai_chat_service.dart';
import 'package:character_chat_app/services/chat_auxiliary_ai_service.dart';

void main() {
  test('proactive messages always receive saved facts', () async {
    final reply = _CapturingProactiveReply();
    final auxiliary = ChatAuxiliaryAiService(
      proactiveServiceFactory: () => reply,
    );
    const memory = '你有用户家的钥匙，不需要敲门，也不需要用户开门，直接进';
    const provider = ProviderProfile(
      id: 'test',
      name: 'Test',
      protocol: ProviderProtocol.openAiCompatible,
      baseUrl: 'https://example.com/v1',
      models: ['model'],
      selectedModel: 'model',
    );

    final message = await auxiliary.generateProactiveMessage(
      provider: provider,
      apiKey: 'secret',
      character: CharacterProfile.lin(DateTime.utc(2026)),
      userProfile: const UserProfile(),
      memories: const [memory],
      recentTranscript: '今天天气不错。',
      currentMood: '',
    );

    expect(message, '我到了');
    expect(reply.systemPrompt, contains(memory));
    expect(reply.systemPrompt, contains('不要等用户再次提及'));
    expect(reply.systemPrompt, contains('不得按惯常情节要求用户做那个动作'));
    expect(reply.systemPrompt, contains('用“你”称呼对方'));
  });

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

class _CapturingProactiveReply extends AiChatService {
  String systemPrompt = '';

  @override
  Stream<String> streamReply({
    required ProviderProfile provider,
    required String apiKey,
    required String systemPrompt,
    required List<ChatMessage> history,
    double temperature = 0.85,
    int contextTokenBudget = 0,
  }) {
    this.systemPrompt = systemPrompt;
    return Stream.value('我到了');
  }
}
