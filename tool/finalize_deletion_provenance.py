from pathlib import Path


def replace_once(path: str, old: str, new: str, label: str) -> None:
    file = Path(path)
    text = file.read_text()
    if old not in text:
        raise SystemExit(f'missing anchor: {label} in {path}')
    file.write_text(text.replace(old, new, 1))


# ---- ChatStore: track auto-derived response preferences too ----
replace_once(
    'lib/services/chat_store.dart',
    "  static const _stylePreferencesKey = 'style_preferences_v1';\n",
    "  static const _stylePreferencesKey = 'style_preferences_v1';\n  static const _stylePreferenceSourcesKey = 'style_preference_sources_v1';\n",
    'style source key',
)

old_style = """  Future<void> saveStylePreferences(List<String> items) async {
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
    final items = preferences.getStringList(_stylePreferencesKey) ?? <String>[];
    if (items.contains(value)) return false;
    items.add(value);
    await preferences.setStringList(_stylePreferencesKey, items);
    return true;
  }
"""
new_style = """  Future<void> saveStylePreferences(List<String> items) async {
    final preferences = await SharedPreferences.getInstance();
    final normalized = items
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList();
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
    final preferences = await SharedPreferences.getInstance();
    final items = preferences.getStringList(_stylePreferencesKey) ?? <String>[];
    if (items.contains(value)) return false;
    items.add(value);
    final saved = await preferences.setStringList(_stylePreferencesKey, items);
    if (saved &&
        sourceConversationId != null &&
        sourceConversationId.trim().isNotEmpty &&
        sourceCharacterId != null &&
        sourceCharacterId.trim().isNotEmpty) {
      final sources = await loadStylePreferenceSources();
      sources[value] =
          '${sourceConversationId.trim()}::${sourceCharacterId.trim()}';
      await saveStylePreferenceSources(sources);
    }
    return saved;
  }

  Future<Map<String, String>> loadStylePreferenceSources() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_stylePreferenceSourcesKey);
    if (raw == null || raw.isEmpty) return <String, String>{};
    try {
      final decoded = Map<String, Object?>.from(jsonDecode(raw) as Map);
      return decoded.map(
        (key, value) => MapEntry(key, value?.toString() ?? ''),
      )..removeWhere((_, value) => value.isEmpty);
    } on Object {
      return <String, String>{};
    }
  }

  Future<void> saveStylePreferenceSources(Map<String, String> sources) async {
    final preferences = await SharedPreferences.getInstance();
    final normalized = Map<String, String>.from(sources)
      ..removeWhere((preference, source) =>
          preference.trim().isEmpty || source.trim().isEmpty);
    if (normalized.isEmpty) {
      await preferences.remove(_stylePreferenceSourcesKey);
    } else {
      await preferences.setString(
        _stylePreferenceSourcesKey,
        jsonEncode(normalized),
      );
    }
  }
"""
replace_once('lib/services/chat_store.dart', old_style, new_style, 'style preference methods')

old_clear_header = """  Future<void> clearConversationDerivedState({
    required String conversationId,
    required Iterable<String> characterIds,
  }) async {
    final ids = characterIds.where((id) => id.trim().isNotEmpty).toSet();
    if (ids.isEmpty) return;
    final characters = await loadCharacters();
    var charactersChanged = false;

    for (final characterId in ids) {
"""
new_clear_header = """  Future<void> clearConversationDerivedState({
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
      final preferences = await loadStylePreferences();
      await saveStylePreferences(
        preferences.where((item) => !preferencesToRemove.contains(item)).toList(),
      );
    }

    if (ids.isEmpty) return;
    final characters = await loadCharacters();
    var charactersChanged = false;

    for (final characterId in ids) {
"""
replace_once('lib/services/chat_store.dart', old_clear_header, new_clear_header, 'conversation preference cleanup')

old_character_clear = """  Future<void> clearCharacterState(String characterId) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove('${_memoriesKey}_$characterId');
"""
new_character_clear = """  Future<void> clearCharacterState(String characterId) async {
    final preferenceSources = await loadStylePreferenceSources();
    final preferencesToRemove = preferenceSources.entries
        .where((entry) => entry.value.endsWith('::$characterId'))
        .map((entry) => entry.key)
        .toSet();
    if (preferencesToRemove.isNotEmpty) {
      final preferences = await loadStylePreferences();
      await saveStylePreferences(
        preferences.where((item) => !preferencesToRemove.contains(item)).toList(),
      );
    }

    final preferences = await SharedPreferences.getInstance();
    await preferences.remove('${_memoriesKey}_$characterId');
"""
replace_once('lib/services/chat_store.dart', old_character_clear, new_character_clear, 'character preference cleanup')

