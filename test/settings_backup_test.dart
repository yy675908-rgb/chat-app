import 'dart:convert';

import 'package:character_chat_app/models/character_profile.dart';
import 'package:character_chat_app/models/provider_profile.dart';
import 'package:character_chat_app/models/user_profile.dart';
import 'package:character_chat_app/services/backup_migrator.dart';
import 'package:character_chat_app/services/backup_service.dart';
import 'package:character_chat_app/services/chat_store.dart';
import 'package:character_chat_app/services/provider_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('provider keeps a separate system prompt for every model', () {
    const original = ProviderProfile(
      id: 'deepseek',
      name: 'DeepSeek',
      protocol: ProviderProtocol.openAiCompatible,
      baseUrl: 'https://api.deepseek.com/v1',
      models: ['deepseek-chat', 'deepseek-reasoner'],
      selectedModel: 'deepseek-chat',
      modelSystemPrompts: {
        'deepseek-chat': '简短回复。',
        'deepseek-reasoner': '不要展示推理。',
      },
    );

    final restored = ProviderProfile.fromJson(original.toJson());

    expect(restored.systemPromptForModel('deepseek-chat'), '简短回复。');
    expect(restored.systemPromptForModel('deepseek-reasoner'), '不要展示推理。');
  });

  test('character intimacy survives JSON and stays within range', () {
    final original = CharacterProfile.newCharacter(DateTime.utc(2026, 8, 20))
        .copyWith(userIntimacy: 82);

    final restored = CharacterProfile.fromJson(original.toJson());
    final tooHigh = restored.copyWith(userIntimacy: 130);

    expect(restored.userIntimacy, 82);
    expect(tooHigh.userIntimacy, 100);
    expect(
      CharacterProfile.fromJson({...original.toJson(), 'userIntimacy': -20})
          .userIntimacy,
      0,
    );
  });

  test('legacy character defaults intimacy without losing settings', () {
    final restored = CharacterProfile.fromJson({
      'id': 'legacy',
      'name': '旧角色',
      'status': '',
      'firstMetAt': '2026-01-01T00:00:00.000Z',
      'greeting': '你好',
      'systemPrompt': '保持原设定。',
    });

    expect(restored.userIntimacy, 50);
    expect(restored.systemPrompt, '保持原设定。');
  });

  test('user profile survives JSON round trip', () {
    const original = UserProfile(
      name: '小满',
      gender: '女',
      description: '医生，与角色是旧识。',
    );

    final restored = UserProfile.fromJson(original.toJson());

    expect(restored.name, original.name);
    expect(restored.gender, original.gender);
    expect(restored.description, original.description);
  });

  test('legacy v1 backup migrates to the current structure', () {
    final profile = CharacterProfile.newCharacter(DateTime.utc(2026, 1, 2));
    final migrated = BackupMigrator.migrate({
      'format': 'character-chat-backup',
      'version': 1,
      'profile': profile.toJson(),
      'memories': ['记得雨夜的约定'],
      'stylePreferences': ['回复简短'],
    });

    expect(migrated['version'], BackupMigrator.currentVersion);
    expect(migrated['scope'], 'configuration');
    expect(migrated['selectedCharacterId'], profile.id);
    expect((migrated['characters'] as List).length, 1);
    expect(
      (migrated['characterMemories'] as Map)[profile.id],
      ['记得雨夜的约定'],
    );
    expect(migrated['characterMemorySources'], isEmpty);
    expect(migrated['stylePreferenceSources'], isEmpty);
    expect(migrated['characterStatusSources'], isEmpty);
    expect(migrated['apiKeysIncluded'], isFalse);
    expect(migrated.containsKey('userProfile'), isFalse);
    expect(migrated.containsKey('providers'), isFalse);
  });

  test('full backup with zero conversations is accepted', () async {
    final chatStore = ChatStore();
    final providerStore = ProviderStore();
    await providerStore.saveProviders([
      const ProviderProfile(
        id: 'test',
        name: 'Test',
        protocol: ProviderProtocol.openAiCompatible,
        baseUrl: 'https://example.com/v1',
        models: ['demo-model'],
        selectedModel: 'demo-model',
      ),
    ]);
    final profile = await chatStore.loadProfile();
    final raw = jsonEncode({
      'format': 'character-chat-backup',
      'version': 4,
      'scope': 'full',
      'profile': profile.toJson(),
      'characters': [profile.toJson()],
      'selectedCharacterId': profile.id,
      'conversations': <Object?>[],
      'messages': <String, Object?>{},
    });

    await expectLater(
      BackupService(
        chatStore: chatStore,
        providerStore: providerStore,
      ).restoreBackup(raw),
      completes,
    );
  });

  test('configuration backup excludes chat history', () async {
    final chatStore = ChatStore();
    final providerStore = ProviderStore();
    await chatStore.saveUserProfile(
      const UserProfile(name: '小满', gender: '女', description: '医生'),
    );
    await providerStore.saveProviders([
      const ProviderProfile(
        id: 'deepseek',
        name: 'DeepSeek',
        protocol: ProviderProtocol.openAiCompatible,
        baseUrl: 'https://api.deepseek.com/v1',
        models: ['deepseek-chat'],
        selectedModel: 'deepseek-chat',
        modelSystemPrompts: {'deepseek-chat': '控制在三句话内。'},
      ),
    ]);
    await providerStore.saveSelectedProviderId('deepseek');
    final existing = await chatStore.loadConversations();
    final selectedCharacter = await chatStore.loadProfile();
    await chatStore.addMemory(
      '只属于当前角色的记忆',
      characterId: selectedCharacter.id,
      sourceConversationId: existing.first.id,
    );
    await chatStore.addStylePreference(
      '当用户疲惫时：回应简短一些',
      sourceConversationId: existing.first.id,
      sourceCharacterId: selectedCharacter.id,
    );
    await chatStore.saveCharacterStatusSource(
      selectedCharacter.id,
      existing.first.id,
    );
    await chatStore.saveAutoMemoryEnabled(false);

    final raw = await BackupService(
      chatStore: chatStore,
      providerStore: providerStore,
    ).createBackup(scope: BackupScope.configuration);
    final data = jsonDecode(raw) as Map<String, dynamic>;

    expect(data['version'], 4);
    expect(data['scope'], 'configuration');
    expect(data.containsKey('conversations'), isFalse);
    expect(data.containsKey('messages'), isFalse);
    expect(data.containsKey('characterMoods'), isFalse);
    expect(data['userProfile']['name'], '小满');
    expect(data['autoMemoryEnabled'], isFalse);
    expect(
      data['characterMemorySources'][selectedCharacter.id]['只属于当前角色的记忆'],
      existing.first.id,
    );
    expect(
      data['stylePreferenceSources']['当用户疲惫时：回应简短一些'],
      '${existing.first.id}::${selectedCharacter.id}',
    );
    expect(
      data['characterStatusSources'][selectedCharacter.id],
      existing.first.id,
    );
    expect(data['characterMemories'][selectedCharacter.id], ['只属于当前角色的记忆']);
    expect(
      data['providers'][0]['modelSystemPrompts']['deepseek-chat'],
      '控制在三句话内。',
    );

    await chatStore.saveMemories(['临时覆盖'], characterId: selectedCharacter.id);
    await chatStore.saveAutoMemoryEnabled(true);
    await chatStore.saveMemorySources(selectedCharacter.id, {});
    await chatStore.saveStylePreferenceSources({});
    await chatStore.saveCharacterStatusSource(selectedCharacter.id, '');
    await BackupService(
      chatStore: chatStore,
      providerStore: providerStore,
    ).restoreBackup(raw);
    final afterRestore = await chatStore.loadConversations();
    expect(
      afterRestore.map((item) => item.id),
      existing.map((item) => item.id),
    );
    expect(await chatStore.loadMemories(characterId: selectedCharacter.id), [
      '只属于当前角色的记忆',
    ]);
    expect(await chatStore.loadAutoMemoryEnabled(), isFalse);
    expect(
      (await chatStore.loadMemorySources(selectedCharacter.id))['只属于当前角色的记忆'],
      existing.first.id,
    );
    expect(
      (await chatStore.loadStylePreferenceSources())['当用户疲惫时：回应简短一些'],
      '${existing.first.id}::${selectedCharacter.id}',
    );
    expect(
      await chatStore.loadCharacterStatusSource(selectedCharacter.id),
      existing.first.id,
    );
  });
}
