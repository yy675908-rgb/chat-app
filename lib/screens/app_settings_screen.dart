import 'package:flutter/material.dart';

class AppSettingsScreen extends StatefulWidget {
  const AppSettingsScreen({
    required this.reasoningExpanded,
    required this.contextTokenBudget,
    required this.onSave,
    super.key,
  });

  final bool reasoningExpanded;
  final int contextTokenBudget;
  final Future<void> Function(bool reasoningExpanded, int contextTokenBudget)
      onSave;

  @override
  State<AppSettingsScreen> createState() => _AppSettingsScreenState();
}

class _AppSettingsScreenState extends State<AppSettingsScreen> {
  late bool _reasoningExpanded;
  late int _contextTokenBudget;
  bool _saving = false;

  static const _budgets = <int, String>{
    16000: '轻量 · 约 16K',
    32000: '平衡 · 约 32K',
    64000: '长记忆 · 约 64K',
    128000: '超长 · 约 128K',
  };

  @override
  void initState() {
    super.initState();
    _reasoningExpanded = widget.reasoningExpanded;
    _contextTokenBudget = _budgets.containsKey(widget.contextTokenBudget)
        ? widget.contextTokenBudget
        : 32000;
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    await widget.onSave(_reasoningExpanded, _contextTokenBudget);
    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? '保存中…' : '保存'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 30),
        children: [
          const Text(
            '显示',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Card(
            elevation: 0,
            child: SwitchListTile(
              title: const Text('思考过程默认展开'),
              subtitle: const Text('只有模型实际返回思考内容时才会显示'),
              value: _reasoningExpanded,
              onChanged: (value) {
                setState(() => _reasoningExpanded = value);
              },
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            '对话上下文',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<int>(
            initialValue: _contextTokenBudget,
            decoration: const InputDecoration(
              labelText: '最近对话预算',
              filled: true,
              border: OutlineInputBorder(),
            ),
            items: _budgets.entries
                .map(
                  (entry) => DropdownMenuItem<int>(
                    value: entry.key,
                    child: Text(entry.value),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() => _contextTokenBudget = value);
              }
            },
          ),
          const SizedBox(height: 10),
          Text(
            '不再固定只记 30 条。应用会从最新消息向前保留，直到接近所选 token 预算；共同记忆和命中的世界书另外加入。',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 12,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
