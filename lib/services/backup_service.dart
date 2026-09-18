import 'dart:convert';

import '../models/chat_message.dart';
import '../models/character_profile.dart';
import '../models/conversation.dart';
import '../models/provider_profile.dart';
import '../models/proactive_message_settings.dart';
import '../models/world_book_entry.dart';
import '../models/user_profile.dart';
import 'backup_migrator.dart';
import 'chat_store.dart';
import 'proactive_message_store.dart';
import 'provider_store.dart';

enum BackupScope { full, configuration }

class BackupService {
  BackupService({
    ChatStore? chatStore,
    ProviderStore? providerStore,
    ProactiveMessageStore? proactiveMessageStore,
  }) : _chatStore = chatStore ?? ChatStore(),
       _providerStore = providerStore ?? ProviderStore(),
       _proactiveMessageStore =
           proactiveMessageStore ?? const ProactiveMessageStore();

  final ChatStore _chatStore;
  final ProviderStore _providerStore;
  final ProactiveMessageStore _proactiveMessageStore;

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
        messages[conversation.id] = items
            .map((message) => message.toJson())
            .toList();
      }
    }
    final providers = await _providerStore.loadProviders();
    final characterMemories = <String, List<String>>{};
    final characterMemorySources = <String, Map<String, String>>{};
    final characterMoods = <String, String>{};
    final characterMoodSources = <String, String>{};
    final characterStatusSources = <String, String>{};
    for (final character in characters) {
      final memories = await _chatStore.loadMemories(characterId: character.id);
      characterMemories[character.id] = memories;
      characterMemorySources[character.id] = await _chatStore.loadMemorySources(
        character.id,
      );
      final statusSource = await _chatStore.loadCharacterStatusSource(
        character.id,
      );
      if (statusSource.isNotEmpty) {
        characterStatusSources[character.id] = statusSource;
      }
      if (scope == BackupScope.full) {
        final mood = await _chatStore.loadCharacterMood(character.id);
        characterMoods[character.id] = mood;
        final moodSource = await _chatStore.loadCharacterMoodSource(
          character.id,
        );
        if (moodSource.isNotEmpty) {
          characterMoodSources[character.id] = moodSource;
        }
      }
    }
    final data = <String, Object?>{
      'format': 'character-chat-backup',
      'version': BackupMigrator.currentVersion,
      'scope': scope.name,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'profile': profile.toJson(),
      'characters': characters.map((item) => item.toJson()).toList(),
      'selectedCharacterId': await _chatStore.loadSelectedCharacterId(),
      'memories': characterMemories[profile.id] ?? const <String>[],
      'characterMemories': characterMemories,
      'characterMemorySources': characterMemorySources,
      'stylePreferences': await _chatStore.loadStylePreferences(),
      'stylePreferenceSources': await _chatStore.loadStylePreferenceSources(),
      'characterStatusSources': characterStatusSources,
      'worldBooks': (await _chatStore.loadWorldBooks())
          .map((entry) => entry.toJson())
          .toList(),
      'reasoningExpanded': await _chatStore.loadReasoningExpanded(),
      'contextTokenBudget': await _chatStore.loadContextTokenBudget(),
      'autoMemoryEnabled': await _chatStore.loadAutoMemoryEnabled(),
      'proactiveMessageSettings':
          (await _proactiveMessageStore.loadSettings()).toJson(),
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
        'characterMoodSources': characterMoodSources,
      });
    }
    return const JsonEncoder.withIndent('  ').convert(data);
  }

  Future<void> restoreBackup(String raw) async {
    final data = _parseAndValidate(raw);

    // Capture the current state only after the incoming file has passed all
    // structural checks. If any write fails, restore this snapshot.
    final rollbackRaw = await createBackup(scope: BackupScope.full);
    final rollbackData = _parseAndValidate(rollbackRaw);
    try {
      await _restoreValidated(data);
    } on Object catch (error) {
      try {
        await _restoreValidated(rollbackData);
      } on Object catch (rollbackError) {
        throw StateError(
          '恢复失败，自动回滚也失败。原错误：$error；回滚错误：$rollbackError',
        );
      }
      throw StateError('恢复失败，已自动恢复到操作前状态：$error');
    }
  }

  Map<String, Object?> _parseAndValidate(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) throw const FormatException('备份文件格式不正确');
    final source = Map<String, Object?>.from(decoded);
    if (source['format'] != 'character-chat-backup') {
      throw const FormatException('不是受支持的聊天备份文件');
    }
    final data = BackupMigrator.migrate(source);

    final charactersRaw = data['characters'];
    if (charactersRaw != null && charactersRaw is! List) {
      throw const FormatException('备份中的角色数据无效');
    }
    for (final item in charactersRaw as List<dynamic>? ?? const []) {
      if (item is! Map) throw const FormatException('备份中的角色数据无效');
      CharacterProfile.fromJson(Map<String, Object?>.from(item));
    }
    if (data['profile'] case final Map profileRaw) {
      CharacterProfile.fromJson(Map<String, Object?>.from(profileRaw));
    } else if ((charactersRaw ?? const []).isEmpty) {
      throw const FormatException('备份缺少角色数据');
    }

    final hasConversationData = data.containsKey('conversations');
    final explicitlyFull = data['scope'] == BackupScope.full.name;
    if (explicitlyFull && !hasConversationData) {
      throw const FormatException('完整备份缺少对话数据');
    }
    if (hasConversationData) {
      final rawConversations = data['conversations'];
      if (rawConversations is! List) {
        throw const FormatException('备份中的对话数据无效');
      }
      final ids = <String>{};
      for (final item in rawConversations) {
        if (item is! Map) throw const FormatException('备份中的对话数据无效');
        final conversation = Conversation.fromJson(
          Map<String, Object?>.from(item),
        );
        if (!ids.add(conversation.id)) {
          throw const FormatException('备份中存在重复的对话 ID');
        }
      }
      final messagesRaw = data['messages'];
      if (messagesRaw is! Map) {
        throw const FormatException('完整备份缺少消息数据');
      }
      for (final entry in messagesRaw.entries) {
        if (entry.value is! List) {
          throw const FormatException('备份中的消息数据无效');
        }
        for (final item in entry.value as List) {
          if (item is! Map) throw const FormatException('备份中的消息数据无效');
          ChatMessage.fromJson(Map<String, Object?>.from(item));
        }
      }
    }

    void requireMapOrNull(String key) {
      final value = data[key];
      if (value != null && value is! Map) {
        throw FormatException('备份中的 $key 数据无效');
      }
    }

    void requireListOrNull(String key) {
      final value = data[key];
      if (value != null && value is! List) {
        throw FormatException('备份中的 $key 数据无效');
      }
    }

    requireMapOrNull('characterMemories');
    requireMapOrNull('characterMemorySources');
    requireMapOrNull('stylePreferenceSources');
    requireMapOrNull('characterStatusSources');
    requireMapOrNull('characterMoods');
    requireMapOrNull('characterMoodSources');
    requireListOrNull('memories');
    requireListOrNull('stylePreferences');
    requireListOrNull('worldBooks');
    requireListOrNull('providers');

    for (final item in data['worldBooks'] as List<dynamic>? ?? const []) {
      if (item is! Map) throw const FormatException('备份中的世界书数据无效');
      WorldBookEntry.fromJson(Map<String, Object?>.from(item));
    }
    for (final item in data['providers'] as List<dynamic>? ?? const []) {
      if (item is! Map) throw const FormatException('备份中的供应商数据无效');
      ProviderProfile.fromJson(Map<String, Object?>.from(item));
    }
    if (data['userProfile'] case final Map userRaw) {
      UserProfile.fromJson(Map<String, Object?>.from(userRaw));
    }
    final tokenBudget = data['contextTokenBudget'];
    if (tokenBudget != null && (tokenBudget is! int || tokenBudget < 2048)) {
      throw const FormatException('备份中的上下文预算无效');
    }
    if (data['reasoningExpanded'] != null && data['reasoningExpanded'] is! bool) {
      throw const FormatException('备份中的显示设置无效');
    }
    if (data['autoMemoryEnabled'] != null && data['autoMemoryEnabled'] is! bool) {
      throw const FormatException('备份中的自动记忆设置无效');
    }
    final proactiveSettings = data['proactiveMessageSettings'];
    if (proactiveSettings != null) {
      if (proactiveSettings is! Map) {
        throw const FormatException('备份中的主动消息设置无效');
      }
      ProactiveMessageSettings.fromJson(
        Map<String, Object?>.from(proactiveSettings),
      );
    }
    return data;
  }

  Future<void> _restoreValidated(Map<String, Object?> data) async {
    final characters = (data['characters'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map(
          (item) => CharacterProfile.fromJson(Map<String, Object?>.from(item)),
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
    final conversations = (data['conversations'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((item) => Conversation.fromJson(Map<String, Object?>.from(item)))
        .toList();
    if (hasConversationData) {
      await _chatStore.saveConversations(conversations);

      final messagesRaw = data['messages'];
      if (messagesRaw is Map) {
        for (final conversation in conversations) {
          final list = messagesRaw[conversation.id];
          if (list is! List) continue;
          final messages = list
              .whereType<Map>()
              .map(
                (item) => ChatMessage.fromJson(Map<String, Object?>.from(item)),
              )
              .toList();
          await _chatStore.saveMessages(conversation.id, messages);
        }
      }
    }

    final characterMemoriesRaw = data['characterMemories'];
    if (characterMemoriesRaw is Map) {
      for (final entry in characterMemoriesRaw.entries) {
        final values = entry.value;
        if (values is! List) continue;
        await _chatStore.saveMemories(
          values.map((item) => item.toString()).toList(),
          characterId: entry.key.toString(),
        );
      }
    } else {
      final selectedCharacterId = await _chatStore.loadSelectedCharacterId();
      final legacyMemories = (data['memories'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .toList();
      if (selectedCharacterId == null) {
        await _chatStore.saveMemories(legacyMemories);
      } else {
        await _chatStore.saveMemories(
          legacyMemories,
          characterId: selectedCharacterId,
        );
      }
    }
    await _chatStore.saveStylePreferences(
      (data['stylePreferences'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .toList(),
    );

    final restoredCharacters = await _chatStore.loadCharacters();
    for (final character in restoredCharacters) {
      await _chatStore.saveMemorySources(character.id, <String, String>{});
      await _chatStore.saveCharacterStatusSource(character.id, '');
      if (data['scope'] == BackupScope.full.name || hasConversationData) {
        await _chatStore.saveCharacterMoodSource(character.id, '');
      }
    }
    await _chatStore.saveStylePreferenceSources(<String, String>{});

    final memorySourcesRaw = data['characterMemorySources'];
    if (memorySourcesRaw is Map) {
      for (final entry in memorySourcesRaw.entries) {
        final values = entry.value;
        if (values is! Map) continue;
        await _chatStore.saveMemorySources(
          entry.key.toString(),
          values.map(
            (key, value) => MapEntry(key.toString(), value.toString()),
          ),
        );
      }
    }
    final styleSourcesRaw = data['stylePreferenceSources'];
    if (styleSourcesRaw is Map) {
      await _chatStore.saveStylePreferenceSources(
        styleSourcesRaw.map(
          (key, value) => MapEntry(key.toString(), value.toString()),
        ),
      );
    }
    final statusSourcesRaw = data['characterStatusSources'];
    if (statusSourcesRaw is Map) {
      for (final entry in statusSourcesRaw.entries) {
        await _chatStore.saveCharacterStatusSource(
          entry.key.toString(),
          entry.value?.toString() ?? '',
        );
      }
    }
    await _chatStore.saveWorldBooks(
      (data['worldBooks'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map(
            (item) => WorldBookEntry.fromJson(Map<String, Object?>.from(item)),
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
    final moodSourcesRaw = data['characterMoodSources'];
    if (moodSourcesRaw is Map) {
      for (final entry in moodSourcesRaw.entries) {
        await _chatStore.saveCharacterMoodSource(
          entry.key.toString(),
          entry.value?.toString() ?? '',
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
    await _chatStore.saveAutoMemoryEnabled(
      data['autoMemoryEnabled'] as bool? ?? true,
    );
    if (data['proactiveMessageSettings'] case final Map proactiveRaw) {
      await _proactiveMessageStore.saveSettings(
        ProactiveMessageSettings.fromJson(
          Map<String, Object?>.from(proactiveRaw),
        ),
      );
      await _proactiveMessageStore.clearPlan();
    }
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
          (item) => ProviderProfile.fromJson(Map<String, Object?>.from(item)),
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
