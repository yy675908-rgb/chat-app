import 'package:flutter/material.dart';

import '../models/character_profile.dart';

class CharacterScreen extends StatefulWidget {
  const CharacterScreen({required this.profile, super.key});

  final CharacterProfile profile;

  @override
  State<CharacterScreen> createState() => _CharacterScreenState();
}

class _CharacterScreenState extends State<CharacterScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _statusController;
  late final TextEditingController _greetingController;
  late final TextEditingController _promptController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.profile.name);
    _statusController = TextEditingController(text: widget.profile.status);
    _greetingController = TextEditingController(text: widget.profile.greeting);
    _promptController = TextEditingController(text: widget.profile.systemPrompt);
  }

  void _save() {
    final name = _nameController.text.trim();
    if (name.isEmpty || _promptController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('名字和角色设定不能为空')),
      );
      return;
    }
    Navigator.of(context).pop(
      widget.profile.copyWith(
        name: name,
        status: _statusController.text.trim(),
        greeting: _greetingController.text.trim(),
        systemPrompt: _promptController.text.trim(),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _statusController.dispose();
    _greetingController.dispose();
    _promptController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('角色档案'),
        actions: [
          TextButton(onPressed: _save, child: const Text('保存')),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 30),
        children: [
          Center(
            child: CircleAvatar(
              radius: 42,
              backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
              child: Text(
                widget.profile.name.isEmpty
                    ? '林'
                    : widget.profile.name.characters.first,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSecondaryContainer,
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: '名字',
              filled: true,
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _statusController,
            decoration: const InputDecoration(
              labelText: '状态',
              filled: true,
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _greetingController,
            minLines: 2,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: '开场白',
              filled: true,
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _promptController,
            minLines: 7,
            maxLines: 14,
            decoration: const InputDecoration(
              labelText: '角色设定',
              alignLabelWithHint: true,
              filled: true,
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            '角色设定会作为系统提示词发送给模型。',
            style: TextStyle(color: Color(0xFF687176), fontSize: 12),
          ),
        ],
      ),
    );
  }
}
