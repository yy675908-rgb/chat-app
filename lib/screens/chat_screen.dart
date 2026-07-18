import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/character_profile.dart';
import '../models/chat_message.dart';
import '../models/conversation.dart';
import '../models/provider_profile.dart';
import '../models/world_book_entry.dart';
import '../services/ai_chat_service.dart';
import '../services/chat_store.dart';
import '../services/provider_store.dart';
import '../widgets/message_bubble.dart';
import 'api_settings_screen.dart';
import 'app_settings_screen.dart';
import 'character_screen.dart';
import 'favorites_screen.dart';
import 'memory_screen.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _chatStore = ChatStore();
  final _providerStore = ProviderStore();

  CharacterProfile _profile = CharacterProfile.lin(DateTime.now());
  List<Conversation> _conversations = const [];
  Conversation? _currentConversation;
  List<ChatMessage> _messages = [];
  List<String> _memories = [];
  List<String> _stylePreferences = [];
  List<WorldBookEntry> _worldBooks = [];
  String _characterMood = '';
  bool _reasoningExpanded = true;
  int _contextTokenBudget = 32000;
  List<ProviderProfile> _providers = const [];
  ProviderProfile? _selectedProvider;
  AiChatService? _activeService;
  String? _activeReplyId;
  bool _loading = true;
  bool _generating = false;
  bool _cancelled = false;
  bool _replyQueued = false;
  bool _drainingReplies = false;

  @override
  void initState() {
    super.initState();
    unawaited(_restore());
  }

  Future<void> _restore() async {
    final profile = await _chatStore.loadProfile();
    final memories = await _chatStore.loadMemories();
    final stylePreferences = await _chatStore.loadStylePreferences();
    final worldBooks = await _chatStore.loadWorldBooks();
    final characterMood = await _chatStore.loadCharacterMood();
    final reasoningExpanded = await _chatStore.loadReasoningExpanded();
    final contextTokenBudget = await _chatStore.loadContextTokenBudget();
    final conversations = await _chatStore.loadConversations();
    final providers = await _providerStore.loadProviders();
    final selectedId = await _providerStore.loadSelectedProviderId();
    final selected = providers.firstWhere(
      (provider) => provider.id == selectedId,
      orElse: () => providers.first,
    );
    await _providerStore.saveSelectedProviderId(selected.id);
    final current = conversations.first;
    final messages = await _messagesWithGreeting(current.id, profile);
    if (!mounted) return;
    setState(() {
      _profile = profile;
      _memories = memories;
      _stylePreferences = stylePreferences;
      _worldBooks = worldBooks;
      _characterMood = characterMood;
      _reasoningExpanded = reasoningExpanded;
      _contextTokenBudget = contextTokenBudget;
      _conversations = conversations;
      _currentConversation = current;
      _providers = providers;
      _selectedProvider = selected;
      _messages = messages;
      _loading = false;
    });
    _scrollToBottom(jump: true);
  }

  Future<List<ChatMessage>> _messagesWithGreeting(
    String conversationId,
    CharacterProfile profile,
  ) async {
    final messages = await _chatStore.loadMessages(conversationId);
    if (messages.isEmpty) {
      messages.add(
        ChatMessage(
          id: 'greeting-${DateTime.now().microsecondsSinceEpoch}',
          author: MessageAuthor.character,
          text: profile.greeting,
          sentAt: DateTime.now(),
        ),
      );
      await _chatStore.saveMessages(conversationId, messages);
    }
    return messages;
  }

  Future<void> _newConversation() async {
    if (_generating) {
      _stopGenerating();
      return;
    }
    final now = DateTime.now();
    final conversation = Conversation(
      id: 'conversation-${now.microsecondsSinceEpoch}',
      title: '新对话',
      createdAt: now,
      updatedAt: now,
    );
    final conversations = [conversation, ..._conversations];
    await _chatStore.saveConversations(conversations);
    final messages = await _messagesWithGreeting(conversation.id, _profile);
    if (!mounted) return;
    Navigator.of(context).maybePop();
    setState(() {
      _conversations = conversations;
      _currentConversation = conversation;
      _messages = messages;
    });
    _scrollToBottom(jump: true);
  }

  Future<void> _selectConversation(Conversation conversation) async {
    if (_currentConversation?.id == conversation.id) {
      Navigator.of(context).maybePop();
      return;
    }
    if (_generating) {
      _stopGenerating();
      return;
    }
    final messages = await _messagesWithGreeting(conversation.id, _profile);
    if (!mounted) return;
    Navigator.of(context).maybePop();
    setState(() {
      _currentConversation = conversation;
      _messages = messages;
    });
    _scrollToBottom(jump: true);
  }

  Future<void> _deleteConversation(Conversation conversation) async {
    if (_generating) {
      _stopGenerating();
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除这段对话？'),
        content: Text('“${conversation.title}”会从这台设备删除。'),
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
    await _chatStore.deleteConversation(conversation.id);
    final remaining = _conversations
        .where((item) => item.id != conversation.id)
        .toList();
    if (remaining.isEmpty) {
      if (!mounted) return;
      setState(() => _conversations = const []);
      await _newConversation();
      return;
    }
    await _chatStore.saveConversations(remaining);
    if (_currentConversation?.id == conversation.id) {
      final next = remaining.first;
      final messages = await _messagesWithGreeting(next.id, _profile);
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

  Future<void> _reloadProviders() async {
    final providers = await _providerStore.loadProviders();
    final selectedId = await _providerStore.loadSelectedProviderId();
    final selected = providers.firstWhere(
      (provider) => provider.id == selectedId,
      orElse: () => providers.first,
    );
    if (!mounted) return;
    setState(() {
      _providers = providers;
      _selectedProvider = selected;
    });
  }

  Future<void> _openProviderSettings() async {
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

  Future<_ModelChoice?> _showModelPicker(String title) async {
    if (_providers.isEmpty) {
      await _openProviderSettings();
      return null;
    }
    return showModalBottomSheet<_ModelChoice>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.72,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 12, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: '管理供应商',
                      onPressed: () {
                        Navigator.pop(context);
                        unawaited(_openProviderSettings());
                      },
                      icon: const Icon(Icons.tune_rounded),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 18),
                  children: [
                    for (final provider in _providers) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                        child: Text(
                          provider.name,
                          style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (provider.models.isEmpty)
                        ListTile(
                          title: const Text('尚未添加模型'),
                          subtitle: const Text('到供应商设置中手动填写或读取列表'),
                          onTap: () {
                            Navigator.pop(context);
                            unawaited(_openProviderSettings());
                          },
                        )
                      else
                        ...provider.models.map(
                          (model) => ListTile(
                            leading: Icon(
                              _selectedProvider?.id == provider.id &&
                                      _selectedProvider?.selectedModel == model
                                  ? Icons.check_circle_rounded
                                  : Icons.circle_outlined,
                            ),
                            title: Text(model),
                            onTap: () => Navigator.pop(
                              context,
                              _ModelChoice(provider: provider, model: model),
                            ),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _chooseModel() async {
    final choice = await _showModelPicker('选择模型');
    if (choice == null) return;
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

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _loading) return;
    final userMessage = ChatMessage(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      author: MessageAuthor.user,
      text: text,
      sentAt: DateTime.now(),
    );
    setState(() {
      _messages.add(userMessage);
      _controller.clear();
    });
    _scrollToBottom();
    await _updateConversationTitle(text);
    await _persistMessages();
    await _queueReply();
  }

  Future<void> _queueReply() async {
    _replyQueued = true;
    if (_drainingReplies) return;
    _drainingReplies = true;
    try {
      while (_replyQueued && mounted) {
        _replyQueued = false;
        if (!await _ensureProviderConfigured()) return;
        await _requestReply();
      }
    } finally {
      _drainingReplies = false;
    }
  }

  Future<void> _requestReply({
    ProviderProfile? providerOverride,
    int? targetReplyIndex,
  }) async {
    final provider = providerOverride ?? _selectedProvider;
    if (provider == null) return;
    final apiKey = await _providerStore.loadApiKey(provider.id);
    if (apiKey.trim().isEmpty) {
      _showError('这个供应商还没有 API Key');
      return;
    }

    final isRetry = targetReplyIndex != null;
    late final int replyIndex;
    ChatMessage? originalReply;
    ChatMessage? newReply;
    if (isRetry) {
      if (targetReplyIndex < 0 || targetReplyIndex >= _messages.length) return;
      replyIndex = targetReplyIndex;
      originalReply = _messages[replyIndex];
    } else {
      newReply = ChatMessage(
        id: 'reply-${DateTime.now().microsecondsSinceEpoch}',
        author: MessageAuthor.character,
        text: '',
        sentAt: DateTime.now(),
      );
      replyIndex = _messages.length;
    }

    setState(() {
      if (newReply != null) {
        _messages.add(newReply);
        _activeReplyId = newReply.id;
      }
      _generating = true;
      _cancelled = false;
    });
    _scrollToBottom();

    final contextMessages = _messages.take(replyIndex).toList();
    final systemPrompt = _assembledSystemPrompt();
    final recent = _messagesWithinBudget(contextMessages, systemPrompt);
    final service = AiChatService();
    _activeService = service;
    var fullReply = '';
    var fullReasoning = '';
    var usage = const AiTokenUsage();
    try {
      await for (final event in service.streamEvents(
        provider: provider,
        apiKey: apiKey,
        systemPrompt: systemPrompt,
        history: recent,
      )) {
        if (event.kind == AiStreamEventKind.content) {
          fullReply += event.text;
        } else if (event.kind == AiStreamEventKind.reasoning) {
          fullReasoning += event.text;
        } else if (event.usage != null) {
          usage = usage.merge(event.usage!);
        }
        if (!mounted || _cancelled) return;
        if (!isRetry && event.kind != AiStreamEventKind.usage) {
          setState(() {
            _messages[replyIndex] = newReply!.copyWith(
              text: _visibleReplyWhileStreaming(fullReply),
              reasoning: fullReasoning,
            );
          });
          _scrollToBottom();
        }
      }
      final parsedReply = _splitMoodFromReply(fullReply);
      final replyText = parsedReply.text;
      if (!_cancelled && replyText.isEmpty) {
        throw const AiChatException('模型没有返回文字，请检查模型 ID 和接口类型');
      }
      if (!_cancelled && mounted) {
        final variant = ReplyVariant(
          id: 'variant-${DateTime.now().microsecondsSinceEpoch}',
          text: replyText,
          generatedAt: DateTime.now(),
          providerId: provider.id,
          modelId: provider.selectedModel,
          reasoning: fullReasoning.trim(),
          promptTokens: usage.promptTokens,
          completionTokens: usage.completionTokens,
          reasoningTokens: usage.reasoningTokens,
          totalTokens: usage.totalTokens,
        );
        setState(() {
          if (isRetry) {
            _messages[replyIndex] = originalReply!.addVariant(variant);
          } else {
            _messages[replyIndex] = newReply!.copyWith(
              text: replyText,
              reasoning: fullReasoning.trim(),
              promptTokens: usage.promptTokens,
              completionTokens: usage.completionTokens,
              reasoningTokens: usage.reasoningTokens,
              totalTokens: usage.totalTokens,
              replyVariants: [variant],
              activeVariantIndex: 0,
            );
          }
          if (parsedReply.mood.isNotEmpty) {
            _characterMood = parsedReply.mood;
          }
        });
        if (parsedReply.mood.isNotEmpty) {
          unawaited(_chatStore.saveCharacterMood(parsedReply.mood));
        }
      }
    } on AiChatException catch (error) {
      if (!_cancelled && mounted) {
        if (!isRetry &&
            _messages.length > replyIndex &&
            fullReply.isEmpty) {
          setState(() => _messages.removeAt(replyIndex));
        }
        _showError(error.message);
      }
    } on Object catch (error) {
      if (!_cancelled && mounted) {
        if (!isRetry &&
            _messages.length > replyIndex &&
            fullReply.isEmpty) {
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
        });
        await _persistMessages();
      }
    }
  }

  void _stopGenerating() {
    _cancelled = true;
    _activeService?.close();
    final activeReplyId = _activeReplyId;
    if (activeReplyId != null) {
      final index = _messages.indexWhere(
        (message) => message.id == activeReplyId && message.text.isEmpty,
      );
      if (index >= 0) _messages.removeAt(index);
    }
    unawaited(_persistMessages());
  }

  Future<void> _retryReply(int replyIndex) async {
    if (_generating) return;
    final choice = await _showModelPicker('选择这次使用的模型');
    if (choice == null || !mounted) return;
    final provider = choice.provider.copyWith(selectedModel: choice.model);
    await _requestReply(
      providerOverride: provider,
      targetReplyIndex: replyIndex,
    );
  }

  Future<void> _moveVariant(int messageIndex, int delta) async {
    if (_generating || messageIndex < 0 || messageIndex >= _messages.length) {
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
    final shouldExtract = !original.isLiked;
    final updated = original.toggleLike();
    setState(() => _messages[messageIndex] = updated);
    await _persistMessages();
    if (!mounted) return;
    _showMessage(updated.isLiked ? '已喜欢并加入收藏' : '已取消喜欢');
    if (shouldExtract) {
      unawaited(_extractStylePreference(messageIndex, original));
    }
  }

  Future<void> _extractStylePreference(
    int messageIndex,
    ChatMessage likedReply,
  ) async {
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
    if (apiKey.trim().isEmpty) return;

    final service = AiChatService();
    var raw = '';
    try {
      final request = ChatMessage(
        id: 'preference-${DateTime.now().microsecondsSinceEpoch}',
        author: MessageAuthor.user,
        text: '用户当时说：$userContext\n'
            '用户喜欢的角色回复：${likedReply.text}',
        sentAt: DateTime.now(),
      );
      await for (final chunk in service.streamReply(
        provider: provider,
        apiKey: apiKey,
        systemPrompt: '把用户喜欢的一次回复提炼为一条可复用的说话偏好。'
            '只输出一行，格式必须为“当……时：……”。'
            '写清适用情境和回应方式，不复述原话，不写分析，不超过45个汉字。',
        history: [request],
        temperature: 0.2,
      )) {
        raw += chunk;
      }
      final rule = _cleanPreference(raw);
      if (rule.isEmpty) return;
      final added = await _chatStore.addStylePreference(rule);
      if (!added) return;
      final latest = await _chatStore.loadStylePreferences();
      if (!mounted) return;
      setState(() => _stylePreferences = latest);
      _showMessage('已提炼回应偏好，可在“记忆与世界”中编辑');
    } on Object {
      if (mounted) {
        _showMessage('回复已收藏；偏好提炼失败，可在“记忆与世界”中添加');
      }
    } finally {
      service.close();
    }
  }

  String _cleanPreference(String raw) {
    var value = raw
        .trim()
        .replaceAll(RegExp(r'^[-•*#\s]+'), '')
        .replaceAll(RegExp(r'\s+'), ' ');
    if (value.startsWith('“') && value.endsWith('”') && value.length > 2) {
      value = value.substring(1, value.length - 1);
    }
    if (value.characters.length > 70) {
      value = value.characters.take(70).join();
    }
    return value;
  }

  Future<void> _openFavorites() async {
    final entries = <FavoriteReplyEntry>[];
    for (final conversation in _conversations) {
      final messages = await _chatStore.loadMessages(conversation.id);
      for (final message in messages) {
        if (message.author != MessageAuthor.character) continue;
        for (final variant in message.replyVariants) {
          if (!variant.isLiked) continue;
          entries.add(
            FavoriteReplyEntry(
              conversationTitle: conversation.title,
              characterName: _profile.name,
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
    await _chatStore.saveConversations(conversations);
    if (!mounted) return;
    setState(() {
      _currentConversation = updated;
      _conversations = conversations;
    });
  }

  Future<void> _persistMessages() async {
    final current = _currentConversation;
    if (current == null) return;
    await _chatStore.saveMessages(current.id, _messages);
    final updated = current.copyWith(updatedAt: DateTime.now());
    final conversations = _conversations
        .map((item) => item.id == updated.id ? updated : item)
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    await _chatStore.saveConversations(conversations);
    if (!mounted) return;
    setState(() {
      _currentConversation = updated;
      _conversations = conversations;
    });
  }

  String _assembledSystemPrompt() {
    final now = DateTime.now().toLocal();
    ChatMessage? lastReply;
    for (var index = _messages.length - 1; index >= 0; index--) {
      final message = _messages[index];
      if (message.author == MessageAuthor.character &&
          message.text.trim().isNotEmpty) {
        lastReply = message;
        break;
      }
    }
    final elapsed = lastReply == null
        ? ''
        : '｜距上一轮：${_formatElapsed(now.difference(lastReply.sentAt))}';
    final context =
        '相识第 ${_profile.daysTogether} 天｜当前：${_formatPromptTime(now)}$elapsed';
    final memoryText = _memories.isEmpty
        ? ''
        : '\n\n你们共同确认的记忆：\n'
            '${_memories.map((memory) => '- $memory').join('\n')}';
    final preferenceText = _stylePreferences.isEmpty
        ? ''
        : '\n\n用户偏好的回应方式（仅在情境吻合时遵循）：\n'
            '${_stylePreferences.map((item) => '- $item').join('\n')}';
    final worldBookText = _matchedWorldBookPrompt();
    const moodInstruction = '\n\n回复正文结束后，必须另起一行输出“[[心绪:……]]”。'
        '其中只写角色此刻不超过12个字的心理活动、短语或表情；不要在正文解释这行。';
    return '${_profile.systemPrompt}\n\n'
        '$context$memoryText$preferenceText$worldBookText$moodInstruction';
  }

  String _matchedWorldBookPrompt() {
    if (_worldBooks.isEmpty || _messages.isEmpty) return '';
    final start = _messages.length > 12 ? _messages.length - 12 : 0;
    final recentText = _messages
        .sublist(start)
        .map((message) => message.text.toLowerCase())
        .join('\n');
    final matched = _worldBooks.where((entry) {
      if (!entry.enabled || entry.keywords.isEmpty) return false;
      return entry.keywords.any(
        (keyword) => recentText.contains(keyword.trim().toLowerCase()),
      );
    });
    final sections = <String>[];
    var used = 0;
    for (final entry in matched) {
      final section = '【${entry.title}】\n${entry.content.trim()}';
      final cost = _estimateTokens(section);
      if (sections.isNotEmpty && used + cost > 6000) break;
      sections.add(section);
      used += cost;
      if (used >= 6000) break;
    }
    return sections.isEmpty
        ? ''
        : '\n\n当前对话命中的世界书设定：\n${sections.join('\n\n')}';
  }

  String _visibleReplyWhileStreaming(String raw) {
    final marker = RegExp(r'\n?\[\[心绪\s*[:：]').firstMatch(raw);
    return (marker == null ? raw : raw.substring(0, marker.start)).trimRight();
  }

  _TaggedReply _splitMoodFromReply(String raw) {
    final match = RegExp(
      r'\[\[心绪\s*[:：]\s*(.*?)\s*\]\]',
      dotAll: true,
    ).firstMatch(raw);
    if (match == null) return _TaggedReply(text: raw.trim(), mood: '');
    final text = '${raw.substring(0, match.start)}${raw.substring(match.end)}'
        .trim();
    final mood = (match.group(1) ?? '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return _TaggedReply(text: text, mood: mood);
  }

  List<ChatMessage> _messagesWithinBudget(
    List<ChatMessage> messages,
    String systemPrompt,
  ) {
    var remaining = _contextTokenBudget - _estimateTokens(systemPrompt);
    if (remaining < 2048) remaining = 2048;
    final selected = <ChatMessage>[];
    for (var index = messages.length - 1; index >= 0; index--) {
      final message = messages[index];
      final cost = _estimateTokens(message.text) + 12;
      if (selected.isNotEmpty && cost > remaining) break;
      selected.add(message);
      remaining -= cost;
      if (remaining <= 0) break;
    }
    return selected.reversed.toList();
  }

  int _estimateTokens(String text) {
    var estimate = 0.0;
    for (final rune in text.runes) {
      if (rune <= 0x7f) {
        estimate += rune == 0x20 || rune == 0x0a ? 0.1 : 0.28;
      } else {
        estimate += 1;
      }
    }
    return estimate.ceil();
  }

  String _formatPromptTime(DateTime value) {
    String two(int number) => number.toString().padLeft(2, '0');
    return '${value.year}-${two(value.month)}-${two(value.day)} '
        '${two(value.hour)}:${two(value.minute)}';
  }

  String _formatElapsed(Duration duration) {
    if (duration.isNegative) return '刚刚';
    final days = duration.inDays;
    final hours = duration.inHours.remainder(24);
    final minutes = duration.inMinutes.remainder(60);
    if (days > 0) {
      return hours == 0 ? '$days天' : '$days天$hours小时';
    }
    if (duration.inHours > 0) {
      return minutes == 0
          ? '${duration.inHours}小时'
          : '${duration.inHours}小时$minutes分钟';
    }
    return duration.inMinutes <= 0 ? '刚刚' : '${duration.inMinutes}分钟';
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(label: '设置', onPressed: _openProviderSettings),
      ),
    );
  }

  Future<void> _openAppSettings() async {
    final restored = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => AppSettingsScreen(
          reasoningExpanded: _reasoningExpanded,
          contextTokenBudget: _contextTokenBudget,
          onSave: (reasoningExpanded, contextTokenBudget) async {
            await _chatStore.saveReasoningExpanded(reasoningExpanded);
            await _chatStore.saveContextTokenBudget(contextTokenBudget);
            if (!mounted) return;
            setState(() {
              _reasoningExpanded = reasoningExpanded;
              _contextTokenBudget = contextTokenBudget;
            });
          },
        ),
      ),
    );
    if (restored == true) await _restore();
  }

  Future<void> _openMemories() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const MemoryScreen()),
    );
    final memories = await _chatStore.loadMemories();
    final preferences = await _chatStore.loadStylePreferences();
    final worldBooks = await _chatStore.loadWorldBooks();
    if (!mounted) return;
    setState(() {
      _memories = memories;
      _stylePreferences = preferences;
      _worldBooks = worldBooks;
    });
  }

  Future<void> _editCharacter() async {
    final updated = await Navigator.of(context).push<CharacterProfile>(
      MaterialPageRoute<CharacterProfile>(
        builder: (_) => CharacterScreen(profile: _profile),
      ),
    );
    if (updated == null) return;
    await _chatStore.saveProfile(updated);
    if (!mounted) return;
    setState(() => _profile = updated);
  }

  void _scrollToBottom({bool jump = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final position = _scrollController.position.maxScrollExtent;
      if (jump) {
        _scrollController.jumpTo(position);
      } else {
        _scrollController.animateTo(
          position,
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _cancelled = true;
    _activeService?.close();
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
    final characterStatus = _generating
        ? '正在回复…'
        : (_characterMood.isNotEmpty
            ? _characterMood
            : (_profile.status == '在这里' ? '' : _profile.status));
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlay.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Theme.of(context).colorScheme.surface,
      ),
      child: Scaffold(
        key: _scaffoldKey,
        drawer: _ConversationDrawer(
          profile: _profile,
          conversations: _conversations,
          selectedId: _currentConversation?.id,
          onNew: _newConversation,
          onSelect: _selectConversation,
          onDelete: _deleteConversation,
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
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _profile.name,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (characterStatus.isNotEmpty)
                Text(
                  characterStatus,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w400,
                  ),
                ),
            ],
          ),
          actions: [
            TextButton.icon(
              onPressed: _chooseModel,
              icon: const Icon(Icons.expand_more_rounded, size: 17),
              iconAlignment: IconAlignment.end,
              label: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 112),
                child: Text(
                  _selectedProvider?.selectedModel.isNotEmpty == true
                      ? _selectedProvider!.selectedModel
                      : '选择模型',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ),
            IconButton(
              tooltip: '记忆与世界',
              onPressed: _openMemories,
              icon: const Icon(Icons.bookmark_border_rounded),
            ),
            const SizedBox(width: 4),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      controller: _scrollController,
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final message = _messages[index];
                        if (_generating &&
                            message.id == _activeReplyId &&
                            message.author == MessageAuthor.character &&
                            message.text.isEmpty &&
                            message.reasoning.isEmpty) {
                          return _ThinkingRow(name: _profile.name);
                        }
                        final canUseActions =
                            message.author == MessageAuthor.character &&
                            message.text.isNotEmpty &&
                            !_generating;
                        return MessageBubble(
                          message: message,
                          characterName: _profile.name,
                          reasoningInitiallyExpanded: _reasoningExpanded,
                          showActions:
                              message.author == MessageAuthor.character &&
                              message.text.isNotEmpty,
                          onPreviousVariant: canUseActions &&
                                  message.activeVariantIndex > 0
                              ? () => _moveVariant(index, -1)
                              : null,
                          onNextVariant: canUseActions &&
                                  message.activeVariantIndex <
                                      message.replyVariants.length - 1
                              ? () => _moveVariant(index, 1)
                              : null,
                          onLike: canUseActions
                              ? () => _toggleLike(index)
                              : null,
                          onRetry: canUseActions
                              ? () => _retryReply(index)
                              : null,
                        );
                      },
                    ),
            ),
            _Composer(
              controller: _controller,
              enabled: !_loading,
              generating: _generating,
              onSend: _send,
              onStop: _stopGenerating,
            ),
          ],
        ),
      ),
    );
  }
}

