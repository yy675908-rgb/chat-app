from pathlib import Path


def replace_once(path: str, old: str, new: str, label: str) -> None:
    file = Path(path)
    text = file.read_text()
    if old not in text:
        raise SystemExit(f'missing anchor: {label} in {path}')
    file.write_text(text.replace(old, new, 1))


# --- chat_store.dart: provenance-aware memories and generated state cleanup ---
replace_once(
    'lib/services/chat_store.dart',
    "  static const _memoriesKey = 'relationship_memories_v1';\n  static const _stylePreferencesKey = 'style_preferences_v1';\n  static const _characterMoodKey = 'character_mood_v1';",
    "  static const _memoriesKey = 'relationship_memories_v1';\n  static const _memorySourcesKey = 'relationship_memory_sources_v1';\n  static const _stylePreferencesKey = 'style_preferences_v1';\n  static const _characterMoodKey = 'character_mood_v1';\n  static const _characterMoodSourceKey = 'character_mood_source_v1';\n  static const _characterStatusSourceKey = 'character_status_source_v1';",
    'store keys',
)

old_memory_block = """  Future<bool> saveMemories(
    List<String> memories, {
    String? characterId,
  }) async {
    final preferences = await SharedPreferences.getInstance();
    final normalized = memories
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList();
    final key = characterId == null
        ? _memoriesKey
        : '${_memoriesKey}_$characterId';
    return preferences.setStringList(key, normalized);
  }

  Future<bool> addMemory(
    String memory, {
    String? characterId,
  }) async {
    final value = memory.trim();
    if (value.isEmpty) return false;
    final preferences = await SharedPreferences.getInstance();
    final key = characterId == null
        ? _memoriesKey
        : '${_memoriesKey}_$characterId';
    final memories = preferences.getStringList(key) ?? <String>[];
    if (memories.contains(value)) return false;
    memories.add(value);
    return preferences.setStringList(key, memories);
  }
"""
new_memory_block = """  Future<bool> saveMemories(
    List<String> memories, {
    String? characterId,
  }) async {
    final preferences = await SharedPreferences.getInstance();
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
    final preferences = await SharedPreferences.getInstance();
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
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString('${_memorySourcesKey}_$characterId');
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

  Future<void> saveMemorySources(
    String characterId,
    Map<String, String> sources,
  ) async {
    final preferences = await SharedPreferences.getInstance();
    final key = '${_memorySourcesKey}_$characterId';
    final normalized = Map<String, String>.from(sources)
      ..removeWhere((memory, source) =>
          memory.trim().isEmpty || source.trim().isEmpty);
    if (normalized.isEmpty) {
      await preferences.remove(key);
    } else {
      await preferences.setString(key, jsonEncode(normalized));
    }
  }
"""
replace_once('lib/services/chat_store.dart', old_memory_block, new_memory_block, 'memory block')

old_clear = """  Future<void> clearCharacterState(String characterId) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove('${_memoriesKey}_$characterId');
    await preferences.remove('${_characterMoodKey}_$characterId');
  }
"""
new_clear = """  Future<String> loadCharacterMoodSource(String characterId) async {
    final preferences = await SharedPreferences.getInstance();
    return preferences
            .getString('${_characterMoodSourceKey}_$characterId')
            ?.trim() ??
        '';
  }

  Future<void> saveCharacterMoodSource(
    String characterId,
    String conversationId,
  ) async {
    final preferences = await SharedPreferences.getInstance();
    final key = '${_characterMoodSourceKey}_$characterId';
    final value = conversationId.trim();
    if (value.isEmpty) {
      await preferences.remove(key);
    } else {
      await preferences.setString(key, value);
    }
  }

  Future<String> loadCharacterStatusSource(String characterId) async {
    final preferences = await SharedPreferences.getInstance();
    return preferences
            .getString('${_characterStatusSourceKey}_$characterId')
            ?.trim() ??
        '';
  }

  Future<void> saveCharacterStatusSource(
    String characterId,
    String conversationId,
  ) async {
    final preferences = await SharedPreferences.getInstance();
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
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove('${_memoriesKey}_$characterId');
    await preferences.remove('${_memorySourcesKey}_$characterId');
    await preferences.remove('${_characterMoodKey}_$characterId');
    await preferences.remove('${_characterMoodSourceKey}_$characterId');
    await preferences.remove('${_characterStatusSourceKey}_$characterId');
    if (characterId == 'character-lin') {
      await preferences.remove(_memoriesKey);
      await preferences.remove(_characterMoodKey);
    }
  }
"""
replace_once('lib/services/chat_store.dart', old_clear, new_clear, 'clear state block')

