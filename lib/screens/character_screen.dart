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
  late final TextEditingController _greetingController;
  late final TextEditingController _promptController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.profile.name)
      ..addListener(_refreshName);
    _greetingController = TextEditingController(text: widget.profile.greeting);
    _promptController = TextEditingController(text: widget.profile.systemPrompt);
  }

  void _refreshName() {
    if (mounted) setState(() {});
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
        greeting: _greetingController.text.trim(),
        systemPrompt: _promptController.text.trim(),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.removeListener(_refreshName);
    _nameController.dispose();
    _greetingController.dispose();
    _promptController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final name = _nameController.text.trim();
    return Scaffold(
      appBar: AppBar(
        title: const Text('角色设定'),
        actions: [
          TextButton(onPressed: _save, child: const Text('保存')),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 34),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Container(
                    width: 70,
                    height: 70,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: scheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      child: Text(
                        name.isEmpty ? '林' : name.characters.first,
                        key: ValueKey(name.isEmpty ? '林' : name.characters.first),
                        style: TextStyle(
                          color: scheme.onSecondaryContainer,
                          fontSize: 27,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name.isEmpty ? '你的角色' : name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          '这里决定角色是谁、如何开口，以及说话时遵循的个性。',
                          style: TextStyle(
                            color: scheme.onSurfaceVariant,
                            fontSize: 12.5,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          const _SectionLabel('基本信息'),
          const SizedBox(height: 9),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: '名字',
              hintText: '角色在对话中使用的名字',
            ),
          ),
          const SizedBox(height: 24),
          const _SectionLabel('初次见面'),
          const SizedBox(height: 9),
          TextField(
            controller: _greetingController,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: '开场白',
              hintText: '创建新对话时，角色先说的话',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 24),
          const _SectionLabel('个性与行为'),
          const SizedBox(height: 9),
          TextField(
            controller: _promptController,
            minLines: 8,
            maxLines: 16,
            decoration: const InputDecoration(
              labelText: '角色设定',
              hintText: '写清角色的性格、关系、语气和边界',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 16,
                color: scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  '角色设定会作为系统提示交给模型；写得明确，比单纯堆很多字更有效。',
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        fontSize: 12.5,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.2,
      ),
    );
  }
}