class _ConversationDrawer extends StatelessWidget {
  const _ConversationDrawer({
    required this.profile,
    required this.conversations,
    required this.selectedId,
    required this.onNew,
    required this.onSelect,
    required this.onDelete,
    required this.onEditCharacter,
    required this.onFavorites,
    required this.onMemoryWorld,
    required this.onSettings,
    required this.onAppSettings,
  });

  final CharacterProfile profile;
  final List<Conversation> conversations;
  final String? selectedId;
  final VoidCallback onNew;
  final ValueChanged<Conversation> onSelect;
  final ValueChanged<Conversation> onDelete;
  final VoidCallback onEditCharacter;
  final VoidCallback onFavorites;
  final VoidCallback onMemoryWorld;
  final VoidCallback onSettings;
  final VoidCallback onAppSettings;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 10, 8),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: scheme.secondaryContainer,
                    child: Text(
                      profile.name.isEmpty
                          ? '林'
                          : profile.name.characters.first,
                      style: TextStyle(
                        color: scheme.onSecondaryContainer,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: InkWell(
                      onTap: onEditCharacter,
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              profile.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              '点击进入角色设定',
                              style: TextStyle(
                                color: scheme.onSurfaceVariant,
                                fontSize: 11.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
              child: FilledButton.tonalIcon(
                onPressed: onNew,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  alignment: Alignment.centerLeft,
                ),
                icon: const Icon(Icons.add_comment_outlined),
                label: const Text('新对话'),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 16, 6),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '最近对话',
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                itemCount: conversations.length,
                itemBuilder: (context, index) {
                  final conversation = conversations[index];
                  final selected = conversation.id == selectedId;
                  return ListTile(
                    selected: selected,
                    selectedTileColor: scheme.secondaryContainer,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    title: Text(
                      conversation.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14),
                    ),
                    trailing: PopupMenuButton<String>(
                      tooltip: '对话操作',
                      onSelected: (value) {
                        if (value == 'delete') onDelete(conversation);
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'delete', child: Text('删除对话')),
                      ],
                    ),
                    onTap: () => onSelect(conversation),
                  );
                },
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.favorite_border_rounded),
              title: const Text('收藏'),
              onTap: onFavorites,
            ),
            ListTile(
              leading: const Icon(Icons.menu_book_outlined),
              title: const Text('记忆与世界'),
              onTap: onMemoryWorld,
            ),
            ListTile(
              leading: const Icon(Icons.manage_accounts_outlined),
              title: const Text('角色设定'),
              onTap: onEditCharacter,
            ),
            ListTile(
              leading: const Icon(Icons.tune_rounded),
              title: const Text('模型供应商'),
              onTap: onSettings,
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: const Text('设置'),
              onTap: onAppSettings,
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.enabled,
    required this.generating,
    required this.onSend,
    required this.onStop,
  });

  final TextEditingController controller;
  final bool enabled;
  final bool generating;
  final VoidCallback onSend;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
        child: Material(
          color: scheme.surfaceContainer,
          borderRadius: BorderRadius.circular(26),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(15, 3, 7, 3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    enabled: enabled,
                    minLines: 1,
                    maxLines: 6,
                    textInputAction: TextInputAction.newline,
                    decoration: InputDecoration(
                      hintText: generating ? '可以继续说…' : '说点什么…',
                      border: InputBorder.none,
                      filled: false,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                if (generating)
                  IconButton(
                    tooltip: '停止当前回复',
                    onPressed: onStop,
                    icon: const Icon(Icons.stop_rounded),
                  ),
                IconButton.filled(
                  tooltip: '发送',
                  onPressed: enabled ? onSend : null,
                  icon: const Icon(Icons.arrow_upward_rounded),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ThinkingRow extends StatelessWidget {
  const _ThinkingRow({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: scheme.secondaryContainer,
            child: Text(
              name.isEmpty ? '林' : name.characters.first,
              style: TextStyle(
                color: scheme.onSecondaryContainer,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 11),
          const SizedBox(
            width: 15,
            height: 15,
            child: CircularProgressIndicator(strokeWidth: 1.8),
          ),
          const SizedBox(width: 9),
          Text(
            '$name 正在想…',
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _TaggedReply {
  const _TaggedReply({required this.text, required this.mood});

  final String text;
  final String mood;
}

class _ModelChoice {
  const _ModelChoice({required this.provider, required this.model});

  final ProviderProfile provider;
  final String model;
}