# --- app_settings_screen.dart: slower, user-confirmed memory extraction ---
replace_once(
    'lib/screens/app_settings_screen.dart',
    "                '每约 8 个用户回合检查一次明确的长期信息，并按角色分别保存；会产生少量额外模型调用。',",
    "                '每约 24 个用户回合检查一次值得长期保留的信息；提取后会先弹窗，可编辑并确认后才写入。会产生少量额外模型调用。',",
    'auto memory settings copy',
)

# --- character_screen.dart: status is no longer user editable ---
replace_once(
    'lib/screens/character_screen.dart',
    "  late final TextEditingController _statusController;\n",
    "",
    'remove status controller field',
)
replace_once(
    'lib/screens/character_screen.dart',
    "    _statusController = TextEditingController(text: widget.profile.status);\n",
    "",
    'remove status controller init',
)
replace_once(
    'lib/screens/character_screen.dart',
    "        status: _statusController.text.trim(),\n",
    "",
    'preserve generated status on save',
)
replace_once(
    'lib/screens/character_screen.dart',
    "    _statusController.dispose();\n",
    "",
    'remove status controller dispose',
)
old_status_field = """          const SizedBox(height: 10),
          TextField(
            controller: _statusController,
            maxLength: 40,
            decoration: const InputDecoration(
              labelText: '当前状态',
              hintText: '例如：刚下班、在生闷气、今晚很闲',
              helperText: '显示在角色名字下方，也会影响群聊中的接话判断',
            ),
          ),
"""
new_status_field = """          const SizedBox(height: 10),
          Card(
            elevation: 0,
            child: ListTile(
              leading: const Icon(Icons.auto_awesome_outlined),
              title: const Text('当前状态由角色自行生成'),
              subtitle: Text(
                widget.profile.status.trim().isEmpty
                    ? '角色会根据实际对话自然更新，不需要手动填写'
                    : widget.profile.status.trim(),
              ),
            ),
          ),
"""
replace_once('lib/screens/character_screen.dart', old_status_field, new_status_field, 'status field')

# --- chat_screen.dart: deletion cleanup ---
old_delete_start = """    if (confirmed != true) return;
    await _chatStore.deleteConversation(conversation.id);
    final remaining = _conversations
"""
new_delete_start = """    if (confirmed != true) return;
    final affectedCharacterIds = conversation.isGroup
        ? conversation.participantIds
        : <String>[conversation.characterId];
    await _chatStore.clearConversationDerivedState(
      conversationId: conversation.id,
      characterIds: affectedCharacterIds,
    );
    await _reloadRelationshipState();
    await _chatStore.deleteConversation(conversation.id);
    final remaining = _conversations
"""
replace_once('lib/screens/chat_screen.dart', old_delete_start, new_delete_start, 'conversation delete cleanup')

