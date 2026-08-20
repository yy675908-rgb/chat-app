import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../models/user_profile.dart';
import '../services/backup_service.dart';

class AppSettingsScreen extends StatefulWidget {
  const AppSettingsScreen({
    required this.reasoningExpanded,
    required this.contextTokenBudget,
    required this.userProfile,
    required this.onSave,
    super.key,
  });

  final bool reasoningExpanded;
  final int contextTokenBudget;
  final UserProfile userProfile;
  final Future<void> Function(
    bool reasoningExpanded,
    int contextTokenBudget,
    UserProfile userProfile,
  ) onSave;

  @override
  State<AppSettingsScreen> createState() => _AppSettingsScreenState();
}

class _AppSettingsScreenState extends State<AppSettingsScreen> {
  late bool _reasoningExpanded;
  late int _contextTokenBudget;
  bool _saving = false;
  bool _backupBusy = false;
  final _backupService = BackupService();
  late final TextEditingController _userNameController;
  late final TextEditingController _userGenderController;
  late final TextEditingController _userDescriptionController;

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
    _userNameController = TextEditingController(text: widget.userProfile.name);
    _userGenderController =
        TextEditingController(text: widget.userProfile.gender);
    _userDescriptionController =
        TextEditingController(text: widget.userProfile.description);
  }

  UserProfile get _userProfileDraft => UserProfile(
        name: _userNameController.text.trim(),
        gender: _userGenderController.text.trim(),
        description: _userDescriptionController.text.trim(),
      );

  Future<void> _persistSettings() async {
    await widget.onSave(
      _reasoningExpanded,
      _contextTokenBudget,
      _userProfileDraft,
    );
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    await _persistSettings();
    if (!mounted) return;
    Navigator.pop(context);
  }

  Future<void> _exportBackup() async {
    if (_backupBusy) return;
    final scope = await showModalBottomSheet<BackupScope>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ListTile(
                title: Text(
                  '选择导出范围',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.archive_outlined),
                title: const Text('全部数据'),
                subtitle: const Text('包含角色、聊天记录、记忆、世界书和设置'),
                onTap: () => Navigator.pop(context, BackupScope.full),
              ),
              ListTile(
                leading: const Icon(Icons.badge_outlined),
                title: const Text('仅角色与设置'),
                subtitle: const Text('不包含聊天记录；保留角色卡、模型提示词、用户信息等'),
                onTap: () =>
                    Navigator.pop(context, BackupScope.configuration),
              ),
            ],
          ),
        ),
      ),
    );
    if (scope == null || !mounted) return;
    setState(() => _backupBusy = true);
    try {
      await _persistSettings();
      final data = await _backupService.createBackup(scope: scope);
      final now = DateTime.now();
      String two(int value) => value.toString().padLeft(2, '0');
      final kind = scope == BackupScope.full ? 'full' : 'settings';
      final fileName = 'linjian-$kind-${now.year}${two(now.month)}'
          '${two(now.day)}-${two(now.hour)}${two(now.minute)}.json';
      final path = await FilePicker.saveFile(
        dialogTitle: '保存林间备份',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: const ['json'],
        bytes: Uint8List.fromList(utf8.encode(data)),
      );
      if (path != null) _notice('备份已保存');
    } on Object catch (error) {
      _notice('备份失败：$error');
    } finally {
      if (mounted) setState(() => _backupBusy = false);
    }
  }

  Future<void> _restoreBackup() async {
    if (_backupBusy) return;
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['json'],
    );
    if (result == null || result.files.isEmpty || !mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('恢复这份备份？'),
        content: const Text('备份中包含的角色和设置会写入当前应用；只有完整备份会替换对话。API Key 不受影响。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('恢复'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _backupBusy = true);
    try {
      final bytes = await result.files.single.readAsBytes();
      await _backupService.restoreBackup(utf8.decode(bytes));
      if (!mounted) return;
      _notice('恢复完成');
      Navigator.pop(context, true);
    } on Object catch (error) {
      _notice('恢复失败：$error');
    } finally {
      if (mounted) setState(() => _backupBusy = false);
    }
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

  @override
  void dispose() {
    _userNameController.dispose();
    _userGenderController.dispose();
    _userDescriptionController.dispose();
    super.dispose();
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
            '应用会从最新消息向前保留，直到接近所选 token 预算；共同记忆和命中的世界书另外加入。',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 12,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            '用户人物信息',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _userNameController,
                  decoration: const InputDecoration(
                    labelText: '名字',
                    filled: true,
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _userGenderController,
                  decoration: const InputDecoration(
                    labelText: '性别',
                    filled: true,
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _userDescriptionController,
            minLines: 3,
            maxLines: 7,
            decoration: const InputDecoration(
              labelText: '设定',
              hintText: '例如：性格、身份、与角色的关系等',
              alignLabelWithHint: true,
              filled: true,
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '会作为用户资料告诉角色，不显示在聊天消息中。',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            '本地数据',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Card(
            elevation: 0,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.file_upload_outlined),
                  title: const Text('导出备份'),
                  subtitle: const Text('可选全部导出，或仅导出角色与设置'),
                  enabled: !_backupBusy,
                  onTap: _exportBackup,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.settings_backup_restore_rounded),
                  title: const Text('从备份恢复'),
                  subtitle: const Text('选择以前导出的 JSON 文件'),
                  enabled: !_backupBusy,
                  onTap: _restoreBackup,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '备份文件不包含 API Key，应用不会主动上传；文件保存位置由你选择。',
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
