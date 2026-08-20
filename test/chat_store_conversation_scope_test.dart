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

  test('group chats are independent from every character conversation list',
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
    expect(
      (await store.loadGroupConversations()).map((item) => item.id),
      ['legacy-group'],
    );
  });

  test('saving either scope preserves conversations in the other scope',
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
    await store.saveConversations(
      [renamedSingle],
      characterId: 'character-a',
    );
    expect((await store.loadGroupConversations()).single.id, 'group-a');

    final renamedGroup = group.copyWith(title: '改名群聊');
    await store.saveGroupConversations([renamedGroup]);
    expect(
      (await store.loadConversations(characterId: 'character-a'))
          .single
          .title,
      '改名单聊',
    );
  });

  test('the latest user message always requires one character reply', () {
    final now = DateTime.utc(2026, 8, 20);
    ChatMessage message(String id, MessageAuthor author) => ChatMessage(
          id: id,
          author: author,
          text: id,
          sentAt: now,
        );

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
    expect(
      const ['character-a', 'character-b', 'character-c'],
      contains(selected),
    );
    expect(selected, isNot('character-a'));
  });
}
