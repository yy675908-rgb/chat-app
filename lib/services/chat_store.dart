import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/character_profile.dart';
import '../models/chat_message.dart';
import '../models/chat_search_result.dart';
import '../models/conversation.dart';
import '../models/world_book_entry.dart';
import '../models/user_profile.dart';
import 'chat_database.dart';
import 'mood_codec.dart';

class ChatStore {
  ChatStore({ChatDatabase? database}) : _database = database ?? ChatDatabase();

  static const _legacyMessagesKey = 'chat_messages_v1';
  static const _conversationsKey = 'conversations_v2';
  static const _messagesPrefix = 'conversation_messages_v2_';
  static const _sqliteMigrationKey = 'chat_sqlite_migration_v1';
  static const _memoriesKey = 'relationship_memories_v1';
  static const _memorySourcesKey = 'relationship_memory_sources_v1';
  static const _stylePreferencesKey = 'style_preferences_v1';
  static const _stylePreferencesScopedPrefix = 'style_preferences_v2_';
  static const _stylePreferenceSourcesKey = 'style_preference_sources_v1';
  static const _characterMoodKey = 'character_mood_v1';
  static const _characterMoodSourceKey = 'character_mood_source_v1';
  static const _characterStatusSourceKey = 'character_status_source_v1';
  static const _worldBooksKey = 'world_books_v1';
  static const _firstMetAtKey = 'first_met_at_v1';
  static const _profileKey = 'character_profile_v1';
  static const _charactersKey = 'character_profiles_v2';
  static const _selectedCharacterKey = 'selected_character_v2';
  static const _reasoningExpandedKey = 'reasoning_expanded_v1';
  static const _contextTokenBudgetKey = 'context_token_budget_v1';
  static const _autoMemoryEnabledKey = 'auto_memory_enabled_v1';
  static const _globalSystemPromptKey = 'global_system_prompt_v1';
  static const _userProfileKey = 'user_profile_v1';

  final ChatDatabase _database;
  bool _sqliteUnavailable = false;
  Future<void>? _migrationFuture;
  ChatDatabase? _readyDatabase;
  SharedPreferences? _preferences;

  Future<SharedPreferences> _prefs() async =>
      _preferences ??= await SharedPreferences.getInstance();

  Future<ChatDatabase?> _databaseOrNull() async {
    if (_sqliteUnavailable) return null;
    final ready = _readyDatabase;
    if (ready != null) return ready;
    try {
      await _database.open();
      _migrationFuture ??= _migrateLegacyChatData();
      await _migrationFuture;
      _readyDatabase = _database;
      return _readyDatabase;
    } on MissingPluginException {
      _sqliteUnavailable = true;
      return null;
    }
  }

  Future<void> _migrateLegacyChatData() async {
    final preferences = await _prefs();
    if (preferences.getBool(_sqliteMigrationKey) == true) return;

    if (await _database.conversationCount() > 0) {
      await preferences.setBool(_sqliteMigrationKey, true);
      return;
    }

    final raw = preferences.getString(_conversationsKey);
    final conversations = <Conversation>[];
    if (raw != null && raw.isNotEmpty) {
      try {
        conversations.addAll(
          (jsonDecode(raw) as List<dynamic>).map(
            (item) =>
                Conversation.fromJson(Map<String, Object?>.from(item as Map)),
          ),
        );
      } on Object {
        // Leave malformed legacy data untouched. A fresh conversation will be
        // created below when the app asks for one.
      }
    }

    if (conversations.isNotEmpty) {
      await _database.replaceConversations(conversations);
      for (final conversation in conversations) {
        final key = '$_messagesPrefix${conversation.id}';
        final messages = _decodeMessages(preferences.getString(key));
        if (messages.isNotEmpty) {
          await _database.saveMessages(conversation.id, messages);
        }
      }

      // Remove the bulky duplicate JSON only after every SQLite write above
      // has succeeded. Lightweight settings remain in SharedPreferences.
      await preferences.remove(_conversationsKey);
      for (final conversation in conversations) {
        await preferences.remove('$_messagesPrefix${conversation.id}');
      }
      await preferences.remove(_legacyMessagesKey);
    }
    await preferences.setBool(_sqliteMigrationKey, true);
  }

