import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
    _promptController = TextEditingController(
      text: widget.profile.systemPrompt,
    );
  }

  void _refreshName() {
    if (mounted) setState(() {});
  }

  void _save() {
    final name = _nameController.text.trim();
    if (name.isEmpty || _promptController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('名字和角色设定不能为空')));
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

  Future<void> _copyPrompt() async {
    final text = _promptController.text;
    if (text.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      const SnackBar(
        content: Text('已复制全部角色设定'),
        duration: Duration(milliseconds: 1200),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _openPromptEditor() async {
    FocusScope.of(context).unfocus();
    final edited = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (_) => _PromptEditorScreen(initialText: _promptController.text),
      ),
    );
    if (edited == null || !mounted) return;
    _promptController.value = TextEditingValue(
      text: edited,
      selection: TextSelection.collapsed(offset: edited.length),
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
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.manual,
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
                        key: ValueKey(
                          name.isEmpty ? '林' : name.characters.first,
                        ),
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
            autofocus: false,
            onTapOutside: (_) => FocusScope.of(context).unfocus(),
            decoration: const InputDecoration(
              labelText: '名字',
              hintText: '角色在对话中使用的名字',
            ),
          ),
          const SizedBox(height: 10),
          Card(
            elevation: 0,
            child: ListTile(
              leading: const Icon(Icons.auto_awesome_outlined),
              title: const Text('当前心绪由角色自行生成'),
              subtitle: Text(
                widget.profile.status.trim().isEmpty
                    ? '角色会随实际对话自行判断；确实没变化时会延续上一轮心绪'
                    : widget.profile.status.trim(),
              ),
            ),
          ),
          const SizedBox(height: 24),
          const _SectionLabel('开场白'),
          const SizedBox(height: 9),
          TextField(
            controller: _greetingController,
            autofocus: false,
            minLines: 2,
            maxLines: 4,
            onTapOutside: (_) => FocusScope.of(context).unfocus(),
            decoration: const InputDecoration(
              labelText: '开场白',
              hintText: '每次新建对话时，角色先说的话',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            '每次新建单聊时都会先显示这段开场白，让角色先开口；内容完全由你自己决定。',
            style: TextStyle(
              color: scheme.onSurfaceVariant,
              fontSize: 12,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              const _SectionLabel('个性与行为'),
              const Spacer(),
              TextButton.icon(
                onPressed: _copyPrompt,
                icon: const Icon(Icons.copy_rounded, size: 16),
                label: const Text('复制全部'),
              ),
              const SizedBox(width: 2),
              TextButton.icon(
                onPressed: _openPromptEditor,
                icon: const Icon(Icons.open_in_full_rounded, size: 16),
                label: const Text('全屏编辑'),
              ),
            ],
          ),
          const SizedBox(height: 7),
          TextField(
            controller: _promptController,
            autofocus: false,
            minLines: 8,
            maxLines: 16,
            onTapOutside: (_) => FocusScope.of(context).unfocus(),
            scrollPadding: const EdgeInsets.only(bottom: 24),
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
                  '长设定建议用“全屏编辑”；全屏模式不会自动弹键盘，也不会和页面滚动抢选择操作。',
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

class _PromptEditorScreen extends StatefulWidget {
  const _PromptEditorScreen({required this.initialText});

  final String initialText;

  @override
  State<_PromptEditorScreen> createState() => _PromptEditorScreenState();
}

class _PromptEditorScreenState extends State<_PromptEditorScreen> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
  }

  void _finish() {
    Navigator.of(context).pop(_controller.text);
  }

  Future<void> _copyAll() async {
    if (_controller.text.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: _controller.text));
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      const SnackBar(
        content: Text('已复制全部角色设定'),
        duration: Duration(milliseconds: 1000),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _finish();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: '返回并保留修改',
            onPressed: _finish,
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          title: const Text('编辑角色设定'),
          actions: [
            IconButton(
              tooltip: '复制全部',
              onPressed: _copyAll,
              icon: const Icon(Icons.copy_rounded),
            ),
            TextButton(onPressed: _finish, child: const Text('完成')),
            const SizedBox(width: 6),
          ],
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: TextField(
              controller: _controller,
              onTapOutside: (_) => FocusScope.of(context).unfocus(),
              autofocus: false,
              expands: true,
              minLines: null,
              maxLines: null,
              textAlignVertical: TextAlignVertical.top,
              scrollPadding: const EdgeInsets.only(bottom: 20),
              decoration: const InputDecoration(
                hintText: '写清角色的性格、关系、语气和边界',
                alignLabelWithHint: true,
                filled: true,
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.all(14),
              ),
            ),
          ),
        ),
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
