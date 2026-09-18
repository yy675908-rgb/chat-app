import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';

import '../models/chat_message.dart';
import '../models/chat_search_result.dart';
import '../models/conversation.dart';
import 'mood_codec.dart';

class ChatDatabase {
  ChatDatabase({DatabaseFactory? factory, String? path})
    : _factoryOverride = factory,
      _pathOverride = path;

  static const _databaseName = 'linjian_chat_v1.db';

  final DatabaseFactory? _factoryOverride;
  final String? _pathOverride;
  Database? _database;

  Future<Database> open() async {
    final existing = _database;
    if (existing != null && existing.isOpen) return existing;
    late final DatabaseFactory factory;
    try {
      factory = _factoryOverride ?? databaseFactory;
    } on StateError catch (error) {
      if (error.toString().contains('databaseFactory not initialized')) {
        throw MissingPluginException('SQLite database factory unavailable');
      }
      rethrow;
    }
    final path = _pathOverride ?? '${await getDatabasesPath()}/$_databaseName';
    final database = await factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE conversations (
              id TEXT PRIMARY KEY,
              character_id TEXT NOT NULL,
              is_group INTEGER NOT NULL,
              updated_at INTEGER NOT NULL,
              payload TEXT NOT NULL
            )
          ''');
          await db.execute(
            'CREATE INDEX conversations_character_idx '
            'ON conversations(character_id, is_group, updated_at)',
          );
          await db.execute('''
            CREATE TABLE messages (
              conversation_id TEXT NOT NULL,
              message_id TEXT NOT NULL,
              ordinal INTEGER NOT NULL,
              payload TEXT NOT NULL,
              PRIMARY KEY (conversation_id, message_id),
              FOREIGN KEY (conversation_id) REFERENCES conversations(id)
                ON DELETE CASCADE
            )
          ''');
          await db.execute(
            'CREATE INDEX messages_conversation_idx '
            'ON messages(conversation_id, ordinal)',
          );
        },
      ),
    );
    _database = database;
    return database;
  }

  Future<int> conversationCount() async {
    final db = await open();
    return Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM conversations'),
        ) ??
        0;
  }

  Future<List<Conversation>> loadConversations({
    String? characterId,
    bool groupsOnly = false,
  }) async {
    final db = await open();
    String? where;
    List<Object?>? whereArgs;
    if (groupsOnly) {
      where = 'is_group = 1';
    } else if (characterId != null) {
      where = 'is_group = 0 AND character_id = ?';
      whereArgs = [characterId];
    }
    final rows = await db.query(
      'conversations',
      columns: ['payload'],
      where: where,
      whereArgs: whereArgs,
      orderBy: 'updated_at DESC',
    );
    final result = <Conversation>[];
    for (final row in rows) {
      final raw = row['payload'];
      if (raw is! String || raw.isEmpty) continue;
      try {
        result.add(
          Conversation.fromJson(
            Map<String, Object?>.from(jsonDecode(raw) as Map),
          ),
        );
      } on Object {
        // Skip only the malformed row instead of losing the whole chat list.
      }
    }
    return result;
  }

  Future<void> replaceConversations(
    List<Conversation> conversations, {
    String? characterId,
    bool groupsOnly = false,
  }) async {
    final db = await open();
    await db.transaction((txn) async {
      String? where;
      List<Object?>? whereArgs;
      if (groupsOnly) {
        where = 'is_group = 1';
      } else if (characterId != null) {
        where = 'is_group = 0 AND character_id = ?';
        whereArgs = [characterId];
      }
      final existingRows = await txn.query(
        'conversations',
        columns: ['id'],
        where: where,
        whereArgs: whereArgs,
      );
      final existingIds = existingRows
          .map((row) => row['id'])
          .whereType<String>()
          .toSet();
      final desiredIds = conversations.map((item) => item.id).toSet();
      final obsoleteIds = existingIds
          .where((id) => !desiredIds.contains(id))
          .toList();
      if (obsoleteIds.isNotEmpty) {
        final batch = txn.batch();
        for (final id in obsoleteIds) {
          batch.delete('conversations', where: 'id = ?', whereArgs: [id]);
        }
        await batch.commit(noResult: true);
      }

      final batch = txn.batch();
      for (final conversation in conversations) {
        final values = <String, Object?>{
          'id': conversation.id,
          'character_id': conversation.characterId,
          'is_group': conversation.isGroup ? 1 : 0,
          'updated_at': conversation.updatedAt.millisecondsSinceEpoch,
          'payload': jsonEncode(conversation.toJson()),
        };
        if (existingIds.contains(conversation.id)) {
          batch.update(
            'conversations',
            values,
            where: 'id = ?',
            whereArgs: [conversation.id],
          );
        } else {
          batch.insert('conversations', values);
        }
      }
      await batch.commit(noResult: true);
    });
  }

  Future<void> upsertConversation(Conversation conversation) async {
    final db = await open();
    final values = <String, Object?>{
      'id': conversation.id,
      'character_id': conversation.characterId,
      'is_group': conversation.isGroup ? 1 : 0,
      'updated_at': conversation.updatedAt.millisecondsSinceEpoch,
      'payload': jsonEncode(conversation.toJson()),
    };
    await db.transaction((txn) async {
      final updated = await txn.update(
        'conversations',
        values,
        where: 'id = ?',
        whereArgs: [conversation.id],
      );
      if (updated == 0) {
        await txn.insert('conversations', values);
      }
    });
  }

  Future<List<ChatMessage>> loadMessages(String conversationId) async {
    final db = await open();
    final rows = await db.query(
      'messages',
      columns: ['payload'],
      where: 'conversation_id = ?',
      whereArgs: [conversationId],
      orderBy: 'ordinal ASC',
    );
    final result = <ChatMessage>[];
    for (final row in rows) {
      final raw = row['payload'];
      if (raw is! String || raw.isEmpty) continue;
      try {
        result.add(
          ChatMessage.fromJson(
            Map<String, Object?>.from(jsonDecode(raw) as Map),
          ),
        );
      } on Object {
        // Skip only the malformed row.
      }
    }
    return result;
  }

  Future<void> upsertMessage(
    String conversationId,
    ChatMessage message,
    int ordinal,
  ) async {
    final db = await open();
    await db.insert(
      'messages',
      {
        'conversation_id': conversationId,
        'message_id': message.id,
        'ordinal': ordinal,
        'payload': jsonEncode(message.toJson()),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> saveMessages(
    String conversationId,
    List<ChatMessage> messages,
  ) async {
    final db = await open();
    await db.transaction((txn) async {
      final existingRows = await txn.query(
        'messages',
        columns: ['message_id', 'ordinal', 'payload'],
        where: 'conversation_id = ?',
        whereArgs: [conversationId],
      );
      final existing = <String, Map<String, Object?>>{
        for (final row in existingRows)
          if (row['message_id'] case final String id) id: row,
      };
      final desiredIds = <String>{};
      final batch = txn.batch();
      for (var index = 0; index < messages.length; index++) {
        final message = messages[index];
        desiredIds.add(message.id);
        final payload = jsonEncode(message.toJson());
        final row = existing[message.id];
        final unchanged =
            row != null && row['ordinal'] == index && row['payload'] == payload;
        if (unchanged) continue;
        batch.insert(
          'messages',
          {
            'conversation_id': conversationId,
            'message_id': message.id,
            'ordinal': index,
            'payload': payload,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      for (final id in existing.keys) {
        if (desiredIds.contains(id)) continue;
        batch.delete(
          'messages',
          where: 'conversation_id = ? AND message_id = ?',
          whereArgs: [conversationId, id],
        );
      }
      await batch.commit(noResult: true);
    });
  }

  Future<void> deleteConversation(String conversationId) async {
    final db = await open();
    await db.delete(
      'conversations',
      where: 'id = ?',
      whereArgs: [conversationId],
    );
  }

  Future<void> deleteMessages(String conversationId) async {
    final db = await open();
    await db.delete(
      'messages',
      where: 'conversation_id = ?',
      whereArgs: [conversationId],
    );
  }

  Future<List<ChatSearchResult>> searchMessages(
    String query, {
    int limit = 100,
  }) async {
    final term = query.trim();
    if (term.isEmpty || limit <= 0) return const [];

    final db = await open();
    final rows = await db.rawQuery(
      '''
        SELECT
          c.payload AS conversation_payload,
          m.payload AS message_payload
        FROM messages AS m
        JOIN conversations AS c ON c.id = m.conversation_id
        WHERE instr(lower(m.payload), lower(?)) > 0
        ORDER BY c.updated_at DESC, m.ordinal DESC
      ''',
      [term],
    );

    final normalized = term.toLowerCase();
    final results = <ChatSearchResult>[];
    for (final row in rows) {
      final conversationRaw = row['conversation_payload'];
      final messageRaw = row['message_payload'];
      if (conversationRaw is! String ||
          conversationRaw.isEmpty ||
          messageRaw is! String ||
          messageRaw.isEmpty) {
        continue;
      }
      try {
        final conversation = Conversation.fromJson(
          Map<String, Object?>.from(jsonDecode(conversationRaw) as Map),
        );
        final message = ChatMessage.fromJson(
          Map<String, Object?>.from(jsonDecode(messageRaw) as Map),
        );
        if (message.author == MessageAuthor.system || message.isRetracted) {
          continue;
        }
        final visibleText = MoodCodec.stripMetadata(message.text).trim();
        if (visibleText.isEmpty ||
            !visibleText.toLowerCase().contains(normalized)) {
          continue;
        }
        results.add(
          ChatSearchResult(conversation: conversation, message: message),
        );
      } on Object {
        // Skip only the malformed row.
      }
    }
    results.sort((a, b) => b.message.sentAt.compareTo(a.message.sentAt));
    if (results.length <= limit) return results;
    return results.sublist(0, limit);
  }

  Future<void> close() async {
    final db = _database;
    _database = null;
    if (db != null && db.isOpen) await db.close();
  }
}
