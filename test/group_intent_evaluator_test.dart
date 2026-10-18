import 'package:flutter_test/flutter_test.dart';

import 'package:character_chat_app/models/character_profile.dart';
import 'package:character_chat_app/models/chat_message.dart';
import 'package:character_chat_app/models/provider_profile.dart';
import 'package:character_chat_app/models/user_profile.dart';
import 'package:character_chat_app/models/world_book_entry.dart';
import 'package:character_chat_app/services/ai_chat_service.dart';
import 'package:character_chat_app/services/group_intent_evaluator.dart';

void main() {
  test('group intent receives each character’s own facts and shared rules', () async {
    final services = <_CapturingIntentReply>[];
    final evaluator = GroupIntentEvaluator(serviceFactory: () {
      final service = _CapturingIntentReply();
      services.add(service);
      return service;
    });
    final now = DateTime.utc(2026, 10, 18);
    final first = CharacterProfile.lin(now);
    final second = CharacterProfile.newCharacter(now).copyWith(name: '阿野');
    final visible = [
      ChatMessage(
        id: 'latest',
        author: MessageAuthor.user,
        text: '今天去海边吗？',
        sentAt: now,
      ),
    ];
    final intents = await evaluator.evaluateCandidates(
      candidates: [first, second],
      provider: const ProviderProfile(
        id: 'test',
        name: 'Test',
        protocol: ProviderProtocol.openAiCompatible,
        baseUrl: 'https://example.com/v1',
        models: ['model'],
        selectedModel: 'model',
      ),
      apiKey: 'secret',
      transcript: '用户：今天去海边吗？',
      roster: '林、阿野',
      spokenNames: '',
      lastSpeakerName: '',
      characterMemories: {
        first.id: ['和林约好带相机'],
        second.id: ['和阿野约好带水'],
      },
      characterStylePreferences: {
        first.id: ['当出游时：说话简短'],
        second.id: ['当出游时：提出具体计划'],
      },
      userProfile: const UserProfile(name: '小元'),
      worldBooks: const [
        WorldBookEntry(
          id: 'coast',
          title: '海边',
          keywords: ['海边'],
          content: '海边的约定是周日',
        ),
      ],
      visibleMessages: visible,
      moodForCharacter: (_) => '',
      intimacyBehavior: (_) => '50/100',
    );

    expect(intents.keys, containsAll([first.id, second.id]));
    expect(services, hasLength(2));
    final firstPrompt = services[0].systemPrompt;
    final secondPrompt = services[1].systemPrompt;
    expect(firstPrompt, contains('和林约好带相机'));
    expect(firstPrompt, isNot(contains('和阿野约好带水')));
    expect(secondPrompt, contains('和阿野约好带水'));
    expect(secondPrompt, isNot(contains('和林约好带相机')));
    expect(firstPrompt, contains('当出游时：说话简短'));
    expect(secondPrompt, contains('当出游时：提出具体计划'));
    for (final prompt in [firstPrompt, secondPrompt]) {
      expect(prompt, contains('名字：小元'));
      expect(prompt, contains('海边的约定是周日'));
    }
  });
}

class _CapturingIntentReply extends AiChatService {
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
    return Stream.value('REPLY|75');
  }
}
