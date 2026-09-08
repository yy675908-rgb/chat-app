from pathlib import Path


def replace_once(path: str, old: str, new: str, label: str) -> None:
    file = Path(path)
    text = file.read_text(encoding='utf-8')
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{label}: expected exactly 1 match, found {count}')
    file.write_text(text.replace(old, new, 1), encoding='utf-8')


# ---- ChatStore: isolate relationship memory and mood per character. ----
replace_once(
    'lib/services/chat_store.dart',
    """  static const _contextTokenBudgetKey = 'context_token_budget_v1';
  static const _globalSystemPromptKey = 'global_system_prompt_v1';
""",
    """  static const _contextTokenBudgetKey = 'context_token_budget_v1';
  static const _autoMemoryEnabledKey = 'auto_memory_enabled_v1';
  static const _globalSystemPromptKey = 'global_system_prompt_v1';
""",
    'chat store auto memory key',
)

replace_once(
    'lib/services/chat_store.dart',
    """  Future<List<String>> loadMemories() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getStringList(_memoriesKey) ?? const [];
  }

  Future<bool> saveMemories(List<String> memories) async {
    final preferences = await SharedPreferences.getInstance();
    final normalized = memories
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList();
    return preferences.setStringList(_memoriesKey, normalized);
  }

  Future<void> addMemory(String memory) async {
    final preferences = await SharedPreferences.getInstance();
    final memories = preferences.getStringList(_memoriesKey) ?? <String>[];
    final value = memory.trim();
    if (value.isEmpty) return;
    if (!memories.contains(value)) memories.add(value);
    await preferences.setStringList(_memoriesKey, memories);
  }
""",
    """  Future<List<String>> loadMemories({String? characterId}) async {
    final preferences = await SharedPreferences.getInstance();
    if (characterId == null) {
      return preferences.getStringList(_memoriesKey) ?? const [];
    }
    final key = '${_memoriesKey}_$characterId';
    final scoped = preferences.getStringList(key);
    if (scoped != null) return scoped;

    // Migrate the pre-multi-character memory only into the built-in character.
    // Never copy that legacy relationship history into every new character.
    if (characterId == 'character-lin') {
      final legacy = preferences.getStringList(_memoriesKey) ?? const <String>[];
      if (legacy.isNotEmpty) {
        await preferences.setStringList(key, legacy);
        return legacy;
      }
    }
    return const [];
  }

  Future<bool> saveMemories(
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
""",
    'chat store scoped memories',
)

replace_once(
    'lib/services/chat_store.dart',
    """  Future<String> loadCharacterMood([String? characterId]) async {
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
""",
    """  Future<String> loadCharacterMood([String? characterId]) async {
    final preferences = await SharedPreferences.getInstance();
    if (characterId != null) {
      final key = '${_characterMoodKey}_$characterId';
      final value = preferences.getString(key)?.trim();
      if (value != null && value.isNotEmpty) return value;
      if (characterId == 'character-lin') {
        final legacy = preferences.getString(_characterMoodKey)?.trim() ?? '';
        if (legacy.isNotEmpty) {
          await preferences.setString(key, legacy);
          return legacy;
        }
      }
      return '';
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

  Future<void> clearCharacterState(String characterId) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove('${_memoriesKey}_$characterId');
    await preferences.remove('${_characterMoodKey}_$characterId');
  }
""",
    'chat store scoped moods',
)

replace_once(
    'lib/services/chat_store.dart',
    """  Future<void> saveContextTokenBudget(int value) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setInt(_contextTokenBudgetKey, value);
  }

  Future<List<CharacterProfile>> loadCharacters() async {
""",
    """  Future<void> saveContextTokenBudget(int value) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setInt(_contextTokenBudgetKey, value);
  }

  Future<bool> loadAutoMemoryEnabled() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(_autoMemoryEnabledKey) ?? true;
  }

  Future<void> saveAutoMemoryEnabled(bool value) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_autoMemoryEnabledKey, value);
  }

  Future<List<CharacterProfile>> loadCharacters() async {
""",
    'chat store auto memory setting',
)

# ---- Memory screen: relationship memory belongs to one character. ----
replace_once(
    'lib/screens/memory_screen.dart',
    """class MemoryScreen extends StatefulWidget {
  const MemoryScreen({super.key});

  @override
""",
    """class MemoryScreen extends StatefulWidget {
  const MemoryScreen({
    required this.characterId,
    required this.characterName,
    super.key,
  });

  final String characterId;
  final String characterName;

  @override
""",
    'memory screen constructor',
)

