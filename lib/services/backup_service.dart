import 'dart:convert';

import '../models/chat_message.dart';
import '../models/character_profile.dart';
import '../models/conversation.dart';
import '../models/provider_profile.dart';
import '../models/world_book_entry.dart';
import 'chat_store.dart';
import 'provider_store.dart';

class BackupService {
  BackupService({
    ChatStore? chatStore,
    ProviderStore? providerStore,
  })  : _chatStore = chatStore ?? ChatStore(),
        _providerStore = providerStore ?? ProviderStore();

  final ChatStore _chatStore;
  final ProviderStore _providerStore;

  Future<String> createBackup() async {
    final profile = await _chatStore.loadProfile();
    final conversations = await _chatStore.loadConversations();
    final messages = <String, Object?>{};
    for (final conversation in conversations) {
      final items = await _chatStore.loadMessages(conversation.id);
      messages[conversation.id] =
          items.map((message) => message.toJson()).toList();
    }
    final providers = await _providerStore.loadProviders();
    return const JsonEncoder.withIndent('  ').convert({
      'format': 'character-chat-backup',
      'version': 1,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'profile': profile.toJson(),
      'conversations':
          conversations.map((conversation) => conversation.toJson()).toList(),
      'messages': messages,
      'memories': await _chatStore.loadMemories(),
      'stylePreferences': await _chatStore.loadStylePreferences(),
      'worldBooks': (await _chatStore.loadWorldBooks())
          .map((entry) => entry.toJson())
          .toList(),
      'characterMood': await _chatStore.loadCharacterMood(),
      'reasoningExpanded': await _chatStore.loadReasoningExpanded(),
      'contextTokenBudget': await _chatStore.loadContextTokenBudget(),
      'providers': providers.map((provider) => provider.toJson()).toList(),
      'selectedProviderId': await _providerStore.loadSelectedProviderId(),
      'apiKeysIncluded': false,
    });
  }

  Future<void> restoreBackup(String raw) async {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) throw const FormatException('备份文件格式不正确');
    final data = Map<String, Object?>.from(decoded);
    if (data['format'] != 'character-chat-backup' || data['version'] != 1) {
      throw const FormatException('不是受支持的聊天备份文件');
    }

    final profileRaw = data['profile'];
    if (profileRaw is Map) {
      await _chatStore.saveProfile(
        CharacterProfile.fromJson(Map<String, Object?>.from(profileRaw)),
      );
    }

    final conversations = (data['conversations'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map(
          (item) => Conversation.fromJson(Map<String, Object?>.from(item)),
        )
        .toList();
    if (conversations.isEmpty) {
      throw const FormatException('备份中没有有效对话');
    }
    await _chatStore.saveConversations(conversations);

    final messagesRaw = data['messages'];
    if (messagesRaw is Map) {
      for (final conversation in conversations) {
        final list = messagesRaw[conversation.id];
        if (list is! List) continue;
        final messages = list
            .whereType<Map>()
            .map(
              (item) => ChatMessage.fromJson(
                Map<String, Object?>.from(item),
              ),
            )
            .toList();
        await _chatStore.saveMessages(conversation.id, messages);
      }
    }

    await _chatStore.saveMemories(
      (data['memories'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .toList(),
    );
    await _chatStore.saveStylePreferences(
      (data['stylePreferences'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .toList(),
    );
    await _chatStore.saveWorldBooks(
      (data['worldBooks'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map(
            (item) => WorldBookEntry.fromJson(
              Map<String, Object?>.from(item),
            ),
          )
          .toList(),
    );
    await _chatStore.saveCharacterMood(
      data['characterMood']?.toString() ?? '',
    );
    await _chatStore.saveReasoningExpanded(
      data['reasoningExpanded'] as bool? ?? true,
    );
    await _chatStore.saveContextTokenBudget(
      data['contextTokenBudget'] as int? ?? 32000,
    );

    final providers = (data['providers'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map(
          (item) => ProviderProfile.fromJson(
            Map<String, Object?>.from(item),
          ),
        )
        .toList();
    if (providers.isNotEmpty) {
      await _providerStore.saveProviders(providers);
      final selectedId = data['selectedProviderId']?.toString();
      final validSelected = providers.any((item) => item.id == selectedId);
      await _providerStore.saveSelectedProviderId(
        validSelected ? selectedId! : providers.first.id,
      );
    }
  }
}
