import 'dart:async';

import 'package:flutter/material.dart';

import '../models/provider_profile.dart';
import '../services/ai_chat_service.dart';
import '../services/provider_service.dart';
import '../services/provider_store.dart';

class ApiSettingsScreen extends StatefulWidget {
  const ApiSettingsScreen({super.key});

  @override
  State<ApiSettingsScreen> createState() => _ApiSettingsScreenState();
}

class _ApiSettingsScreenState extends State<ApiSettingsScreen> {
  final _store = ProviderStore();
  List<ProviderProfile> _providers = const [];
  String? _selectedId;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final providers = await _store.loadProviders();
    final selected = await _store.loadSelectedProviderId();
    if (!mounted) return;
    setState(() {
      _providers = providers;
      _selectedId = providers.any((item) => item.id == selected)
          ? selected
          : (providers.isEmpty ? null : providers.first.id);
      _loading = false;
    });
    if (_selectedId != null && _selectedId != selected) {
      await _store.saveSelectedProviderId(_selectedId!);
    }
  }

  Future<void> _select(String id) async {
    await _store.saveSelectedProviderId(id);
    if (!mounted) return;
    setState(() => _selectedId = id);
  }

  Future<void> _addProvider() async {
    final protocol = await showModalBottomSheet<ProviderProtocol>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(8, 0, 8, 8),
                child: Text(
                  '选择接口类型',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.hub_outlined),
                title: const Text('OpenAI 兼容'),
                subtitle: const Text('适合 OpenAI、代理站和大多数聚合服务'),
                onTap: () => Navigator.pop(
                  context,
                  ProviderProtocol.openAiCompatible,
                ),
              ),
              ListTile(
                leading: const Icon(Icons.auto_awesome_outlined),
                title: const Text('Anthropic'),
                subtitle: const Text('Claude 原生 Messages API'),
                onTap: () =>
                    Navigator.pop(context, ProviderProtocol.anthropic),
              ),
            ],
          ),
        ),
      ),
    );
    if (protocol == null || !mounted) return;
    final now = DateTime.now().microsecondsSinceEpoch;
    final provider = ProviderProfile(
      id: 'provider-$now',
      name: protocol == ProviderProtocol.anthropic
          ? 'Anthropic'
          : 'OpenAI 兼容',
      protocol: protocol,
      baseUrl: protocol == ProviderProtocol.anthropic
          ? 'https://api.anthropic.com/v1'
          : 'https://api.openai.com/v1',
      models: const [],
      selectedModel: '',
    );
    await _editProvider(provider, isNew: true);
  }

  Future<void> _editProvider(
    ProviderProfile provider, {
    bool isNew = false,
  }) async {
    final updated = await Navigator.of(context).push<ProviderProfile>(
      MaterialPageRoute<ProviderProfile>(
        builder: (_) => ProviderEditScreen(provider: provider),
      ),
    );
    if (updated == null) return;
    final providers = [..._providers];
    final index = providers.indexWhere((item) => item.id == updated.id);
    if (index == -1) {
      providers.add(updated);
    } else {
      providers[index] = updated;
    }
    await _store.saveProviders(providers);
    if (isNew || _selectedId == null) {
      await _store.saveSelectedProviderId(updated.id);
    }
    if (!mounted) return;
    setState(() {
      _providers = providers;
      if (isNew || _selectedId == null) _selectedId = updated.id;
    });
  }

  Future<void> _delete(ProviderProfile provider) async {
    if (_providers.length == 1) {
      _show('至少保留一个供应商');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('删除“${provider.name}”？'),
        content: const Text('对应的本机 API Key 也会一并删除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final providers = _providers.where((item) => item.id != provider.id).toList();
    await _store.saveProviders(providers);
    await _store.deleteProviderKey(provider.id);
    var selected = _selectedId;
    if (selected == provider.id) {
      selected = providers.first.id;
      await _store.saveSelectedProviderId(selected);
    }
    if (!mounted) return;
    setState(() {
      _providers = providers;
      _selectedId = selected;
    });
  }

  void _show(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('模型供应商'),
        actions: [
          IconButton(
            tooltip: '添加供应商',
            onPressed: _addProvider,
            icon: const Icon(Icons.add_rounded),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
              children: [
                const _PrivacyNote(),
                const SizedBox(height: 16),
                ..._providers.map(
                  (provider) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Material(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(20),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => _editProvider(provider),
                        onLongPress: () => _delete(provider),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(10, 10, 8, 10),
                          child: Row(
                            children: [
                              IconButton(
                                tooltip: '设为当前供应商',
                                onPressed: () => _select(provider.id),
                                icon: Icon(
                                  _selectedId == provider.id
                                      ? Icons.check_circle_rounded
                                      : Icons.circle_outlined,
                                ),
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      provider.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      provider.selectedModel.isEmpty
                                          ? '尚未选择模型'
                                          : provider.selectedModel,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
                                        fontSize: 12.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                tooltip: '编辑',
                                onPressed: () => _editProvider(provider),
                                icon: const Icon(Icons.chevron_right_rounded),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                TextButton.icon(
                  onPressed: _addProvider,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('添加供应商'),
                ),
                const SizedBox(height: 8),
                Text(
                  '长按供应商可以删除。聊天页顶部可直接切换模型。',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
    );
  }
}

class ProviderEditScreen extends StatefulWidget {
  const ProviderEditScreen({required this.provider, super.key});

  final ProviderProfile provider;

  @override
  State<ProviderEditScreen> createState() => _ProviderEditScreenState();
}

class _ProviderEditScreenState extends State<ProviderEditScreen> {
  final _store = ProviderStore();
  final _service = ProviderService();
  late final TextEditingController _nameController;
  late final TextEditingController _baseController;
  late final TextEditingController _keyController;
  late final TextEditingController _modelsController;
  late ProviderProtocol _protocol;
  String _selectedModel = '';
  bool _loadingKey = true;
  bool _fetching = false;
  bool _obscureKey = true;

  @override
  void initState() {
    super.initState();
    final provider = widget.provider;
    _protocol = provider.protocol;
    _selectedModel = provider.selectedModel;
    _nameController = TextEditingController(text: provider.name);
    _baseController = TextEditingController(text: provider.baseUrl);
    _keyController = TextEditingController();
    _modelsController = TextEditingController(text: provider.models.join('\n'));
    unawaited(_loadKey());
  }

  Future<void> _loadKey() async {
    _keyController.text = await _store.loadApiKey(widget.provider.id);
    if (mounted) setState(() => _loadingKey = false);
  }

  List<String> get _models => _modelsController.text
      .split(RegExp(r'[\n,]'))
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toSet()
      .toList();

  ProviderProfile _draft() {
    final models = _models;
    final selected = models.contains(_selectedModel)
        ? _selectedModel
        : (models.isEmpty ? '' : models.first);
    return widget.provider.copyWith(
      name: _nameController.text.trim(),
      protocol: _protocol,
      baseUrl: _baseController.text.trim(),
      models: models,
      selectedModel: selected,
    );
  }

  Future<void> _fetchModels() async {
    final draft = _draft();
    final uri = Uri.tryParse(draft.baseUrl);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      _show('先填写正确的 API 地址');
      return;
    }
    setState(() => _fetching = true);
    try {
      final models = await _service.fetchModels(draft, _keyController.text);
      if (!mounted) return;
      setState(() {
        _modelsController.text = models.join('\n');
        if (!models.contains(_selectedModel)) _selectedModel = models.first;
      });
      _show('已读取 ${models.length} 个模型');
    } on AiChatException catch (error) {
      _show(error.message);
    } finally {
      if (mounted) setState(() => _fetching = false);
    }
  }

  Future<void> _save() async {
    final draft = _draft();
    final uri = Uri.tryParse(draft.baseUrl);
    if (draft.name.isEmpty) {
      _show('供应商名称不能为空');
      return;
    }
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      _show('API 地址不正确');
      return;
    }
    if (draft.selectedModel.isEmpty) {
      _show('至少填写一个模型 ID');
      return;
    }
    if (_keyController.text.trim().isEmpty) {
      _show('API Key 不能为空');
      return;
    }
    await _store.saveApiKey(draft.id, _keyController.text);
    if (!mounted) return;
    Navigator.pop(context, draft);
  }

  void _show(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _baseController.dispose();
    _keyController.dispose();
    _modelsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('供应商设置'),
        actions: [
          TextButton(onPressed: _save, child: const Text('保存')),
          const SizedBox(width: 8),
        ],
      ),
      body: _loadingKey
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                DropdownButtonFormField<ProviderProtocol>(
                  initialValue: _protocol,
                  isExpanded: true,
                  itemHeight: null,
                  menuMaxHeight: 360,
                  decoration: const InputDecoration(
                    labelText: '接口格式',
                    filled: true,
                    border: OutlineInputBorder(),
                  ),
                  selectedItemBuilder: (context) => const [
                    _ProtocolSelectedLabel(
                      icon: Icons.hub_outlined,
                      text: 'OpenAI 兼容',
                    ),
                    _ProtocolSelectedLabel(
                      icon: Icons.auto_awesome_outlined,
                      text: 'Anthropic',
                    ),
                  ],
                  items: const [
                    DropdownMenuItem(
                      value: ProviderProtocol.openAiCompatible,
                      child: _ProtocolOption(
                        title: 'OpenAI 兼容',
                        providers:
                            '常见：OpenAI、DeepSeek、OpenRouter、硅基流动、Kimi、通义千问',
                      ),
                    ),
                    DropdownMenuItem(
                      value: ProviderProtocol.anthropic,
                      child: _ProtocolOption(
                        title: 'Anthropic',
                        providers:
                            '常见：Anthropic Claude、DeepSeek Anthropic 接口及兼容代理',
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _protocol = value);
                  },
                ),
                const SizedBox(height: 7),
                Text(
                  '这里选择的是接口格式，不是限定供应商；请以服务商提供的 API 文档为准。',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 11.5,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: '名称',
                    filled: true,
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _baseController,
                  keyboardType: TextInputType.url,
                  autocorrect: false,
                  decoration: InputDecoration(
                    labelText: 'Base URL',
                    hintText: _protocol == ProviderProtocol.anthropic
                        ? 'https://api.anthropic.com/v1'
                        : 'https://api.openai.com/v1',
                    prefixIcon: const Icon(Icons.link_rounded),
                    filled: true,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _keyController,
                  obscureText: _obscureKey,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: InputDecoration(
                    labelText: 'API Key',
                    prefixIcon: const Icon(Icons.key_rounded),
                    suffixIcon: IconButton(
                      onPressed: () =>
                          setState(() => _obscureKey = !_obscureKey),
                      icon: Icon(
                        _obscureKey
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                    filled: true,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        '模型 ID',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _fetching ? null : _fetchModels,
                      icon: _fetching
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.cloud_download_outlined),
                      label: const Text('读取列表'),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _modelsController,
                  minLines: 3,
                  maxLines: 8,
                  autocorrect: false,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    hintText: '每行一个模型 ID，也可以用逗号分隔',
                    filled: true,
                    border: OutlineInputBorder(),
                  ),
                ),
                if (_models.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: _models.contains(_selectedModel)
                        ? _selectedModel
                        : _models.first,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: '默认模型',
                      filled: true,
                      border: OutlineInputBorder(),
                    ),
                    items: _models
                        .map(
                          (model) => DropdownMenuItem(
                            value: model,
                            child: Text(
                              model,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) =>
                        setState(() => _selectedModel = value ?? ''),
                  ),
                ],
                const SizedBox(height: 14),
                Text(
                  '读取模型失败不代表聊天接口不可用。有些代理不提供 /models，请直接手动填写。',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 12,
                    height: 1.45,
                  ),
                ),
              ],
            ),
    );
  }
}

class _ProtocolSelectedLabel extends StatelessWidget {
  const _ProtocolSelectedLabel({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 10),
        Text(text),
      ],
    );
  }
}

class _ProtocolOption extends StatelessWidget {
  const _ProtocolOption({
    required this.title,
    required this.providers,
  });

  final String title;
  final String providers;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 3),
          Text(
            providers,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 11.5,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _PrivacyNote extends StatelessWidget {
  const _PrivacyNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lock_outline_rounded, size: 21),
          SizedBox(width: 11),
          Expanded(
            child: Text(
              'API Key 使用 Android 加密存储。供应商配置与聊天记录仅保存在本机。',
              style: TextStyle(height: 1.45),
            ),
          ),
        ],
      ),
    );
  }
}