replace_once(
    'lib/screens/memory_screen.dart',
    """  Future<void> _load() async {
    final memories = await _store.loadMemories();
    final preferences = await _store.loadStylePreferences();
""",
    """  Future<void> _load() async {
    final memories = await _store.loadMemories(characterId: widget.characterId);
    final preferences = await _store.loadStylePreferences();
""",
    'memory screen scoped load',
)

replace_once(
    'lib/screens/memory_screen.dart',
    """      final saved = await _store.saveMemories(next);
      if (!saved) throw StateError('本地存储未确认写入');
      final latest = await _store.loadMemories();
""",
    """      final saved = await _store.saveMemories(
        next,
        characterId: widget.characterId,
      );
      if (!saved) throw StateError('本地存储未确认写入');
      final latest = await _store.loadMemories(
        characterId: widget.characterId,
      );
""",
    'memory screen scoped save',
)

replace_once(
    'lib/screens/memory_screen.dart',
    """        description: memory
            ? '把重要的人、事和约定慢慢留在这里'
            : '喜欢一条回复后，应用也会自动提炼',
""",
    """        description: memory
            ? '这里只保存你和${widget.characterName}之间的关系记忆；开启自动记忆后也会从明确事实中慢慢沉淀'
            : '喜欢一条回复后，应用也会自动提炼',
""",
    'memory screen scope copy',
)

replace_once(
    'lib/screens/memory_screen.dart',
    """        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: '共同记忆'),
            Tab(text: '回应偏好'),
            Tab(text: '世界书'),
          ],
        ),
""",
    """        bottom: TabBar(
          controller: _tabs,
          tabs: [
            Tab(text: '共同记忆·${widget.characterName}'),
            const Tab(text: '回应偏好'),
            const Tab(text: '世界书'),
          ],
        ),
""",
    'memory screen tab scope',
)

# ---- App settings: make automatic memory explicit and controllable. ----
replace_once(
    'lib/screens/app_settings_screen.dart',
    """    required this.reasoningExpanded,
    required this.contextTokenBudget,
    required this.userProfile,
""",
    """    required this.reasoningExpanded,
    required this.contextTokenBudget,
    required this.autoMemoryEnabled,
    required this.userProfile,
""",
    'settings constructor auto memory',
)

replace_once(
    'lib/screens/app_settings_screen.dart',
    """  final bool reasoningExpanded;
  final int contextTokenBudget;
  final UserProfile userProfile;
  final Future<void> Function(
    bool reasoningExpanded,
    int contextTokenBudget,
    UserProfile userProfile,
  ) onSave;
""",
    """  final bool reasoningExpanded;
  final int contextTokenBudget;
  final bool autoMemoryEnabled;
  final UserProfile userProfile;
  final Future<void> Function(
    bool reasoningExpanded,
    int contextTokenBudget,
    bool autoMemoryEnabled,
    UserProfile userProfile,
  ) onSave;
""",
    'settings callback signature',
)

replace_once(
    'lib/screens/app_settings_screen.dart',
    """  late bool _reasoningExpanded;
  late int _contextTokenBudget;
  bool _saving = false;
""",
    """  late bool _reasoningExpanded;
  late int _contextTokenBudget;
  late bool _autoMemoryEnabled;
  bool _saving = false;
""",
    'settings state auto memory',
)

replace_once(
    'lib/screens/app_settings_screen.dart',
    """    _contextTokenBudget = _budgets.containsKey(widget.contextTokenBudget)
        ? widget.contextTokenBudget
        : 32000;
    _userNameController = TextEditingController(text: widget.userProfile.name);
""",
    """    _contextTokenBudget = _budgets.containsKey(widget.contextTokenBudget)
        ? widget.contextTokenBudget
        : 32000;
    _autoMemoryEnabled = widget.autoMemoryEnabled;
    _userNameController = TextEditingController(text: widget.userProfile.name);
""",
    'settings init auto memory',
)

replace_once(
    'lib/screens/app_settings_screen.dart',
    """    await widget.onSave(
      _reasoningExpanded,
      _contextTokenBudget,
      _userProfileDraft,
    );
""",
    """    await widget.onSave(
      _reasoningExpanded,
      _contextTokenBudget,
      _autoMemoryEnabled,
      _userProfileDraft,
    );
""",
    'settings persist auto memory',
)

replace_once(
    'lib/screens/app_settings_screen.dart',
    """          Text(
            '应用会从最新消息向前保留，直到接近所选 token 预算；共同记忆和命中的世界书另外加入。',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 12,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            '用户人物信息',
""",
    """          Text(
            '应用会从最新消息向前保留，直到接近所选 token 预算；共同记忆和命中的世界书另外加入。',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 12,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          Card(
            elevation: 0,
            child: SwitchListTile(
              title: const Text('自动沉淀共同记忆'),
              subtitle: const Text(
                '每约 8 个用户回合检查一次明确的长期信息，并按角色分别保存；会产生少量额外模型调用。',
              ),
              value: _autoMemoryEnabled,
              onChanged: (value) {
                setState(() => _autoMemoryEnabled = value);
              },
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            '用户人物信息',
""",
    'settings auto memory switch',
)

