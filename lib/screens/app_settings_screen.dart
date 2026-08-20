import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../models/provider_profile.dart';
import '../models/user_profile.dart';
import '../services/backup_service.dart';

class AppSettingsScreen extends StatefulWidget {
  const AppSettingsScreen({
    required this.reasoningExpanded,
    required this.contextTokenBudget,
    required this.userProfile,
    required this.providers,
    required this.selectedProviderId,
    required this.onSave,
    super.key,
  });

  final bool reasoningExpanded;
  final int contextTokenBudget;
  final UserProfile userProfile;
  final List<ProviderProfile> providers;
  final String? selectedProviderId;
  final Future<void> Function(
    bool reasoningExpanded,
    int contextTokenBudget,
    UserProfile userProfile,
    List<ProviderProfile> providers,
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
  late List<ProviderProfile> _providers;
  String? _promptTargetKey;
  late final TextEditingController _modelPromptController;
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
    _providers = [...widget.providers];
    final targets = _promptTargets;
    final selectedProvider = _providers.where(
      (item) => item.id == widget.selectedProviderId,
    );
    final preferred = selectedProvider.isEmpty
        ? null
        : '${selectedProvider.first.id}\u0000${selectedProvider.first.selectedModel}';
    _promptTargetKey = targets.any((item) => item.key == preferred)
        ? preferred
        : (targets.isEmpty ? null : targets.first.key);
    _modelPromptController = TextEditingController(text: _currentModelPrompt);
    _userNameController = TextEditingController(text: widget.userProfile.name);
    _userGenderController =
        TextEditingController(text: widget.userProfile.gender);
    _userDescriptionController =
        TextEditingController(text: widget.userProfile.description);
  }

  List<_ModelPromptTarget> get _promptTargets => _providers
      .expand(
        (provider) => {
          ...provider.models,
          if (provider.selectedModel.isNotEmpty) provider.selectedModel,
        }.map(
              (model) => _ModelPromptTarget(
                providerId: provider.id,
                providerName: provider.name,
                model: model,
              ),
            ),
      )
      .toList();

  String get _currentModelPrompt {
    final target = _targetForKey(_promptTargetKey);
    if (target == null) return '';
    final provider = _providers.firstWhere(
      (item) => item.id == target.providerId,
    );
    return provider.systemPromptForModel(target.model);
  }

  _ModelPromptTarget? _targetForKey(String? key) {
    if (key == null) return null;
    for (final target in _promptTargets) {
      if (target.key == key) return target;
    }
    return null;
  }

  void _storePromptDraft() {
    final target = _targetForKey(_promptTargetKey);
    if (target == null) return;
    final index = _providers.indexWhere((item) => item.id == target.providerId);
    if (index < 0) return;
    final prompts = Map<String, String>.from(
      _providers[index].modelSystemPrompts,
    );
    final value = _modelPromptController.text.trim();
    if (value.isEmpty) {
      prompts.remove(target.model);
    } else {
      prompts[target.model] = value;
    }
    _providers[index] = _providers[index].copyWith(
      modelSystemPrompts: prompts,
    );
  }

  void _selectPromptTarget(String? key) {
    if (key == null || key == _promptTargetKey) return;
    _storePromptDraft();
    setState(() {
      _promptTargetKey = key;
      _modelPromptController.text = _currentModelPrompt;
    });
  }

  UserProfile get _userProfileDraft => UserProfile(
        name: _userNameController.text.trim(),
        gender: _userGenderController.text.trim(),
        description: _userDescriptionController.text.trim(),
      );

  Future<void> _persistSettings() async {
    _storePromptDraft();
    await widget.onSave(
      _reasoningExpanded,
      _contextTokenBudget,
      _userProfileDraft,
      _providers,
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
    _modelPromptController.dispose();
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
            '模型系统提示词',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          if (_promptTargets.isEmpty)
            const Card(
              elevation: 0,
              child: ListTile(
                title: Text('还没有可配置的模型'),
                subtitle: Text('请先在“模型供应商”中添加模型 ID'),
              ),
            )
          else ...[
            DropdownButtonFormField<String>(
              key: ValueKey(_promptTargetKey),
              initialValue: _promptTargetKey,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: '供应商与模型',
                filled: true,
                border: OutlineInputBorder(),
              ),
              items: _promptTargets
                  .map(
                    (target) => DropdownMenuItem(
                      value: target.key,
                      child: Text(
                        '${target.providerName} · ${target.model}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: _selectPromptTarget,
            ),
            const SizedBox(height: 10),
          TextField(
            controller: _modelPromptController,
            minLines: 6,
            maxLines: 14,
            decoration: const InputDecoration(
              labelText: '隐藏规则与禁忌',
              hintText: '例如：日常回复控制在1—3句话；不要使用某些表达……',
              helperText: '只对上方选中的模型生效；发送给模型但不显示在聊天中',
              alignLabelWithHint: true,
              filled: true,
              border: OutlineInputBorder(),
            ),
          ),
          ],
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

class _ModelPromptTarget {
  const _ModelPromptTarget({
    required this.providerId,
    required this.providerName,
    required this.model,
  });

  final String providerId;
  final String providerName;
  final String model;

  String get key => '$providerId\u0000$model';
}
