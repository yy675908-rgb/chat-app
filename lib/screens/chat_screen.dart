import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: const Color(0xFFF7F6F2),
      ),
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              _ConversationHeader(
                profile: _profile,
                thinking: _thinking,
                onMemories: _openMemories,
              ),
              Expanded(
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    color: Color(0xFFEDEBE6),
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(26),
                    ),
                  ),
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                          itemCount: _messages.length + (_thinking ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (_thinking && index == _messages.length) {
                              return const Align(
                                alignment: Alignment.centerLeft,
                                child: _ThinkingBubble(),
                              );
                            }
                            return MessageBubble(message: _messages[index]);
                          },
                        ),
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
      ),
    );
  }
}

class _ConversationHeader extends StatelessWidget {
  const _ConversationHeader({
    required this.profile,
    required this.thinking,
    required this.onMemories,
  });

  final CharacterProfile profile;
  final bool thinking;
  final VoidCallback onMemories;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF7F6F2),
      padding: const EdgeInsets.fromLTRB(18, 10, 10, 16),
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              const CircleAvatar(
                radius: 25,
                backgroundColor: Color(0xFFCDD4CF),
                child: Text(
                  '01',
                  style: TextStyle(
                    color: Color(0xFF2F4741),
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              Positioned(
                right: -1,
                bottom: 1,
                child: Container(
                  width: 11,
                  height: 11,
                  decoration: BoxDecoration(
                    color: const Color(0xFF69877D),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFF7F6F2),
                      width: 2,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF1C2522),
                    fontSize: 17,
                    fontWeight: FontWeight.w650,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  thinking
                      ? '正在想…'
                      : '${profile.status}  ·  相识第 ${profile.daysTogether} 天',
                  style: const TextStyle(
                    color: Color(0xFF727772),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: '共同记忆',
            onPressed: onMemories,
            style: IconButton.styleFrom(
              foregroundColor: const Color(0xFF2F4741),
              backgroundColor: const Color(0xFFE5E8E3),
            ),
            icon: const Icon(Icons.bookmark_border_rounded, size: 21),
          ),
          IconButton(
            tooltip: '更多',
            onPressed: () {},
            icon: const Icon(Icons.more_horiz_rounded),
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
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
      decoration: const BoxDecoration(
        color: Color(0xFFFAF9F5),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(17),
          topRight: Radius.circular(17),
          bottomRight: Radius.circular(17),
          bottomLeft: Radius.circular(4),
        ),
      ),
      child: const Text(
        '正在想…',
        style: TextStyle(color: Color(0xFF747A76), fontSize: 13),
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
      padding: const EdgeInsets.fromLTRB(10, 10, 12, 12),
      decoration: const BoxDecoration(
        color: Color(0xFFF7F6F2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          IconButton(
            tooltip: '更多',
            onPressed: null,
            icon: const Icon(Icons.add_rounded),
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
                fillColor: const Color(0xFFEDEBE6),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 11,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            tooltip: '发送',
            onPressed: enabled ? onSend : null,
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFF2F4741),
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