# ---- Character editor: expose current status, which was previously unreachable. ----
replace_once(
    'lib/screens/character_screen.dart',
    """  late final TextEditingController _nameController;
  late final TextEditingController _greetingController;
""",
    """  late final TextEditingController _nameController;
  late final TextEditingController _statusController;
  late final TextEditingController _greetingController;
""",
    'character status controller field',
)

replace_once(
    'lib/screens/character_screen.dart',
    """    _nameController = TextEditingController(text: widget.profile.name)
      ..addListener(_refreshName);
    _greetingController = TextEditingController(text: widget.profile.greeting);
""",
    """    _nameController = TextEditingController(text: widget.profile.name)
      ..addListener(_refreshName);
    _statusController = TextEditingController(text: widget.profile.status);
    _greetingController = TextEditingController(text: widget.profile.greeting);
""",
    'character status controller init',
)

replace_once(
    'lib/screens/character_screen.dart',
    """      widget.profile.copyWith(
        name: name,
        greeting: _greetingController.text.trim(),
""",
    """      widget.profile.copyWith(
        name: name,
        status: _statusController.text.trim(),
        greeting: _greetingController.text.trim(),
""",
    'character status save',
)

replace_once(
    'lib/screens/character_screen.dart',
    """    _nameController.removeListener(_refreshName);
    _nameController.dispose();
    _greetingController.dispose();
""",
    """    _nameController.removeListener(_refreshName);
    _nameController.dispose();
    _statusController.dispose();
    _greetingController.dispose();
""",
    'character status dispose',
)

replace_once(
    'lib/screens/character_screen.dart',
    """          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: '名字',
              hintText: '角色在对话中使用的名字',
            ),
          ),
          const SizedBox(height: 24),
          const _SectionLabel('初次见面'),
""",
    """          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: '名字',
              hintText: '角色在对话中使用的名字',
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _statusController,
            maxLength: 40,
            decoration: const InputDecoration(
              labelText: '当前状态',
              hintText: '例如：刚下班、在生闷气、今晚很闲',
              helperText: '显示在角色名字下方，也会影响群聊中的接话判断',
            ),
          ),
          const SizedBox(height: 24),
          const _SectionLabel('初次见面'),
""",
    'character status field',
)

# ---- Better default agency for newly created characters. ----
replace_once(
    'lib/models/character_profile.dart',
    """      systemPrompt: '你是一个有独立性格的真实聊天对象。请用自然、简洁的方式与用户交流。',
""",
    """      systemPrompt: '''你是一个有独立性格、判断和边界的真实聊天对象，不是客服或一味顺从用户的助手。
请自然、简洁地交流，并持续遵循自己的性格。你可以主动追问、延续重要话题、提出要求、表达偏爱或不满、改变话题，也可以在不想说时克制或拒绝。
关系状态会影响你的主动程度和在意方式，但不要为了表现亲密而机械撒娇、迎合或失去个性。''',
""",
    'new character agency prompt',
)

# ---- Chat screen: keep per-character memory/mood maps and use them in groups. ----
replace_once(
    'lib/screens/chat_screen.dart',
    """  List<ChatMessage> _messages = [];
  List<String> _memories = [];
  List<String> _stylePreferences = [];
  List<WorldBookEntry> _worldBooks = [];
  String _characterMood = '';
  UserProfile _userProfile = const UserProfile();
  bool _reasoningExpanded = true;
  int _contextTokenBudget = 32000;
""",
    """  List<ChatMessage> _messages = [];
  List<String> _memories = [];
  Map<String, List<String>> _characterMemories = {};
  List<String> _stylePreferences = [];
  List<WorldBookEntry> _worldBooks = [];
  String _characterMood = '';
  Map<String, String> _characterMoods = {};
  UserProfile _userProfile = const UserProfile();
  bool _reasoningExpanded = true;
  int _contextTokenBudget = 32000;
  bool _autoMemoryEnabled = true;
  final Set<String> _autoMemoryExtractionMarkers = {};
""",
    'chat relationship state fields',
)

