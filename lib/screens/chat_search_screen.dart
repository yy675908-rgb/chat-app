import 'package:flutter/material.dart';

import '../models/character_profile.dart';
import '../models/chat_message.dart';
import '../models/chat_search_result.dart';
import '../services/chat_store.dart';
import '../services/mood_codec.dart';

class ChatSearchScreen extends StatefulWidget {
  const ChatSearchScreen({super.key, required this.characters});

  final List<CharacterProfile> characters;

  @override
  State<ChatSearchScreen> createState() => _ChatSearchScreenState();
}

class _ChatSearchScreenState extends State<ChatSearchScreen> {
  final _controller = TextEditingController();
  final _store = ChatStore();

  List<ChatSearchResult> _results = const [];
  bool _searching = false;
  bool _searched = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _controller.text.trim();
    if (query.isEmpty) {
      setState(() {
        _results = const [];
        _searched = false;
      });
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _searching = true;
      _searched = true;
    });
    try {
      final results = await _store.searchMessages(query, limit: 100);
      if (!mounted) return;
      setState(() => _results = results);
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  CharacterProfile? _character(String id) {
    for (final character in widget.characters) {
      if (character.id == id) return character;
    }
    return null;
  }

  String _speaker(ChatSearchResult result) {
    final message = result.message;
    if (message.author == MessageAuthor.user) return '你';
    if (message.speakerCharacterId.isNotEmpty) {
      return _character(message.speakerCharacterId)?.name ?? '角色';
    }
    if (!result.conversation.isGroup) {
      return _character(result.conversation.characterId)?.name ?? '角色';
    }
    return '角色';
  }

  String _timeLabel(DateTime value) {
    String two(int number) => number.toString().padLeft(2, '0');
    return '${value.year}-${two(value.month)}-${two(value.day)} '
        '${two(value.hour)}:${two(value.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('搜索聊天记录')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
              child: TextField(
                controller: _controller,
                autofocus: true,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _search(),
                decoration: InputDecoration(
                  hintText: '输入聊天内容关键词',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _controller.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: '清空',
                          onPressed: () {
                            _controller.clear();
                            setState(() {
                              _results = const [];
                              _searched = false;
                            });
                          },
                          icon: const Icon(Icons.close_rounded),
                        ),
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            if (_searching) const LinearProgressIndicator(minHeight: 2),
            Expanded(
              child: !_searched
                  ? Center(
                      child: Text(
                        '搜索全部单聊和群聊中的消息',
                        style: TextStyle(color: scheme.onSurfaceVariant),
                      ),
                    )
                  : _results.isEmpty && !_searching
                  ? Center(
                      child: Text(
                        '没有找到相关聊天记录',
                        style: TextStyle(color: scheme.onSurfaceVariant),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(8, 6, 8, 18),
                      itemCount: _results.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 2),
                      itemBuilder: (context, index) {
                        final result = _results[index];
                        final visibleText = MoodCodec.stripMetadata(
                          result.message.text,
                        );
                        return ListTile(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          leading: Icon(
                            result.conversation.isGroup
                                ? Icons.groups_2_outlined
                                : Icons.chat_bubble_outline_rounded,
                          ),
                          title: Text(
                            result.conversation.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 2),
                              Text(
                                '${_speaker(result)} · '
                                '${_timeLabel(result.message.sentAt)}',
                                style: TextStyle(
                                  color: scheme.onSurfaceVariant,
                                  fontSize: 11.5,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                visibleText,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                          trailing: const Icon(
                            Icons.chevron_right_rounded,
                            size: 20,
                          ),
                          onTap: () => Navigator.pop(context, result),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