  Future<List<Conversation>> loadConversations({String? characterId}) async {
    final database = await _databaseOrNull();
    if (database != null) {
      final conversations = await database.loadConversations(
        characterId: characterId,
      );
      if (conversations.isNotEmpty) return conversations;

      final now = DateTime.now();
      final first = Conversation(
        id: 'conversation-${now.microsecondsSinceEpoch}',
        characterId: characterId ?? 'character-lin',
        title: '第一次见面',
        createdAt: now,
        updatedAt: now,
      );
      final preferences = await _prefs();
      final legacyMessages =
          characterId == null || characterId == 'character-lin'
          ? _decodeMessages(preferences.getString(_legacyMessagesKey))
          : <ChatMessage>[];
      await database.replaceConversations([first], characterId: characterId);
      if (legacyMessages.isNotEmpty) {
        await database.saveMessages(first.id, legacyMessages);
        await preferences.remove(_legacyMessagesKey);
      }
      return [first];
    }

    final preferences = await _prefs();
    final raw = preferences.getString(_conversationsKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final conversations = (jsonDecode(raw) as List<dynamic>)
            .map(
              (item) =>
                  Conversation.fromJson(Map<String, Object?>.from(item as Map)),
            )
            .toList();
        conversations.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        if (characterId == null) return conversations;
        final matching = conversations
            .where((item) => !item.isGroup && item.characterId == characterId)
            .toList();
        if (matching.isNotEmpty) return matching;
      } on Object {
        // Create a fresh conversation below.
      }
    }