replace_once(
    'lib/screens/chat_screen.dart',
    """    await _chatStore.saveSelectedCharacterId(profile.id);
    final memories = await _chatStore.loadMemories();
    final stylePreferences = await _chatStore.loadStylePreferences();
    final worldBooks = await _chatStore.loadWorldBooks();
    final characterMood = await _chatStore.loadCharacterMood(profile.id);
    final reasoningExpanded = await _chatStore.loadReasoningExpanded();
    final contextTokenBudget = await _chatStore.loadContextTokenBudget();
    final userProfile = await _chatStore.loadUserProfile();
""",
    """    await _chatStore.saveSelectedCharacterId(profile.id);
    final characterMemories = <String, List<String>>{};
    final characterMoods = <String, String>{};
    for (final character in characters) {
      characterMemories[character.id] = await _chatStore.loadMemories(
        characterId: character.id,
      );
      final mood = await _chatStore.loadCharacterMood(character.id);
      if (mood.isNotEmpty) characterMoods[character.id] = mood;
    }
    final memories = characterMemories[profile.id] ?? const <String>[];
    final stylePreferences = await _chatStore.loadStylePreferences();
    final worldBooks = await _chatStore.loadWorldBooks();
    final characterMood = characterMoods[profile.id] ?? '';
    final reasoningExpanded = await _chatStore.loadReasoningExpanded();
    final contextTokenBudget = await _chatStore.loadContextTokenBudget();
    final autoMemoryEnabled = await _chatStore.loadAutoMemoryEnabled();
    final userProfile = await _chatStore.loadUserProfile();
""",
    'chat restore scoped relationship state',
)

replace_once(
    'lib/screens/chat_screen.dart',
    """      _profile = profile;
      _characters = characters;
      _memories = memories;
      _stylePreferences = stylePreferences;
      _worldBooks = worldBooks;
      _characterMood = characterMood;
      _reasoningExpanded = reasoningExpanded;
      _contextTokenBudget = contextTokenBudget;
      _userProfile = userProfile;
""",
    """      _profile = profile;
      _characters = characters;
      _memories = memories;
      _characterMemories = characterMemories;
      _stylePreferences = stylePreferences;
      _worldBooks = worldBooks;
      _characterMood = characterMood;
      _characterMoods = characterMoods;
      _reasoningExpanded = reasoningExpanded;
      _contextTokenBudget = contextTokenBudget;
      _autoMemoryEnabled = autoMemoryEnabled;
      _userProfile = userProfile;
""",
    'chat restore state assignment',
)

replace_once(
    'lib/screens/chat_screen.dart',
    """      final modelPrompt = provider.systemPromptForModel().trim();
      final request = ChatMessage(
""",
    """      final modelPrompt = provider.systemPromptForModel().trim();
      final memories = _characterMemories[character.id] ?? const <String>[];
      final memoryPrompt = memories.isEmpty
          ? ''
          : '\\n\\n你和用户的共同记忆：\\n'
              '${memories.map((item) => '- $item').join('\\n')}';
      final request = ChatMessage(
""",
    'group intent memory context',
)

replace_once(
    'lib/screens/chat_screen.dart',
    """        systemPrompt: '${modelPrompt.isEmpty ? '' : '$modelPrompt\\n\\n'}'
            '${character.systemPrompt}\\n\\n'
            '【群聊内部意愿判断】你现在不是正式发言，也不生成回复正文。'
""",
    """        systemPrompt: '${modelPrompt.isEmpty ? '' : '$modelPrompt\\n\\n'}'
            '${character.systemPrompt}$memoryPrompt\\n\\n'
            '【群聊内部意愿判断】你现在不是正式发言，也不生成回复正文。'
""",
    'group intent inject memory',
)

replace_once(
    'lib/screens/chat_screen.dart',
    """    var fullReply = '';
    var fullReasoning = '';
    var usage = const AiTokenUsage();
    try {
""",
    """    var fullReply = '';
    var fullReasoning = '';
    var usage = const AiTokenUsage();
    var replyCompleted = false;
    try {
""",
    'reply completion marker',
)

replace_once(
    'lib/screens/chat_screen.dart',
    """          if (parsedReply.mood.isNotEmpty) {
            if (_currentConversation?.isGroup != true ||
                speakingCharacter.id == _profile.id) {
              _characterMood = parsedReply.mood;
            }
          } else {
            if (_currentConversation?.isGroup != true ||
                speakingCharacter.id == _profile.id) {
              _characterMood = '';
            }
          }
""",
    """          final moods = Map<String, String>.from(_characterMoods);
          if (parsedReply.mood.isNotEmpty) {
            moods[speakingCharacter.id] = parsedReply.mood;
          } else {
            moods.remove(speakingCharacter.id);
          }
          _characterMoods = moods;
          if (speakingCharacter.id == _profile.id) {
            _characterMood = parsedReply.mood;
          }
""",
    'reply mood map update',
)

