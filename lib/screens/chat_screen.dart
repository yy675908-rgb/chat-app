import 'dart:async';

import 'package:flutter/material.dart';

import '../models/character_profile.dart';
import '../models/chat_message.dart';
import '../services/chat_store.dart';
import '../widgets/message_bubble.dart';
import 'memory_screen.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _store = ChatStore();
  CharacterProfile _profile = CharacterProfile(
    name: '未命名角色',
    status: '在这里',
    firstMetAt: DateTime.now(),
  );

  List<ChatMessage> _messages = [];
  List<String> _memories = [];
  bool _loading = true;
  bool _thinking = false;

  @override
  void initState() {
    super.initState();
    unawaited(_restore());
  }

  Future<void> _restore() async {
    final messages = await _store.loadMessages();
    final memories = await _store.loadMemories();
    final firstMetAt = await _store.loadFirstMetAt();
    if (!mounted) return;

    setState(() {
      _messages = messages.isEmpty
          ? [
              ChatMessage(
                id: 'welcome',
                author: MessageAuthor.system,
                text: '你们的故事从今天开始',
                sentAt: DateTime.now(),
              ),
            ]
          : messages;
      _memories = memories;
      _profile = CharacterProfile(
        name: _profile.name,
        status: _profile.status,
        firstMetAt: firstMetAt,
      );
      _loading = false;
    });
    _scrollToBottom();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _thinking) return;

    final message = ChatMessage(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      author: MessageAuthor.user,
      text: text,
      sentAt: DateTime.now(),
    );

    setState(() {
      _messages.add(message);
      _thinking = true;
      _controller.clear();
    });
    await _store.saveMessages(_messages);
    _scrollToBottom();

    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    setState(() => _thinking = false);
    _showModelNotConnected();
  }

  void _showModelNotConnected() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('消息已保存。下一阶段接入 AI 后，角色会在这里回应。'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _openMemories() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => MemoryScreen(memories: _memories),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 18,
        title: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Color(0xFFAAA0C8), Color(0xFF6D648E)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: const Icon(Icons.person_outline, color: Colors.white),
            ),
            const SizedBox(width: 11),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_profile.name, style: const TextStyle(fontSize: 16)),
                Text(
                  _thinking ? '正在想…' : '${_profile.status} · 第 ${_profile.daysTogether} 天',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: '共同记忆',
            onPressed: _openMemories,
            icon: const Icon(Icons.auto_stories_outlined),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
                      itemCount: _messages.length + (_thinking ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (_thinking && index == _messages.length) {
                          return const Align(
                            alignment: Alignment.centerLeft,
                            child: Padding(
                              padding: EdgeInsets.all(12),
                              child: Text('正在想…'),
                            ),
                          );
                        }
                        return MessageBubble(message: _messages[index]);
                      },
                    ),
            ),
            _Composer(
              controller: _controller,
              enabled: !_thinking,
              onSend: _send,
            ),
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
    required this.onSend,
  });

  final TextEditingController controller;
  final bool enabled;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: const BoxDecoration(
        color: Color(0xFFF6F3F1),
        border: Border(top: BorderSide(color: Color(0x14000000))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          IconButton(
            tooltip: '语音（稍后开放）',
            onPressed: null,
            icon: const Icon(Icons.mic_none_rounded),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              enabled: enabled,
              minLines: 1,
              maxLines: 5,
              textInputAction: TextInputAction.newline,
              decoration: InputDecoration(
                hintText: '说点什么…',
                filled: true,
                fillColor: const Color(0xD1FFFFFF),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 11,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            tooltip: '发送',
            onPressed: enabled ? onSend : null,
            icon: const Icon(Icons.arrow_upward_rounded),
          ),
        ],
      ),
    );
  }
}
