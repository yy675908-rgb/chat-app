import 'package:flutter/material.dart';

import '../models/api_profile.dart';
import '../services/api_settings_store.dart';

class ApiSettingsScreen extends StatefulWidget {
  const ApiSettingsScreen({super.key});

  @override
  State<ApiSettingsScreen> createState() => _ApiSettingsScreenState();
}

class _ApiSettingsScreenState extends State<ApiSettingsScreen> {
  final _store = ApiSettingsStore();
  final _baseUrlController = TextEditingController();
  final _modelController = TextEditingController();
  final _keyController = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  bool _obscureKey = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final profile = await _store.loadProfile();
    final key = await _store.loadApiKey();
    if (!mounted) return;
    _baseUrlController.text = profile.baseUrl;
    _modelController.text = profile.model;
    _keyController.text = key;
    setState(() => _loading = false);
  }

  Future<void> _save() async {
    final baseUrl = _baseUrlController.text.trim();
    final model = _modelController.text.trim();
    final uri = Uri.tryParse(baseUrl);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      _show('接口地址不正确');
      return;
    }
    if (model.isEmpty) {
      _show('请填写模型名称');
      return;
    }
    setState(() => _saving = true);
    await _store.save(
      ApiProfile(baseUrl: baseUrl, model: model),
      _keyController.text,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    Navigator.of(context).pop(true);
  }

  void _show(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  void dispose() {
    _baseUrlController.dispose();
    _modelController.dispose();
    _keyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('模型设置')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 30),
              children: [
                const _SettingIntro(),
                const SizedBox(height: 18),
                TextField(
                  controller: _baseUrlController,
                  keyboardType: TextInputType.url,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    labelText: 'API 地址',
                    hintText: 'https://api.openai.com/v1',
                    prefixIcon: Icon(Icons.link_rounded),
                    filled: true,
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _modelController,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    labelText: '模型名称',
                    hintText: '填写服务商提供的模型 ID',
                    prefixIcon: Icon(Icons.smart_toy_outlined),
                    filled: true,
                    border: OutlineInputBorder(),
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
                const SizedBox(height: 10),
                const Text(
                  '支持 OpenAI 兼容的 /chat/completions 接口。密钥会加密保存在本机，不会写入聊天记录。',
                  style: TextStyle(
                    color: Color(0xFF777A74),
                    fontSize: 12,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                  ),
                  child: Text(_saving ? '保存中…' : '保存设置'),
                ),
              ],
            ),
    );
  }
}

class _SettingIntro extends StatelessWidget {
  const _SettingIntro();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFCF7),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.auto_awesome_rounded, color: Color(0xFFB56E50)),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              '连接你自己的模型服务后，林才会真正回复。只需要设置一次。',
              style: TextStyle(height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}
