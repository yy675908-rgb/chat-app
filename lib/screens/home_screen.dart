import 'dart:async';

import 'package:flutter/material.dart';

import '../models/character_profile.dart';
import '../models/chat_message.dart';
import '../services/chat_store.dart';
import 'api_settings_screen.dart';
import 'character_screen.dart';
import 'chat_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _store = ChatStore();
  CharacterProfile? _profile;
  List<ChatMessage> _messages = const [];

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final profile = await _store.loadProfile();
    final messages = await _store.loadMessages();
    if (!mounted) return;
    setState(() {
      _profile = profile;
      _messages = messages;
    });
  }

  Future<void> _openChat() async {
    final profile = _profile;
    if (profile == null) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => ChatScreen(profile: profile)),
    );
    await _load();
  }

  Future<void> _openProfile() async {
    final profile = _profile;
    if (profile == null) return;
    final changed = await Navigator.of(context).push<CharacterProfile>(
      MaterialPageRoute<CharacterProfile>(
        builder: (_) => CharacterScreen(profile: profile),
      ),
    );
    if (changed == null) return;
    await _store.saveProfile(changed);
    if (!mounted) return;
    setState(() => _profile = changed);
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profile;
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '角色',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            tooltip: '模型设置',
            onPressed: () => Navigator.of(context).push<bool>(
              MaterialPageRoute<bool>(
                builder: (_) => const ApiSettingsScreen(),
              ),
            ),
            icon: const Icon(Icons.tune_rounded),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: profile == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
              children: [
                const Text(
                  '有人正在等你',
                  style: TextStyle(
                    color: Color(0xFF77766F),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 14),
                Material(
                  color: const Color(0xFFFFFCF7),
                  borderRadius: BorderRadius.circular(28),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: _openChat,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(18, 20, 16, 18),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              _CharacterAvatar(name: profile.name, radius: 31),
                              const SizedBox(width: 15),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      profile.name,
                                      style: const TextStyle(
                                        color: Color(0xFF192A24),
                                        fontSize: 21,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${profile.status} · 相识第 ${profile.daysTogether} 天',
                                      style: const TextStyle(
                                        color: Color(0xFF737771),
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                tooltip: '角色档案',
                                onPressed: _openProfile,
                                icon: const Icon(Icons.person_outline_rounded),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F0EA),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Text(
                              _preview(profile),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFF4F5752),
                                fontSize: 14,
                                height: 1.45,
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              const Icon(
                                Icons.lock_outline_rounded,
                                size: 15,
                                color: Color(0xFF868880),
                              ),
                              const SizedBox(width: 5),
                              const Expanded(
                                child: Text(
                                  '对话只保存在这台设备',
                                  style: TextStyle(
                                    color: Color(0xFF868880),
                                    fontSize: 11.5,
                                  ),
                                ),
                              ),
                              FilledButton.tonalIcon(
                                onPressed: _openChat,
                                icon: const Icon(Icons.arrow_forward_rounded),
                                label: const Text('继续聊天'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  String _preview(CharacterProfile profile) {
    final conversational = _messages
        .where((message) => message.author != MessageAuthor.system)
        .toList();
    if (conversational.isEmpty) return profile.greeting;
    final last = conversational.last;
    return '${last.author == MessageAuthor.user ? '你' : profile.name}：${last.text}';
  }
}

class _CharacterAvatar extends StatelessWidget {
  const _CharacterAvatar({required this.name, required this.radius});

  final String name;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: radius * 2,
      height: radius * 2,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFDCE6DF),
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFFFFFFF), width: 3),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Text(
        name.isEmpty ? '林' : name.characters.first,
        style: TextStyle(
          color: const Color(0xFF27483D),
          fontSize: radius * 0.72,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
