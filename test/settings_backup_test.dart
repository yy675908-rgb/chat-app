import 'dart:convert';

import 'package:character_chat_app/models/character_profile.dart';
import 'package:character_chat_app/models/provider_profile.dart';
import 'package:character_chat_app/models/user_profile.dart';
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
    final original = CharacterProfile.newCharacter(
      DateTime.utc(2026, 8, 20),
    ).copyWith(userIntimacy: 82);

    final restored = CharacterProfile.fromJson(original.toJson());
    final tooHigh = restored.copyWith(userIntimacy: 130);

    expect(restored.userIntimacy, 82);
    expect(tooHigh.userIntimacy, 100);
    expect(
      CharacterProfile.fromJson({
        ...original.toJson(),
        'userIntimacy': -20,
      }).userIntimacy,
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

    final raw = await BackupService(
      chatStore: chatStore,
      providerStore: providerStore,
    ).createBackup(scope: BackupScope.configuration);
    final data = jsonDecode(raw) as Map<String, dynamic>;

    expect(data['version'], 2);
    expect(data['scope'], 'configuration');
    expect(data.containsKey('conversations'), isFalse);
    expect(data.containsKey('messages'), isFalse);
    expect(data.containsKey('characterMoods'), isFalse);
    expect(data['userProfile']['name'], '小满');
    expect(
      data['providers'][0]['modelSystemPrompts']['deepseek-chat'],
      '控制在三句话内。',
    );

    await BackupService(
      chatStore: chatStore,
      providerStore: providerStore,
    ).restoreBackup(raw);
    final afterRestore = await chatStore.loadConversations();
    expect(afterRestore.map((item) => item.id), existing.map((item) => item.id));
  });
}
