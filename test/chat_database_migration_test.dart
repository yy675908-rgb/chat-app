import 'dart:convert';

import 'package:character_chat_app/models/chat_message.dart';
import 'package:character_chat_app/models/conversation.dart';
import 'package:character_chat_app/services/chat_database.dart';
import 'package:character_chat_app/services/chat_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  test('legacy chat JSON migrates to SQLite without losing messages', () async {
    final conversation = Conversation(
      id: 'conversation-old',
      characterId: 'character-lin',
      title: '旧对话',
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 2),
    );
    final messages = [
      ChatMessage(
        id: 'u1',
        author: MessageAuthor.user,
        text: '还记得吗',
        sentAt: DateTime.utc(2026, 1, 1, 12),
      ),
      ChatMessage(
        id: 'a1',
        author: MessageAuthor.character,
        text: '记得。',
        sentAt: DateTime.utc(2026, 1, 1, 12, 1),
      ),
    ];
    SharedPreferences.setMockInitialValues({
      'conversations_v2': jsonEncode([conversation.toJson()]),
      'conversation_messages_v2_${conversation.id}':
          jsonEncode(messages.map((item) => item.toJson()).toList()),
    });

    final database = ChatDatabase(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    final store = ChatStore(database: database);

    final migratedConversations = await store.loadConversations(
      characterId: 'character-lin',
    );
    final migratedMessages = await store.loadMessages(conversation.id);

    expect(migratedConversations.single.id, conversation.id);
    expect(
      migratedMessages.map((item) => item.text).toList(),
      ['还记得吗', '记得。'],
    );

    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getBool('chat_sqlite_migration_v1'), isTrue);
    expect(preferences.getString('conversations_v2'), isNull);
    expect(
      preferences.getString('conversation_messages_v2_${conversation.id}'),
      isNull,
    );

    final edited = [
      ...migratedMessages,
      ChatMessage(
        id: 'u2',
        author: MessageAuthor.user,
        text: '那继续。',
        sentAt: DateTime.utc(2026, 1, 1, 12, 2),
      ),
    ];
    await store.saveMessages(conversation.id, edited);
    final roundTrip = await store.loadMessages(conversation.id);
    expect(roundTrip.map((item) => item.id).toList(), ['u1', 'a1', 'u2']);

    await database.close();
  });

  test('scoped conversation saves do not erase messages for kept chats', () async {
    SharedPreferences.setMockInitialValues({});
    final database = ChatDatabase(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    final store = ChatStore(database: database);
    final now = DateTime.utc(2026, 2, 1);
    final conversation = Conversation(
      id: 'kept',
      characterId: 'character-lin',
      title: '保留',
      createdAt: now,
      updatedAt: now,
    );
    await store.saveConversations([conversation], characterId: 'character-lin');
    await store.saveMessages(conversation.id, [
      ChatMessage(
        id: 'm1',
        author: MessageAuthor.user,
        text: '不会被删',
        sentAt: now,
      ),
    ]);

    await store.saveConversations(
      [conversation.copyWith(updatedAt: now.add(const Duration(minutes: 1)))],
      characterId: 'character-lin',
    );

    final messages = await store.loadMessages(conversation.id);
    expect(messages.single.text, '不会被删');
    await database.close();
  });
  test('single conversation metadata updates preserve sibling chats and messages', () async {
    SharedPreferences.setMockInitialValues({});
    final database = ChatDatabase(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    final store = ChatStore(database: database);
    final now = DateTime.utc(2026, 2, 2);
    final first = Conversation(
      id: 'first',
      characterId: 'character-lin',
      title: '第一段',
      createdAt: now,
      updatedAt: now,
    );
    final second = Conversation(
      id: 'second',
      characterId: 'character-lin',
      title: '第二段',
      createdAt: now,
      updatedAt: now,
    );
    await store.saveConversations([first, second], characterId: 'character-lin');
    await store.saveMessages(first.id, [
      ChatMessage(
        id: 'm1',
        author: MessageAuthor.user,
        text: '保留这条消息',
        sentAt: now,
      ),
    ]);

    await store.saveConversation(
      first.copyWith(updatedAt: now.add(const Duration(minutes: 1))),
    );

    final conversations = await store.loadConversations(
      characterId: 'character-lin',
    );
    expect(conversations.map((item) => item.id).toSet(), {'first', 'second'});
    expect((await store.loadMessages(first.id)).single.text, '保留这条消息');
    await database.close();
  });

  test('chat search finds visible text and ignores hidden metadata', () async {
    SharedPreferences.setMockInitialValues({});
    final database = ChatDatabase(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    final store = ChatStore(database: database);
    final now = DateTime.utc(2026, 3, 1);
    final conversation = Conversation(
      id: 'search-chat',
      characterId: 'character-lin',
      title: '旅行',
      createdAt: now,
      updatedAt: now,
    );
    await store.saveConversations([conversation]);
    await store.saveMessages(conversation.id, [
      ChatMessage(
        id: 'u1',
        author: MessageAuthor.user,
        text: '下次去景德镇看陶瓷',
        sentAt: now,
      ),
      ChatMessage(
        id: 'a1',
        author: MessageAuthor.character,
        text: '可以去御窑博物馆\n[[心绪:期待]]',
        sentAt: now.add(const Duration(minutes: 1)),
      ),
      ChatMessage(
        id: 's1',
        author: MessageAuthor.system,
        text: '景德镇系统提示',
        sentAt: now.add(const Duration(minutes: 2)),
      ),
    ]);

    final placeResults = await store.searchMessages('景德镇');
    expect(placeResults.map((item) => item.message.id).toList(), ['u1']);
    expect(placeResults.single.conversation.title, '旅行');

    final visibleResults = await store.searchMessages('御窑');
    expect(visibleResults.single.message.id, 'a1');

    final hiddenResults = await store.searchMessages('期待');
    expect(hiddenResults, isEmpty);

    await database.close();
  });

}
