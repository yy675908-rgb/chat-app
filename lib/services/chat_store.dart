import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/character_profile.dart';
import '../models/chat_message.dart';
import '../models/conversation.dart';

class ChatStore {
  static const _legacyMessagesKey = 'chat_messages_v1';
  static const _conversationsKey = 'conversations_v2';
  static const _messagesPrefix = 'conversation_messages_v2_';
  static const _memoriesKey = 'relationship_memories_v1';
  static const _stylePreferencesKey = 'style_preferences_v1';
  static const _characterMoodKey = 'character_mood_v1';
  static const _firstMetAtKey = 'first_met_at_v1';
  static const _profileKey = 'character_profile_v1';

  Future<List<Conversation>> loadConversations() async {
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
        return conversations;
      } on Object {
        // Create a fresh conversation below.
      }
    }

    final now = DateTime.now();
    final first = Conversation(
      id: 'conversation-${now.microsecondsSinceEpoch}',
      title: '第一次见面',
      createdAt: now,
      updatedAt: now,
    );
    final legacyMessages = _decodeMessages(
      preferences.getString(_legacyMessagesKey),
    );
    await saveConversations([first]);
    if (legacyMessages.isNotEmpty) {
      await saveMessages(first.id, legacyMessages);
    }
    return [first];
  }

  Future<void> saveConversations(List<Conversation> conversations) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _conversationsKey,
      jsonEncode(
        conversations.map((conversation) => conversation.toJson()).toList(),
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

  Future<String> loadCharacterMood() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getString(_characterMoodKey)?.trim() ?? '';
  }

  Future<void> saveCharacterMood(String mood) async {
    final preferences = await SharedPreferences.getInstance();
    final value = mood.trim();
    if (value.isEmpty) {
      await preferences.remove(_characterMoodKey);
    } else {
      await preferences.setString(_characterMoodKey, value);
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

  Future<CharacterProfile> loadProfile() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_profileKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        return CharacterProfile.fromJson(
          Map<String, Object?>.from(jsonDecode(raw) as Map),
        );
      } on Object {
        // Fall through to the built-in character.
      }
    }
    return CharacterProfile.lin(await loadFirstMetAt());
  }

  Future<void> saveProfile(CharacterProfile profile) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_profileKey, jsonEncode(profile.toJson()));
  }
}
