import 'package:flutter/material.dart';

import '../models/provider_profile.dart';
import '../services/provider_store.dart';

class ModelOutputSettingsScreen extends StatefulWidget {
  const ModelOutputSettingsScreen({super.key});

  @override
  State<ModelOutputSettingsScreen> createState() =>
      _ModelOutputSettingsScreenState();
}

class _ModelOutputSettingsScreenState
    extends State<ModelOutputSettingsScreen> {
  final _store = ProviderStore();
  final _tokensController = TextEditingController();
  List<ProviderProfile> _providers = const [];
  String? _providerId;
  String? _model;
  bool _loading = true;
  bool _saving = false;

  List<ProviderProfile> get _anthropicProviders => _providers
      .where((provider) => provider.protocol == ProviderProtocol.anthropic)
      .toList();

  ProviderProfile? get _provider {
    for (final provider in _anthropicProviders) {
      if (provider.id == _providerId) return provider;
    }
    return _anthropicProviders.isEmpty ? null : _anthropicProviders.first;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final providers = await _store.loadProviders();
    final selectedId = await _store.loadSelectedProviderId();
    final anthropic = providers
        .where((provider) => provider.protocol == ProviderProtocol.anthropic)
        .toList();
    ProviderProfile? selected;
    for (final provider in anthropic) {
      if (provider.id == selectedId) {
        selected = provider;
        break;
      }
    }
    selected ??= anthropic.isEmpty ? null : anthropic.first;
    final model = selected == null || selected.models.isEmpty
        ? null
        : (selected.models.contains(selected.selectedModel)
              ? selected.selectedModel
              : selected.models.first);
    if (!mounted) return;
    setState(() {
      _providers = providers;
      _providerId = selected?.id;
      _model = model;
      _loading = false;
    });
    _refreshTokens();
  }

  void _refreshTokens() {
    final provider = _provider;
    final model = _model;
    if (provider == null || model == null) {
      _tokensController.clear();
      return;
    }
    _tokensController.text = provider.maxOutputTokensForModel(model).toString();
  }

  void _selectProvider(String? id) {
    if (id == null) return;
    final provider = _anthropicProviders.firstWhere((item) => item.id == id);
    setState(() {
      _providerId = id;
      _model = provider.models.isEmpty
          ? null
          : (provider.models.contains(provider.selectedModel)
                ? provider.selectedModel
                : provider.models.first);
    });
    _refreshTokens();
  }

  void _selectModel(String? model) {
    if (model == null) return;
    setState(() => _model = model);
    _refreshTokens();
  }

  Future<void> _save() async {
    if (_saving) return;
    final provider = _provider;
    final model = _model;
    if (provider == null || model == null) return;
    final tokens = int.tryParse(_tokensController.text.trim());
    if (tokens == null ||
        tokens < ProviderProfile.minMaxOutputTokens ||
        tokens > ProviderProfile.maxMaxOutputTokens) {
      _notice(
        '请输入 ${ProviderProfile.minMaxOutputTokens}–${ProviderProfile.maxMaxOutputTokens} 之间的整数',
      );
      return;
    }
    setState(() => _saving = true);
    final limits = Map<String, int>.from(provider.modelMaxOutputTokens)
      ..[model] = tokens;
    final updated = provider.copyWith(modelMaxOutputTokens: limits);
    final providers = _providers
        .map((item) => item.id == updated.id ? updated : item)
        .toList();
    await _store.saveProviders(providers);
    if (!mounted) return;
    Navigator.pop(context);
  }

  void _notice(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  void dispose() {
    _tokensController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final providers = _anthropicProviders;
    final provider = _provider;
    final models = provider?.models ?? const <String>[];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Anthropic 输出上限'),
        actions: [
          TextButton(
            onPressed: _loading || provider == null || _model == null || _saving
                ? null
                : _save,
            child: Text(_saving ? '保存中…' : '保存'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : providers.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('当前没有 Anthropic 格式的供应商。请先在模型供应商中添加。'),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 32),
              children: [
                DropdownButtonFormField<String>(
                  initialValue: provider?.id,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: '供应商',
                    filled: true,
                    border: OutlineInputBorder(),
                  ),
                  items: providers
                      .map(
                        (item) => DropdownMenuItem(
                          value: item.id,
                          child: Text(item.name),
                        ),
                      )
                      .toList(),
                  onChanged: _selectProvider,
                ),
                const SizedBox(height: 14),
                if (models.isEmpty)
                  const Text('这个供应商还没有配置模型 ID。')
                else ...[
                  DropdownButtonFormField<String>(
                    key: ValueKey('${provider?.id}-${models.join('|')}-$_model'),
                    initialValue: models.contains(_model) ? _model : models.first,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: '模型',
                      filled: true,
                      border: OutlineInputBorder(),
                    ),
                    items: models
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
                    onChanged: _selectModel,
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _tokensController,
                    autofocus: false,
                    keyboardType: TextInputType.number,
                    autocorrect: false,
                    decoration: const InputDecoration(
                      labelText: '最大输出 Tokens',
                      hintText: '4096',
                      filled: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '每个模型单独保存。旧配置默认使用 '
                    '${ProviderProfile.defaultAnthropicMaxOutputTokens}；'
                    '实际请求还会受当前上下文预算限制。',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}
