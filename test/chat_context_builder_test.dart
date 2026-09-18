import 'package:flutter_test/flutter_test.dart';

import 'package:character_chat_app/models/character_profile.dart';
import 'package:character_chat_app/models/chat_message.dart';
import 'package:character_chat_app/models/conversation.dart';
import 'package:character_chat_app/models/provider_profile.dart';
import 'package:character_chat_app/models/user_profile.dart';
import 'package:character_chat_app/models/world_book_entry.dart';
import 'package:character_chat_app/services/chat_context_builder.dart';

void main() {
  group('ChatContextBuilder', () {
    test('builds the same prompt sections from explicit chat state', () {
      final now = DateTime(2026, 9, 18, 14, 30);
      final character = CharacterProfile(
        id: 'c1',
        name: '林',
        status: '',
        firstMetAt: now,
        greeting: '',
        systemPrompt: '角色设定正文。',
        userIntimacy: 72,
      );
      final provider = ProviderProfile(
        id: 'p1',
        name: '测试',
        protocol: ProviderProtocol.openAiCompatible,
        baseUrl: 'https://example.com/v1',
        models: const ['m1'],
        selectedModel: 'm1',
        modelSystemPrompts: const {'m1': '模型隐藏提示。'},
      );
      final current = Conversation(
        id: 'chat-1',
        characterId: 'c1',
        title: '当前对话',
        createdAt: now,
        updatedAt: now,
        branchSummaries: const {'root': '较早内容摘要。'},
        summarizedThroughMessageIds: const {'root': 'm1'},
      );
      final prompt = ChatContextBuilder.buildSystemPrompt(
        activeCharacter: character,
        selectedProvider: null,
        userProfile: const UserProfile(),
        activeMemories: const [],
        stylePreferences: const [],
        worldBooks: const [],
        visibleMessages: const [],
        currentConversation: current,
        branchKey: 'root',
        groupParticipants: const [],
        savedMood: '',
        contextMessages: const [],
        now: now,
      );

      expect(prompt, isNot(contains('不该出现的摘要')));
    });

    test('context trimming honors summarized-through marker and budget', () {
      final now = DateTime(2026, 9, 18);
      final messages = [
        ChatMessage(
          id: 'old',
          author: MessageAuthor.user,
          text: '旧消息',
          sentAt: now,
        ),
        ChatMessage(
          id: 'middle',
          author: MessageAuthor.character,
          text: List.filled(2600, '中').join(),
          sentAt: now,
        ),
        ChatMessage(
          id: 'latest',
          author: MessageAuthor.user,
          text: List.filled(2600, '新').join(),
          sentAt: now,
        ),
      ];

      final trimmed = ChatContextBuilder.messagesWithinBudget(
        messages: messages,
        systemPrompt: '',
        contextTokenBudget: 2048,
        summarizedThroughMessageId: 'old',
      );

      expect(trimmed.map((message) => message.id).toList(), ['latest']);
    });

    test('intimacy labels keep existing thresholds', () {
      expect(ChatContextBuilder.intimacyLabel(19), '很低');
      expect(ChatContextBuilder.intimacyLabel(20), '偏低');
      expect(ChatContextBuilder.intimacyLabel(40), '一般');
      expect(ChatContextBuilder.intimacyLabel(60), '较高');
      expect(ChatContextBuilder.intimacyLabel(80), '很高');
    });
  });
}
