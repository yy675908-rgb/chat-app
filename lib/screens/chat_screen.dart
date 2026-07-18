import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/character_profile.dart';
import '../models/chat_message.dart';
import '../models/conversation.dart';
import '../models/provider_profile.dart';
import '../services/ai_chat_service.dart';
import '../services/chat_store.dart';
import '../services/provider_store.dart';
import '../widgets/message_bubble.dart';
import 'api_settings_screen.dart';
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
  List<ProviderProfile> _providers = const [];
  ProviderProfile? _selectedProvider;
  AiChatService? _activeService;
  bool _loading = true;
  bool _submitting = false;
  bool _generating = false;
  bool _cancelled = false;

  @override
  void initState() {
    super.initState();
    unawaited(_restore());
  }

  Future<void> _restore() async {
    final profile = await _chatStore.loadProfile();
    final memories = await _chatStore.loadMemories();
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
    if (text.isEmpty || _generating || _submitting) return;
    setState(() => _submitting = true);
    try {
      if (!await _ensureProviderConfigured()) return;
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
      await _updateConversationTitle(text);
      await _persistMessages();
      await _requestReply();
    } finally {
      if (mounted) setState(() => _submitting = false);
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
      if (newReply != null) _messages.add(newReply);
      _generating = true;
      _cancelled = false;
    });
    _scrollToBottom();

    final contextMessages = _messages.take(replyIndex).toList();
    final recent = contextMessages.length > 30
        ? contextMessages.sublist(contextMessages.length - 30)
        : contextMessages;
    final service = AiChatService();
    _activeService = service;
    var fullReply = '';
    try {
      await for (final chunk in service.streamReply(
        provider: provider,
        apiKey: apiKey,
        systemPrompt: _assembledSystemPrompt(),
        history: recent,
      )) {
        fullReply += chunk;
        if (!mounted || _cancelled) return;
        if (!isRetry) {
          setState(() {
            _messages[replyIndex] = newReply!.copyWith(text: fullReply);
          });
          _scrollToBottom();
        }
      }
      if (!_cancelled && fullReply.trim().isEmpty) {
        throw const AiChatException('模型没有返回文字，请检查模型 ID 和接口类型');
      }
      if (!_cancelled && mounted) {
        final variant = ReplyVariant(
          id: 'variant-${DateTime.now().microsecondsSinceEpoch}',
          text: fullReply,
          generatedAt: DateTime.now(),
          providerId: provider.id,
          modelId: provider.selectedModel,
        );
        setState(() {
          if (isRetry) {
            _messages[replyIndex] = originalReply!.addVariant(variant);
          } else {
            _messages[replyIndex] = newReply!.copyWith(
              text: fullReply,
              replyVariants: [variant],
              activeVariantIndex: 0,
            );
          }
        });
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
        setState(() => _generating = false);
        await _persistMessages();
      }
    }
  }

  void _stopGenerating() {
    _cancelled = true;
    _activeService?.close();
    if (_messages.isNotEmpty &&
        _messages.last.author == MessageAuthor.character &&
        _messages.last.text.isEmpty) {
      _messages.removeLast();
    }
    unawaited(_persistMessages());
  }

  Future<void> _retryReply(int replyIndex) async {
    if (_generating || _submitting) return;
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
    final updated = _messages[messageIndex].toggleLike();
    setState(() => _messages[messageIndex] = updated);
    await _persistMessages();
    if (!mounted) return;
    _showError(updated.isLiked ? '已喜欢并加入收藏' : '已取消喜欢');
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
    return '${_profile.systemPrompt}\n\n$context$memoryText';
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

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(label: '设置', onPressed: _openProviderSettings),
      ),
    );
  }

  Future<void> _openMemories() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => MemoryScreen(
          memories: _memories,
          onAdd: (memory) async {
            await _chatStore.addMemory(memory);
            if (!mounted) return;
            setState(() => _memories = [..._memories, memory]);
          },
        ),
      ),
    );
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
          onSettings: _openProviderSettings,
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
              Text(
                _generating ? '正在回复…' : _profile.status,
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
              tooltip: '共同记忆',
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
                            index == _messages.length - 1 &&
                            message.author == MessageAuthor.character &&
                            message.text.isEmpty) {
                          return _ThinkingRow(name: _profile.name);
                        }
                        final canUseActions =
                            message.author == MessageAuthor.character &&
                            message.text.isNotEmpty &&
                            !_generating;
                        return MessageBubble(
                          message: message,
                          characterName: _profile.name,
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
              enabled: !_loading && !_submitting,
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
    required this.onSettings,
  });

  final CharacterProfile profile;
  final List<Conversation> conversations;
  final String? selectedId;
  final VoidCallback onNew;
  final ValueChanged<Conversation> onSelect;
  final ValueChanged<Conversation> onDelete;
  final VoidCallback onEditCharacter;
  final VoidCallback onFavorites;
  final VoidCallback onSettings;

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
              leading: const Icon(Icons.manage_accounts_outlined),
              title: const Text('角色设定'),
              onTap: onEditCharacter,
            ),
            ListTile(
              leading: const Icon(Icons.tune_rounded),
              title: const Text('模型供应商'),
              onTap: onSettings,
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
                    enabled: enabled && !generating,
                    minLines: 1,
                    maxLines: 6,
                    textInputAction: TextInputAction.newline,
                    decoration: InputDecoration(
                      hintText: generating ? '等林说完…' : '说点什么…',
                      border: InputBorder.none,
                      filled: false,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                IconButton.filled(
                  tooltip: generating ? '停止' : '发送',
                  onPressed: generating ? onStop : (enabled ? onSend : null),
                  icon: Icon(
                    generating ? Icons.stop_rounded : Icons.arrow_upward_rounded,
                  ),
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

class _ModelChoice {
  const _ModelChoice({required this.provider, required this.model});

  final ProviderProfile provider;
  final String model;
}
