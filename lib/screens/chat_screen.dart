import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/api_profile.dart';
import '../models/character_profile.dart';
import '../models/chat_message.dart';
import '../services/ai_chat_service.dart';
import '../services/api_settings_store.dart';
import '../services/chat_store.dart';
import '../widgets/message_bubble.dart';
import 'api_settings_screen.dart';
import 'character_screen.dart';
import 'memory_screen.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({required this.profile, super.key});

  final CharacterProfile profile;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _store = ChatStore();
  final _apiStore = ApiSettingsStore();
  final _ai = AiChatService();

  late CharacterProfile _profile;
  ApiProfile? _apiProfile;
  String _apiKey = '';
  List<ChatMessage> _messages = [];
  List<String> _memories = [];
  bool _loading = true;
  bool _thinking = false;

  @override
  void initState() {
    super.initState();
    _profile = widget.profile;
    unawaited(_restore());
  }

  Future<void> _restore() async {
    final messages = await _store.loadMessages();
    final memories = await _store.loadMemories();
    final profile = await _store.loadProfile();
    final apiProfile = await _apiStore.loadProfile();
    final apiKey = await _apiStore.loadApiKey();

    if (!messages.any((message) => message.author == MessageAuthor.character)) {
      messages.add(
        ChatMessage(
          id: 'greeting-${DateTime.now().microsecondsSinceEpoch}',
          author: MessageAuthor.character,
          text: profile.greeting,
          sentAt: DateTime.now(),
        ),
      );
      await _store.saveMessages(messages);
    }
    if (!mounted) return;
    setState(() {
      _messages = messages;
      _memories = memories;
      _profile = profile;
      _apiProfile = apiProfile;
      _apiKey = apiKey;
      _loading = false;
    });
    _scrollToBottom(jump: true);
  }

  Future<bool> _ensureApiConfigured() async {
    if ((_apiProfile?.isConfigured ?? false) && _apiKey.trim().isNotEmpty) {
      return true;
    }
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (_) => const ApiSettingsScreen()),
    );
    if (saved != true) return false;
    final profile = await _apiStore.loadProfile();
    final apiKey = await _apiStore.loadApiKey();
    if (!mounted) return false;
    setState(() {
      _apiProfile = profile;
      _apiKey = apiKey;
    });
    return profile.isConfigured && apiKey.trim().isNotEmpty;
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _thinking) return;
    if (!await _ensureApiConfigured()) return;
    final apiProfile = _apiProfile;
    if (apiProfile == null) return;

    final userMessage = ChatMessage(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      author: MessageAuthor.user,
      text: text,
      sentAt: DateTime.now(),
    );
    final reply = ChatMessage(
      id: 'reply-${DateTime.now().microsecondsSinceEpoch}',
      author: MessageAuthor.character,
      text: '',
      sentAt: DateTime.now(),
    );

    setState(() {
      _messages.add(userMessage);
      _messages.add(reply);
      _thinking = true;
      _controller.clear();
    });
    await _store.saveMessages(_messages);
    _scrollToBottom();

    final replyIndex = _messages.length - 1;
    var fullReply = '';
    try {
      final contextMessages = _messages
          .take(_messages.length - 1)
          .where((message) => message.author != MessageAuthor.system)
          .toList();
      final recent = contextMessages.length > 24
          ? contextMessages.sublist(contextMessages.length - 24)
          : contextMessages;
      await for (final chunk in _ai.streamReply(
        profile: apiProfile,
        apiKey: _apiKey,
        systemPrompt: _assembledSystemPrompt(),
        history: recent,
      )) {
        fullReply += chunk;
        if (!mounted) return;
        setState(() {
          _messages[replyIndex] = reply.copyWith(text: fullReply);
        });
        _scrollToBottom();
      }
      if (fullReply.trim().isEmpty) {
        throw const AiChatException('模型没有返回文字，请检查模型名称或接口兼容性');
      }
      await _store.saveMessages(_messages);
    } on AiChatException catch (error) {
      if (!mounted) return;
      setState(() => _messages.removeAt(replyIndex));
      await _store.saveMessages(_messages);
      _showError(error.message);
    } catch (error) {
      if (!mounted) return;
      setState(() => _messages.removeAt(replyIndex));
      await _store.saveMessages(_messages);
      _showError('回复失败：$error');
    } finally {
      if (mounted) setState(() => _thinking = false);
    }
  }

  String _assembledSystemPrompt() {
    if (_memories.isEmpty) return _profile.systemPrompt;
    return '${_profile.systemPrompt}\n\n你们已经共同确认的记忆：\n'
        '${_memories.map((memory) => '- $memory').join('\n')}';
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: '设置',
          onPressed: () => Navigator.of(context).push<bool>(
            MaterialPageRoute<bool>(builder: (_) => const ApiSettingsScreen()),
          ),
        ),
      ),
    );
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
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _openMemories() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => MemoryScreen(
          memories: _memories,
          onAdd: (memory) async {
            await _store.addMemory(memory);
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
    await _store.saveProfile(updated);
    if (!mounted) return;
    setState(() => _profile = updated);
  }

  Future<void> _clearConversation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清空这段对话？'),
        content: const Text('聊天记录会从这台设备删除，共同记忆会保留。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('清空'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _store.clearMessages();
    if (!mounted) return;
    setState(() {
      _messages = [
        ChatMessage(
          id: 'greeting-${DateTime.now().microsecondsSinceEpoch}',
          author: MessageAuthor.character,
          text: _profile.greeting,
          sentAt: DateTime.now(),
        ),
      ];
    });
    await _store.saveMessages(_messages);
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _ai.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: const Color(0xFFFFFCF7),
      ),
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              _ConversationHeader(
                profile: _profile,
                thinking: _thinking,
                onBack: () => Navigator.of(context).pop(),
                onMemories: _openMemories,
                onSettings: () => Navigator.of(context).push<bool>(
                  MaterialPageRoute<bool>(
                    builder: (_) => const ApiSettingsScreen(),
                  ),
                ),
                onEditCharacter: _editCharacter,
                onClear: _clearConversation,
              ),
              Expanded(
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    color: Color(0xFFF1EFE9),
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(28),
                    ),
                  ),
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
                          itemCount: _messages.length,
                          itemBuilder: (context, index) {
                            final message = _messages[index];
                            if (_thinking &&
                                index == _messages.length - 1 &&
                                message.author == MessageAuthor.character &&
                                message.text.isEmpty) {
                              return const Align(
                                alignment: Alignment.centerLeft,
                                child: _ThinkingBubble(),
                              );
                            }
                            return MessageBubble(
                              message: message,
                              characterName: _profile.name,
                            );
                          },
                        ),
                ),
              ),
              _Composer(
                controller: _controller,
                enabled: !_loading && !_thinking,
                onSend: _send,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConversationHeader extends StatelessWidget {
  const _ConversationHeader({
    required this.profile,
    required this.thinking,
    required this.onBack,
    required this.onMemories,
    required this.onSettings,
    required this.onEditCharacter,
    required this.onClear,
  });

  final CharacterProfile profile;
  final bool thinking;
  final VoidCallback onBack;
  final VoidCallback onMemories;
  final VoidCallback onSettings;
  final VoidCallback onEditCharacter;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFFFFCF7),
      padding: const EdgeInsets.fromLTRB(4, 8, 8, 14),
      child: Row(
        children: [
          IconButton(onPressed: onBack, icon: const Icon(Icons.arrow_back)),
          CircleAvatar(
            radius: 24,
            backgroundColor: const Color(0xFFDCE6DF),
            child: Text(
              profile.name.isEmpty ? '林' : profile.name.characters.first,
              style: const TextStyle(
                color: Color(0xFF27483D),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF192A24),
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  thinking
                      ? '正在回复…'
                      : '${profile.status} · 相识第 ${profile.daysTogether} 天',
                  style: const TextStyle(
                    color: Color(0xFF777A74),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: '共同记忆',
            onPressed: onMemories,
            icon: const Icon(Icons.bookmark_border_rounded),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'settings':
                  onSettings();
                  break;
                case 'character':
                  onEditCharacter();
                  break;
                case 'clear':
                  onClear();
                  break;
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'settings', child: Text('模型设置')),
              PopupMenuItem(value: 'character', child: Text('角色档案')),
              PopupMenuDivider(),
              PopupMenuItem(value: 'clear', child: Text('清空对话')),
            ],
          ),
        ],
      ),
    );
  }
}

class _ThinkingBubble extends StatelessWidget {
  const _ThinkingBubble();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFFFFFCF7),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(19),
          topRight: Radius.circular(19),
          bottomRight: Radius.circular(19),
          bottomLeft: Radius.circular(5),
        ),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 13,
            height: 13,
            child: CircularProgressIndicator(strokeWidth: 1.7),
          ),
          SizedBox(width: 9),
          Text('正在想…', style: TextStyle(color: Color(0xFF747A76))),
        ],
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.enabled,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool enabled;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      color: const Color(0xFFFFFCF7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              enabled: enabled,
              minLines: 1,
              maxLines: 5,
              textInputAction: TextInputAction.newline,
              onSubmitted: (_) => onSend(),
              decoration: InputDecoration(
                hintText: enabled ? '说点什么…' : '等林说完…',
                filled: true,
                fillColor: const Color(0xFFF1EFE9),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 17,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 9),
          IconButton.filled(
            tooltip: '发送',
            onPressed: enabled ? onSend : null,
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFF27483D),
              foregroundColor: Colors.white,
              disabledBackgroundColor: const Color(0xFFB8BFBB),
            ),
            icon: const Icon(Icons.arrow_upward_rounded),
          ),
        ],
      ),
    );
  }
}