insert_before_rename = """  Future<void> _renameConversation(Conversation conversation) async {
"""
reload_helper = """  Future<void> _reloadRelationshipState() async {
    final characters = await _chatStore.loadCharacters();
    final memories = <String, List<String>>{};
    final moods = <String, String>{};
    for (final character in characters) {
      memories[character.id] = await _chatStore.loadMemories(
        characterId: character.id,
      );
      final mood = await _chatStore.loadCharacterMood(character.id);
      if (mood.isNotEmpty) moods[character.id] = mood;
    }
    if (!mounted) return;
    final active = characters.firstWhere(
      (item) => item.id == _profile.id,
      orElse: () => characters.first,
    );
    setState(() {
      _characters = characters;
      _profile = active;
      _characterMemories = memories;
      _memories = memories[active.id] ?? const <String>[];
      _characterMoods = moods;
      _characterMood = moods[active.id] ?? '';
    });
  }

  Future<void> _renameConversation(Conversation conversation) async {
"""
replace_once('lib/screens/chat_screen.dart', insert_before_rename, reload_helper, 'relationship reload helper')

old_group_cleanup = """    for (final group in updatedGroups) {
      final messages = await _chatStore.loadMessages(group.id);
      final rosterIndex = messages.indexWhere(
        (message) =>
            message.author == MessageAuthor.system &&
            message.text.startsWith('群聊成员：'),
      );
      if (rosterIndex >= 0) {
        final names = group.participantIds
            .map((id) => remainingById[id]?.name ?? '已删除角色')
            .join('、');
        messages[rosterIndex] =
            messages[rosterIndex].editText('群聊成员：$names');
        await _chatStore.saveMessages(group.id, messages);
      }
    }
"""
new_group_cleanup = """    for (final group in updatedGroups) {
      final messages = await _chatStore.loadMessages(group.id);
      final removedMessageIds = messages
          .where((message) => message.speakerCharacterId == character.id)
          .map((message) => message.id)
          .toSet();
      final cleanedMessages = messages
          .where((message) => message.speakerCharacterId != character.id)
          .map((message) {
            if (removedMessageIds.isEmpty || message.branchBindings.isEmpty) {
              return message;
            }
            final bindings = Map<String, String>.from(message.branchBindings)
              ..removeWhere((messageId, _) =>
                  removedMessageIds.contains(messageId));
            return bindings.length == message.branchBindings.length
                ? message
                : message.copyWith(branchBindings: bindings);
          })
          .toList();
      final rosterIndex = cleanedMessages.indexWhere(
        (message) =>
            message.author == MessageAuthor.system &&
            message.text.startsWith('群聊成员：'),
      );
      if (rosterIndex >= 0) {
        final names = group.participantIds
            .map((id) => remainingById[id]?.name ?? '已删除角色')
            .join('、');
        cleanedMessages[rosterIndex] = cleanedMessages[rosterIndex]
            .editText('群聊成员：$names');
      }
      await _chatStore.saveMessages(group.id, cleanedMessages);
    }
"""
replace_once('lib/screens/chat_screen.dart', old_group_cleanup, new_group_cleanup, 'purge deleted character from groups')