    final now = DateTime.now();
    final first = Conversation(
      id: 'conversation-${now.microsecondsSinceEpoch}',
      characterId: characterId ?? 'character-lin',
      title: '第一次见面',
      createdAt: now,
      updatedAt: now,
    );
    final legacyMessages =
        raw == null && (characterId == null || characterId == 'character-lin')
        ? _decodeMessages(preferences.getString(_legacyMessagesKey))
        : <ChatMessage>[];
    await saveConversations([first], characterId: characterId);
    if (legacyMessages.isNotEmpty) {
      await saveMessages(first.id, legacyMessages);
    }
    return [first];
  }

  Future<List<Conversation>> loadGroupConversations() async {
    final database = await _databaseOrNull();
    if (database != null) {
      return database.loadConversations(groupsOnly: true);
    }

    final preferences = await _prefs();
    final raw = preferences.getString(_conversationsKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final conversations =
          (jsonDecode(raw) as List<dynamic>)
              .map(
                (item) => Conversation.fromJson(
                  Map<String, Object?>.from(item as Map),
                ),
              )
              .where((item) => item.isGroup)
              .toList()
            ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return conversations;
    } on Object {
      return const [];
    }
  }

  Future<void> saveConversations(
    List<Conversation> conversations, {
    String? characterId,
  }) async {
    final database = await _databaseOrNull();
    if (database != null) {
      await database.replaceConversations(
        conversations,
        characterId: characterId,
      );
      return;
    }

    final preferences = await _prefs();
    var items = conversations;
    if (characterId != null) {
      final raw = preferences.getString(_conversationsKey);
      final existing = <Conversation>[];
      if (raw != null && raw.isNotEmpty) {
        try {
          existing.addAll(
            (jsonDecode(raw) as List<dynamic>).map(
              (item) =>
                  Conversation.fromJson(Map<String, Object?>.from(item as Map)),
            ),
          );
        } on Object {
          // Replace malformed data with the active character's conversations.
        }
      }
      items = [
        ...existing.where(
          (item) => item.isGroup || item.characterId != characterId,
        ),
        ...conversations,
      ];
    }
    await preferences.setString(
      _conversationsKey,
      jsonEncode(items.map((conversation) => conversation.toJson()).toList()),
    );
  }

  Future<void> saveGroupConversations(List<Conversation> conversations) async {
    final database = await _databaseOrNull();
    if (database != null) {
      await database.replaceConversations(conversations, groupsOnly: true);
      return;
    }

    final preferences = await _prefs();
    final raw = preferences.getString(_conversationsKey);
    final existing = <Conversation>[];
    if (raw != null && raw.isNotEmpty) {
      try {
        existing.addAll(
          (jsonDecode(raw) as List<dynamic>).map(
            (item) =>
                Conversation.fromJson(Map<String, Object?>.from(item as Map)),
          ),
        );
      } on Object {
        // Replace malformed group data while preserving what can be decoded.
      }
    }
    final items = [
      ...existing.where((item) => !item.isGroup),
      ...conversations,
    ];
    await preferences.setString(
      _conversationsKey,
      jsonEncode(items.map((item) => item.toJson()).toList()),
    );
  }

  Future<void> saveConversation(Conversation conversation) async {
    final database = await _databaseOrNull();
    if (database != null) {
      await database.upsertConversation(conversation);
      return;
    }

    final preferences = await _prefs();
    final raw = preferences.getString(_conversationsKey);
    final conversations = <Conversation>[];
    if (raw != null && raw.isNotEmpty) {
      try {
        conversations.addAll(
          (jsonDecode(raw) as List<dynamic>).map(
            (item) =>
                Conversation.fromJson(Map<String, Object?>.from(item as Map)),
          ),
        );
      } on Object {
        // Replace malformed storage with the conversation being saved.
      }
    }
    final index = conversations.indexWhere((item) => item.id == conversation.id);
    if (index < 0) {
      conversations.add(conversation);
    } else {
      conversations[index] = conversation;
    }
    conversations.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    await preferences.setString(
      _conversationsKey,
      jsonEncode(conversations.map((item) => item.toJson()).toList()),
    );
  }

  Future<List<ChatMessage>> loadMessages(String conversationId) async {
    final database = await _databaseOrNull();
    if (database != null) return database.loadMessages(conversationId);

    final preferences = await _prefs();
    return _decodeMessages(
      preferences.getString('$_messagesPrefix$conversationId'),
    );
  }

  Future<void> saveMessage(
    String conversationId,
    ChatMessage message,
    int ordinal,
  ) async {
    final database = await _databaseOrNull();
    if (database != null) {
      await database.upsertMessage(conversationId, message, ordinal);
      return;
    }

    final preferences = await _prefs();
    final key = '$_messagesPrefix$conversationId';
    final messages = _decodeMessages(preferences.getString(key));
    final existing = messages.indexWhere((item) => item.id == message.id);
    if (existing >= 0) {
      messages[existing] = message;
    } else {
      final insertion = ordinal.clamp(0, messages.length);
      messages.insert(insertion, message);
    }
    await preferences.setString(
      key,
      jsonEncode(messages.map((item) => item.toJson()).toList()),
    );
  }

  Future<void> saveMessages(
    String conversationId,
    List<ChatMessage> messages,
  ) async {
    final database = await _databaseOrNull();
    if (database != null) {
      await database.saveMessages(conversationId, messages);
      return;
    }

    final preferences = await _prefs();
    await preferences.setString(
      '$_messagesPrefix$conversationId',
      jsonEncode(messages.map((message) => message.toJson()).toList()),
    );
  }

  Future<void> deleteConversation(String conversationId) async {
    final database = await _databaseOrNull();
    if (database != null) {
      await database.deleteMessages(conversationId);
      return;
    }

    final preferences = await _prefs();
    await preferences.remove('$_messagesPrefix$conversationId');
  }

  Future<List<ChatSearchResult>> searchMessages(
    String query, {
    int limit = 100,
  }) async {
    final term = query.trim();
    if (term.isEmpty || limit <= 0) return const [];

    final database = await _databaseOrNull();
    if (database != null) {
      return database.searchMessages(term, limit: limit);
    }

    final normalized = term.toLowerCase();
    final conversations = await loadConversations();
    final results = <ChatSearchResult>[];
    for (final conversation in conversations) {
      final messages = await loadMessages(conversation.id);
      for (final message in messages) {
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
      }
    }
    results.sort((a, b) => b.message.sentAt.compareTo(a.message.sentAt));
    if (results.length <= limit) return results;
    return results.sublist(0, limit);
  }

  List<ChatMessage> _decodeMessages(String? raw) {
    if (raw == null || raw.isEmpty) return [];
    try {
      return (jsonDecode(raw) as List<dynamic>)
          .map(
            (item) =>
                ChatMessage.fromJson(Map<String, Object?>.from(item as Map)),
          )
          .toList();
    } on Object {
      return [];
    }
  }

  Future<List<String>> loadMemories({String? characterId}) async {
    final preferences = await _prefs();
    if (characterId == null) {
      return preferences.getStringList(_memoriesKey) ?? const [];
    }
    final key = '${_memoriesKey}_$characterId';
    final scoped = preferences.getStringList(key);
    if (scoped != null) return scoped;

    // Migrate the pre-multi-character memory only into the built-in character.
    // Never copy that legacy relationship history into every new character.
    if (characterId == 'character-lin') {
      final legacy =
          preferences.getStringList(_memoriesKey) ?? const <String>[];
      if (legacy.isNotEmpty) {
        await preferences.setStringList(key, legacy);
        return legacy;
      }
    }
    return const [];
  }

  Future<bool> saveMemories(
    List<String> memories, {
    String? characterId,
  }) async {
    final preferences = await _prefs();
    final normalized = memories
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList();
    final key = characterId == null
        ? _memoriesKey
        : '${_memoriesKey}_$characterId';
    final saved = await preferences.setStringList(key, normalized);
    if (characterId != null) {
      final sources = await loadMemorySources(characterId);
      sources.removeWhere((memory, _) => !normalized.contains(memory));
      await saveMemorySources(characterId, sources);
    }
    return saved;
  }

  Future<bool> addMemory(
    String memory, {
    String? characterId,
    String? sourceConversationId,
  }) async {
    final value = memory.trim();
    if (value.isEmpty) return false;
    final preferences = await _prefs();
    final key = characterId == null
        ? _memoriesKey
        : '${_memoriesKey}_$characterId';
    final memories = preferences.getStringList(key) ?? <String>[];
    if (memories.contains(value)) return false;
    memories.add(value);
    final saved = await preferences.setStringList(key, memories);
    if (saved &&
        characterId != null &&
        sourceConversationId != null &&
        sourceConversationId.trim().isNotEmpty) {
      final sources = await loadMemorySources(characterId);
      sources[value] = sourceConversationId.trim();
      await saveMemorySources(characterId, sources);
    }
    return saved;
  }

  Future<Map<String, String>> loadMemorySources(String characterId) async {
    final preferences = await _prefs();
    final raw = preferences.getString('${_memorySourcesKey}_$characterId');
    if (raw == null || raw.isEmpty) return <String, String>{};
    try {
      final decoded = Map<String, Object?>.from(jsonDecode(raw) as Map);
      return decoded.map((key, value) => MapEntry(key, value?.toString() ?? ''))
        ..removeWhere((_, value) => value.isEmpty);
    } on Object {
      return <String, String>{};
    }
  }

  Future<void> saveMemorySources(
    String characterId,
    Map<String, String> sources,
  ) async {
    final preferences = await _prefs();
    final key = '${_memorySourcesKey}_$characterId';
    final normalized = Map<String, String>.from(sources)
      ..removeWhere(
        (memory, source) => memory.trim().isEmpty || source.trim().isEmpty,
      );
    if (normalized.isEmpty) {
      await preferences.remove(key);
    } else {
      await preferences.setString(key, jsonEncode(normalized));
    }
  }

  Future<String> loadGlobalSystemPrompt() async {
    final preferences = await _prefs();
    return preferences.getString(_globalSystemPromptKey)?.trim() ?? '';
  }

  Future<void> saveGlobalSystemPrompt(String prompt) async {
    final preferences = await _prefs();
    final value = prompt.trim();
    if (value.isEmpty) {
      await preferences.remove(_globalSystemPromptKey);
    } else {
      await preferences.setString(_globalSystemPromptKey, value);
    }
  }

  Future<UserProfile> loadUserProfile() async {
    final preferences = await _prefs();
    final raw = preferences.getString(_userProfileKey);
    if (raw == null || raw.isEmpty) return const UserProfile();
    try {
      return UserProfile.fromJson(
        Map<String, Object?>.from(jsonDecode(raw) as Map),
      );
    } on Object {
      return const UserProfile();
    }
  }

  Future<void> saveUserProfile(UserProfile profile) async {
    final preferences = await _prefs();
    if (profile.isEmpty) {
      await preferences.remove(_userProfileKey);
      return;
    }
    await preferences.setString(_userProfileKey, jsonEncode(profile.toJson()));
  }

  Future<List<String>> loadStylePreferences({String? characterId}) async {
    final preferences = await _prefs();
    final legacy =
        preferences.getStringList(_stylePreferencesKey) ?? const <String>[];
    if (characterId == null || characterId.trim().isEmpty) return legacy;

    final id = characterId.trim();
    final scopedKey = '$_stylePreferencesScopedPrefix$id';
    final scoped = preferences.getStringList(scopedKey);
    if (scoped != null) return scoped;

    final sources = await loadStylePreferenceSources();
    final migrated = <String>[];
    for (final item in legacy) {
      final source = sources[item]?.trim() ?? '';
      if (source.isEmpty) {
        if (id == 'character-lin') migrated.add(item);
        continue;
      }
      final split = source.split('::');
      if (split.length >= 2 && split.last == id) migrated.add(item);
    }
    await preferences.setStringList(scopedKey, migrated);
    return migrated;
  }

  Future<void> saveStylePreferences(
    List<String> items, {
    String? characterId,
  }) async {
    final preferences = await _prefs();
    final normalized = items
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList();
    if (characterId != null && characterId.trim().isNotEmpty) {
      await preferences.setStringList(
        '$_stylePreferencesScopedPrefix${characterId.trim()}',
        normalized,
      );
      return;
    }

    await preferences.setStringList(_stylePreferencesKey, normalized);
    final sources = await loadStylePreferenceSources();
    sources.removeWhere((preference, _) => !normalized.contains(preference));
    await saveStylePreferenceSources(sources);
  }

  Future<bool> addStylePreference(
    String item, {
    String? sourceConversationId,
    String? sourceCharacterId,
  }) async {
    final value = item.trim();
    if (value.isEmpty) return false;

    final id = sourceCharacterId?.trim() ?? '';
    if (id.isNotEmpty) {
      final scoped = await loadStylePreferences(characterId: id);
      if (scoped.contains(value)) return false;
      await saveStylePreferences([...scoped, value], characterId: id);
    }

    final preferences = await _prefs();
    final legacy =
        preferences.getStringList(_stylePreferencesKey) ?? <String>[];
    if (!legacy.contains(value)) {
      legacy.add(value);
      await preferences.setStringList(_stylePreferencesKey, legacy);
    }

    if (sourceConversationId != null &&
        sourceConversationId.trim().isNotEmpty &&
        id.isNotEmpty) {
      final sources = await loadStylePreferenceSources();
      sources[value] = '${sourceConversationId.trim()}::$id';
      await saveStylePreferenceSources(sources);
    }
    return true;
  }

  Future<Map<String, String>> loadStylePreferenceSources() async {
    final preferences = await _prefs();
    final raw = preferences.getString(_stylePreferenceSourcesKey);
    if (raw == null || raw.isEmpty) return <String, String>{};
    try {
      final decoded = Map<String, Object?>.from(jsonDecode(raw) as Map);
      return decoded.map((key, value) => MapEntry(key, value?.toString() ?? ''))
        ..removeWhere((_, value) => value.isEmpty);
    } on Object {
      return <String, String>{};
    }
  }

  Future<void> saveStylePreferenceSources(Map<String, String> sources) async {
    final preferences = await _prefs();
    final normalized = Map<String, String>.from(sources)
      ..removeWhere(
        (preference, source) =>
            preference.trim().isEmpty || source.trim().isEmpty,
      );
    if (normalized.isEmpty) {
      await preferences.remove(_stylePreferenceSourcesKey);
    } else {
      await preferences.setString(
        _stylePreferenceSourcesKey,
        jsonEncode(normalized),
      );
    }
  }

  Future<List<WorldBookEntry>> loadWorldBooks() async {
    final preferences = await _prefs();
    final raw = preferences.getString(_worldBooksKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      return (jsonDecode(raw) as List<dynamic>)
          .map(
            (item) =>
                WorldBookEntry.fromJson(Map<String, Object?>.from(item as Map)),
          )
          .where((item) => item.content.trim().isNotEmpty)
          .toList();
    } on Object {
      return const [];
    }
  }

  Future<void> saveWorldBooks(List<WorldBookEntry> entries) async {
    final preferences = await _prefs();
    await preferences.setString(
      _worldBooksKey,
      jsonEncode(entries.map((entry) => entry.toJson()).toList()),
    );
  }

  Future<String> loadCharacterMood([String? characterId]) async {
    final preferences = await _prefs();
    if (characterId != null) {
      final key = '${_characterMoodKey}_$characterId';
      final value = preferences.getString(key)?.trim();
      if (value != null && value.isNotEmpty) return value;
      if (characterId == 'character-lin') {
        final legacy = preferences.getString(_characterMoodKey)?.trim() ?? '';
        if (legacy.isNotEmpty) {
          await preferences.setString(key, legacy);
          return legacy;
        }
      }
      return '';
    }
    return preferences.getString(_characterMoodKey)?.trim() ?? '';
  }

  Future<void> saveCharacterMood(String mood, [String? characterId]) async {
    final preferences = await _prefs();
    final value = mood.trim();
    final key = characterId == null
        ? _characterMoodKey
        : '${_characterMoodKey}_$characterId';
    if (value.isEmpty) {
      await preferences.remove(key);
    } else {
      await preferences.setString(key, value);
    }
  }

  Future<String> loadCharacterMoodSource(String characterId) async {
    final preferences = await _prefs();
    return preferences
            .getString('${_characterMoodSourceKey}_$characterId')
            ?.trim() ??
        '';
  }

  Future<void> saveCharacterMoodSource(
    String characterId,
    String conversationId,
  ) async {
    final preferences = await _prefs();
    final key = '${_characterMoodSourceKey}_$characterId';
    final value = conversationId.trim();
    if (value.isEmpty) {
      await preferences.remove(key);
    } else {
      await preferences.setString(key, value);
    }
  }

  Future<String> loadCharacterStatusSource(String characterId) async {
    final preferences = await _prefs();
    return preferences
            .getString('${_characterStatusSourceKey}_$characterId')
            ?.trim() ??
        '';
  }

  Future<void> saveCharacterStatusSource(
    String characterId,
    String conversationId,
  ) async {
    final preferences = await _prefs();
    final key = '${_characterStatusSourceKey}_$characterId';
    final value = conversationId.trim();
    if (value.isEmpty) {
      await preferences.remove(key);
    } else {
      await preferences.setString(key, value);
    }
  }

  Future<void> clearConversationDerivedState({
    required String conversationId,
    required Iterable<String> characterIds,
  }) async {
    final ids = characterIds.where((id) => id.trim().isNotEmpty).toSet();

    final preferenceSources = await loadStylePreferenceSources();
    final preferencesToRemove = preferenceSources.entries
        .where((entry) => entry.value.startsWith('$conversationId::'))
        .map((entry) => entry.key)
        .toSet();
    if (preferencesToRemove.isNotEmpty) {
      for (final characterId in ids) {
        final scoped = await loadStylePreferences(characterId: characterId);
        final next = scoped
            .where((item) => !preferencesToRemove.contains(item))
            .toList();
        if (next.length != scoped.length) {
          await saveStylePreferences(next, characterId: characterId);
        }
      }
      final preferences = await loadStylePreferences();
      await saveStylePreferences(
        preferences
            .where((item) => !preferencesToRemove.contains(item))
            .toList(),
      );
    }

    if (ids.isEmpty) return;
    final characters = await loadCharacters();
    var charactersChanged = false;

    for (final characterId in ids) {
      final sources = await loadMemorySources(characterId);
      final memoriesToRemove = sources.entries
          .where((entry) => entry.value == conversationId)
          .map((entry) => entry.key)
          .toSet();
      if (memoriesToRemove.isNotEmpty) {
        final memories = await loadMemories(characterId: characterId);
        await saveMemories(
          memories.where((item) => !memoriesToRemove.contains(item)).toList(),
          characterId: characterId,
        );
        sources.removeWhere((_, source) => source == conversationId);
        await saveMemorySources(characterId, sources);
      }

      if (await loadCharacterMoodSource(characterId) == conversationId) {
        await saveCharacterMood('', characterId);
        await saveCharacterMoodSource(characterId, '');
      }
      if (await loadCharacterStatusSource(characterId) == conversationId) {
        final index = characters.indexWhere((item) => item.id == characterId);
        if (index >= 0 && characters[index].status.isNotEmpty) {
          characters[index] = characters[index].copyWith(status: '');
          charactersChanged = true;
        }
        await saveCharacterStatusSource(characterId, '');
      }
    }

    if (charactersChanged) await saveCharacters(characters);
  }

  Future<void> clearCharacterState(String characterId) async {
    final preferenceSources = await loadStylePreferenceSources();
    final preferencesToRemove = preferenceSources.entries
        .where((entry) => entry.value.endsWith('::$characterId'))
        .map((entry) => entry.key)
        .toSet();
    if (preferencesToRemove.isNotEmpty) {
      final preferences = await loadStylePreferences();
      await saveStylePreferences(
        preferences
            .where((item) => !preferencesToRemove.contains(item))
            .toList(),
      );
    }

    final preferences = await _prefs();
    await preferences.remove('${_memoriesKey}_$characterId');
    await preferences.remove('${_memorySourcesKey}_$characterId');
    await preferences.remove('$_stylePreferencesScopedPrefix$characterId');
    await preferences.remove('${_characterMoodKey}_$characterId');
    await preferences.remove('${_characterMoodSourceKey}_$characterId');
    await preferences.remove('${_characterStatusSourceKey}_$characterId');
    if (characterId == 'character-lin') {
      await preferences.remove(_memoriesKey);
      await preferences.remove(_characterMoodKey);
    }
  }

  Future<DateTime> loadFirstMetAt() async {
    final preferences = await _prefs();
    final saved = preferences.getString(_firstMetAtKey);
    if (saved != null) {
      final parsed = DateTime.tryParse(saved);
      if (parsed != null) return parsed;
    }
    final now = DateTime.now();
    await preferences.setString(_firstMetAtKey, now.toIso8601String());
    return now;
  }

  Future<bool> loadReasoningExpanded() async {
    final preferences = await _prefs();
    return preferences.getBool(_reasoningExpandedKey) ?? true;
  }

  Future<void> saveReasoningExpanded(bool value) async {
    final preferences = await _prefs();
    await preferences.setBool(_reasoningExpandedKey, value);
  }

  Future<int> loadContextTokenBudget() async {
    final preferences = await _prefs();
    return preferences.getInt(_contextTokenBudgetKey) ?? 32000;
  }

  Future<void> saveContextTokenBudget(int value) async {
    final preferences = await _prefs();
    await preferences.setInt(_contextTokenBudgetKey, value);
  }

  Future<bool> loadAutoMemoryEnabled() async {
    final preferences = await _prefs();
    return preferences.getBool(_autoMemoryEnabledKey) ?? true;
  }

  Future<void> saveAutoMemoryEnabled(bool value) async {
    final preferences = await _prefs();
    await preferences.setBool(_autoMemoryEnabledKey, value);
  }

  Future<List<CharacterProfile>> loadCharacters() async {
    final preferences = await _prefs();
    final savedCharacters = preferences.getString(_charactersKey);
    if (savedCharacters != null && savedCharacters.isNotEmpty) {
      try {
        final characters = (jsonDecode(savedCharacters) as List<dynamic>)
            .map(
              (item) => CharacterProfile.fromJson(
                Map<String, Object?>.from(item as Map),
              ),
            )
            .toList();
        if (characters.isNotEmpty) return characters;
      } on Object {
        // Migrate the legacy profile below.
      }
    }
    final raw = preferences.getString(_profileKey);
    CharacterProfile profile;
    if (raw != null && raw.isNotEmpty) {
      try {
        profile = CharacterProfile.fromJson(
          Map<String, Object?>.from(jsonDecode(raw) as Map),
        );
        await saveCharacters([profile]);
        return [profile];
      } on Object {
        // Fall through to the built-in character.
      }
    }
    profile = CharacterProfile.lin(await loadFirstMetAt());
    await saveCharacters([profile]);
    return [profile];
  }

  Future<void> saveCharacters(List<CharacterProfile> characters) async {
    final preferences = await _prefs();
    await preferences.setString(
      _charactersKey,
      jsonEncode(characters.map((item) => item.toJson()).toList()),
    );
  }

  Future<String?> loadSelectedCharacterId() async {
    final preferences = await _prefs();
    return preferences.getString(_selectedCharacterKey);
  }

  Future<void> saveSelectedCharacterId(String id) async {
    final preferences = await _prefs();
    await preferences.setString(_selectedCharacterKey, id);
  }

  Future<CharacterProfile> loadProfile() async {
    final characters = await loadCharacters();
    final selectedId = await loadSelectedCharacterId();
    return characters.firstWhere(
      (item) => item.id == selectedId,
      orElse: () => characters.first,
    );
  }

  Future<void> saveProfile(CharacterProfile profile) async {
    final preferences = await _prefs();
    await preferences.setString(_profileKey, jsonEncode(profile.toJson()));
    final characters = await loadCharacters();
    final index = characters.indexWhere((item) => item.id == profile.id);
    if (index < 0) {
      characters.add(profile);
    } else {
      characters[index] = profile;
    }
    await saveCharacters(characters);
    await saveSelectedCharacterId(profile.id);
  }
}
