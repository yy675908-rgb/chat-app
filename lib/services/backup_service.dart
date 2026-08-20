import 'dart:convert';

import '../models/chat_message.dart';
import '../models/character_profile.dart';
import '../models/conversation.dart';
import '../models/provider_profile.dart';
import '../models/world_book_entry.dart';
import '../models/user_profile.dart';
import 'chat_store.dart';
import 'provider_store.dart';

enum BackupScope { full, configuration }

class BackupService {
  BackupService({
    ChatStore? chatStore,
    ProviderStore? providerStore,
  })  : _chatStore = chatStore ?? ChatStore(),
        _providerStore = providerStore ?? ProviderStore();

  final ChatStore _chatStore;
  final ProviderStore _providerStore;

  Future<String> createBackup({BackupScope scope = BackupScope.full}) async {
    final profile = await _chatStore.loadProfile();
    final characters = await _chatStore.loadCharacters();
    final conversations = scope == BackupScope.full
        ? await _chatStore.loadConversations()
        : <Conversation>[];
    final messages = <String, Object?>{};
    if (scope == BackupScope.full) {
      for (final conversation in conversations) {
        final items = await _chatStore.loadMessages(conversation.id);
        messages[conversation.id] =
            items.map((message) => message.toJson()).toList();
      }
    }
    final providers = await _providerStore.loadProviders();
    final characterMoods = <String, String>{};
    if (scope == BackupScope.full) {
      for (final character in characters) {
        final mood = await _chatStore.loadCharacterMood(character.id);
        if (mood.isNotEmpty) characterMoods[character.id] = mood;
      }
    }
    final data = <String, Object?>{
      'format': 'character-chat-backup',
      'version': 2,
      'scope': scope.name,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'profile': profile.toJson(),
      'characters': characters.map((item) => item.toJson()).toList(),
      'selectedCharacterId': await _chatStore.loadSelectedCharacterId(),
      'memories': await _chatStore.loadMemories(),
      'stylePreferences': await _chatStore.loadStylePreferences(),
      'worldBooks': (await _chatStore.loadWorldBooks())
          .map((entry) => entry.toJson())
          .toList(),
      'reasoningExpanded': await _chatStore.loadReasoningExpanded(),
      'contextTokenBudget': await _chatStore.loadContextTokenBudget(),
      'globalSystemPrompt': await _chatStore.loadGlobalSystemPrompt(),
      'userProfile': (await _chatStore.loadUserProfile()).toJson(),
      'providers': providers.map((provider) => provider.toJson()).toList(),
      'selectedProviderId': await _providerStore.loadSelectedProviderId(),
      'apiKeysIncluded': false,
    };
    if (scope == BackupScope.full) {
      data.addAll({
        'conversations': conversations
            .map((conversation) => conversation.toJson())
            .toList(),
        'messages': messages,
        'characterMood': await _chatStore.loadCharacterMood(),
        'characterMoods': characterMoods,
      });
    }
    return const JsonEncoder.withIndent('  ').convert(data);
  }

  Future<void> restoreBackup(String raw) async {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) throw const FormatException('备份文件格式不正确');
    final data = Map<String, Object?>.from(decoded);
    final version = data['version'];
    if (data['format'] != 'character-chat-backup' ||
        (version != 1 && version != 2)) {
      throw const FormatException('不是受支持的聊天备份文件');
    }

    final characters = (data['characters'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map(
          (item) => CharacterProfile.fromJson(
            Map<String, Object?>.from(item),
          ),
        )
        .toList();
    if (characters.isNotEmpty) {
      await _chatStore.saveCharacters(characters);
      final selectedId = data['selectedCharacterId'] as String?;
      await _chatStore.saveSelectedCharacterId(
        characters.any((item) => item.id == selectedId)
            ? selectedId!
            : characters.first.id,
      );
    } else if (data['profile'] case final Map profileRaw) {
      await _chatStore.saveProfile(
        CharacterProfile.fromJson(Map<String, Object?>.from(profileRaw)),
      );
    }

    final hasConversationData = data.containsKey('conversations');
    if (data['scope'] == BackupScope.full.name && !hasConversationData) {
      throw const FormatException('完整备份缺少对话数据');
    }
    final conversations = (data['conversations'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map(
          (item) => Conversation.fromJson(Map<String, Object?>.from(item)),
        )
        .toList();
    if (hasConversationData) {
      if (conversations.isEmpty) {
        throw const FormatException('备份中的对话数据无效');
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
    final moodsRaw = data['characterMoods'];
    if (moodsRaw is Map) {
      for (final entry in moodsRaw.entries) {
        await _chatStore.saveCharacterMood(
          entry.value?.toString() ?? '',
          entry.key.toString(),
        );
      }
    }
    if (data.containsKey('characterMood')) {
      await _chatStore.saveCharacterMood(
        data['characterMood']?.toString() ?? '',
      );
    }
    await _chatStore.saveReasoningExpanded(
      data['reasoningExpanded'] as bool? ?? true,
    );
    await _chatStore.saveContextTokenBudget(
      data['contextTokenBudget'] as int? ?? 32000,
    );
    await _chatStore.saveGlobalSystemPrompt(
      data['globalSystemPrompt']?.toString() ?? '',
    );
    if (data['userProfile'] case final Map userRaw) {
      await _chatStore.saveUserProfile(
        UserProfile.fromJson(Map<String, Object?>.from(userRaw)),
      );
    }

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