# --- chat_screen.dart: memory extraction becomes slower and requires editable approval ---
start = Path('lib/screens/chat_screen.dart').read_text().index('  Future<void> _maybeExtractRelationshipMemory({')
end = Path('lib/screens/chat_screen.dart').read_text().index('  List<ChatMessage> _messagesWithinBudget(', start)
text = Path('lib/screens/chat_screen.dart').read_text()
old_extract = text[start:end]
new_extract = """  Future<void> _maybeExtractRelationshipMemory({
    required CharacterProfile character,
    required ProviderProfile provider,
    required String apiKey,
  }) async {
    if (!_autoMemoryEnabled || apiKey.trim().isEmpty) return;
    final current = _currentConversation;
    if (current == null || current.isGroup || current.characterId != character.id) {
      return;
    }
    final conversationId = current.id;
    final visible = _messages
        .where(_isMessageVisible)
        .where((message) => message.author != MessageAuthor.system)
        .toList();
    final userTurns = visible
        .where((message) => message.author == MessageAuthor.user)
        .length;
    if (userTurns < 24 || userTurns % 24 != 0) return;
    final marker = '$conversationId|$userTurns';
    if (!_autoMemoryExtractionMarkers.add(marker)) return;

    final start = visible.length > 40 ? visible.length - 40 : 0;
    final recent = visible.sublist(start);
    final transcript = recent.map((message) {
      final speaker = message.author == MessageAuthor.user
          ? '用户'
          : character.name;
      return '$speaker：${message.text}';
    }).join('\\n');
    final existing = _characterMemories[character.id] ?? const <String>[];
    final existingText = existing.isEmpty
        ? '无'
        : existing.take(20).map((item) => '- $item').join('\\n');
    final service = AiChatService();
    var raw = '';
    try {
      final request = ChatMessage(
        id: 'memory-${DateTime.now().microsecondsSinceEpoch}',
        author: MessageAuthor.user,
        text: '已有共同记忆：\\n$existingText\\n\\n最近一段较长对话：\\n$transcript',
        sentAt: DateTime.now(),
      );
      await for (final chunk in service.streamReply(
        provider: provider,
        apiKey: apiKey,
        systemPrompt: '从较长一段对话中判断是否有一条真正值得长期保留的共同记忆。'
            '只记录用户明确表达或双方明确发生的稳定事实，例如持续偏好、重要事件、约定、关系变化或长期未完成事项。'
            '不要记录临时情绪、普通寒暄、模型推测或已经存在的同义记忆。'
            '没有合适内容时只输出 NONE；有则只输出一条简洁事实，不编号、不解释，最多60个汉字。',
        history: [request],
        temperature: 0.1,
      )) {
        raw += chunk;
      }
      var memory = raw
          .replaceAll(RegExp(r'[\\r\\n]+'), ' ')
          .replaceAll(RegExp(r'\\s+'), ' ')
          .trim();
      if (memory.isEmpty || memory.toUpperCase() == 'NONE') return;
      if (memory.startsWith('“') && memory.endsWith('”') && memory.length > 2) {
        memory = memory.substring(1, memory.length - 1).trim();
      }
      if (memory.characters.length > 60) {
        memory = memory.characters.take(60).join();
      }
      if (memory.isEmpty || !mounted) return;
      if (_currentConversation?.id != conversationId) return;

      final controller = TextEditingController(text: memory);
      final approved = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('写入共同记忆？'),
          content: TextField(
            controller: controller,
            autofocus: true,
            minLines: 2,
            maxLines: 5,
            maxLength: 80,
            decoration: const InputDecoration(
              labelText: '准备写入的内容',
              helperText: '可以先修改；只有确认后才会保存',
              alignLabelWithHint: true,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('不写入'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(
                context,
                controller.text.trim(),
              ),
              child: const Text('写入记忆'),
            ),
          ],
        ),
      );
      controller.dispose();
      final value = approved?.trim() ?? '';
      if (value.isEmpty || !mounted) return;
      if (_currentConversation?.id != conversationId) return;
      final added = await _chatStore.addMemory(
        value,
        characterId: character.id,
        sourceConversationId: conversationId,
      );
      if (!added) return;
      final latest = await _chatStore.loadMemories(characterId: character.id);
      if (!mounted) return;
      setState(() {
        _characterMemories = {
          ..._characterMemories,
          character.id: latest,
        };
        if (_profile.id == character.id) _memories = latest;
      });
    } on Object {
      // Memory extraction is optional; never invalidate a successful reply.
    } finally {
      service.close();
    }
  }

"""
Path('lib/screens/chat_screen.dart').write_text(text[:start] + new_extract + text[end:])

