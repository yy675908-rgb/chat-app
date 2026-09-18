import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/character_profile.dart';
import '../models/chat_message.dart';
import '../models/chat_search_result.dart';
import '../models/conversation.dart';
import '../models/provider_profile.dart';
import '../models/proactive_message_settings.dart';
import '../models/world_book_entry.dart';
import '../models/user_profile.dart';
import '../services/ai_chat_service.dart';
import '../services/chat_auxiliary_ai_service.dart';
import '../services/chat_context_builder.dart';
import '../services/chat_store.dart';
import '../services/group_intent_evaluator.dart';
import '../services/group_reply_policy.dart';
import '../services/mood_codec.dart';
import '../services/proactive_message_coordinator.dart';
import '../services/provider_store.dart';
import '../services/reply_stream_accumulator.dart';
import '../widgets/chat_composer.dart';
import '../widgets/chat_message_list.dart';
import '../widgets/chat_picker_sheets.dart';
import '../widgets/conversation_drawer.dart';
import '../widgets/group_conversation_sheet.dart';
import '../widgets/message_bubble.dart';
import 'api_settings_screen.dart';
import 'app_settings_screen.dart';
import 'character_screen.dart';
import 'chat_search_screen.dart';
import 'favorites_screen.dart';
import 'memory_screen.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _chatStore = ChatStore();
  final _providerStore = ProviderStore();
  final _auxiliaryAiService = const ChatAuxiliaryAiService();
  final _proactiveCoordinator = const ProactiveMessageCoordinator();

  CharacterProfile _profile = CharacterProfile.lin(DateTime.now());
  List<CharacterProfile> _characters = const [];
  List<Conversation> _conversations = const [];
  Conversation? _currentConversation;
  List<ChatMessage> _messages = [];
  List<String> _memories = [];
  Map<String, List<String>> _characterMemories = {};
  List<String> _stylePreferences = [];
  Map<String, List<String>> _characterStylePreferences = {};
  List<WorldBookEntry> _worldBooks = [];
  String _characterMood = '';
  Map<String, String> _characterMoods = {};
  UserProfile _userProfile = const UserProfile();
  bool _reasoningExpanded = true;
  int _contextTokenBudget = 32000;
  bool _autoMemoryEnabled = true;
  final Set<String> _autoMemoryExtractionMarkers = {};
  List<ProviderProfile> _providers = const [];
  ProviderProfile? _selectedProvider;
  AiChatService? _activeService;
  final _groupIntentEvaluator = GroupIntentEvaluator();
  String? _activeReplyId;
  bool _loading = true;
  bool _groupScope = false;
  bool _generating = false;
  bool _evaluatingGroupIntents = false;
  bool _cancelled = false;
  bool _replyQueued = false;
  bool _drainingReplies = false;
  int? _activeRetryIndex;
  List<ChatMessage>? _activeRetrySnapshot;
  bool _compressionPromptActive = false;
  final Map<String, int> _compressionPromptedAtCounts = {};
  bool _memoryPromptActive = false;
  bool _pointerHoldingMessages = false;
  bool _followStreamingOutput = true;
  String? _searchTargetMessageId;
  int _searchTargetRequest = 0;
  bool _checkingProactiveMessage = false;
  Timer? _proactiveTimer;
  Future<void> _persistQueue = Future<void>.value();

  bool get _isBusy => _generating || _evaluatingGroupIntents;

  Future<void> _saveScopedConversations(List<Conversation> conversations) {
    if (_groupScope) {
      return _chatStore.saveGroupConversations(conversations);
    }
    return _chatStore.saveConversations(
      conversations,
      characterId: _profile.id,
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_restore());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_loading) {
      unawaited(_syncProactiveSchedule());
    }
  }

  Future<void> _restore() async {
    final characters = await _chatStore.loadCharacters();
    final selectedCharacterId = await _chatStore.loadSelectedCharacterId();
    final profile = characters.firstWhere(
      (item) => item.id == selectedCharacterId,
      orElse: () => characters.first,
    );
    await _chatStore.saveSelectedCharacterId(profile.id);
    final characterMemories = <String, List<String>>{};
    final characterStylePreferences = <String, List<String>>{};
    final characterMoods = <String, String>{};
    await Future.wait([
      for (final character in characters)
        () async {
          final results = await Future.wait<Object>([
            _chatStore.loadMemories(characterId: character.id),
            _chatStore.loadStylePreferences(characterId: character.id),
            _chatStore.loadCharacterMood(character.id),
          ]);
          characterMemories[character.id] = results[0] as List<String>;
          characterStylePreferences[character.id] =
              results[1] as List<String>;
          final mood = _normalizeMood(results[2] as String);
          if (mood.isNotEmpty) characterMoods[character.id] = mood;
        }(),
    ]);
    final memories = characterMemories[profile.id] ?? const <String>[];
    final stylePreferences =
        characterStylePreferences[profile.id] ?? const <String>[];
    final worldBooks = await _chatStore.loadWorldBooks();
    final characterMood = characterMoods[profile.id] ?? '';
    final reasoningExpanded = await _chatStore.loadReasoningExpanded();
    final contextTokenBudget = await _chatStore.loadContextTokenBudget();
    final autoMemoryEnabled = await _chatStore.loadAutoMemoryEnabled();
    final userProfile = await _chatStore.loadUserProfile();
    final conversations = await _chatStore.loadConversations(
      characterId: profile.id,
    );
    var providers = await _providerStore.loadProviders();
    final current = conversations.first;
    final selectedId = await _providerStore.loadSelectedProviderId();
    var selected = providers.firstWhere(
      (provider) => provider.id == selectedId,
      orElse: () => providers.first,
    );
    final legacyPrompt = await _chatStore.loadGlobalSystemPrompt();
    if (legacyPrompt.isNotEmpty && selected.selectedModel.isNotEmpty) {
      if (selected.systemPromptForModel().isEmpty) {
        final prompts = Map<String, String>.from(selected.modelSystemPrompts)
          ..[selected.selectedModel] = legacyPrompt;
        selected = selected.copyWith(modelSystemPrompts: prompts);
        providers = providers
            .map((item) => item.id == selected.id ? selected : item)
            .toList();
        await _providerStore.saveProviders(providers);
      }
      await _chatStore.saveGlobalSystemPrompt('');
    }
    await _providerStore.saveSelectedProviderId(selected.id);
    final messages = await _messagesWithGreeting(
      current.id,
      profile,
      isGroup: current.isGroup,
    );
    if (!mounted) return;
    setState(() {
      _profile = profile;
      _characters = characters;
      _memories = memories;
      _characterMemories = characterMemories;
      _stylePreferences = stylePreferences;
      _characterStylePreferences = characterStylePreferences;
      _worldBooks = worldBooks;
      _characterMood = characterMood;
      _characterMoods = characterMoods;
      _reasoningExpanded = reasoningExpanded;
      _contextTokenBudget = contextTokenBudget;
      _autoMemoryEnabled = autoMemoryEnabled;
      _userProfile = userProfile;
      _conversations = conversations;
      _currentConversation = current;
      _providers = providers;
      _selectedProvider = selected;
      _messages = messages;
      _groupScope = false;
      _loading = false;
    });
    _scrollToBottom(jump: true);
    unawaited(_syncProactiveSchedule());
  }

  Future<List<ChatMessage>> _messagesWithGreeting(
    String conversationId,
    CharacterProfile profile, {
    bool isGroup = false,
  }) async {
    final loadedMessages = await _chatStore.loadMessages(conversationId);
    var cleanedStoredMetadata = false;
    final messages = <ChatMessage>[];
    for (final message in loadedMessages) {
      final cleaned = _sanitizeMoodMetadataInMessage(message);
      if (_messageMoodMetadataChanged(message, cleaned)) {
        cleanedStoredMetadata = true;
      }
      messages.add(cleaned);
    }
    if (messages.isNotEmpty) {
      if (cleanedStoredMetadata) {
        await _chatStore.saveMessages(conversationId, messages);
      }
      return messages;
    }

    if (isGroup) {
      messages.add(
        ChatMessage(
          id: 'greeting-${DateTime.now().microsecondsSinceEpoch}',
          author: MessageAuthor.system,
          text: '群聊已创建',
          sentAt: DateTime.now(),
        ),
      );
    } else if (profile.greeting.trim().isNotEmpty) {
      messages.add(
        ChatMessage(
          id: 'greeting-${DateTime.now().microsecondsSinceEpoch}',
          author: MessageAuthor.character,
          text: profile.greeting.trim(),
          sentAt: DateTime.now(),
          speakerCharacterId: profile.id,
        ),
      );
    }
    if (messages.isNotEmpty) {
      await _chatStore.saveMessages(conversationId, messages);
    }
    return messages;
  }

  Future<void> _newConversation() async {
    _scaffoldKey.currentState?.closeDrawer();
    if (_isBusy) {
      _stopGenerating();
      while (_isBusy && mounted) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      if (!mounted) return;
    }
    final now = DateTime.now();
    final conversation = Conversation(
      id: 'conversation-${now.microsecondsSinceEpoch}',
      characterId: _profile.id,
      title: '新对话',
      createdAt: now,
      updatedAt: now,
    );
    final conversations = [conversation, ..._conversations];
    await _chatStore.saveConversations(conversations, characterId: _profile.id);
    final messages = await _messagesWithGreeting(
      conversation.id,
      _profile,
      isGroup: conversation.isGroup,
    );
    if (!mounted) return;
    setState(() {
      _conversations = conversations;
      _currentConversation = conversation;
      _messages = messages;
      _groupScope = false;
    });
    _scrollToBottom(jump: true);
  }

  Future<void> _newGroupConversation() async {
    if (_isBusy) {
      _stopGenerating();
      while (_isBusy && mounted) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      if (!mounted) return;
    }
    if (_characters.length < 2) {
      _showMessage('至少添加两个角色后才能创建群聊');
      return;
    }
    final scaffold = _scaffoldKey.currentState;
    if (scaffold?.isDrawerOpen == true) {
      scaffold!.closeDrawer();
      await Future<void>.delayed(const Duration(milliseconds: 120));
      if (!mounted) return;
    }
    final draft = await showGroupConversationSheet(
      context: context,
      characters: _characters,
      moodForCharacter: _moodForCharacter,
    );
    if (draft == null) return;
    final participants = _characters
        .where((item) => draft.participantIds.contains(item.id))
        .toList();
    if (participants.length < 2) return;
    final now = DateTime.now();
    final title = draft.title.isEmpty
        ? participants.map((item) => item.name).join('、')
        : draft.title;
    final conversation = Conversation(
      id: 'conversation-${now.microsecondsSinceEpoch}',
      characterId: Conversation.groupSpaceId,
      title: title,
      createdAt: now,
      updatedAt: now,
      participantIds: participants.map((item) => item.id).toList(),
    );
    final messages = <ChatMessage>[
      ChatMessage(
        id: 'group-start-${now.microsecondsSinceEpoch}',
        author: MessageAuthor.system,
        text: '群聊成员：${participants.map((item) => item.name).join('、')}',
        sentAt: now,
      ),
    ];
    final existingGroups = _groupScope
        ? _conversations
        : await _chatStore.loadGroupConversations();
    final conversations = [conversation, ...existingGroups];
    await _chatStore.saveMessages(conversation.id, messages);
    await _chatStore.saveGroupConversations(conversations);
    if (!mounted) return;
    setState(() {
      _conversations = conversations;
      _currentConversation = conversation;
      _messages = messages;
      _groupScope = true;
      _followStreamingOutput = true;
    });
    _scrollToBottom(jump: true);
    await _queueReply();
  }

  Future<void> _selectConversation(
    Conversation conversation, {
    bool scrollToBottom = true,
  }) async {
    if (_searchTargetMessageId != null && mounted) {
      setState(() => _searchTargetMessageId = null);
    }
    if (_currentConversation?.id == conversation.id) {
      _scaffoldKey.currentState?.closeDrawer();
      return;
    }
    _scaffoldKey.currentState?.closeDrawer();
    if (_isBusy) {
      _stopGenerating();
      while (_isBusy && mounted) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      if (!mounted) return;
    }
    final messages = await _messagesWithGreeting(
      conversation.id,
      _profile,
      isGroup: conversation.isGroup,
    );
    if (!mounted) return;
    setState(() {
      _currentConversation = conversation;
      _messages = messages;
      _groupScope = conversation.isGroup;
    });
    if (scrollToBottom) _scrollToBottom(jump: true);
  }

  Future<void> _deleteConversation(Conversation conversation) async {
    if (_isBusy) {
      _stopGenerating();
      while (_isBusy && mounted) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      if (!mounted) return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除这段对话？'),
        content: Text(
          '“${conversation.title}”会从这台设备删除。由这段对话产生的共同记忆、回应偏好和心绪也会一并清除。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
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
        .where((item) => item.id != conversation.id)
        .toList();
    if (remaining.isEmpty) {
      if (_groupScope) {
        await _chatStore.saveGroupConversations(const []);
        if (!mounted) return;
        setState(() {
          _conversations = const [];
          _currentConversation = null;
          _messages = const [];
        });
        return;
      }
      if (!mounted) return;
      setState(() => _conversations = const []);
      await _newConversation();
      return;
    }
    await _saveScopedConversations(remaining);
    if (_currentConversation?.id == conversation.id) {
      final next = remaining.first;
      final messages = await _messagesWithGreeting(
        next.id,
        _profile,
        isGroup: next.isGroup,
      );
      if (!mounted) return;
      setState(() {
        _conversations = remaining;
        _currentConversation = next;
        _messages = messages;
      });
    } else if (mounted) {
      setState(() => _conversations = remaining);
    }
  }

  Future<void> _reloadRelationshipState() async {
    final characters = await _chatStore.loadCharacters();
    final memories = <String, List<String>>{};
    final moods = <String, String>{};
    for (final character in characters) {
      memories[character.id] = await _chatStore.loadMemories(
        characterId: character.id,
      );
      final mood = _normalizeMood(
        await _chatStore.loadCharacterMood(character.id),
      );
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
    final controller = TextEditingController(text: conversation.title);
    final title = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('修改对话名称'),
        content: TextField(
          controller: controller,
          onTapOutside: (_) => FocusScope.of(context).unfocus(),
          autofocus: false,
          maxLength: 30,
          decoration: const InputDecoration(labelText: '名称'),
          onSubmitted: (value) => Navigator.pop(context, value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (title == null || title.isEmpty || title == conversation.title) return;
    final updated = conversation.copyWith(
      title: title,
      updatedAt: DateTime.now(),
    );
    final conversations = _conversations
        .map((item) => item.id == updated.id ? updated : item)
        .toList();
    await _saveScopedConversations(conversations);
    if (!mounted) return;
    setState(() {
      _conversations = conversations;
      if (_currentConversation?.id == updated.id) {
        _currentConversation = updated;
      }
    });
  }

  Future<void> _reloadProviders() async {
    var providers = await _providerStore.loadProviders();
    final selectedId = await _providerStore.loadSelectedProviderId();
    var selected = providers.firstWhere(
      (provider) => provider.id == selectedId,
      orElse: () => providers.first,
    );
    final legacyPrompt = await _chatStore.loadGlobalSystemPrompt();
    if (legacyPrompt.isNotEmpty && selected.selectedModel.isNotEmpty) {
      if (selected.systemPromptForModel().isEmpty) {
        final prompts = Map<String, String>.from(selected.modelSystemPrompts)
          ..[selected.selectedModel] = legacyPrompt;
        selected = selected.copyWith(modelSystemPrompts: prompts);
        providers = providers
            .map((item) => item.id == selected.id ? selected : item)
            .toList();
        await _providerStore.saveProviders(providers);
      }
      await _chatStore.saveGlobalSystemPrompt('');
    }
    if (!mounted) return;
    setState(() {
      _providers = providers;
      _selectedProvider = selected;
    });
  }

  Future<void> _openChatSearch() async {
    _scaffoldKey.currentState?.closeDrawer();
    final result = await Navigator.of(context).push<ChatSearchResult>(
      MaterialPageRoute<ChatSearchResult>(
        builder: (_) => ChatSearchScreen(characters: _characters),
      ),
    );
    if (result == null || !mounted) return;
    await _openSearchResult(result);
  }

  Future<void> _openSearchResult(ChatSearchResult result) async {
    final conversation = result.conversation;
    if (conversation.isGroup) {
      if (!_groupScope) await _switchToGroupScope();
    } else {
      CharacterProfile? targetProfile;
      for (final character in _characters) {
        if (character.id == conversation.characterId) {
          targetProfile = character;
          break;
        }
      }
      if (targetProfile == null) {
        _showMessage('这段对话对应的角色已不存在');
        return;
      }
      if (_groupScope || _profile.id != targetProfile.id) {
        await _switchCharacter(targetProfile);
      }
    }
    if (!mounted) return;

    Conversation? targetConversation;
    for (final item in _conversations) {
      if (item.id == conversation.id) {
        targetConversation = item;
        break;
      }
    }
    if (targetConversation == null) {
      _showMessage('这段对话已不存在');
      return;
    }

    await _selectConversation(targetConversation, scrollToBottom: false);
    if (!mounted) return;

    final targetIndex = _messages.indexWhere(
      (message) => message.id == result.message.id,
    );
    if (targetIndex < 0) {
      _showMessage('这条聊天记录已经不存在');
      return;
    }

    var branchChanged = false;
    final updatedMessages = [..._messages];
    for (final binding in result.message.branchBindings.entries) {
      final ancestorIndex = updatedMessages.indexWhere(
        (message) => message.id == binding.key,
      );
      if (ancestorIndex < 0) continue;
      final ancestor = updatedMessages[ancestorIndex];
      final variantIndex = ancestor.replyVariants.indexWhere(
        (variant) => variant.id == binding.value,
      );
      if (variantIndex < 0 || ancestor.activeVariantIndex == variantIndex) {
        continue;
      }
      updatedMessages[ancestorIndex] = ancestor.selectVariant(variantIndex);
      branchChanged = true;
    }

    if (branchChanged) {
      setState(() => _messages = updatedMessages);
      final current = _currentConversation;
      if (current != null) {
        await _chatStore.saveMessages(current.id, _messages);
      }
      if (!mounted) return;
    }

    if (!_isMessageVisible(_messages[targetIndex])) {
      _showMessage('这条记录所在的回复分支暂时无法定位');
      return;
    }

    setState(() {
      _followStreamingOutput = false;
      _searchTargetMessageId = result.message.id;
      _searchTargetRequest++;
    });
  }

  Future<void> _openProviderSettings() async {
    _scaffoldKey.currentState?.closeDrawer();
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const ApiSettingsScreen()),
    );
    await _reloadProviders();
  }

  Future<bool> _ensureProviderConfigured() async {
    final provider = _selectedProvider;
    final key = provider == null
        ? ''
        : await _providerStore.loadApiKey(provider.id);
    if (provider?.isConfigured == true && key.trim().isNotEmpty) return true;
    if (!mounted) return false;
    await _openProviderSettings();
    final updated = _selectedProvider;
    final updatedKey = updated == null
        ? ''
        : await _providerStore.loadApiKey(updated.id);
    return updated?.isConfigured == true && updatedKey.trim().isNotEmpty;
  }

  Future<void> _applyModelChoice(ChatModelChoice choice) async {
    final updatedProvider = choice.provider.copyWith(
      selectedModel: choice.model,
    );
    final providers = _providers
        .map(
          (provider) =>
              provider.id == updatedProvider.id ? updatedProvider : provider,
        )
        .toList();
    await _providerStore.saveProviders(providers);
    await _providerStore.saveSelectedProviderId(updatedProvider.id);
    if (!mounted) return;
    setState(() {
      _providers = providers;
      _selectedProvider = updatedProvider;
    });
  }

  Future<void> _showChatModelPicker() async {
    final available = _providers
        .where((provider) => provider.models.isNotEmpty)
        .toList();
    if (available.isEmpty) {
      await _openProviderSettings();
      return;
    }

    final choice = await showChatModelPickerSheet(
      context: context,
      providers: _providers,
      selectedProvider: _selectedProvider,
      onManageProviders: () {
        unawaited(_openProviderSettings());
      },
    );
    if (choice != null) await _applyModelChoice(choice);
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _loading) return;
    final userMessage = ChatMessage(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      author: MessageAuthor.user,
      text: text,
      sentAt: DateTime.now(),
      branchBindings: _activeBranchBindings(),
    );
    setState(() {
      _messages.add(userMessage);
      _controller.clear();
      _followStreamingOutput = true;
    });
    _scrollToBottom(force: true);
    await _updateConversationTitle(text);
    await _persistMessages();
    unawaited(
      _proactiveCoordinator.postponeCurrent(characters: _characters),
    );
    await _queueReply();
  }

  Map<String, String> _activeVariantIdsFor(List<ChatMessage> messages) {
    return <String, String>{
      for (final message in messages)
        if (message.activeVariant case final variant?)
          message.id: variant.id,
    };
  }

  bool _isVisibleWithActiveVariants(
    ChatMessage message,
    Map<String, String> activeVariantIds,
  ) {
    for (final binding in message.branchBindings.entries) {
      if (activeVariantIds[binding.key] != binding.value) return false;
    }
    return true;
  }

  List<ChatMessage> _visibleMessagesFor(List<ChatMessage> messages) {
    final activeVariantIds = _activeVariantIdsFor(messages);
    return [
      for (final message in messages)
        if (_isVisibleWithActiveVariants(message, activeVariantIds)) message,
    ];
  }

  Map<String, String> _activeBranchBindings() {
    final bindings = <String, String>{};
    final activeVariantIds = _activeVariantIdsFor(_messages);
    for (final message in _messages) {
      if (!_isVisibleWithActiveVariants(message, activeVariantIds)) continue;
      final variant = message.activeVariant;
      if (message.author == MessageAuthor.character &&
          message.replyVariants.length > 1 &&
          variant != null) {
        bindings[message.id] = variant.id;
      }
    }
    return bindings;
  }

  bool _isMessageVisible(ChatMessage message) {
    return _isVisibleWithActiveVariants(
      message,
      _activeVariantIdsFor(_messages),
    );
  }

  List<int> get _visibleMessageIndices {
    final activeVariantIds = _activeVariantIdsFor(_messages);
    return [
      for (var index = 0; index < _messages.length; index++)
        if (_isVisibleWithActiveVariants(_messages[index], activeVariantIds))
          index,
    ];
  }

  CharacterProfile? _characterForId(String id) {
    for (final character in _characters) {
      if (character.id == id) return character;
    }
    return null;
  }

  String _moodForCharacter(String characterId) {
    return _normalizeMood(_characterMoods[characterId] ?? '');
  }

  List<CharacterProfile> get _groupParticipants {
    final ids = _currentConversation?.participantIds ?? const <String>[];
    return _characters.where((item) => ids.contains(item.id)).toList();
  }

  String _speakerName(ChatMessage message) {
    if (message.speakerCharacterId.isEmpty) return _profile.name;
    return _characterForId(message.speakerCharacterId)?.name ?? '已删除角色';
  }

  List<ChatMessage> _historyForModel(List<ChatMessage> history) {
    if (_currentConversation?.isGroup != true) return history;
    return history.map((message) {
      if (message.author == MessageAuthor.system) return message;
      final speaker = message.author == MessageAuthor.user
          ? '用户'
          : _speakerName(message);
      return message.editText('$speaker：${message.text}');
    }).toList();
  }

  Future<void> _queueReply() async {
    _replyQueued = true;
    if (_drainingReplies) return;
    _drainingReplies = true;
    try {
      while (_replyQueued && mounted) {
        _replyQueued = false;
        if (!await _ensureProviderConfigured()) return;
        if (_currentConversation?.isGroup == true) {
          await _requestGroupReplies();
        } else {
          await _requestReply();
        }
      }
    } finally {
      _drainingReplies = false;
    }
  }

  Future<void> _requestGroupReplies() async {
    _cancelled = false;
    final participants = _groupParticipants;
    if (participants.length < 2) {
      _showMessage('这个群聊的有效角色不足两个');
      return;
    }
    final visible = _visibleMessagesFor(_messages);
    ChatMessage? latestUser;
    for (var index = visible.length - 1; index >= 0; index--) {
      if (visible[index].author == MessageAuthor.user) {
        latestUser = visible[index];
        break;
      }
    }
    final spokenIds = <String>[];
    final scheduledSpeakers = <CharacterProfile>[];
    var userReplyCovered = !GroupReplyPolicy.latestUserNeedsReply(visible);
    var lastSpeakerId = '';
    for (var index = visible.length - 1; index >= 0; index--) {
      final message = visible[index];
      if (message.author == MessageAuthor.character &&
          message.speakerCharacterId.isNotEmpty) {
        lastSpeakerId = message.speakerCharacterId;
        break;
      }
    }
    const maxGroupTurns = 7;
    for (var turn = 0; turn < maxGroupTurns; turn++) {
      if (!mounted || _cancelled) return;
      final requireSpeaker = latestUser != null && !userReplyCovered;
      if (scheduledSpeakers.isEmpty) {
        scheduledSpeakers.addAll(
          await _selectGroupSpeakers(
            participants: participants,
            spokenIds: spokenIds,
            lastSpeakerId: lastSpeakerId,
          ),
        );
      }
      if (!mounted || _cancelled) return;
      if (scheduledSpeakers.isEmpty && requireSpeaker) {
        final fallbackId = GroupReplyPolicy.fallbackSpeakerId(
          participants.map((item) => item.id).toList(),
          lastSpeakerId: lastSpeakerId,
          seed: latestUser.id,
        );
        final fallback = fallbackId == null
            ? null
            : _characterForId(fallbackId);
        if (fallback != null) scheduledSpeakers.add(fallback);
      }
      if (scheduledSpeakers.isEmpty) break;
      final speaker = scheduledSpeakers.removeAt(0);
      final beforeCount = _messages.length;
      await _requestReply(characterOverride: speaker);
      if (_cancelled || _messages.length <= beforeCount) break;
      final latest = _messages.last;
      if (latest.author != MessageAuthor.character ||
          latest.text.trim().isEmpty) {
        break;
      }
      spokenIds.add(speaker.id);
      lastSpeakerId = speaker.id;
      final latestVisible = _visibleMessagesFor(_messages);
      userReplyCovered = !GroupReplyPolicy.latestUserNeedsReply(latestVisible);
      if (!userReplyCovered) {
        for (var index = latestVisible.length - 1; index >= 0; index--) {
          if (latestVisible[index].author == MessageAuthor.user) {
            latestUser = latestVisible[index];
            break;
          }
        }
      }
    }
  }

  Future<List<CharacterProfile>> _selectGroupSpeakers({
    required List<CharacterProfile> participants,
    required List<String> spokenIds,
    required String lastSpeakerId,
  }) async {
    final provider = _selectedProvider;
    if (provider == null) return const [];
    final apiKey = await _providerStore.loadApiKey(provider.id);
    if (apiKey.trim().isEmpty) return const [];
    final visible = _visibleMessagesFor(_messages);
    final start = visible.length > 16 ? visible.length - 16 : 0;
    final transcript = visible
        .sublist(start)
        .map((message) {
          final speaker = message.author == MessageAuthor.user
              ? '用户'
              : message.author == MessageAuthor.character
              ? _speakerName(message)
              : '系统';
          return '$speaker：${message.text}';
        })
        .join('\n');
    final roster = participants
        .map((character) {
          final moodValue = _moodForCharacter(character.id);
          final mood = moodValue.isEmpty ? '' : '；当前心绪：$moodValue';
          return '- ${character.name}$mood；'
              '用户好感度：${character.userIntimacy}/100'
              '（${_intimacyLabel(character.userIntimacy)}）';
        })
        .join('\n');
    final candidates = participants
        .where((character) => character.id != lastSpeakerId)
        .toList();
    if (candidates.isEmpty) candidates.addAll(participants);
    final spokenNames = spokenIds
        .map(_characterForId)
        .whereType<CharacterProfile>()
        .map((character) => character.name)
        .join('、');
    final lastSpeakerName = _characterForId(lastSpeakerId)?.name ?? '';
    if (mounted) setState(() => _evaluatingGroupIntents = true);
    try {
      final intents = await _groupIntentEvaluator.evaluateCandidates(
        candidates: candidates,
        provider: provider,
        apiKey: apiKey,
        transcript: transcript,
        roster: roster,
        spokenNames: spokenNames,
        lastSpeakerName: lastSpeakerName,
        characterMemories: _characterMemories,
        moodForCharacter: _moodForCharacter,
        intimacyBehavior: _intimacyBehavior,
      );
      if (_cancelled) return const [];
      final seed = visible.isEmpty ? '' : visible.last.id;
      final rankedIds = GroupReplyPolicy.rankWillingSpeakers(
        intents,
        spokenIds: spokenIds,
        lastSpeakerId: lastSpeakerId,
        seed: seed,
      );
      return rankedIds
          .map(_characterForId)
          .whereType<CharacterProfile>()
          .toList();
    } finally {
      if (mounted) setState(() => _evaluatingGroupIntents = false);
    }
  }

  Future<void> _requestReply({
    ProviderProfile? providerOverride,
    int? targetReplyIndex,
    CharacterProfile? characterOverride,
  }) async {
    final provider = providerOverride ?? _selectedProvider;
    if (provider == null) return;
    final apiKey = await _providerStore.loadApiKey(provider.id);
    if (apiKey.trim().isEmpty) {
      _showError('这个供应商还没有 API Key');
      return;
    }

    final isRetry = targetReplyIndex != null;
    final replyConversationId = _currentConversation?.id ?? '';
    var speakingCharacter = characterOverride ?? _profile;
    late final int replyIndex;
    ChatMessage? originalReply;
    ChatMessage? newReply;
    ReplyVariant? streamingVariant;
    List<ChatMessage>? retrySnapshot;
    if (isRetry) {
      if (targetReplyIndex < 0 || targetReplyIndex >= _messages.length) return;
      replyIndex = targetReplyIndex;
      originalReply = _messages[replyIndex];
      final originalSpeaker = _characterForId(originalReply.speakerCharacterId);
      if (characterOverride == null && originalSpeaker != null) {
        speakingCharacter = originalSpeaker;
      }
      retrySnapshot = List<ChatMessage>.from(_messages);
      streamingVariant = ReplyVariant(
        id: 'variant-${DateTime.now().microsecondsSinceEpoch}',
        text: '',
        generatedAt: DateTime.now(),
        providerId: provider.id,
        modelId: provider.selectedModel,
      );
    } else {
      newReply = ChatMessage(
        id: 'reply-${DateTime.now().microsecondsSinceEpoch}',
        author: MessageAuthor.character,
        text: '',
        sentAt: DateTime.now(),
        branchBindings: _activeBranchBindings(),
        speakerCharacterId: speakingCharacter.id,
      );
      replyIndex = _messages.length;
    }

    setState(() {
      if (isRetry) {
        final previousVariantId =
            originalReply!.activeVariant?.id ?? 'original-${originalReply.id}';
        final activeVariantIds = _activeVariantIdsFor(_messages);
        final visibleDescendants = <int>[
          for (var index = replyIndex + 1; index < _messages.length; index++)
            if (_isVisibleWithActiveVariants(
              _messages[index],
              activeVariantIds,
            ))
              index,
        ];
        for (final index in visibleDescendants) {
          final descendant = _messages[index];
          if (descendant.branchBindings.containsKey(originalReply.id)) {
            continue;
          }
          _messages[index] = descendant.copyWith(
            branchBindings: {
              ...descendant.branchBindings,
              originalReply.id: previousVariantId,
            },
          );
        }
        _messages[replyIndex] = originalReply.addVariant(streamingVariant!);
        _activeReplyId = originalReply.id;
        _activeRetryIndex = replyIndex;
        _activeRetrySnapshot = retrySnapshot;
      } else if (newReply != null) {
        _messages.add(newReply);
        _activeReplyId = newReply.id;
      }
      _generating = true;
      _cancelled = false;
    });
    _scrollToBottom();

    final contextMessages = _visibleMessagesFor(
      _messages.take(replyIndex).toList(),
    );
    final systemPrompt = _assembledSystemPrompt(
      contextMessages: contextMessages,
      character: speakingCharacter,
    );
    final recent = _historyForModel(
      _messagesWithinBudget(contextMessages, systemPrompt),
    );
    final service = AiChatService();
    _activeService = service;
    final streamState = ReplyStreamAccumulator();
    var replyCompleted = false;
    try {
      await for (final event in service.streamEvents(
        provider: provider,
        apiKey: apiKey,
        systemPrompt: systemPrompt,
        history: recent,
      )) {
        streamState.add(event);
        if (!mounted || _cancelled) return;
        if (event.kind != AiStreamEventKind.usage) {
          final reasoningDurationMs = streamState.reasoningDurationMs();
          setState(() {
            if (isRetry) {
              final current = _messages[replyIndex];
              final variants = [...current.replyVariants];
              variants[current.activeVariantIndex] = streamingVariant!.copyWith(
                text: _visibleReplyWhileStreaming(streamState.fullReply),
                reasoning: streamState.fullReasoning,
                reasoningDurationMs: reasoningDurationMs,
              );
              _messages[replyIndex] = current.copyWith(replyVariants: variants);
            } else {
              _messages[replyIndex] = newReply!.copyWith(
                text: _visibleReplyWhileStreaming(streamState.fullReply),
                reasoning: streamState.fullReasoning,
                reasoningDurationMs: reasoningDurationMs,
              );
            }
          });
          if (event.kind == AiStreamEventKind.content ||
              reasoningDurationMs < 500) {
            _scrollToBottom();
          }
        }
      }
      final parsedReply = _splitMoodFromReply(streamState.fullReply);
      final replyText = parsedReply.text;
      if (!_cancelled && replyText.isEmpty) {
        throw const AiChatException('模型没有返回文字，请检查模型 ID 和接口类型');
      }
      if (!_cancelled && mounted) {
        final reasoningDurationMs = streamState.reasoningDurationMs();
        final variant = ReplyVariant(
          id:
              streamingVariant?.id ??
              'variant-${DateTime.now().microsecondsSinceEpoch}',
          text: replyText,
          generatedAt: DateTime.now(),
          providerId: provider.id,
          modelId: provider.selectedModel,
          reasoning: streamState.fullReasoning.trim(),
          reasoningDurationMs: reasoningDurationMs,
          promptTokens: streamState.usage.promptTokens,
          completionTokens: streamState.usage.completionTokens,
          reasoningTokens: streamState.usage.reasoningTokens,
          totalTokens: streamState.usage.totalTokens,
        );
        final previousMood = _moodForCharacter(speakingCharacter.id);
        final nextMood = parsedReply.mood.toUpperCase() == 'SAME'
            ? previousMood
            : parsedReply.mood;
        setState(() {
          if (isRetry) {
            final current = _messages[replyIndex];
            final variants = [...current.replyVariants];
            variants[current.activeVariantIndex] = variant;
            _messages[replyIndex] = current.copyWith(replyVariants: variants);
          } else {
            _messages[replyIndex] = newReply!.copyWith(
              text: replyText,
              reasoning: streamState.fullReasoning.trim(),
              reasoningDurationMs: reasoningDurationMs,
              promptTokens: streamState.usage.promptTokens,
              completionTokens: streamState.usage.completionTokens,
              reasoningTokens: streamState.usage.reasoningTokens,
              totalTokens: streamState.usage.totalTokens,
              replyVariants: [variant],
              activeVariantIndex: 0,
            );
          }
          if (nextMood.isNotEmpty) {
            _characterMoods = {
              ..._characterMoods,
              speakingCharacter.id: nextMood,
            };
            if (speakingCharacter.id == _profile.id) {
              _characterMood = nextMood;
            }
          }
        });
        if (nextMood.isNotEmpty) {
          await _chatStore.saveCharacterMood(nextMood, speakingCharacter.id);
          if (replyConversationId.isNotEmpty) {
            await _chatStore.saveCharacterMoodSource(
              speakingCharacter.id,
              replyConversationId,
            );
          }
        }
        if (nextMood.isEmpty && replyConversationId.isNotEmpty) {
          await _repairMoodFromLatestTurn(
            provider: provider,
            apiKey: apiKey,
            contextMessages: contextMessages,
            replyText: replyText,
            character: speakingCharacter,
            conversationId: replyConversationId,
            sourceReplyId: isRetry ? originalReply!.id : newReply!.id,
            previousMood: previousMood,
          );
        }
        replyCompleted = true;
      }
    } on AiChatException catch (error) {
      if (!_cancelled && mounted) {
        if (isRetry) {
          setState(() => _messages = retrySnapshot!);
        } else if (_messages.length > replyIndex && streamState.fullReply.isEmpty) {
          setState(() => _messages.removeAt(replyIndex));
        }
        _showError(error.message);
      }
    } on Object catch (error) {
      if (!_cancelled && mounted) {
        if (isRetry) {
          setState(() => _messages = retrySnapshot!);
        } else if (_messages.length > replyIndex && streamState.fullReply.isEmpty) {
          setState(() => _messages.removeAt(replyIndex));
        }
        _showError('回复失败：$error');
      }
    } finally {
      service.close();
      if (identical(_activeService, service)) _activeService = null;
      if (mounted) {
        setState(() {
          _generating = false;
          _activeReplyId = null;
          _activeRetryIndex = null;
          _activeRetrySnapshot = null;
        });
        unawaited(_persistMessages());
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
      }
    }
  }

  void _stopGenerating() {
    _cancelled = true;
    _activeService?.close();
    _groupIntentEvaluator.cancel();
    setState(() {
      _evaluatingGroupIntents = false;
      final retryIndex = _activeRetryIndex;
      final retrySnapshot = _activeRetrySnapshot;
      if (retryIndex != null &&
          retrySnapshot != null &&
          retryIndex < _messages.length) {
        _messages = retrySnapshot;
      } else {
        final activeReplyId = _activeReplyId;
        if (activeReplyId != null) {
          final index = _messages.indexWhere(
            (message) => message.id == activeReplyId && message.text.isEmpty,
          );
          if (index >= 0) _messages.removeAt(index);
        }
      }
    });
    unawaited(_persistMessages());
  }

  Future<void> _retryReply(int replyIndex, RetryModelOption option) async {
    if (_isBusy) return;
    FocusManager.instance.primaryFocus?.unfocus();
    final source = _providers.firstWhere(
      (item) => item.id == option.providerId,
      orElse: () => _providers.first,
    );
    final provider = source.copyWith(selectedModel: option.modelId);
    await _requestReply(
      providerOverride: provider,
      targetReplyIndex: replyIndex,
    );
  }

  Future<void> _moveVariant(int messageIndex, int delta) async {
    if (_isBusy || messageIndex < 0 || messageIndex >= _messages.length) {
      return;
    }
    final message = _messages[messageIndex];
    final target = message.activeVariantIndex + delta;
    if (target < 0 || target >= message.replyVariants.length) return;
    setState(() {
      _messages[messageIndex] = message.selectVariant(target);
    });
    await _persistMessages();
  }

  Future<void> _toggleLike(int messageIndex) async {
    if (messageIndex < 0 || messageIndex >= _messages.length) return;
    final original = _messages[messageIndex];
    final updated = original.toggleLike();
    setState(() => _messages[messageIndex] = updated);
    await _persistMessages();
    if (!mounted) return;
    _showMessage(updated.isLiked ? '已加入收藏' : '已取消收藏');
  }

  Future<void> _editMessage(int messageIndex) async {
    if (_isBusy || messageIndex < 0 || messageIndex >= _messages.length) {
      return;
    }
    final original = _messages[messageIndex];
    final controller = TextEditingController(text: original.text);
    final value = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(
          18,
          2,
          18,
          MediaQuery.viewInsetsOf(context).bottom + 18,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '编辑消息',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              onTapOutside: (_) => FocusScope.of(context).unfocus(),
              autofocus: false,
              minLines: 3,
              maxLines: 12,
              decoration: const InputDecoration(
                alignLabelWithHint: true,
                filled: true,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              child: const Text('保存修改'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    if (value == null || value.isEmpty || value == original.text) return;
    setState(() => _messages[messageIndex] = original.editText(value));
    await _persistMessages();
  }

  Future<void> _extractStylePreference(
    int messageIndex,
    ChatMessage likedReply,
  ) async {
    final sourceConversationId = _currentConversation?.id ?? '';
    final sourceCharacterId = likedReply.speakerCharacterId.isEmpty
        ? _profile.id
        : likedReply.speakerCharacterId;
    if (sourceConversationId.isEmpty || sourceCharacterId.isEmpty) return;
    var userContext = '';
    for (var index = messageIndex - 1; index >= 0; index--) {
      if (_messages[index].author == MessageAuthor.user) {
        userContext = _messages[index].text;
        break;
      }
    }
    final variant = likedReply.activeVariant;
    ProviderProfile? provider;
    if (variant != null && variant.providerId.isNotEmpty) {
      for (final item in _providers) {
        if (item.id == variant.providerId) {
          provider = item;
          break;
        }
      }
    }
    provider ??= _selectedProvider;
    if (provider == null) return;
    if (variant != null && variant.modelId.isNotEmpty) {
      provider = provider.copyWith(selectedModel: variant.modelId);
    }
    final apiKey = await _providerStore.loadApiKey(provider.id);
    if (apiKey.trim().isEmpty || !mounted) return;

    try {
      final rule = await _auxiliaryAiService.extractStylePreference(
        provider: provider,
        apiKey: apiKey,
        userContext: userContext,
        likedReplyText: likedReply.text,
      );
      if (rule.isEmpty) return;
      final conversations = await _chatStore.loadConversations();
      if (!conversations.any((item) => item.id == sourceConversationId)) return;
      final added = await _chatStore.addStylePreference(
        rule,
        sourceConversationId: sourceConversationId,
        sourceCharacterId: sourceCharacterId,
      );
      if (!added) {
        if (mounted) _showMessage('这条回复没有产生新的回应偏好');
        return;
      }
      final latest = await _chatStore.loadStylePreferences(
        characterId: sourceCharacterId,
      );
      if (!mounted) return;
      setState(() {
        _characterStylePreferences = {
          ..._characterStylePreferences,
          sourceCharacterId: latest,
        };
        if (_profile.id == sourceCharacterId) _stylePreferences = latest;
      });
      _showMessage('已提炼回应偏好，可在“记忆与世界”中编辑');
    } on Object {
      if (mounted) {
        _showMessage('偏好提炼失败，可在“记忆与世界”中手动添加');
      }
    }
  }

  Future<void> _openFavorites() async {
    _scaffoldKey.currentState?.closeDrawer();
    final entries = <FavoriteReplyEntry>[];
    final loadedMessages = await Future.wait([
      for (final conversation in _conversations)
        _chatStore.loadMessages(conversation.id),
    ]);
    for (var conversationIndex = 0;
        conversationIndex < _conversations.length;
        conversationIndex++) {
      final conversation = _conversations[conversationIndex];
      final messages = loadedMessages[conversationIndex];
      for (final message in messages) {
        if (message.author != MessageAuthor.character) continue;
        for (final variant in message.replyVariants) {
          if (!variant.isLiked) continue;
          entries.add(
            FavoriteReplyEntry(
              conversationTitle: conversation.title,
              characterName: _speakerName(message),
              text: variant.text,
              generatedAt: variant.generatedAt,
              modelId: variant.modelId,
            ),
          );
        }
      }
    }
    entries.sort((a, b) => b.generatedAt.compareTo(a.generatedAt));
    if (!mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => FavoritesScreen(entries: entries),
      ),
    );
  }

  Future<void> _updateConversationTitle(String text) async {
    final current = _currentConversation;
    if (current == null ||
        (current.title != '新对话' && current.title != '第一次见面')) {
      return;
    }
    final compact = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    final title = compact.characters.length > 18
        ? '${compact.characters.take(18).join()}…'
        : compact;
    final updated = current.copyWith(title: title, updatedAt: DateTime.now());
    final conversations = _conversations
        .map((item) => item.id == updated.id ? updated : item)
        .toList();
    await _saveScopedConversations(conversations);
    if (!mounted) return;
    setState(() {
      _currentConversation = updated;
      _conversations = conversations;
    });
  }

  Future<void> _persistMessages() async {
    final current = _currentConversation;
    if (current == null) return;
    final conversationId = current.id;
    final messagesSnapshot = List<ChatMessage>.from(_messages);
    final updatedAt = DateTime.now();

    final operation = _persistQueue.then((_) async {
      await _chatStore.saveMessages(conversationId, messagesSnapshot);
      final updated = current.copyWith(updatedAt: updatedAt);
      await _chatStore.saveConversation(updated);
      if (!mounted || _currentConversation?.id != conversationId) return;
      setState(() {
        _currentConversation = updated;
        _conversations =
            _conversations
                .map((item) => item.id == updated.id ? updated : item)
                .toList()
              ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      });
    });
    _persistQueue = operation.catchError((Object _) {});
    await operation;
  }

  String _currentBranchKey() {
    final entries = _activeBranchBindings().entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    if (entries.isEmpty) return 'root';
    return entries.map((entry) => '${entry.key}=${entry.value}').join('|');
  }

  String _assembledSystemPrompt({
    List<ChatMessage>? contextMessages,
    CharacterProfile? character,
  }) {
    final activeCharacter = character ?? _profile;
    return ChatContextBuilder.buildSystemPrompt(
      activeCharacter: activeCharacter,
      selectedProvider: _selectedProvider,
      userProfile: _userProfile,
      activeMemories:
          _characterMemories[activeCharacter.id] ?? const <String>[],
      stylePreferences:
          _characterStylePreferences[activeCharacter.id] ??
          (_profile.id == activeCharacter.id
              ? _stylePreferences
              : const <String>[]),
      worldBooks: _worldBooks,
      visibleMessages: _visibleMessagesFor(_messages),
      currentConversation: _currentConversation,
      branchKey: _currentBranchKey(),
      groupParticipants: _groupParticipants,
      savedMood: _moodForCharacter(activeCharacter.id),
      contextMessages: contextMessages,
      now: DateTime.now().toLocal(),
    );
  }

  ChatMessage _sanitizeMoodMetadataInMessage(ChatMessage message) {
    if (message.author != MessageAuthor.character) return message;
    final cleanedText = MoodCodec.stripMetadata(message.text);
    if (message.replyVariants.isEmpty) {
      return cleanedText == message.text
          ? message
          : message.copyWith(text: cleanedText);
    }
    final variants = [
      for (final variant in message.replyVariants)
        variant.copyWith(text: MoodCodec.stripMetadata(variant.text)),
    ];
    return message.copyWith(text: cleanedText, replyVariants: variants);
  }

  bool _messageMoodMetadataChanged(
    ChatMessage original,
    ChatMessage cleaned,
  ) {
    if (original.text != cleaned.text) return true;
    if (original.replyVariants.length != cleaned.replyVariants.length) {
      return true;
    }
    for (var i = 0; i < original.replyVariants.length; i++) {
      if (original.replyVariants[i].text != cleaned.replyVariants[i].text) {
        return true;
      }
    }
    return false;
  }

  String _visibleReplyWhileStreaming(String raw) {
    return MoodCodec.visibleTextWhileStreaming(raw);
  }

  _TaggedReply _splitMoodFromReply(String raw) {
    final parsed = MoodCodec.parse(raw);
    return _TaggedReply(
      text: parsed.text.trim(),
      mood: parsed.mood,
      status: '',
    );
  }

  String _normalizeMood(String raw) => MoodCodec.normalizeMood(raw);

  Future<void> _repairMoodFromLatestTurn({
    required ProviderProfile provider,
    required String apiKey,
    required List<ChatMessage> contextMessages,
    required String replyText,
    required CharacterProfile character,
    required String conversationId,
    required String sourceReplyId,
    required String previousMood,
  }) async {
    if (replyText.trim().isEmpty) return;
    ChatMessage? latestUser;
    for (var index = contextMessages.length - 1; index >= 0; index--) {
      if (contextMessages[index].author == MessageAuthor.user) {
        latestUser = contextMessages[index];
        break;
      }
    }
    if (latestUser == null) return;

    final service = AiChatService();
    var raw = '';
    try {
      final request = ChatMessage(
        id: 'mood-repair-${DateTime.now().microsecondsSinceEpoch}',
        author: MessageAuthor.user,
        text:
            '上一轮心绪：${previousMood.isEmpty ? '未记录' : previousMood}\n\n'
            '用户最新消息：${latestUser.text}\n\n'
            '${character.name}的本轮回复：$replyText',
        sentAt: DateTime.now(),
      );
      await for (final chunk in service.streamReply(
        provider: provider,
        apiKey: apiKey,
        systemPrompt:
            '主回复已经完成，你只补齐遗漏的角色心绪，不生成正文。'
            '必须根据这一轮真实对话重新判断，不能为了变化而强行变化，也不能机械沿用。'
            '心绪由角色自己决定写什么，只要真实反映此刻即可；最多10个字符，'
            '可用文字、emoji、符号或混合表达，但不要使用颜文字。'
            '若上一轮已有心绪且你判断本轮没有实质变化，输出 SAME；上一轮未记录时不得输出 SAME。'
            '严格只输出“[[心绪:结果]]”，不解释，不添加其他文字。',
        history: [request],
        temperature: 0.1,
      )) {
        raw += chunk;
      }
      if (!mounted || _currentConversation?.id != conversationId) return;
      ChatMessage? currentLatestUser;
      for (var index = _messages.length - 1; index >= 0; index--) {
        if (_messages[index].author == MessageAuthor.user) {
          currentLatestUser = _messages[index];
          break;
        }
      }
      if (currentLatestUser?.id != latestUser.id) return;
      ChatMessage? currentReply;
      for (final message in _messages) {
        if (message.id == sourceReplyId) {
          currentReply = message;
          break;
        }
      }
      if (currentReply == null || currentReply.text.trim() != replyText.trim()) {
        return;
      }

      final repaired = _splitMoodFromReply(raw);
      if (repaired.mood.isEmpty) return;
      final mood = repaired.mood.toUpperCase() == 'SAME'
          ? previousMood
          : repaired.mood;
      if (mood.isEmpty) return;
      setState(() {
        _characterMoods = {..._characterMoods, character.id: mood};
        if (_profile.id == character.id) _characterMood = mood;
      });
      await _chatStore.saveCharacterMood(mood, character.id);
      await _chatStore.saveCharacterMoodSource(character.id, conversationId);
    } on Object {
      // Keep the last valid mood when the optional repair request fails.
    } finally {
      service.close();
    }
  }

  Future<void> _maybeExtractRelationshipMemory({
    required CharacterProfile character,
    required ProviderProfile provider,
    required String apiKey,
  }) async {
    if (!_autoMemoryEnabled || apiKey.trim().isEmpty || _memoryPromptActive) {
      return;
    }
    final current = _currentConversation;
    if (current == null ||
        current.isGroup ||
        current.characterId != character.id) {
      return;
    }
    final conversationId = current.id;
    final visible = _visibleMessagesFor(_messages)
        .where((message) => message.author != MessageAuthor.system)
        .toList();
    final userTurns = visible
        .where((message) => message.author == MessageAuthor.user)
        .length;
    if (userTurns < 24 || userTurns % 24 != 0) return;
    final marker = '$conversationId|$userTurns';
    if (!_autoMemoryExtractionMarkers.add(marker)) return;
    final sourceBranchKey = _currentBranchKey();
    _memoryPromptActive = true;

    final start = visible.length > 40 ? visible.length - 40 : 0;
    final recent = visible.sublist(start);
    final transcript = recent
        .map((message) {
          final speaker = message.author == MessageAuthor.user
              ? '用户'
              : character.name;
          return '$speaker：${message.text}';
        })
        .join('\n');
    final existing = _characterMemories[character.id] ?? const <String>[];
    final existingText = existing.isEmpty
        ? '无'
        : existing.take(20).map((item) => '- $item').join('\n');
    try {
      final memory = await _auxiliaryAiService.suggestRelationshipMemory(
        provider: provider,
        apiKey: apiKey,
        existingText: existingText,
        transcript: transcript,
      );
      if (memory.isEmpty || !mounted) return;
      if (_currentConversation?.id != conversationId ||
          _currentBranchKey() != sourceBranchKey) {
        return;
      }
      final currentUserTurns = _messages
          .where(_isMessageVisible)
          .where((message) => message.author == MessageAuthor.user)
          .length;
      if (currentUserTurns != userTurns) return;

      final controller = TextEditingController(text: memory);
      final approved = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('写入共同记忆？'),
          content: TextField(
            controller: controller,
            onTapOutside: (_) => FocusScope.of(context).unfocus(),
            autofocus: false,
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
              onPressed: () => Navigator.pop(context, controller.text.trim()),
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
        _characterMemories = {..._characterMemories, character.id: latest};
        if (_profile.id == character.id) _memories = latest;
      });
    } on Object {
      // Memory extraction is optional; never invalidate a successful reply.
    } finally {
      _memoryPromptActive = false;
    }
  }

  List<ChatMessage> _messagesWithinBudget(
    List<ChatMessage> messages,
    String systemPrompt,
  ) {
    final summarizedThrough =
        _currentConversation?.summarizedThroughMessageIds[_currentBranchKey()] ??
        '';
    return ChatContextBuilder.messagesWithinBudget(
      messages: messages,
      systemPrompt: systemPrompt,
      contextTokenBudget: _contextTokenBudget,
      summarizedThroughMessageId: summarizedThrough,
    );
  }

  int _estimateTokens(String text) => ChatContextBuilder.estimateTokens(text);

  Future<void> _maybeOfferCompression() async {
    if (!mounted ||
        _loading ||
        _isBusy ||
        _compressionPromptActive ||
        _memoryPromptActive) {
      return;
    }
    final current = _currentConversation;
    if (current == null) return;
    final visible = _visibleMessagesFor(_messages);
    final branchKey = _currentBranchKey();
    final promptKey = '${current.id}|$branchKey';
    final promptedAt = _compressionPromptedAtCounts[promptKey] ?? 0;
    if (visible.length < 20 || visible.length < promptedAt + 10) {
      return;
    }
    final markerId = current.summarizedThroughMessageIds[branchKey] ?? '';
    var start = 0;
    if (markerId.isNotEmpty) {
      final marker = visible.indexWhere((message) => message.id == markerId);
      if (marker >= 0) start = marker + 1;
    }
    final unsummarized = visible.sublist(start);
    final estimated = unsummarized.fold<int>(
      0,
      (total, message) => total + _estimateTokens(message.text) + 12,
    );
    if (estimated < (_contextTokenBudget * 0.82).round()) return;

    _compressionPromptActive = true;
    _compressionPromptedAtCounts[promptKey] = visible.length;
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('这段对话有点长了'),
          content: const Text(
            '可以把当前分支较早的内容整理成一份短摘要，后续聊天会更省 token。原始消息和其他分支仍会完整保留。',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('暂不'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(context, true),
              icon: const Icon(Icons.compress_rounded),
              label: const Text('压缩历史'),
            ),
          ],
        ),
      );
      if (confirmed == true) await _compressCurrentBranch();
    } finally {
      _compressionPromptActive = false;
    }
  }

  Future<void> _compressCurrentBranch() async {
    if (!await _ensureProviderConfigured()) return;
    final provider = _selectedProvider;
    final current = _currentConversation;
    if (provider == null || current == null || !mounted) return;
    final apiKey = await _providerStore.loadApiKey(provider.id);
    if (apiKey.trim().isEmpty || !mounted) return;

    final visible = _visibleMessagesFor(_messages);
    if (visible.length <= 14) return;
    final branchKey = _currentBranchKey();
    final markerId = current.summarizedThroughMessageIds[branchKey] ?? '';
    var start = 0;
    if (markerId.isNotEmpty) {
      final marker = visible.indexWhere((message) => message.id == markerId);
      if (marker >= 0) start = marker + 1;
    }
    final end = visible.length - 12;
    if (end <= start) {
      _showMessage('目前没有需要继续压缩的旧内容');
      return;
    }
    final segment = visible.sublist(start, end);
    final transcript = segment
        .map((message) {
          final speaker = message.author == MessageAuthor.user
              ? '用户'
              : message.author == MessageAuthor.character
              ? _speakerName(message)
              : '系统';
          return '$speaker：${message.text}';
        })
        .join('\n\n');
    final previousSummary = current.branchSummaries[branchKey] ?? '';

    BuildContext? progressContext;
    unawaited(
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          progressContext = context;
          return const AlertDialog(
            content: Row(
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 18),
                Expanded(child: Text('正在整理这段关系里的重要内容…')),
              ],
            ),
          );
        },
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 80));

    try {
      final summary = await _auxiliaryAiService.summarizeConversation(
        provider: provider,
        apiKey: apiKey,
        previousSummary: previousSummary,
        transcript: transcript,
      );
      final updated = current.copyWith(
        branchSummaries: {...current.branchSummaries, branchKey: summary},
        summarizedThroughMessageIds: {
          ...current.summarizedThroughMessageIds,
          branchKey: segment.last.id,
        },
        updatedAt: DateTime.now(),
      );
      final conversations = _conversations
          .map((item) => item.id == updated.id ? updated : item)
          .toList();
      await _saveScopedConversations(conversations);
      if (!mounted) return;
      setState(() {
        _currentConversation = updated;
        _conversations = conversations;
      });
      _showMessage('历史已压缩，原始消息仍完整保留');
    } on Object catch (error) {
      if (mounted) _showError('压缩失败：$error');
    } finally {
      final dialogContext = progressContext;
      if (dialogContext != null && dialogContext.mounted) {
        Navigator.of(dialogContext).pop();
      }
    }
  }

  void _showMessage(String message) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(milliseconds: 1600),
      ),
    );
  }

  void _showError(String message) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(label: '设置', onPressed: _openProviderSettings),
      ),
    );
  }

  Future<void> _openAppSettings() async {
    _scaffoldKey.currentState?.closeDrawer();
    final restored = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => AppSettingsScreen(
          reasoningExpanded: _reasoningExpanded,
          contextTokenBudget: _contextTokenBudget,
          autoMemoryEnabled: _autoMemoryEnabled,
          userProfile: _userProfile,
          onSave:
              (
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
        ),
      ),
    );
    if (restored == true) {
      await _restore();
    } else if (mounted) {
      await _syncProactiveSchedule();
    }
  }

  Future<void> _openMemories() async {
    _scaffoldKey.currentState?.closeDrawer();
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => MemoryScreen(
          characterId: _profile.id,
          characterName: _profile.name,
        ),
      ),
    );
    final memories = await _chatStore.loadMemories(characterId: _profile.id);
    final preferences = await _chatStore.loadStylePreferences(
      characterId: _profile.id,
    );
    final worldBooks = await _chatStore.loadWorldBooks();
    if (!mounted) return;
    setState(() {
      _memories = memories;
      _characterMemories = {..._characterMemories, _profile.id: memories};
      _stylePreferences = preferences;
      _characterStylePreferences = {
        ..._characterStylePreferences,
        _profile.id: preferences,
      };
      _worldBooks = worldBooks;
    });
  }

  Future<void> _showCharacterPicker() async {
    final scaffold = _scaffoldKey.currentState;
    if (scaffold?.isDrawerOpen == true) {
      scaffold!.closeDrawer();
      await Future<void>.delayed(const Duration(milliseconds: 120));
      if (!mounted) return;
    }

    final choice = await showConversationSpacePickerSheet(
      context: context,
      characters: _characters,
      currentProfile: _profile,
      groupScope: _groupScope,
    );
    if (choice == null) return;

    switch (choice.action) {
      case ConversationSpaceAction.add:
        await _createCharacter();
        return;
      case ConversationSpaceAction.delete:
        final character = _characters.firstWhere(
          (item) => item.id == choice.characterId,
        );
        await _deleteCharacter(character);
        return;
      case ConversationSpaceAction.groups:
        if (!_groupScope) await _switchToGroupScope();
        return;
      case ConversationSpaceAction.character:
        if (!_groupScope && choice.characterId == _profile.id) return;
        final selected = _characters.firstWhere(
          (item) => item.id == choice.characterId,
        );
        await _switchCharacter(selected);
        return;
    }
  }

  Future<void> _createCharacter() async {
    final draft = CharacterProfile.newCharacter(DateTime.now());
    final created = await Navigator.of(context).push<CharacterProfile>(
      MaterialPageRoute<CharacterProfile>(
        builder: (_) => CharacterScreen(profile: draft),
      ),
    );
    if (created == null) return;
    final characters = [..._characters, created];
    await _chatStore.saveCharacters(characters);
    if (!mounted) return;
    setState(() => _characters = characters);
    await _switchCharacter(created);
  }

  Future<void> _deleteCharacter(CharacterProfile character) async {
    if (_characters.length <= 1) {
      _showMessage('至少保留一个角色');
      return;
    }
    if (_isBusy) {
      _stopGenerating();
      while (_isBusy && mounted) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    }
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除这个角色？'),
        content: Text(
          '将删除“${character.name}”的角色设定和单聊记录。'
          '群聊中会移除这个角色；移除后不足两人的群聊也会一并删除。'
          '此操作不可撤销。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final remainingCharacters = _characters
        .where((item) => item.id != character.id)
        .toList();
    final remainingById = {
      for (final item in remainingCharacters) item.id: item,
    };
    final allConversations = await _chatStore.loadConversations();
    final keptConversations = <Conversation>[];
    final deletedConversationIds = <String>[];
    final updatedGroups = <Conversation>[];

    for (final conversation in allConversations) {
      if (!conversation.isGroup && conversation.characterId == character.id) {
        deletedConversationIds.add(conversation.id);
        continue;
      }
      if (conversation.isGroup &&
          conversation.participantIds.contains(character.id)) {
        final participantIds = conversation.participantIds
            .where((id) => id != character.id)
            .toList();
        if (participantIds.length < 2) {
          deletedConversationIds.add(conversation.id);
          continue;
        }
        final updated = conversation.copyWith(
          participantIds: participantIds,
          branchSummaries: const {},
          summarizedThroughMessageIds: const {},
          updatedAt: DateTime.now(),
        );
        keptConversations.add(updated);
        updatedGroups.add(updated);
        continue;
      }
      keptConversations.add(conversation);
    }

    for (final conversationId in deletedConversationIds) {
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
    for (final group in updatedGroups) {
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
              ..removeWhere(
                (messageId, _) => removedMessageIds.contains(messageId),
              );
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
        cleanedMessages[rosterIndex] = cleanedMessages[rosterIndex].editText(
          '群聊成员：$names',
        );
      }
      await _chatStore.saveMessages(group.id, cleanedMessages);
    }
    await _chatStore.saveConversations(keptConversations);
    await _chatStore.saveCharacters(remainingCharacters);
    await _chatStore.clearCharacterState(character.id);
    unawaited(
      _proactiveCoordinator.reschedule(characters: remainingCharacters),
    );

    final remainingMemoryMap = Map<String, List<String>>.from(
      _characterMemories,
    )..remove(character.id);
    final remainingMoodMap = Map<String, String>.from(_characterMoods)
      ..remove(character.id);
    var nextProfile = _profile;
    var nextMood = _characterMood;
    var nextMemories = _memories;
    if (_profile.id == character.id) {
      nextProfile = remainingCharacters.first;
      await _chatStore.saveSelectedCharacterId(nextProfile.id);
      nextMood = _normalizeMood(
        await _chatStore.loadCharacterMood(nextProfile.id),
      );
      nextMemories = await _chatStore.loadMemories(characterId: nextProfile.id);
      remainingMemoryMap[nextProfile.id] = nextMemories;
      if (nextMood.isNotEmpty) remainingMoodMap[nextProfile.id] = nextMood;
    }
    if (!mounted) return;

    if (_groupScope) {
      final groups = keptConversations.where((item) => item.isGroup).toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      Conversation? current;
      final currentId = _currentConversation?.id;
      for (final group in groups) {
        if (group.id == currentId) {
          current = group;
          break;
        }
      }
      current ??= groups.isEmpty ? null : groups.first;
      final messages = current == null
          ? <ChatMessage>[]
          : await _messagesWithGreeting(current.id, nextProfile, isGroup: true);
      if (!mounted) return;
      setState(() {
        _characters = remainingCharacters;
        _profile = nextProfile;
        _memories = nextMemories;
        _characterMemories = remainingMemoryMap;
        _characterMood = nextMood;
        _characterMoods = remainingMoodMap;
        _conversations = groups;
        _currentConversation = current;
        _messages = messages;
        _groupScope = true;
      });
    } else if (_profile.id == character.id) {
      setState(() {
        _characters = remainingCharacters;
        _profile = nextProfile;
        _memories = nextMemories;
        _characterMemories = remainingMemoryMap;
        _characterMood = nextMood;
        _characterMoods = remainingMoodMap;
      });
      await _switchCharacter(nextProfile);
    } else {
      setState(() {
        _characters = remainingCharacters;
        _characterMemories = remainingMemoryMap;
        _characterMoods = remainingMoodMap;
      });
    }
    if (mounted) _showMessage('已删除角色“${character.name}”');
  }

  Future<bool> _stopBusyWorkBeforeNavigation() async {
    if (!_isBusy) return true;
    _stopGenerating();
    final deadline = DateTime.now().add(const Duration(seconds: 2));
    while (_isBusy && mounted && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    if (!_isBusy) return true;
    if (mounted) _showMessage('当前回复仍在结束，请稍后再试');
    return false;
  }

  Future<void> _switchCharacter(CharacterProfile profile) async {
    if (!await _stopBusyWorkBeforeNavigation()) return;
    await _chatStore.saveSelectedCharacterId(profile.id);
    final loaded = await Future.wait<Object>([
      _chatStore.loadConversations(characterId: profile.id),
      _chatStore.loadMemories(characterId: profile.id),
      _chatStore.loadStylePreferences(characterId: profile.id),
      _chatStore.loadCharacterMood(profile.id),
    ]);
    final conversations = loaded[0] as List<Conversation>;
    final memories = loaded[1] as List<String>;
    final stylePreferences = loaded[2] as List<String>;
    final mood = _normalizeMood(loaded[3] as String);
    final current = conversations.first;
    final messages = await _messagesWithGreeting(
      current.id,
      profile,
      isGroup: current.isGroup,
    );
    if (!mounted) return;
    setState(() {
      _profile = profile;
      _memories = memories;
      _characterMemories = {..._characterMemories, profile.id: memories};
      _stylePreferences = stylePreferences;
      _characterStylePreferences = {
        ..._characterStylePreferences,
        profile.id: stylePreferences,
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
    _scrollToBottom(jump: true);
  }

  Future<void> _switchToGroupScope() async {
    if (!await _stopBusyWorkBeforeNavigation()) return;
    final conversations = await _chatStore.loadGroupConversations();
    final current = conversations.isEmpty ? null : conversations.first;
    final messages = current == null
        ? <ChatMessage>[]
        : await _messagesWithGreeting(current.id, _profile, isGroup: true);
    if (!mounted) return;
    setState(() {
      _groupScope = true;
      _conversations = conversations;
      _currentConversation = current;
      _messages = messages;
    });
    _scrollToBottom(jump: true);
    if (current == null) await _newGroupConversation();
  }

  Future<void> _editCharacter() async {
    _scaffoldKey.currentState?.closeDrawer();
    final updated = await Navigator.of(context).push<CharacterProfile>(
      MaterialPageRoute<CharacterProfile>(
        builder: (_) => CharacterScreen(
          profile: _profile.copyWith(status: _normalizeMood(_characterMood)),
        ),
      ),
    );
    if (updated == null) return;
    await _chatStore.saveProfile(updated);
    if (!mounted) return;
    setState(() {
      _profile = updated;
      _characters = _characters
          .map((item) => item.id == updated.id ? updated : item)
          .toList();
    });
    unawaited(
      _proactiveCoordinator.postponeCurrent(characters: _characters),
    );
  }

  Future<void> _saveUserIntimacy(int value) async {
    final updated = _profile.copyWith(userIntimacy: value);
    final characters = _characters
        .map((item) => item.id == updated.id ? updated : item)
        .toList();
    await _chatStore.saveCharacters(characters);
    if (!mounted) return;
    setState(() {
      _characters = characters;
      if (_profile.id == updated.id) _profile = updated;
    });
  }

  bool _isMessageVisibleIn(
    List<ChatMessage> messages,
    ChatMessage message,
  ) {
    for (final binding in message.branchBindings.entries) {
      ChatMessage? ancestor;
      for (final candidate in messages) {
        if (candidate.id == binding.key) {
          ancestor = candidate;
          break;
        }
      }
      if (ancestor == null || ancestor.activeVariant?.id != binding.value) {
        return false;
      }
    }
    return true;
  }

  Map<String, String> _activeBranchBindingsFor(List<ChatMessage> messages) {
    final bindings = <String, String>{};
    for (final message in messages) {
      if (!_isMessageVisibleIn(messages, message)) continue;
      final variant = message.activeVariant;
      if (message.author == MessageAuthor.character &&
          message.replyVariants.length > 1 &&
          variant != null) {
        bindings[message.id] = variant.id;
      }
    }
    return bindings;
  }

  Future<void> _syncProactiveSchedule() async {
    _proactiveTimer?.cancel();
    if (_loading || _characters.isEmpty) return;
    final plan = await _proactiveCoordinator.ensureScheduled(
      characters: _characters,
    );
    if (!mounted) return;
    _armProactiveTimer(plan);
  }

  void _armProactiveTimer(ProactiveMessagePlan? plan) {
    _proactiveTimer?.cancel();
    _proactiveTimer = null;
    if (plan == null || !mounted) return;
    final delay = plan.dueAt.difference(DateTime.now());
    _proactiveTimer = Timer(
      delay.isNegative ? Duration.zero : delay,
      () => unawaited(_checkDueProactiveMessage()),
    );
  }

  Future<void> _checkDueProactiveMessage() async {
    if (_checkingProactiveMessage || _loading || _characters.isEmpty) {
      return;
    }
    if (_isBusy) {
      _proactiveTimer?.cancel();
      _proactiveTimer = Timer(
        const Duration(seconds: 30),
        () => unawaited(_checkDueProactiveMessage()),
      );
      return;
    }
    _checkingProactiveMessage = true;
    ProactiveMessagePlan? consumed;
    try {
      consumed = await _proactiveCoordinator.consumeDue(
        characters: _characters,
      );
      if (consumed == null) return;
      await _generateProactiveMessage(consumed);
    } on Object {
      // Proactive messages are optional and must never disrupt normal chat.
    } finally {
      if (consumed != null) {
        final next = await _proactiveCoordinator.scheduleAfterConsumed(
          characters: _characters,
          consumed: consumed,
        );
        if (mounted) _armProactiveTimer(next);
      }
      _checkingProactiveMessage = false;
      if (consumed == null && mounted) {
        unawaited(_syncProactiveSchedule());
      }
    }
  }

  Future<void> _generateProactiveMessage(ProactiveMessagePlan plan) async {
    CharacterProfile? character;
    for (final item in _characters) {
      if (item.id == plan.characterId) {
        character = item;
        break;
      }
    }
    if (character == null) return;

    final provider = _selectedProvider;
    if (provider == null) return;
    final apiKey = await _providerStore.loadApiKey(provider.id);
    if (apiKey.trim().isEmpty) return;

    final conversations = await _chatStore.loadConversations(
      characterId: character.id,
    );
    if (conversations.isEmpty) return;
    final targetConversation = conversations.first;
    final storedMessages = await _chatStore.loadMessages(targetConversation.id);
    final visible = storedMessages
        .where(
          (message) =>
              message.author != MessageAuthor.system &&
              _isMessageVisibleIn(storedMessages, message),
        )
        .toList();
    final start = visible.length > 12 ? visible.length - 12 : 0;
    final transcript = visible
        .sublist(start)
        .map(
          (message) =>
              '${message.author == MessageAuthor.user ? '用户' : character!.name}：'
              '${MoodCodec.stripMetadata(message.text).trim()}',
        )
        .where((line) => !line.endsWith('：'))
        .join('\n');
    final memories =
        _characterMemories[character.id] ??
        await _chatStore.loadMemories(characterId: character.id);
    final mood =
        _characterMoods[character.id] ??
        await _chatStore.loadCharacterMood(character.id);

    final text = await _auxiliaryAiService.generateProactiveMessage(
      provider: provider,
      apiKey: apiKey,
      character: character,
      userProfile: _userProfile,
      memories: memories,
      recentTranscript: transcript,
      currentMood: mood,
    );
    if (text.trim().isEmpty) return;

    final now = DateTime.now();
    final newMessage = ChatMessage(
      id: 'proactive-${now.microsecondsSinceEpoch}',
      author: MessageAuthor.character,
      text: text.trim(),
      sentAt: now,
      branchBindings: _activeBranchBindingsFor(storedMessages),
      speakerCharacterId: character.id,
    );
    final updatedMessages = [...storedMessages, newMessage];
    await _chatStore.saveMessages(targetConversation.id, updatedMessages);

    final updatedConversation = targetConversation.copyWith(updatedAt: now);
    final updatedConversations = conversations
        .map(
          (conversation) => conversation.id == updatedConversation.id
              ? updatedConversation
              : conversation,
        )
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    await _chatStore.saveConversations(
      updatedConversations,
      characterId: character.id,
    );

    if (!mounted || _groupScope || _profile.id != character.id) return;
    setState(() {
      _conversations = updatedConversations;
      if (_currentConversation?.id == targetConversation.id) {
        _currentConversation = updatedConversation;
        _messages = updatedMessages;
        _followStreamingOutput = true;
      }
    });
    if (_currentConversation?.id == targetConversation.id) {
      _scrollToBottom(force: true);
    }
  }

  void _scrollToBottom({bool jump = false, bool force = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      if (!jump &&
          !force &&
          (_pointerHoldingMessages || !_followStreamingOutput)) {
        return;
      }
      final position = _scrollController.position.maxScrollExtent;
      if (jump || (_generating && !force)) {
        _scrollController.jumpTo(position);
      } else {
        _scrollController.animateTo(
          position,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  void _updateStreamingFollow() {
    if (!_scrollController.hasClients) return;
    final distance =
        _scrollController.position.maxScrollExtent -
        _scrollController.position.pixels;
    final follow = distance <= 72;
    if (follow != _followStreamingOutput && mounted) {
      setState(() => _followStreamingOutput = follow);
    }
  }

  void _resumeStreamingFollow() {
    setState(() => _followStreamingOutput = true);
    _scrollToBottom(force: true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _proactiveTimer?.cancel();
    _cancelled = true;
    _activeService?.close();
    _groupIntentEvaluator.dispose();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final overlay = isDark
        ? SystemUiOverlayStyle.light
        : SystemUiOverlayStyle.dark;
    final isGroup = _groupScope;
    final headerTitle = isGroup
        ? (_currentConversation?.title ?? '群聊')
        : _profile.name;
    final mood = _normalizeMood(_characterMood);
    final characterStatus = isGroup
        ? (_currentConversation == null
              ? '暂无群聊'
              : (_evaluatingGroupIntents
                    ? '角色正在判断是否接话…'
                    : (_generating
                          ? '群聊中…'
                          : '${_groupParticipants.length} 位角色')))
        : mood;
    final visibleMessageIndices = _visibleMessageIndices;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlay.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Theme.of(context).colorScheme.surface,
      ),
      child: Scaffold(
        key: _scaffoldKey,
        drawer: ConversationDrawer(
          profile: _profile,
          currentMood: mood,
          groupScope: _groupScope,
          conversations: _conversations,
          selectedId: _currentConversation?.id,
          onNew: _newConversation,
          onNewGroup: _newGroupConversation,
          onSearch: _openChatSearch,
          onSelect: _selectConversation,
          onDelete: _deleteConversation,
          onRename: _renameConversation,
          onCharacterPicker: _showCharacterPicker,
          onIntimacyChanged: _saveUserIntimacy,
          onEditCharacter: _editCharacter,
          onFavorites: _openFavorites,
          onMemoryWorld: _openMemories,
          onSettings: _openProviderSettings,
          onAppSettings: _openAppSettings,
        ),
        appBar: AppBar(
          leading: IconButton(
            tooltip: '会话',
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
            icon: const Icon(Icons.menu_rounded),
          ),
          titleSpacing: 2,
          title: InkWell(
            onTap: _showCharacterPicker,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 3),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          headerTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 160),
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeInCubic,
                          child: characterStatus.isEmpty
                              ? const SizedBox.shrink()
                              : Text(
                                  characterStatus,
                                  key: ValueKey(characterStatus),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(
                    isGroup
                        ? Icons.groups_2_outlined
                        : Icons.swap_horiz_rounded,
                    size: 17,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: InkWell(
                onTap: _showChatModelPicker,
                borderRadius: BorderRadius.circular(22),
                child: Container(
                  constraints: const BoxConstraints(
                    minHeight: 42,
                    maxWidth: 146,
                  ),
                  padding: const EdgeInsets.fromLTRB(12, 4, 7, 4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _selectedProvider?.name ?? '选择供应商',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              _selectedProvider?.selectedModel ?? '选择模型',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 3),
                      const Icon(Icons.expand_more_rounded, size: 17),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Theme.of(context).colorScheme.surface,
                Theme.of(context).colorScheme.surfaceContainerLowest,
              ],
            ),
          ),
          child: Column(
            children: [
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _currentConversation == null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(28),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.groups_2_outlined,
                                size: 42,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                '还没有群聊',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                '从左侧会话栏创建一个群聊',
                                style: TextStyle(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ChatMessageList(
                        controller: _scrollController,
                        messages: _messages,
                        visibleMessageIndices: visibleMessageIndices,
                        generating: _generating,
                        busy: _isBusy,
                        activeRetryIndex: _activeRetryIndex,
                        activeReplyId: _activeReplyId,
                        reasoningExpanded: _reasoningExpanded,
                        providers: _providers,
                        speakerName: _speakerName,
                        followStreamingOutput: _followStreamingOutput,
                        targetMessageId: _searchTargetMessageId,
                        targetRequest: _searchTargetRequest,
                        onPointerHoldingChanged: (value) {
                          _pointerHoldingMessages = value;
                        },
                        onScrollActivity: _updateStreamingFollow,
                        onResumeStreamingFollow: _resumeStreamingFollow,
                        onEdit: _editMessage,
                        onMoveVariant: _moveVariant,
                        onLike: _toggleLike,
                        onLearnStyle: _extractStylePreference,
                        onRetryWithModel: _retryReply,
                      )
              ),
              ChatComposer(
                controller: _controller,
                enabled: !_loading && _currentConversation != null,
                generating: _isBusy,
                onSend: _send,
                onStop: _stopGenerating,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _intimacyLabel(int value) => ChatContextBuilder.intimacyLabel(value);

String _intimacyBehavior(int value) =>
    ChatContextBuilder.intimacyBehavior(value);

class _TaggedReply {
  const _TaggedReply({
    required this.text,
    required this.mood,
    this.status = '',
  });

  final String text;
  final String mood;
  final String status;
}
