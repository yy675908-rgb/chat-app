import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/chat_message.dart';

class ChatStore {
  static const _messagesKey = 'chat_messages_v1';
  static const _memoriesKey = 'relationship_memories_v1';
  static const _firstMetAtKey = 'first_met_at_v1';

  Future<List<ChatMessage>> loadMessages() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_messagesKey);
    if (raw == null || raw.isEmpty) return const [];

    try {
      final items = jsonDecode(raw) as List<dynamic>;
      return items
          .map(
            (item) => ChatMessage.fromJson(
              Map<String, Object?>.from(item as Map),
            ),
          )
          .toList();
    } on FormatException {
      return const [];
    }
  }

  Future<void> saveMessages(List<ChatMessage> messages) async {
    final preferences = await SharedPreferences.getInstance();
    final raw = jsonEncode(messages.map((message) => message.toJson()).toList());
    await preferences.setString(_messagesKey, raw);
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
}