# --- chat_screen.dart: role generates hidden mood + status tags ---
old_state_prompt = """    final savedMood = _characterMoods[activeCharacter.id] ?? '';
    final previousMood = savedMood.isEmpty ? '未记录' : savedMood;
    final moodInstruction = '\\n\\n心绪输出规则：心绪只描述角色读完用户最新消息、'
        '完成本轮回复后的即时内在状态，必须结合本轮内容重新判断，不能输出无关状态。'
        '上一轮心绪是“$previousMood”，可以保持，也可以自然变化。'
        '有鲜明情绪时优先使用一个贴切的 emoji、颜文字或“短词+emoji”。'
        '回复正文结束后必须另起一行，严格输出“[[心绪:……]]”；'
        '内容1—12个字，不要在正文解释。';
"""
new_state_prompt = """    final savedMood = _characterMoods[activeCharacter.id] ?? '';
    final previousMood = savedMood.isEmpty ? '未记录' : savedMood;
    final previousStatus = activeCharacter.status.trim().isEmpty
        ? '未记录'
        : activeCharacter.status.trim();
    final stateInstruction = '\\n\\n角色状态输出规则：读完用户最新消息并完成正文回复后，'
        '由你自己判断即时心绪和当前状态。上一轮心绪是“$previousMood”，'
        '上一轮状态是“$previousStatus”；都可以保持，也可以随实际对话自然变化。'
        '心绪只写1—12个字；状态写2—16个字，描述此刻真实的态度、活动或关系状态，'
        '不要写成对用户的说明。正文结束后另起两行，严格输出'
        '“[[心绪:……]]”和“[[状态:……]]”。这两行只供系统读取，不要在正文解释。';
"""
replace_once('lib/screens/chat_screen.dart', old_state_prompt, new_state_prompt, 'state prompt')
replace_once(
    'lib/screens/chat_screen.dart',
    "        '$summaryText$previousSummaryText$moodInstruction';",
    "        '$summaryText$previousSummaryText$stateInstruction';",
    'state prompt return',
)

old_tag_parser = """  String _visibleReplyWhileStreaming(String raw) {
    final marker = RegExp(r'\\n?\\[\\[心绪\\s*[:：]').firstMatch(raw);
    return (marker == null ? raw : raw.substring(0, marker.start)).trimRight();
  }

  _TaggedReply _splitMoodFromReply(String raw) {
    final match = RegExp(
      r'\\[\\[心绪\\s*[:：]\\s*(.*?)\\s*\\]\\]',
      dotAll: true,
    ).firstMatch(raw);
    if (match == null) return _TaggedReply(text: raw.trim(), mood: '');
    final text = '${raw.substring(0, match.start)}${raw.substring(match.end)}'
        .trim();
    final mood = _normalizeMood(match.group(1) ?? '');
    return _TaggedReply(text: text, mood: mood);
  }

  String _normalizeMood(String raw) {
    var value = raw
        .replaceAll(RegExp(r'[\\[\\]\\r\\n]'), ' ')
        .replaceAll(RegExp(r'\\s+'), ' ')
        .trim();
    if (value.characters.length > 12) {
      value = value.characters.take(12).join();
    }
    return value;
  }
"""
new_tag_parser = """  String _visibleReplyWhileStreaming(String raw) {
    final marker = RegExp(r'\\n?\\[\\[(?:心绪|状态)\\s*[:：]').firstMatch(raw);
    return (marker == null ? raw : raw.substring(0, marker.start)).trimRight();
  }

  _TaggedReply _splitMoodFromReply(String raw) {
    final moodMatch = RegExp(
      r'\\[\\[心绪\\s*[:：]\\s*(.*?)\\s*\\]\\]',
      dotAll: true,
    ).firstMatch(raw);
    final statusMatch = RegExp(
      r'\\[\\[状态\\s*[:：]\\s*(.*?)\\s*\\]\\]',
      dotAll: true,
    ).firstMatch(raw);
    final text = raw
        .replaceAll(
          RegExp(r'\\[\\[(?:心绪|状态)\\s*[:：]\\s*.*?\\s*\\]\\]', dotAll: true),
          '',
        )
        .trim();
    return _TaggedReply(
      text: text,
      mood: _normalizeMood(moodMatch?.group(1) ?? ''),
      status: _normalizeStatus(statusMatch?.group(1) ?? ''),
    );
  }

  String _normalizeMood(String raw) {
    var value = raw
        .replaceAll(RegExp(r'[\\[\\]\\r\\n]'), ' ')
        .replaceAll(RegExp(r'\\s+'), ' ')
        .trim();
    if (value.characters.length > 12) {
      value = value.characters.take(12).join();
    }
    return value;
  }

  String _normalizeStatus(String raw) {
    var value = raw
        .replaceAll(RegExp(r'[\\[\\]\\r\\n]'), ' ')
        .replaceAll(RegExp(r'\\s+'), ' ')
        .trim();
    if (value.characters.length > 16) {
      value = value.characters.take(16).join();
    }
    return value;
  }

  Future<void> _applyGeneratedStatus({
    required CharacterProfile character,
    required String status,
    required String conversationId,
  }) async {
    final value = _normalizeStatus(status);
    if (value.isEmpty || conversationId.isEmpty) return;
    final characters = _characters
        .map((item) => item.id == character.id ? item.copyWith(status: value) : item)
        .toList();
    await _chatStore.saveCharacters(characters);
    await _chatStore.saveCharacterStatusSource(character.id, conversationId);
    if (!mounted) return;
    final updated = characters.firstWhere((item) => item.id == character.id);
    setState(() {
      _characters = characters;
      if (_profile.id == character.id) _profile = updated;
    });
  }
"""
replace_once('lib/screens/chat_screen.dart', old_tag_parser, new_tag_parser, 'tag parser')

