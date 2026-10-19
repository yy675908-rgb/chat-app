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
    test('builds prompt from current chat state without unrelated memory', () {
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
      final contextMessages = [
        ChatMessage(
          id: 'm1',
          author: MessageAuthor.user,
          text: '之前说到周末。',
          sentAt: now.subtract(const Duration(minutes: 2)),
        ),
        ChatMessage(
          id: 'm2',
          author: MessageAuthor.user,
          text: '现在想喝咖啡。',
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
        activeMemories: const ['用户喝咖啡通常不加糖', '用户喜欢陶瓷'],
        stylePreferences: const ['遇到明确问题时直接回答'],
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
        groupParticipants: const [],
        savedMood: '平静',
        contextMessages: contextMessages,
        now: now,
      );

      expect(prompt, startsWith('模型隐藏提示。\n\n角色设定正文。'));
      expect(prompt, contains('用户对你的亲密度为72/100（较高）'));
      expect(prompt, contains('关系亲近时也可能很低'));
      expect(prompt, contains('名字：小元'));
      expect(prompt, contains('用户喝咖啡通常不加糖'));
      expect(prompt, contains('用户喜欢陶瓷'));
      expect(prompt, contains('遇到明确问题时直接回答'));
      expect(prompt, contains('【咖啡店】\n这是一家安静的店。'));
      expect(prompt, contains('当前对话较早内容的摘要：\n较早内容摘要。'));
      expect(prompt, contains('上一轮心绪是“平静”'));
      expect(prompt, contains('2026-09-18 14:30'));
      expect(prompt, isNot(contains('拉长回复')));
      expect(prompt, isNot(contains('自行增加回复长度')));
      expect(prompt, isNot(contains('应用在本次回复前获取')));
    });

    test('location context belongs to the user and is only included when given', () {
      final now = DateTime(2026, 10, 14, 9);
      final prompt = ChatContextBuilder.buildSystemPrompt(
        activeCharacter: CharacterProfile.lin(now),
        selectedProvider: null,
        userProfile: const UserProfile(),
        activeMemories: const [],
        stylePreferences: const [],
        worldBooks: const [],
        visibleMessages: const [],
        currentConversation: null,
        branchKey: 'root',
        groupParticipants: const [],
        savedMood: '',
        contextMessages: const [],
        now: now,
        currentPlace: '北京市 朝阳区',
        locationEnabled: true,
      );
      expect(prompt, contains('用户设备位置：北京市 朝阳区'));
      expect(prompt, contains('不代表你也在那里'));
      expect(prompt, contains('不要说自己无法读取'));
    });

    test('drops current summary when its marker is outside current context', () {
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
      final latest = [
        ChatMessage(
          id: 'latest',
          author: MessageAuthor.user,
          text: '只看当前内容',
          sentAt: now,
        ),
      ];

      final prompt = ChatContextBuilder.buildSystemPrompt(
        activeCharacter: character,
        selectedProvider: null,
        userProfile: const UserProfile(),
        activeMemories: const [],
        stylePreferences: const [],
        worldBooks: const [],
        visibleMessages: latest,
        currentConversation: current,
        branchKey: 'root',
        groupParticipants: const [],
        savedMood: '',
        contextMessages: latest,
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

    test('a missing summary keeps earlier conversation messages', () {
      final now = DateTime.utc(2026);
      final conversation = Conversation(
        id: 'c',
        characterId: 'role',
        title: '聊天',
        createdAt: now,
        updatedAt: now,
        summarizedThroughMessageIds: const {'root': 'old'},
      );
      final messages = [
        ChatMessage(id: 'old', author: MessageAuthor.user, text: '旧事实', sentAt: now),
        ChatMessage(id: 'new', author: MessageAuthor.user, text: '继续', sentAt: now),
      ];
      expect(
        ChatContextBuilder.summaryForContext(
          conversation: conversation,
          branchKey: 'root',
          messages: messages,
        ),
        isEmpty,
      );
      final trimmed = ChatContextBuilder.messagesWithinBudget(
        messages: messages,
        systemPrompt: '',
        contextTokenBudget: 4096,
      );
      expect(trimmed.map((message) => message.id), ['old', 'new']);
    });

    test('intimacy labels keep existing thresholds', () {
      expect(ChatContextBuilder.intimacyLabel(19), '很低');
      expect(ChatContextBuilder.intimacyLabel(20), '偏低');
      expect(ChatContextBuilder.intimacyLabel(40), '一般');
      expect(ChatContextBuilder.intimacyLabel(60), '较高');
      expect(ChatContextBuilder.intimacyLabel(80), '很高');
    });

    test('group prompt addresses other characters without forcing user address', () {
      final now = DateTime.utc(2026, 10, 18);
      final character = CharacterProfile.lin(now);
      final prompt = ChatContextBuilder.buildSystemPrompt(
        activeCharacter: character,
        selectedProvider: null,
        userProfile: const UserProfile(),
        activeMemories: const [],
        stylePreferences: const [],
        worldBooks: const [],
        visibleMessages: const [],
        currentConversation: Conversation(
          id: 'group',
          characterId: Conversation.groupSpaceId,
          participantIds: [character.id, 'other'],
          title: '群聊',
          createdAt: now,
          updatedAt: now,
        ),
        branchKey: 'root',
        groupParticipants: [character],
        savedMood: '',
        contextMessages: const [],
        now: now,
      );
      expect(prompt, contains('回应其他角色时直接称呼对方'));
      expect(prompt, isNot(contains('你正在直接和用户说话')));
    });

    test('blank world-book keywords do not activate every rule', () {
      final prompt = ChatContextBuilder.matchedWorldBookPrompt(
        worldBooks: const [
          WorldBookEntry(
            id: 'blank',
            title: '不相关',
            keywords: ['  '],
            content: '不要带入这条设定',
          ),
        ],
        visibleMessages: [
          ChatMessage(
            id: 'recent',
            author: MessageAuthor.user,
            text: '你好',
            sentAt: DateTime.utc(2026),
          ),
        ],
      );
      expect(prompt, isEmpty);
    });

    test('keyword-free world-book rules reach old and new roles every turn', () {
      final now = DateTime.utc(2026);
      const books = [
        WorldBookEntry(
          id: 'permanent',
          title: '常驻规则',
          keywords: [],
          content: '无论对话多久，都记得周六的约定。',
        ),
        WorldBookEntry(
          id: 'conditional',
          title: '海边',
          keywords: ['海边'],
          content: '带上蓝伞。',
        ),
        WorldBookEntry(
          id: 'disabled',
          title: '关闭',
          keywords: [],
          content: '不应出现。',
          enabled: false,
        ),
      ];
      for (final character in [
        CharacterProfile.lin(now),
        CharacterProfile.newCharacter(now).copyWith(name: '阿野'),
      ]) {
        final prompt = ChatContextBuilder.buildSystemPrompt(
          activeCharacter: character,
          selectedProvider: null,
          userProfile: const UserProfile(),
          activeMemories: const [],
          stylePreferences: const [],
          worldBooks: books,
          visibleMessages: [
            ChatMessage(
              id: 'latest',
              author: MessageAuthor.user,
              text: '继续',
              sentAt: now,
            ),
          ],
          currentConversation: null,
          branchKey: 'root',
          groupParticipants: const [],
          savedMood: '',
          contextMessages: null,
          now: now,
        );
        expect(prompt, contains('无论对话多久，都记得周六的约定。'));
        expect(prompt, isNot(contains('带上蓝伞。')));
        expect(prompt, isNot(contains('不应出现。')));
      }
    });

    test('permanent rules are not silently dropped by the lore limit', () {
      final prompt = ChatContextBuilder.matchedWorldBookPrompt(
        worldBooks: [
          WorldBookEntry(
            id: 'large',
            title: '长设定',
            keywords: const [],
            content: List.filled(6100, '设').join(),
          ),
          const WorldBookEntry(
            id: 'rule',
            title: '常驻规则',
            keywords: [],
            content: '始终遵守约定。',
          ),
        ],
        visibleMessages: const [],
      );
      expect(prompt, contains('始终遵守约定。'));
    });
  });
}
