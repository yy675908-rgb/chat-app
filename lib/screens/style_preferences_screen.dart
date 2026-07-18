import 'package:flutter/material.dart';

class StylePreferencesScreen extends StatefulWidget {
  const StylePreferencesScreen({
    required this.preferences,
    required this.onChanged,
    super.key,
  });

  final List<String> preferences;
  final Future<void> Function(List<String> preferences) onChanged;

  @override
  State<StylePreferencesScreen> createState() =>
      _StylePreferencesScreenState();
}

class _StylePreferencesScreenState extends State<StylePreferencesScreen> {
  late List<String> _preferences;

  @override
  void initState() {
    super.initState();
    _preferences = [...widget.preferences];
  }

  Future<void> _edit({int? index}) async {
    final controller = TextEditingController(
      text: index == null ? '' : _preferences[index],
    );
    final value = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          18,
          20,
          MediaQuery.viewInsetsOf(context).bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              index == null ? '添加回应偏好' : '编辑回应偏好',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              '写清楚情境和希望角色怎么回应。',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              minLines: 2,
              maxLines: 5,
              decoration: const InputDecoration(
                hintText: '例如：当我只想安静待着时：少追问，简单陪着。',
                filled: true,
                border: OutlineInputBorder(),
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
    if (value == null || value.isEmpty) return;
    final next = [..._preferences];
    if (index == null) {
      if (next.contains(value)) return;
      next.add(value);
    } else {
      next[index] = value;
    }
    await widget.onChanged(next);
    if (mounted) setState(() => _preferences = next);
  }

  Future<void> _delete(int index) async {
    final next = [..._preferences]..removeAt(index);
    await widget.onChanged(next);
    if (mounted) setState(() => _preferences = next);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('回应偏好'),
        actions: [
          IconButton(
            tooltip: '添加偏好',
            onPressed: _edit,
            icon: const Icon(Icons.add_rounded),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: _preferences.isEmpty
          ? const Center(
              child: Text(
                '还没有提炼出的偏好。\n喜欢一条回复后，会自动整理到这里。',
                textAlign: TextAlign.center,
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
              itemCount: _preferences.length,
              separatorBuilder: (_, __) => const SizedBox(height: 9),
              itemBuilder: (context, index) {
                final scheme = Theme.of(context).colorScheme;
                return Container(
                  padding: const EdgeInsets.fromLTRB(16, 11, 4, 11),
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    borderRadius: BorderRadius.circular(17),
                    border: Border.all(color: scheme.outlineVariant),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _preferences[index],
                          style: const TextStyle(height: 1.45),
                        ),
                      ),
                      IconButton(
                        tooltip: '编辑',
                        onPressed: () => _edit(index: index),
                        icon: const Icon(Icons.edit_outlined, size: 19),
                      ),
                      IconButton(
                        tooltip: '删除',
                        onPressed: () => _delete(index),
                        icon: const Icon(Icons.delete_outline_rounded, size: 19),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