# capture source conversation for generated state
replace_once(
    'lib/screens/chat_screen.dart',
    "    final isRetry = targetReplyIndex != null;\n    var speakingCharacter = characterOverride ?? _profile;",
    "    final isRetry = targetReplyIndex != null;\n    final replyConversationId = _currentConversation?.id ?? '';\n    var speakingCharacter = characterOverride ?? _profile;",
    'reply conversation source',
)

# persist mood source and generated status, and pass source to mood fallback
old_state_save = """        if (parsedReply.mood.isNotEmpty) {
          unawaited(
            _chatStore.saveCharacterMood(
              parsedReply.mood,
              speakingCharacter.id,
            ),
          );
        } else {
          unawaited(
            _chatStore.saveCharacterMood('', speakingCharacter.id),
          );
          unawaited(
            _deriveMoodFromLatestTurn(
              provider: provider,
              apiKey: apiKey,
              contextMessages: contextMessages,
              replyText: replyText,
              character: speakingCharacter,
            ),
          );
        }
        replyCompleted = true;
"""
new_state_save = """        if (parsedReply.mood.isNotEmpty) {
          unawaited(
            _chatStore.saveCharacterMood(
              parsedReply.mood,
              speakingCharacter.id,
            ),
          );
          if (replyConversationId.isNotEmpty) {
            unawaited(
              _chatStore.saveCharacterMoodSource(
                speakingCharacter.id,
                replyConversationId,
              ),
            );
          }
        } else {
          unawaited(
            _chatStore.saveCharacterMood('', speakingCharacter.id),
          );
          unawaited(
            _deriveMoodFromLatestTurn(
              provider: provider,
              apiKey: apiKey,
              contextMessages: contextMessages,
              replyText: replyText,
              character: speakingCharacter,
              conversationId: replyConversationId,
            ),
          );
        }
        if (parsedReply.status.isNotEmpty && replyConversationId.isNotEmpty) {
          await _applyGeneratedStatus(
            character: speakingCharacter,
            status: parsedReply.status,
            conversationId: replyConversationId,
          );
        }
        replyCompleted = true;
"""
replace_once('lib/screens/chat_screen.dart', old_state_save, new_state_save, 'save generated state')

replace_once(
    'lib/screens/chat_screen.dart',
    "    required CharacterProfile character,\n  }) async {\n    ChatMessage? latestUser;",
    "    required CharacterProfile character,\n    required String conversationId,\n  }) async {\n    ChatMessage? latestUser;",
    'mood fallback signature',
)
replace_once(
    'lib/screens/chat_screen.dart',
    "      await _chatStore.saveCharacterMood(mood, character.id);",
    "      await _chatStore.saveCharacterMood(mood, character.id);\n      if (conversationId.isNotEmpty) {\n        await _chatStore.saveCharacterMoodSource(character.id, conversationId);\n      }",
    'mood fallback source',
)