replace_once(
    'lib/screens/chat_screen.dart',
    """          unawaited(
            _deriveMoodFromLatestTurn(
              provider: provider,
              apiKey: apiKey,
              contextMessages: contextMessages,
              replyText: replyText,
              character: speakingCharacter,
            ),
          );
        }
      }
    } on AiChatException catch (error) {
""",
    """          unawaited(
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
      }
    } on AiChatException catch (error) {
""",
    'reply completed success',
)

replace_once(
    'lib/screens/chat_screen.dart',
    """        await _persistMessages();
        if (!_cancelled && !_replyQueued) {
          unawaited(_maybeOfferCompression());
        }
""",
    """        await _persistMessages();
        if (replyCompleted &&
            !isRetry &&
            !_cancelled &&
            !_replyQueued &&
            _currentConversation?.isGroup != true) {
          unawaited(
            _maybeExtractRelationshipMemory(
              character: speakingCharacter,
              provider: provider,
              apiKey: apiKey,
            ),
          );
        }
        if (!_cancelled && !_replyQueued) {
          unawaited(_maybeOfferCompression());
        }
""",
    'reply auto memory call',
)

replace_once(
    'lib/screens/chat_screen.dart',
    """    final context = '当前时间：${_formatPromptTime(now)}$interval';
    final memoryText = _memories.isEmpty
        ? ''
        : '\\n\\n你们共同确认的记忆：\\n'
            '${_memories.map((memory) => '- $memory').join('\\n')}';
""",
    """    final context = '当前时间：${_formatPromptTime(now)}$interval';
    final activeMemories =
        _characterMemories[activeCharacter.id] ?? const <String>[];
    final memoryText = activeMemories.isEmpty
        ? ''
        : '\\n\\n你和用户的共同记忆（仅属于你们这段关系）：\\n'
            '${activeMemories.map((memory) => '- $memory').join('\\n')}';
""",
    'prompt scoped memory',
)

replace_once(
    'lib/screens/chat_screen.dart',
    """    final previousMood = activeCharacter.id == _profile.id &&
            _characterMood.isNotEmpty
        ? _characterMood
        : '未记录';
""",
    """    final savedMood = _characterMoods[activeCharacter.id] ?? '';
    final previousMood = savedMood.isEmpty ? '未记录' : savedMood;
""",
    'prompt scoped mood',
)

replace_once(
    'lib/screens/chat_screen.dart',
    """      if (_currentConversation?.isGroup != true ||
          _profile.id == character.id) {
        setState(() => _characterMood = mood);
      }
      await _chatStore.saveCharacterMood(mood, character.id);
""",
    """      setState(() {
        _characterMoods = {
          ..._characterMoods,
          character.id: mood,
        };
        if (_profile.id == character.id) _characterMood = mood;
      });
      await _chatStore.saveCharacterMood(mood, character.id);
""",
    'derived mood map update',
)

# Insert automatic memory extractor after mood repair.
replace_once(
    'lib/screens/chat_screen.dart',
    """  List<ChatMessage> _messagesWithinBudget(
    List<ChatMessage> messages,
    String systemPrompt,
  ) {
""",
    """  Future<void> _maybeExtractRelationshipMemory({
    required CharacterProfile character,
    required ProviderProfile provider,
    required String apiKey,
  }) async {
    if (!_autoMemoryEnabled || apiKey.trim().isEmpty) return;
    final current = _currentConversation;
    if (current == null || current.isGroup || current.characterId != character.id) {
      return;
    }
    final visible = _messages
        .where(_isMessageVisible)
        .where((message) => message.author != MessageAuthor.system)
        .toList();
    final userTurns = visible
        .where((message) => message.author == MessageAuthor.user)
        .length;
    if (userTurns < 8 || userTurns % 8 != 0) return;
    final marker = '${current.id}|$userTurns';
    if (!_autoMemoryExtractionMarkers.add(marker)) return;

    final start = visible.length > 12 ? visible.length - 12 : 0;
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
        text: '已有共同记忆：\\n$existingText\\n\\n最近对话：\\n$transcript',
        sentAt: DateTime.now(),
      );
      await for (final chunk in service.streamReply(
        provider: provider,
        apiKey: apiKey,
        systemPrompt: '从最近对话中判断是否有一条值得长期保留的共同记忆。'
            '只记录用户明确表达或双方明确发生的事实，例如持续偏好、重要事件、约定、关系变化或未完成事项。'
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
      if (memory.isEmpty) return;
      final added = await _chatStore.addMemory(
        memory,
        characterId: character.id,
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

  List<ChatMessage> _messagesWithinBudget(
    List<ChatMessage> messages,
    String systemPrompt,
  ) {
""",
    'insert auto relationship memory extractor',
)

