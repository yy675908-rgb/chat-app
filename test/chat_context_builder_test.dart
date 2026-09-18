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
      final previous = Conversation(
        id: 'chat-0',
        characterId: 'c1',
        title: '昨天',
        createdAt: now.subtract(const Duration(days: 1)),
        updatedAt: now.subtract(const Duration(days: 1)),
        branchSummaries: const {'root': '之前聊过旅行。'},
      );
      final contextMessages = [
        ChatMessage(
          id: 'm1',
          author: MessageAuthor.user,
          text: '提到咖啡',
          sentAt: now,
        ),
      ];

      final prompt = ChatContextBuilder.buildSystemPrompt(
        activeCharacter: character,
        selectedProvider: provider,
        userProfile: const UserProfile(
          name: '小元',
          gender: '女',
          description: '喜欢直接交流',
        ),
        activeMemories: const ['用户喜欢陶瓷'],
        stylePreferences: const ['当用户直接提问时：先给结论'],
        worldBooks: const [
          WorldBookEntry(
            id: 'w1',
            title: '咖啡店',
            keywords: ['咖啡'],
            content: '这是一家安静的店。',
          ),
        ],
        visibleMessages: contextMessages,
        currentConversation: current,
        branchKey: 'root',
        conversations: [current, previous],
        groupParticipants: const [],
        savedMood: '平静',
        contextMessages: contextMessages,
        now: now,
      );

      expect(prompt, startsWith('模型隐藏提示。\n\n角色设定正文。'));
      expect(prompt, contains('用户当前对你的好感度为72/100（较高）'));
      expect(prompt, contains('名字：小元'));
      expect(prompt, contains('用户喜欢陶瓷'));
      expect(prompt, contains('当用户直接提问时：先给结论'));
      expect(prompt, contains('【咖啡店】\n这是一家安静的店。'));
      expect(prompt, contains('当前对话较早内容的摘要：\n较早内容摘要。'));
      expect(prompt, contains('- 昨天：之前聊过旅行。'));
      expect(prompt, contains('上一轮心绪是“平静”'));
      expect(prompt, contains('2026-09-18 14:30'));
    });

    test('drops current summary when its marker is outside context', () {
      final now = DateTime(2026, 9, 18);
      final character = CharacterProfile.lin(now);
      final current = Conversation(
        id: 'chat-1',
        characterId: character.id,
        title: '当前',
        createdAt: now,
        updatedAt: now,
        branchSummaries: const {'root': '不该出现的摘要'},
        summarizedThroughMessageIds: const {'root': 'old-marker'},
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
        conversations: [current],
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