# ---- ChatScreen: auto style preference provenance + deleted conversation cleanup during character deletion ----
old_extract_start = """  Future<void> _extractStylePreference(
    int messageIndex,
    ChatMessage likedReply,
  ) async {
    var userContext = '';
"""
new_extract_start = """  Future<void> _extractStylePreference(
    int messageIndex,
    ChatMessage likedReply,
  ) async {
    final sourceConversationId = _currentConversation?.id ?? '';
    final sourceCharacterId = likedReply.speakerCharacterId.isEmpty
        ? _profile.id
        : likedReply.speakerCharacterId;
    if (sourceConversationId.isEmpty || sourceCharacterId.isEmpty) return;
    var userContext = '';
"""
replace_once('lib/screens/chat_screen.dart', old_extract_start, new_extract_start, 'preference provenance capture')

replace_once(
    'lib/screens/chat_screen.dart',
    "      final rule = _cleanPreference(raw);\n      if (rule.isEmpty) return;\n      final added = await _chatStore.addStylePreference(rule);",
    "      final rule = _cleanPreference(raw);\n      if (rule.isEmpty) return;\n      final conversations = await _chatStore.loadConversations();\n      if (!conversations.any((item) => item.id == sourceConversationId)) return;\n      final added = await _chatStore.addStylePreference(\n        rule,\n        sourceConversationId: sourceConversationId,\n        sourceCharacterId: sourceCharacterId,\n      );",
    'preference provenance save',
)

old_deleted_loop = """    for (final conversationId in deletedConversationIds) {
      await _chatStore.deleteConversation(conversationId);
    }
"""
new_deleted_loop = """    for (final conversationId in deletedConversationIds) {
      final original = allConversations.firstWhere(
        (item) => item.id == conversationId,
      );
      await _chatStore.clearConversationDerivedState(
        conversationId: conversationId,
        characterIds: original.isGroup
            ? original.participantIds
            : <String>[original.characterId],
      );
      await _chatStore.deleteConversation(conversationId);
    }
"""
replace_once('lib/screens/chat_screen.dart', old_deleted_loop, new_deleted_loop, 'character deletion conversation cleanup')

# ---- BackupService: preserve deletion provenance through backup/restore ----
path = Path('lib/services/backup_service.dart')
text = path.read_text()
text = text.replace("      'version': 3,", "      'version': 4,", 1)
text = text.replace(
    "        (version != 1 && version != 2 && version != 3)) {",
    "        (version != 1 && version != 2 && version != 3 && version != 4)) {",
    1,
)
old_maps = """    final characterMemories = <String, List<String>>{};
    final characterMoods = <String, String>{};
    for (final character in characters) {
      final memories = await _chatStore.loadMemories(characterId: character.id);
      characterMemories[character.id] = memories;
      if (scope == BackupScope.full) {
        final mood = await _chatStore.loadCharacterMood(character.id);
        characterMoods[character.id] = mood;
      }
    }
"""
new_maps = """    final characterMemories = <String, List<String>>{};
    final characterMemorySources = <String, Map<String, String>>{};
    final characterMoods = <String, String>{};
    final characterMoodSources = <String, String>{};
    final characterStatusSources = <String, String>{};
    for (final character in characters) {
      final memories = await _chatStore.loadMemories(characterId: character.id);
      characterMemories[character.id] = memories;
      characterMemorySources[character.id] =
          await _chatStore.loadMemorySources(character.id);
      final statusSource = await _chatStore.loadCharacterStatusSource(character.id);
      if (statusSource.isNotEmpty) {
        characterStatusSources[character.id] = statusSource;
      }
      if (scope == BackupScope.full) {
        final mood = await _chatStore.loadCharacterMood(character.id);
        characterMoods[character.id] = mood;
        final moodSource = await _chatStore.loadCharacterMoodSource(character.id);
        if (moodSource.isNotEmpty) {
          characterMoodSources[character.id] = moodSource;
        }
      }
    }
"""
if old_maps not in text:
    raise SystemExit('missing backup map anchor')
text = text.replace(old_maps, new_maps, 1)
text = text.replace(
    "      'characterMemories': characterMemories,\n      'stylePreferences': await _chatStore.loadStylePreferences(),",
    "      'characterMemories': characterMemories,\n      'characterMemorySources': characterMemorySources,\n      'stylePreferences': await _chatStore.loadStylePreferences(),\n      'stylePreferenceSources': await _chatStore.loadStylePreferenceSources(),\n      'characterStatusSources': characterStatusSources,",
    1,
)
text = text.replace(
    "        'characterMoods': characterMoods,",
    "        'characterMoods': characterMoods,\n        'characterMoodSources': characterMoodSources,",
    1,
)

restore_anchor = """    await _chatStore.saveStylePreferences(
      (data['stylePreferences'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .toList(),
    );
"""
restore_replacement = """    await _chatStore.saveStylePreferences(
      (data['stylePreferences'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .toList(),
    );

    final restoredCharacters = await _chatStore.loadCharacters();
    for (final character in restoredCharacters) {
      await _chatStore.saveMemorySources(character.id, <String, String>{});
      await _chatStore.saveCharacterStatusSource(character.id, '');
      if (data['scope'] == BackupScope.full.name) {
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
"""
if restore_anchor not in text:
    raise SystemExit('missing backup restore style anchor')