replace_once(
    'lib/screens/chat_screen.dart',
    """        builder: (_) => AppSettingsScreen(
          reasoningExpanded: _reasoningExpanded,
          contextTokenBudget: _contextTokenBudget,
          userProfile: _userProfile,
          onSave: (
            reasoningExpanded,
            contextTokenBudget,
            userProfile,
          ) async {
            await _chatStore.saveReasoningExpanded(reasoningExpanded);
            await _chatStore.saveContextTokenBudget(contextTokenBudget);
            await _chatStore.saveUserProfile(userProfile);
            if (!mounted) return;
            setState(() {
              _reasoningExpanded = reasoningExpanded;
              _contextTokenBudget = contextTokenBudget;
              _userProfile = userProfile;
            });
          },
""",
    """        builder: (_) => AppSettingsScreen(
          reasoningExpanded: _reasoningExpanded,
          contextTokenBudget: _contextTokenBudget,
          autoMemoryEnabled: _autoMemoryEnabled,
          userProfile: _userProfile,
          onSave: (
            reasoningExpanded,
            contextTokenBudget,
            autoMemoryEnabled,
            userProfile,
          ) async {
            await _chatStore.saveReasoningExpanded(reasoningExpanded);
            await _chatStore.saveContextTokenBudget(contextTokenBudget);
            await _chatStore.saveAutoMemoryEnabled(autoMemoryEnabled);
            await _chatStore.saveUserProfile(userProfile);
            if (!mounted) return;
            setState(() {
              _reasoningExpanded = reasoningExpanded;
              _contextTokenBudget = contextTokenBudget;
              _autoMemoryEnabled = autoMemoryEnabled;
              _userProfile = userProfile;
            });
          },
""",
    'chat settings auto memory wiring',
)

replace_once(
    'lib/screens/chat_screen.dart',
    """  Future<void> _openMemories() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const MemoryScreen()),
    );
    final memories = await _chatStore.loadMemories();
    final preferences = await _chatStore.loadStylePreferences();
""",
    """  Future<void> _openMemories() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => MemoryScreen(
          characterId: _profile.id,
          characterName: _profile.name,
        ),
      ),
    );
    final memories = await _chatStore.loadMemories(characterId: _profile.id);
    final preferences = await _chatStore.loadStylePreferences();
""",
    'chat open scoped memories',
)

replace_once(
    'lib/screens/chat_screen.dart',
    """    setState(() {
      _memories = memories;
      _stylePreferences = preferences;
      _worldBooks = worldBooks;
    });
""",
    """    setState(() {
      _memories = memories;
      _characterMemories = {
        ..._characterMemories,
        _profile.id: memories,
      };
      _stylePreferences = preferences;
      _worldBooks = worldBooks;
    });
""",
    'chat refresh scoped memories',
)

replace_once(
    'lib/screens/chat_screen.dart',
    """    await _chatStore.saveConversations(keptConversations);
    await _chatStore.saveCharacters(remainingCharacters);
    await _chatStore.saveCharacterMood('', character.id);

    var nextProfile = _profile;
    var nextMood = _characterMood;
    if (_profile.id == character.id) {
      nextProfile = remainingCharacters.first;
      await _chatStore.saveSelectedCharacterId(nextProfile.id);
      nextMood = await _chatStore.loadCharacterMood(nextProfile.id);
    }
""",
    """    await _chatStore.saveConversations(keptConversations);
    await _chatStore.saveCharacters(remainingCharacters);
    await _chatStore.clearCharacterState(character.id);

    final remainingMemoryMap =
        Map<String, List<String>>.from(_characterMemories)
          ..remove(character.id);
    final remainingMoodMap = Map<String, String>.from(_characterMoods)
      ..remove(character.id);
    var nextProfile = _profile;
    var nextMood = _characterMood;
    var nextMemories = _memories;
    if (_profile.id == character.id) {
      nextProfile = remainingCharacters.first;
      await _chatStore.saveSelectedCharacterId(nextProfile.id);
      nextMood = await _chatStore.loadCharacterMood(nextProfile.id);
      nextMemories = await _chatStore.loadMemories(characterId: nextProfile.id);
      remainingMemoryMap[nextProfile.id] = nextMemories;
      if (nextMood.isNotEmpty) remainingMoodMap[nextProfile.id] = nextMood;
    }
""",
    'delete character scoped state',
)

replace_once(
    'lib/screens/chat_screen.dart',
    """      setState(() {
        _characters = remainingCharacters;
        _profile = nextProfile;
        _characterMood = nextMood;
        _conversations = groups;
""",
    """      setState(() {
        _characters = remainingCharacters;
        _profile = nextProfile;
        _memories = nextMemories;
        _characterMemories = remainingMemoryMap;
        _characterMood = nextMood;
        _characterMoods = remainingMoodMap;
        _conversations = groups;
""",
    'delete character group state maps',
)

