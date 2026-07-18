import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../models/world_book_entry.dart';
import '../services/chat_store.dart';

class MemoryScreen extends StatefulWidget {
  const MemoryScreen({super.key});

  @override
  State<MemoryScreen> createState() => _MemoryScreenState();
}

class _MemoryScreenState extends State<MemoryScreen>
    with SingleTickerProviderStateMixin {
  final _store = ChatStore();
  late final TabController _tabs;
  List<String> _memories = [];
  List<String> _preferences = [];
  List<WorldBookEntry> _worldBooks = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this)
      ..addListener(() {
        if (mounted && !_tabs.indexIsChanging) setState(() {});
      });
    _load();
  }

  Future<void> _load() async {
    final memories = await _store.loadMemories();
    final preferences = await _store.loadStylePreferences();
    final worldBooks = await _store.loadWorldBooks();
    if (!mounted) return;
    setState(() {
      _memories = memories;
      _preferences = preferences;
      _worldBooks = worldBooks;
      _loading = false;
    });
  }

  Future<String?> _editText({
    required String title,
    required String hint,
    String initialValue = '',
  }) async {
    final controller = TextEditingController(text: initialValue);
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          4,
          20,
          MediaQuery.viewInsetsOf(context).bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              autofocus: true,
              minLines: 3,
              maxLines: 8,
              decoration: InputDecoration(
                hintText: hint,
                filled: true,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    return result;
  }

  Future<void> _addOrEditMemory([int? index]) async {
    final value = await _editText(
      title: index == null ? '添加共同记忆' : '编辑共同记忆',
      hint: '例如：我们第一次聊天是在雨天。',
      initialValue: index == null ? '' : _memories[index],
    );
    if (value == null || value.isEmpty) return;
    setState(() {
      if (index == null) {
        if (!_memories.contains(value)) _memories.add(value);
      } else {
        _memories[index] = value;
      }
    });
    await _store.saveMemories(_memories);
  }

  Future<void> _addOrEditPreference([int? index]) async {
    final value = await _editText(
      title: index == null ? '添加回应偏好' : '编辑回应偏好',
      hint: '例如：当我情绪低落时，用短句陪伴，不急着分析。',
      initialValue: index == null ? '' : _preferences[index],
    );
    if (value == null || value.isEmpty) return;
    setState(() {
      if (index == null) {
        if (!_preferences.contains(value)) _preferences.add(value);
      } else {
        _preferences[index] = value;
      }
    });
    await _store.saveStylePreferences(_preferences);
  }

  Future<void> _deleteSimple({
    required bool memory,
    required int index,
  }) async {
    setState(() {
      if (memory) {
        _memories.removeAt(index);
      } else {
        _preferences.removeAt(index);
      }
    });
    if (memory) {
      await _store.saveMemories(_memories);
    } else {
      await _store.saveStylePreferences(_preferences);
    }
  }

  Future<void> _editWorldBook({
    WorldBookEntry? entry,
    String initialTitle = '',
    String initialContent = '',
  }) async {
    final titleController = TextEditingController(
      text: entry?.title ?? initialTitle,
    );
    final keywordsController = TextEditingController(
      text: entry?.keywords.join('，') ?? '',
    );
    final contentController = TextEditingController(
      text: entry?.content ?? initialContent,
    );
    final result = await showModalBottomSheet<WorldBookEntry>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(
          18,
          2,
          18,
          MediaQuery.viewInsetsOf(context).bottom + 18,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.82,
          ),
          child: ListView(
            shrinkWrap: true,
            children: [
              Text(
                entry == null ? '添加世界书条目' : '编辑世界书条目',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: '标题',
                  filled: true,
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: keywordsController,
                decoration: const InputDecoration(
                  labelText: '触发关键词',
                  hintText: '例如：王都，银塔，北境',
                  helperText: '只有最近对话出现关键词时，才把条目交给模型',
                  filled: true,
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: contentController,
                minLines: 7,
                maxLines: 16,
                decoration: const InputDecoration(
                  labelText: '世界设定',
                  alignLabelWithHint: true,
                  filled: true,
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),
              FilledButton(
                onPressed: () {
                  final content = contentController.text.trim();
                  if (content.isEmpty) return;
                  final keywords = keywordsController.text
                      .split(RegExp(r'[,，\n]'))
                      .map((item) => item.trim())
                      .where((item) => item.isNotEmpty)
                      .toSet()
                      .toList();
                  Navigator.pop(
                    context,
                    WorldBookEntry(
                      id: entry?.id ??
                          'world-${DateTime.now().microsecondsSinceEpoch}',
                      title: titleController.text.trim().isEmpty
                          ? '未命名条目'
                          : titleController.text.trim(),
                      keywords: keywords,
                      content: content,
                      enabled: entry?.enabled ?? true,
                    ),
                  );
                },
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                child: const Text('保存世界书条目'),
              ),
            ],
          ),
        ),
      ),
    );
    titleController.dispose();
    keywordsController.dispose();
    contentController.dispose();
    if (result == null) return;
    setState(() {
      final index = _worldBooks.indexWhere((item) => item.id == result.id);
      if (index < 0) {
        _worldBooks.add(result);
      } else {
        _worldBooks[index] = result;
      }
    });
    await _store.saveWorldBooks(_worldBooks);
  }

  Future<void> _importWorldBook() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['txt', 'md', 'markdown'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.single;
    final bytes = file.bytes;
    if (bytes == null) {
      _notice('没有读取到文档内容');
      return;
    }
    var text = utf8.decode(bytes, allowMalformed: true).trim();
    if (text.isEmpty) {
      _notice('文档是空的');
      return;
    }
    if (text.length > 200000) {
      text = text.substring(0, 200000);
      _notice('文档较大，已导入前 20 万字');
    }
    final title = file.name.replaceFirst(RegExp(r'\.[^.]+$'), '');
    await _editWorldBook(initialTitle: title, initialContent: text);
  }

  Future<void> _toggleWorldBook(WorldBookEntry entry, bool enabled) async {
    final index = _worldBooks.indexWhere((item) => item.id == entry.id);
    if (index < 0) return;
    setState(() => _worldBooks[index] = entry.copyWith(enabled: enabled));
    await _store.saveWorldBooks(_worldBooks);
  }

  Future<void> _deleteWorldBook(WorldBookEntry entry) async {
    setState(() => _worldBooks.removeWhere((item) => item.id == entry.id));
    await _store.saveWorldBooks(_worldBooks);
  }

  void _notice(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _addForCurrentTab() {
    if (_tabs.index == 0) {
      _addOrEditMemory();
    } else if (_tabs.index == 1) {
      _addOrEditPreference();
    } else {
      _editWorldBook();
    }
  }

  Widget _simpleList({
    required List<String> items,
    required bool memory,
  }) {
    if (items.isEmpty) {
      return _MemoryEmptyState(
        icon: memory
            ? Icons.auto_awesome_outlined
            : Icons.favorite_border_rounded,
        title: memory ? '还没有共同记忆' : '还没有回应偏好',
        description: memory
            ? '把重要的人、事和约定慢慢留在这里'
            : '喜欢一条回复后，应用也会自动提炼',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) => Card(
        elevation: 0,
        child: ListTile(
          contentPadding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
          leading: Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              memory
                  ? Icons.auto_awesome_outlined
                  : Icons.favorite_border_rounded,
              size: 18,
              color: Theme.of(context).colorScheme.onSecondaryContainer,
            ),
          ),
          title: Text(items[index]),
          onTap: () => memory
              ? _addOrEditMemory(index)
              : _addOrEditPreference(index),
          trailing: IconButton(
            tooltip: '删除',
            onPressed: () => _deleteSimple(memory: memory, index: index),
            icon: const Icon(Icons.delete_outline_rounded, size: 20),
          ),
        ),
      ),
    );
  }

  Widget _worldBookList() {
    if (_worldBooks.isEmpty) {
      return const _MemoryEmptyState(
        icon: Icons.public_rounded,
        title: '还没有世界书',
        description: '可以粘贴文字，或导入 TXT / Markdown 文档',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: _worldBooks.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final entry = _worldBooks[index];
        return Card(
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 6, 8, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        entry.title,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    Switch(
                      value: entry.enabled,
                      onChanged: (value) => _toggleWorldBook(entry, value),
                    ),
                    PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'edit') {
                          _editWorldBook(entry: entry);
                        } else if (value == 'delete') {
                          _deleteWorldBook(entry);
                        }
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'edit', child: Text('编辑')),
                        PopupMenuItem(value: 'delete', child: Text('删除')),
                      ],
                    ),
                  ],
                ),
                if (entry.keywords.isEmpty)
                  const Text(
                    '未设置触发词：当前不会自动加入对话',
                    style: TextStyle(fontSize: 11.5),
                  )
                else
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: entry.keywords
                        .map((keyword) => Chip(
                              label: Text(keyword),
                              visualDensity: VisualDensity.compact,
                            ))
                        .toList(),
                  ),
                const SizedBox(height: 6),
                Text(
                  entry.content,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 12.5,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const labels = ['添加记忆', '添加偏好', '添加条目'];
    return Scaffold(
      appBar: AppBar(
        title: const Text('记忆与世界'),
        actions: [
          if (_tabs.index == 2)
            IconButton(
              tooltip: '导入本地文档',
              onPressed: _importWorldBook,
              icon: const Icon(Icons.upload_file_outlined),
            ),
          const SizedBox(width: 6),
        ],
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: '共同记忆'),
            Tab(text: '回应偏好'),
            Tab(text: '世界书'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabs,
              children: [
                _simpleList(items: _memories, memory: true),
                _simpleList(items: _preferences, memory: false),
                _worldBookList(),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addForCurrentTab,
        icon: const Icon(Icons.add_rounded),
        label: Text(labels[_tabs.index]),
      ),
    );
  }
}

class _MemoryEmptyState extends StatelessWidget {
  const _MemoryEmptyState({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: scheme.secondaryContainer.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Icon(icon, size: 27, color: scheme.onSecondaryContainer),
            ),
            const SizedBox(height: 17),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              description,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontSize: 12.5,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