text = text.replace(restore_anchor, restore_replacement, 1)

moods_anchor = """    final moodsRaw = data['characterMoods'];
    if (moodsRaw is Map) {
      for (final entry in moodsRaw.entries) {
        await _chatStore.saveCharacterMood(
          entry.value?.toString() ?? '',
          entry.key.toString(),
        );
      }
    }
"""
moods_replacement = moods_anchor + """    final moodSourcesRaw = data['characterMoodSources'];
    if (moodSourcesRaw is Map) {
      for (final entry in moodSourcesRaw.entries) {
        await _chatStore.saveCharacterMoodSource(
          entry.key.toString(),
          entry.value?.toString() ?? '',
        );
      }
    }
"""
if moods_anchor not in text:
    raise SystemExit('missing backup mood anchor')
text = text.replace(moods_anchor, moods_replacement, 1)
path.write_text(text)

# ---- Tests ----
path = Path('test/settings_backup_test.dart')
text = path.read_text()
text = text.replace("expect(data['version'], 3);", "expect(data['version'], 4);", 1)
text = text.replace(
    "    await chatStore.saveMemories(\n      ['只属于当前角色的记忆'],\n      characterId: selectedCharacter.id,\n    );",
    "    await chatStore.addMemory(\n      '只属于当前角色的记忆',\n      characterId: selectedCharacter.id,\n      sourceConversationId: existing.first.id,\n    );\n    await chatStore.addStylePreference(\n      '当用户疲惫时：回应简短一些',\n      sourceConversationId: existing.first.id,\n      sourceCharacterId: selectedCharacter.id,\n    );\n    await chatStore.saveCharacterStatusSource(\n      selectedCharacter.id,\n      existing.first.id,\n    );",
    1,
)
text = text.replace(
    "    expect(data['autoMemoryEnabled'], isFalse);",
    "    expect(data['autoMemoryEnabled'], isFalse);\n    expect(\n      data['characterMemorySources'][selectedCharacter.id]\n          ['只属于当前角色的记忆'],\n      existing.first.id,\n    );\n    expect(\n      data['stylePreferenceSources']['当用户疲惫时：回应简短一些'],\n      '${existing.first.id}::${selectedCharacter.id}',\n    );\n    expect(\n      data['characterStatusSources'][selectedCharacter.id],\n      existing.first.id,\n    );",
    1,
)
text = text.replace(
    "    await chatStore.saveAutoMemoryEnabled(true);",
    "    await chatStore.saveAutoMemoryEnabled(true);\n    await chatStore.saveMemorySources(selectedCharacter.id, {});\n    await chatStore.saveStylePreferenceSources({});\n    await chatStore.saveCharacterStatusSource(selectedCharacter.id, '');",
    1,
)
text = text.replace(
    "    expect(await chatStore.loadAutoMemoryEnabled(), isFalse);",
    "    expect(await chatStore.loadAutoMemoryEnabled(), isFalse);\n    expect(\n      (await chatStore.loadMemorySources(selectedCharacter.id))\n          ['只属于当前角色的记忆'],\n      existing.first.id,\n    );\n    expect(\n      (await chatStore.loadStylePreferenceSources())\n          ['当用户疲惫时：回应简短一些'],\n      '${existing.first.id}::${selectedCharacter.id}',\n    );\n    expect(\n      await chatStore.loadCharacterStatusSource(selectedCharacter.id),\n      existing.first.id,\n    );",
    1,
)
path.write_text(text)

path = Path('test/chat_store_conversation_scope_test.dart')
text = path.read_text()
anchor = """  test('deleting a character clears scoped relationship state completely',
      () async {
"""
new_test = """  test('conversation deletion also clears auto-derived response preferences',
      () async {
    final store = ChatStore();
    await store.addStylePreference(
      '来自将删除对话的偏好',
      sourceConversationId: 'conversation-a',
      sourceCharacterId: 'character-a',
    );
    await store.addStylePreference(
      '来自其他对话的偏好',
      sourceConversationId: 'conversation-b',
      sourceCharacterId: 'character-a',
    );
    await store.saveStylePreferences([
      ...await store.loadStylePreferences(),
      '手动添加的偏好',
    ]);

    await store.clearConversationDerivedState(
      conversationId: 'conversation-a',
      characterIds: const ['character-a'],
    );

    expect(
      await store.loadStylePreferences(),
      ['来自其他对话的偏好', '手动添加的偏好'],
    );
  });

""" + anchor
if anchor not in text:
    raise SystemExit('missing preference deletion test anchor')
path.write_text(text.replace(anchor, new_test, 1))