replace_once(
    'lib/screens/chat_screen.dart',
    """      setState(() {
        _characters = remainingCharacters;
        _profile = nextProfile;
        _characterMood = nextMood;
      });
""",
    """      setState(() {
        _characters = remainingCharacters;
        _profile = nextProfile;
        _memories = nextMemories;
        _characterMemories = remainingMemoryMap;
        _characterMood = nextMood;
        _characterMoods = remainingMoodMap;
      });
""",
    'delete selected character state maps',
)

replace_once(
    'lib/screens/chat_screen.dart',
    """    } else {
      setState(() => _characters = remainingCharacters);
    }
""",
    """    } else {
      setState(() {
        _characters = remainingCharacters;
        _characterMemories = remainingMemoryMap;
        _characterMoods = remainingMoodMap;
      });
    }
""",
    'delete other character state maps',
)

replace_once(
    'lib/screens/chat_screen.dart',
    """    final mood = await _chatStore.loadCharacterMood(profile.id);
    if (!mounted) return;
    setState(() {
      _profile = profile;
      _conversations = conversations;
      _currentConversation = current;
      _messages = messages;
      _characterMood = mood;
      _groupScope = false;
    });
""",
    """    final memories = await _chatStore.loadMemories(characterId: profile.id);
    final mood = await _chatStore.loadCharacterMood(profile.id);
    if (!mounted) return;
    setState(() {
      _profile = profile;
      _memories = memories;
      _characterMemories = {
        ..._characterMemories,
        profile.id: memories,
      };
      _conversations = conversations;
      _currentConversation = current;
      _messages = messages;
      _characterMood = mood;
      final moods = Map<String, String>.from(_characterMoods);
      if (mood.isEmpty) {
        moods.remove(profile.id);
      } else {
        moods[profile.id] = mood;
      }
      _characterMoods = moods;
      _groupScope = false;
    });
""",
    'switch character scoped state',
)

# ---- Backup v3: preserve per-character memories and automatic-memory setting. ----
replace_once(
    'lib/services/backup_service.dart',
    """    final providers = await _providerStore.loadProviders();
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
""",
    """    final providers = await _providerStore.loadProviders();
    final characterMemories = <String, List<String>>{};
    final characterMoods = <String, String>{};
    for (final character in characters) {
      final memories = await _chatStore.loadMemories(characterId: character.id);
      if (memories.isNotEmpty) characterMemories[character.id] = memories;
      if (scope == BackupScope.full) {
        final mood = await _chatStore.loadCharacterMood(character.id);
        if (mood.isNotEmpty) characterMoods[character.id] = mood;
      }
    }
    final data = <String, Object?>{
      'format': 'character-chat-backup',
      'version': 3,
""",
    'backup v3 state maps',
)

replace_once(
    'lib/services/backup_service.dart',
    """      'selectedCharacterId': await _chatStore.loadSelectedCharacterId(),
      'memories': await _chatStore.loadMemories(),
      'stylePreferences': await _chatStore.loadStylePreferences(),
""",
    """      'selectedCharacterId': await _chatStore.loadSelectedCharacterId(),
      'memories': characterMemories[profile.id] ?? const <String>[],
      'characterMemories': characterMemories,
      'stylePreferences': await _chatStore.loadStylePreferences(),
""",
    'backup character memories fields',
)

replace_once(
    'lib/services/backup_service.dart',
    """      'contextTokenBudget': await _chatStore.loadContextTokenBudget(),
      'globalSystemPrompt': await _chatStore.loadGlobalSystemPrompt(),
""",
    """      'contextTokenBudget': await _chatStore.loadContextTokenBudget(),
      'autoMemoryEnabled': await _chatStore.loadAutoMemoryEnabled(),
      'globalSystemPrompt': await _chatStore.loadGlobalSystemPrompt(),
""",
    'backup auto memory field',
)

replace_once(
    'lib/services/backup_service.dart',
    """    if (data['format'] != 'character-chat-backup' ||
        (version != 1 && version != 2)) {
""",
    """    if (data['format'] != 'character-chat-backup' ||
        (version != 1 && version != 2 && version != 3)) {
""",
    'backup accept v3',
)

replace_once(
    'lib/services/backup_service.dart',
    """    await _chatStore.saveMemories(
      (data['memories'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .toList(),
    );
    await _chatStore.saveStylePreferences(
""",
    """    final characterMemoriesRaw = data['characterMemories'];
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
""",
    'backup restore scoped memories',
)

