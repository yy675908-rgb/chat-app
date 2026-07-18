import 'package:flutter/material.dart';

class MemoryScreen extends StatefulWidget {
  const MemoryScreen({
    required this.memories,
    required this.onAdd,
    super.key,
  });

  final List<String> memories;
  final Future<void> Function(String memory) onAdd;

  @override
  State<MemoryScreen> createState() => _MemoryScreenState();
}

class _MemoryScreenState extends State<MemoryScreen> {
  late List<String> _memories;

  @override
  void initState() {
    super.initState();
    _memories = [...widget.memories];
  }

  Future<void> _addMemory() async {
    final controller = TextEditingController();
    final memory = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          MediaQuery.viewInsetsOf(context).bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '留下一件重要的事',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              autofocus: true,
              minLines: 2,
              maxLines: 5,
              decoration: const InputDecoration(
                hintText: '例如：我们第一次聊天是在雨天。',
                filled: true,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
              ),
              child: const Text('保存到共同记忆'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    if (memory == null || memory.isEmpty || _memories.contains(memory)) return;
    await widget.onAdd(memory);
    if (!mounted) return;
    setState(() => _memories.add(memory));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('共同记忆'),
        actions: [
          IconButton(onPressed: _addMemory, icon: const Icon(Icons.add_rounded)),
        ],
      ),
      body: _memories.isEmpty
          ? const Center(
              child: Text(
                '还没有被留下的记忆。\n以后重要的事会慢慢长在这里。',
                textAlign: TextAlign.center,
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(18),
              itemCount: _memories.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) => Card(
                elevation: 0,
                color: Theme.of(context).colorScheme.surface,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(_memories[index]),
                ),
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addMemory,
        icon: const Icon(Icons.add_rounded),
        label: const Text('添加记忆'),
      ),
    );
  }
}
