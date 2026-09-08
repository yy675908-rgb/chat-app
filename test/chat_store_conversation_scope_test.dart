import 'package:character_chat_app/models/character_profile.dart';
import 'package:character_chat_app/models/chat_message.dart';
import 'package:character_chat_app/models/conversation.dart';
import 'package:character_chat_app/services/chat_store.dart';
import 'package:character_chat_app/services/group_reply_policy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'group chats are independent from every character conversation list',
    () async {
      final store = ChatStore();
      final now = DateTime.utc(2026, 8, 20);
      final characterA = Conversation(
        id: 'single-a',
        characterId: 'character-a',
        title: 'A 的对话',
        createdAt: now,
        updatedAt: now,
      );
      final characterB = Conversation(
        id: 'single-b',
        characterId: 'character-b',
        title: 'B 的对话',
        createdAt: now,
        updatedAt: now,
      );
      final legacyGroup = Conversation(
        id: 'legacy-group',
        characterId: 'character-a',
        title: '旧群聊',
        createdAt: now,
        updatedAt: now.add(const Duration(minutes: 1)),
        participantIds: const ['character-a', 'character-b'],
      );
      await store.saveConversations([characterA, characterB, legacyGroup]);

      expect(
        (await store.loadConversations(characterId: 'character-a'))
            .map((item) => item.id),
        ['single-a'],
      );
      expect(
        (await store.loadConversations(characterId: 'character-b'))
            .map((item) => item.id),
        ['single-b'],
      );
      expect((await store.loadGroupConversations()).map((item) => item.id), [
        'legacy-group',
      ]);
    },
  );

  test(
    'saving either scope preserves conversations in the other scope',
    () async {
      final store = ChatStore();
      final now = DateTime.utc(2026, 8, 20);
      final single = Conversation(
        id: 'single-a',
        characterId: 'character-a',
        title: '单聊',
        createdAt: now,
        updatedAt: now,
      );
      final group = Conversation(
        id: 'group-a',
        characterId: Conversation.groupSpaceId,
        title: '群聊',
        createdAt: now,
        updatedAt: now,
        participantIds: const ['character-a', 'character-b'],
      );
      await store.saveConversations([single, group]);

      final renamedSingle = single.copyWith(title: '改名单聊');
      await store.saveConversations([
        renamedSingle,
      ], characterId: 'character-a');
      expect((await store.loadGroupConversations()).single.id, 'group-a');

      final renamedGroup = group.copyWith(title: '改名群聊');
      await store.saveGroupConversations([renamedGroup]);
      expect(
        (await store.loadConversations(characterId: 'character-a'))
            .single
            .title,
        '改名单聊',
      );
    },
  );

  test('relationship memory and mood stay isolated by character', () async {
    final store = ChatStore();
    await store.saveMemories(['A 的共同记忆'], characterId: 'character-a');
    await store.saveMemories(['B 的共同记忆'], characterId: 'character-b');
    await store.saveCharacterMood('开心', 'character-a');

    expect(await store.loadMemories(characterId: 'character-a'), ['A 的共同记忆']);
    expect(await store.loadMemories(characterId: 'character-b'), ['B 的共同记忆']);
    expect(await store.loadCharacterMood('character-a'), '开心');
    expect(await store.loadCharacterMood('character-b'), isEmpty);

    expect(await store.loadAutoMemoryEnabled(), isTrue);
    await store.saveAutoMemoryEnabled(false);
    expect(await store.loadAutoMemoryEnabled(), isFalse);
  });

  test(
    'deleting a conversation clears only data derived from that conversation',
    () async {
      final store = ChatStore();
      final now = DateTime.utc(2026, 8, 20);
      final character = CharacterProfile.newCharacter(now)
          .copyWith(status: '在生闷气');
      await store.saveCharacters([character]);
      await store.addMemory(
        '来自将删除对话的记忆',
        characterId: character.id,
        sourceConversationId: 'conversation-a',
      );
      await store.addMemory(
        '来自其他对话的记忆',
        characterId: character.id,
        sourceConversationId: 'conversation-b',
      );
      await store.addMemory('手动添加的关系记忆', characterId: character.id);
      await store.saveCharacterMood('不高兴', character.id);
      await store.saveCharacterMoodSource(character.id, 'conversation-a');
      await store.saveCharacterStatusSource(character.id, 'conversation-a');

      await store.clearConversationDerivedState(
        conversationId: 'conversation-a',
        characterIds: [character.id],
      );

      expect(await store.loadMemories(characterId: character.id), [
        '来自其他对话的记忆',
        '手动添加的关系记忆',
      ]);
      expect(await store.loadCharacterMood(character.id), isEmpty);
      expect((await store.loadCharacters()).single.status, isEmpty);
      expect(await store.loadCharacterMoodSource(character.id), isEmpty);
      expect(await store.loadCharacterStatusSource(character.id), isEmpty);
    },
  );

  test(
    'deleting a character clears scoped relationship state completely',
    () async {
      final store = ChatStore();
      await store.addMemory(
        '角色记忆',
        characterId: 'character-a',
        sourceConversationId: 'conversation-a',
      );
      await store.saveCharacterMood('开心', 'character-a');
      await store.saveCharacterMoodSource('character-a', 'conversation-a');
      await store.saveCharacterStatusSource('character-a', 'conversation-a');

      await store.clearCharacterState('character-a');

      expect(await store.loadMemories(characterId: 'character-a'), isEmpty);
      expect(await store.loadMemorySources('character-a'), isEmpty);
      expect(await store.loadCharacterMood('character-a'), isEmpty);
      expect(await store.loadCharacterMoodSource('character-a'), isEmpty);
      expect(await store.loadCharacterStatusSource('character-a'), isEmpty);
    },
  );

  test(
    'legacy relationship memory migrates only to the built-in character',
    () async {
      SharedPreferences.setMockInitialValues({
        'relationship_memories_v1': ['旧的共同记忆'],
      });
      final store = ChatStore();

      expect(await store.loadMemories(characterId: 'character-lin'), [
        '旧的共同记忆',
      ]);
      expect(await store.loadMemories(characterId: 'character-new'), isEmpty);
    },
  );

  test('the latest user message always requires one character reply', () {
    final now = DateTime.utc(2026, 8, 20);
    ChatMessage message(String id, MessageAuthor author) =>
        ChatMessage(id: id, author: author, text: id, sentAt: now);

    expect(
      GroupReplyPolicy.latestUserNeedsReply([
        message('角色回复', MessageAuthor.character),
        message('用户新消息', MessageAuthor.user),
        message('系统消息', MessageAuthor.system),
      ]),
      isTrue,
    );
    expect(
      GroupReplyPolicy.latestUserNeedsReply([
        message('用户消息', MessageAuthor.user),
        message('角色回复', MessageAuthor.character),
      ]),
      isFalse,
    );
  });

  test('fallback speaker is valid and avoids consecutive speech', () {
    final selected = GroupReplyPolicy.fallbackSpeakerId(
      const ['character-a', 'character-b', 'character-c'],
      lastSpeakerId: 'character-a',
      seed: 'message-1',
    );

    expect(selected, isNotNull);
    expect(const [
      'character-a',
      'character-b',
      'character-c',
    ], contains(selected));
    expect(selected, isNot('character-a'));
  });

  test('character reply intents parse strict reply and pass decisions', () {
    final reply = GroupReplyPolicy.parseIntent('REPLY|87');
    final pass = GroupReplyPolicy.parseIntent('PASS|12');

    expect(reply.wantsToReply, isTrue);
    expect(reply.priority, 87);
    expect(pass.wantsToReply, isFalse);
    expect(pass.priority, 12);
  });

  test('willing characters are ranked without repeating the last speaker', () {
    final ranked = GroupReplyPolicy.rankWillingSpeakers(
      const {
        'character-a': GroupReplyIntent(wantsToReply: true, priority: 95),
        'character-b': GroupReplyIntent(wantsToReply: true, priority: 80),
        'character-c': GroupReplyIntent(wantsToReply: false, priority: 99),
      },
      spokenIds: const [],
      lastSpeakerId: 'character-a',
      seed: 'message-2',
    );

    expect(ranked, ['character-b']);
  });
}
