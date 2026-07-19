import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/character_profile.dart';
import '../models/chat_message.dart';
import '../models/conversation.dart';
import '../models/world_book_entry.dart';

class ChatStore {
  static const _legacyMessagesKey = 'chat_messages_v1';
  static const _conversationsKey = 'conversations_v2';
  static const _messagesPrefix = 'conversation_messages_v2_';
  static const _memoriesKey = 'relationship_memories_v1';
  static const _stylePreferencesKey = 'style_preferences_v1';
  static const _characterMoodKey = 'character_mood_v1';
  static const _worldBooksKey = 'world_books_v1';
  static const _firstMetAtKey = 'first_met_at_v1';
  static const _profileKey = 'character_profile_v1';
  static const _charactersKey = 'character_profiles_v2';
  static const _selectedCharacterKey = 'selected_character_v2';
  static const _reasoningExpandedKey = 'reasoning_expanded_v1';
  static const _contextTokenBudgetKey = 'context_token_budget_v1';

  Future<List<Conversation>> loadConversations({String? characterId}) async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_conversationsKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final conversations = (jsonDecode(raw) as List<dynamic>)
            .map(
              (item) => Conversation.fromJson(
                Map<String, Object?>.from(item as Map),
              ),
            )
            .toList();
        conversations.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        if (characterId == null) return conversations;
        final matching = conversations
            .where((item) => item.characterId == characterId)
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
    final legacyMessages = raw == null &&
            (characterId == null || characterId == 'character-lin')
        ? _decodeMessages(preferences.getString(_legacyMessagesKey))
        : <ChatMessage>[];
    await saveConversations([first], characterId: characterId);
    if (legacyMessages.isNotEmpty) {
      await saveMessages(first.id, legacyMessages);
    }
    return [first];
  }

  Future<void> saveConversations(
    List<Conversation> conversations, {
    String? characterId,
  }) async {
    final preferences = await SharedPreferences.getInstance();
    var items = conversations;
    if (characterId != null) {
      final raw = preferences.getString(_conversationsKey);
      final existing = <Conversation>[];
      if (raw != null && raw.isNotEmpty) {
        try {
          existing.addAll(
            (jsonDecode(raw) as List<dynamic>).map(
              (item) => Conversation.fromJson(
                Map<String, Object?>.from(item as Map),
              ),
            ),
          );
        } on Object {
          // Replace malformed data with the active character's conversations.
        }
      }
      items = [
        ...existing.where((item) => item.characterId != characterId),
        ...conversations,
      ];
    }
    await preferences.setString(
      _conversationsKey,
      jsonEncode(
        items.map((conversation) => conversation.toJson()).toList(),
      ),
    );
  }

  Future<List<ChatMessage>> loadMessages(String conversationId) async {
    final preferences = await SharedPreferences.getInstance();
    return _decodeMessages(
      preferences.getString('$_messagesPrefix$conversationId'),
    );
  }

  Future<void> saveMessages(
    String conversationId,
    List<ChatMessage> messages,
  ) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      '$_messagesPrefix$conversationId',
      jsonEncode(messages.map((message) => message.toJson()).toList()),
    );
  }

  Future<void> deleteConversation(String conversationId) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove('$_messagesPrefix$conversationId');
  }

  List<ChatMessage> _decodeMessages(String? raw) {
    if (raw == null || raw.isEmpty) return [];
    try {
      return (jsonDecode(raw) as List<dynamic>)
          .map(
            (item) => ChatMessage.fromJson(
              Map<String, Object?>.from(item as Map),
            ),
          )
          .toList();
    } on Object {
      return [];
    }
  }

  Future<List<String>> loadMemories() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getStringList(_memoriesKey) ?? const [];
  }

  Future<void> saveMemories(List<String> memories) async {
    final preferences = await SharedPreferences.getInstance();
    final normalized = memories
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList();
    await preferences.setStringList(_memoriesKey, normalized);
  }

  Future<void> addMemory(String memory) async {
    final preferences = await SharedPreferences.getInstance();
    final memories = preferences.getStringList(_memoriesKey) ?? <String>[];
    if (!memories.contains(memory)) memories.add(memory);
    await preferences.setStringList(_memoriesKey, memories);
  }

  Future<List<String>> loadStylePreferences() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getStringList(_stylePreferencesKey) ?? const [];
  }

  Future<void> saveStylePreferences(List<String> items) async {
    final preferences = await SharedPreferences.getInstance();
    final normalized = items
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList();
    await preferences.setStringList(_stylePreferencesKey, normalized);
  }

  Future<bool> addStylePreference(String item) async {
    final value = item.trim();
    if (value.isEmpty) return false;
    final preferences = await SharedPreferences.getInstance();
    final items =
        preferences.getStringList(_stylePreferencesKey) ?? <String>[];
    if (items.contains(value)) return false;
    items.add(value);
    await preferences.setStringList(_stylePreferencesKey, items);
    return true;
  }

  Future<List<WorldBookEntry>> loadWorldBooks() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_worldBooksKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      return (jsonDecode(raw) as List<dynamic>)
          .map(
            (item) => WorldBookEntry.fromJson(
              Map<String, Object?>.from(item as Map),
            ),
          )
          .where((item) => item.content.trim().isNotEmpty)
          .toList();
    } on Object {
      return const [];
    }
  }

  Future<void> saveWorldBooks(List<WorldBookEntry> entries) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _worldBooksKey,
      jsonEncode(entries.map((entry) => entry.toJson()).toList()),
    );
  }

  Future<String> loadCharacterMood([String? characterId]) async {
    final preferences = await SharedPreferences.getInstance();
    if (characterId != null) {
      final value = preferences
          .getString('${_characterMoodKey}_$characterId')
          ?.trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return preferences.getString(_characterMoodKey)?.trim() ?? '';
  }

  Future<void> saveCharacterMood(String mood, [String? characterId]) async {
    final preferences = await SharedPreferences.getInstance();
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

  Future<DateTime> loadFirstMetAt() async {
    final preferences = await SharedPreferences.getInstance();
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
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(_reasoningExpandedKey) ?? true;
  }

  Future<void> saveReasoningExpanded(bool value) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_reasoningExpandedKey, value);
  }

  Future<int> loadContextTokenBudget() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getInt(_contextTokenBudgetKey) ?? 32000;
  }

  Future<void> saveContextTokenBudget(int value) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setInt(_contextTokenBudgetKey, value);
  }

  Future<List<CharacterProfile>> loadCharacters() async {
    final preferences = await SharedPreferences.getInstance();
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
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _charactersKey,
      jsonEncode(characters.map((item) => item.toJson()).toList()),
    );
  }

  Future<String?> loadSelectedCharacterId() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getString(_selectedCharacterKey);
  }

  Future<void> saveSelectedCharacterId(String id) async {
    final preferences = await SharedPreferences.getInstance();
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
    final preferences = await SharedPreferences.getInstance();
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