# drawer shows the model-generated status instead of asking the user to maintain it
replace_once(
    'lib/screens/chat_screen.dart',
    "                              groupScope\n                                  ? '点击切换到角色或其他分组'\n                                  : '点击切换角色或进入群聊',",
    "                              groupScope\n                                  ? '点击切换到角色或其他分组'\n                                  : (profile.status.trim().isEmpty\n                                      ? '点击切换角色或进入群聊'\n                                      : profile.status.trim()),",
    'drawer generated status',
)

replace_once(
    'lib/screens/chat_screen.dart',
    "class _TaggedReply {\n  const _TaggedReply({required this.text, required this.mood});\n\n  final String text;\n  final String mood;\n}",
    "class _TaggedReply {\n  const _TaggedReply({\n    required this.text,\n    required this.mood,\n    this.status = '',\n  });\n\n  final String text;\n  final String mood;\n  final String status;\n}",
    'tagged reply status',
)

# --- tests: deletion/provenance behavior ---
path = Path('test/chat_store_conversation_scope_test.dart')
text = path.read_text()
anchor = """  test('legacy relationship memory migrates only to the built-in character',
      () async {
"""
new_tests = """  test('deleting a conversation clears only data derived from that conversation',
      () async {
    final store = ChatStore();
    final now = DateTime.utc(2026, 8, 20);
    final character = CharacterProfile.newCharacter(now).copyWith(
      status: '在生闷气',
    );
    await store.saveCharacters([character]);
    await store.addMemory(
      '来自将删除对话的记忆',
      characterId: character.id,
      sourceConversationId: 'conversation-a',
    );
    await store.addMemory(
      '来自其他对话的记忆',
      characterId: character.id,
      sourceConversationId: 'conversation-b',
    );
    await store.addMemory(
      '手动添加的关系记忆',
      characterId: character.id,
    );
    await store.saveCharacterMood('不高兴', character.id);
    await store.saveCharacterMoodSource(character.id, 'conversation-a');
    await store.saveCharacterStatusSource(character.id, 'conversation-a');

    await store.clearConversationDerivedState(
      conversationId: 'conversation-a',
      characterIds: [character.id],
    );

    expect(
      await store.loadMemories(characterId: character.id),
      ['来自其他对话的记忆', '手动添加的关系记忆'],
    );
    expect(await store.loadCharacterMood(character.id), isEmpty);
    expect((await store.loadCharacters()).single.status, isEmpty);
    expect(await store.loadCharacterMoodSource(character.id), isEmpty);
    expect(await store.loadCharacterStatusSource(character.id), isEmpty);
  });

  test('deleting a character clears scoped relationship state completely',
      () async {
    final store = ChatStore();
    await store.addMemory(
      '角色记忆',
      characterId: 'character-a',
      sourceConversationId: 'conversation-a',
    );
    await store.saveCharacterMood('开心', 'character-a');
    await store.saveCharacterMoodSource('character-a', 'conversation-a');
    await store.saveCharacterStatusSource('character-a', 'conversation-a');

    await store.clearCharacterState('character-a');

    expect(await store.loadMemories(characterId: 'character-a'), isEmpty);
    expect(await store.loadMemorySources('character-a'), isEmpty);
    expect(await store.loadCharacterMood('character-a'), isEmpty);
    expect(await store.loadCharacterMoodSource('character-a'), isEmpty);
    expect(await store.loadCharacterStatusSource('character-a'), isEmpty);
  });

""" + anchor
if anchor not in text:
    raise SystemExit('missing test insertion anchor')
path.write_text(text.replace(anchor, new_tests, 1))

# version bump
replace_once(
    'pubspec.yaml',
    'version: 0.9.7+17',
    'version: 0.9.8+18',
    'version bump',
)