replace_once(
    'lib/services/backup_service.dart',
    """    await _chatStore.saveContextTokenBudget(
      data['contextTokenBudget'] as int? ?? 32000,
    );
    await _chatStore.saveGlobalSystemPrompt(
""",
    """    await _chatStore.saveContextTokenBudget(
      data['contextTokenBudget'] as int? ?? 32000,
    );
    await _chatStore.saveAutoMemoryEnabled(
      data['autoMemoryEnabled'] as bool? ?? true,
    );
    await _chatStore.saveGlobalSystemPrompt(
""",
    'backup restore auto memory',
)

# ---- Tests for scoping and backup format. ----
replace_once(
    'test/chat_store_conversation_scope_test.dart',
    """  test('the latest user message always requires one character reply', () {
""",
    """  test('relationship memory and mood stay isolated by character', () async {
    final store = ChatStore();
    await store.saveMemories(['A 的共同记忆'], characterId: 'character-a');
    await store.saveMemories(['B 的共同记忆'], characterId: 'character-b');
    await store.saveCharacterMood('开心', 'character-a');

    expect(
      await store.loadMemories(characterId: 'character-a'),
      ['A 的共同记忆'],
    );
    expect(
      await store.loadMemories(characterId: 'character-b'),
      ['B 的共同记忆'],
    );
    expect(await store.loadCharacterMood('character-a'), '开心');
    expect(await store.loadCharacterMood('character-b'), isEmpty);

    expect(await store.loadAutoMemoryEnabled(), isTrue);
    await store.saveAutoMemoryEnabled(false);
    expect(await store.loadAutoMemoryEnabled(), isFalse);
  });

  test('legacy relationship memory migrates only to the built-in character',
      () async {
    SharedPreferences.setMockInitialValues({
      'relationship_memories_v1': ['旧的共同记忆'],
    });
    final store = ChatStore();

    expect(
      await store.loadMemories(characterId: 'character-lin'),
      ['旧的共同记忆'],
    );
    expect(
      await store.loadMemories(characterId: 'character-new'),
      isEmpty,
    );
  });

  test('the latest user message always requires one character reply', () {
""",
    'chat store relationship tests',
)

replace_once(
    'test/settings_backup_test.dart',
    """    final existing = await chatStore.loadConversations();

    final raw = await BackupService(
""",
    """    final existing = await chatStore.loadConversations();
    final selectedCharacter = await chatStore.loadProfile();
    await chatStore.saveMemories(
      ['只属于当前角色的记忆'],
      characterId: selectedCharacter.id,
    );
    await chatStore.saveAutoMemoryEnabled(false);

    final raw = await BackupService(
""",
    'backup test seed relationship state',
)

replace_once(
    'test/settings_backup_test.dart',
    """    expect(data['version'], 2);
    expect(data['scope'], 'configuration');
""",
    """    expect(data['version'], 3);
    expect(data['scope'], 'configuration');
""",
    'backup test version 3',
)

replace_once(
    'test/settings_backup_test.dart',
    """    expect(data['userProfile']['name'], '小满');
    expect(
      data['providers'][0]['modelSystemPrompts']['deepseek-chat'],
      '控制在三句话内。',
    );

    await BackupService(
""",
    """    expect(data['userProfile']['name'], '小满');
    expect(data['autoMemoryEnabled'], isFalse);
    expect(
      data['characterMemories'][selectedCharacter.id],
      ['只属于当前角色的记忆'],
    );
    expect(
      data['providers'][0]['modelSystemPrompts']['deepseek-chat'],
      '控制在三句话内。',
    );

    await chatStore.saveMemories(
      ['临时覆盖'],
      characterId: selectedCharacter.id,
    );
    await chatStore.saveAutoMemoryEnabled(true);
    await BackupService(
""",
    'backup test inspect scoped state',
)

replace_once(
    'test/settings_backup_test.dart',
    """    final afterRestore = await chatStore.loadConversations();
    expect(afterRestore.map((item) => item.id), existing.map((item) => item.id));
  });
""",
    """    final afterRestore = await chatStore.loadConversations();
    expect(afterRestore.map((item) => item.id), existing.map((item) => item.id));
    expect(
      await chatStore.loadMemories(characterId: selectedCharacter.id),
      ['只属于当前角色的记忆'],
    );
    expect(await chatStore.loadAutoMemoryEnabled(), isFalse);
  });
""",
    'backup test restored scoped state',
)

# ---- Version bump. ----
replace_once(
    'pubspec.yaml',
    'version: 0.9.6+15\n',
    'version: 0.9.7+16\n',
    'version bump',
)

print('relationship continuity pass applied')
