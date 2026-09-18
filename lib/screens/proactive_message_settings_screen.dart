import 'package:flutter/material.dart';

import '../models/character_profile.dart';
import '../models/proactive_message_settings.dart';
import '../services/chat_store.dart';
import '../services/proactive_message_coordinator.dart';
import '../services/proactive_message_store.dart';
import '../services/proactive_notification_service.dart';

class ProactiveMessageSettingsScreen extends StatefulWidget {
  const ProactiveMessageSettingsScreen({super.key});

  @override
  State<ProactiveMessageSettingsScreen> createState() =>
      _ProactiveMessageSettingsScreenState();
}

class _ProactiveMessageSettingsScreenState
    extends State<ProactiveMessageSettingsScreen> {
  final _chatStore = ChatStore();
  final _store = const ProactiveMessageStore();
  final _notifications = const ProactiveNotificationService();
  final _coordinator = const ProactiveMessageCoordinator();

  List<CharacterProfile> _characters = const [];
  ProactiveMessageSettings _settings = const ProactiveMessageSettings();
  String? _selectedCharacterId;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final characters = await _chatStore.loadCharacters();
    final selectedCharacterId = await _chatStore.loadSelectedCharacterId();
    final settings = await _store.loadSettings();
    if (!mounted) return;
    setState(() {
      _characters = characters;
      _selectedCharacterId = selectedCharacterId;
      _settings = settings;
      _loading = false;
    });
  }

  String _frequencyLabel(ProactiveFrequency value) => switch (value) {
    ProactiveFrequency.occasional => '偶尔 · 约 48 小时',
    ProactiveFrequency.balanced => '适中 · 约 24 小时',
    ProactiveFrequency.frequent => '较频繁 · 约 8 小时',
  };

  TimeOfDay _timeFromMinutes(int minutes) =>
      TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60);

  String _timeLabel(int minutes) {
    final time = _timeFromMinutes(minutes);
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(time.hour)}:${two(time.minute)}';
  }

  Future<void> _pickQuietStart() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _timeFromMinutes(_settings.quietStartMinutes),
      helpText: '安静时段开始',
    );
    if (time == null || !mounted) return;
    setState(() {
      _settings = _settings.copyWith(
        quietStartMinutes: time.hour * 60 + time.minute,
      );
    });
  }

  Future<void> _pickQuietEnd() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _timeFromMinutes(_settings.quietEndMinutes),
      helpText: '安静时段结束',
    );
    if (time == null || !mounted) return;
    setState(() {
      _settings = _settings.copyWith(
        quietEndMinutes: time.hour * 60 + time.minute,
      );
    });
  }

  void _setEnabled(bool value) {
    var ids = _settings.enabledCharacterIds;
    if (value && ids.isEmpty) {
      final selectedId = _selectedCharacterId;
      if (selectedId != null &&
          _characters.any((character) => character.id == selectedId)) {
        ids = [selectedId];
      } else if (_characters.isNotEmpty) {
        ids = [_characters.first.id];
      }
    }
    setState(() {
      _settings = _settings.copyWith(
        enabled: value,
        enabledCharacterIds: ids,
      );
    });
  }

  void _toggleCharacter(String characterId, bool enabled) {
    final ids = _settings.enabledCharacterIds.toSet();
    if (enabled) {
      ids.add(characterId);
    } else {
      ids.remove(characterId);
    }
    setState(() {
      _settings = _settings.copyWith(enabledCharacterIds: ids.toList());
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    if (_settings.enabled && _settings.enabledCharacterIds.isEmpty) {
      _notice('至少选择一个可以主动找你的角色');
      return;
    }

    setState(() => _saving = true);
    try {
      var settings = _settings;
      if (settings.enabled) {
        final granted = await _notifications.requestPermission();
        if (!granted) {
          settings = settings.copyWith(enabled: false);
          if (mounted) setState(() => _settings = settings);
          _notice('没有通知权限，主动消息暂未启用');
        }
      }
      await _store.saveSettings(settings);
      await _coordinator.reschedule(characters: _characters);
      if (!mounted) return;
      Navigator.pop(context, true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _notice(String message) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('主动消息与通知'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? '保存中…' : '保存'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 32),
        children: [
          Card(
            elevation: 0,
            child: SwitchListTile(
              title: const Text('允许角色主动找你'),
              subtitle: const Text(
                '到时间后本机只发通知；打开 App 后才会按最新对话生成真正的主动内容，不会在后台调用 API。',
              ),
              value: _settings.enabled,
              onChanged: _setEnabled,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            '角色',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Card(
            elevation: 0,
            child: Column(
              children: [
                for (var index = 0; index < _characters.length; index++) ...[
                  SwitchListTile(
                    title: Text(_characters[index].name),
                    subtitle: const Text('允许这个角色主动发起单聊'),
                    value: _settings.enabledCharacterIds.contains(
                      _characters[index].id,
                    ),
                    onChanged: _settings.enabled
                        ? (value) =>
                              _toggleCharacter(_characters[index].id, value)
                        : null,
                  ),
                  if (index != _characters.length - 1)
                    const Divider(height: 1),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            '频率',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<ProactiveFrequency>(
            initialValue: _settings.frequency,
            decoration: const InputDecoration(
              labelText: '主动联系频率',
              filled: true,
              border: OutlineInputBorder(),
            ),
            items: [
              for (final value in ProactiveFrequency.values)
                DropdownMenuItem(
                  value: value,
                  child: Text(_frequencyLabel(value)),
                ),
            ],
            onChanged: _settings.enabled
                ? (value) {
                    if (value != null) {
                      setState(() {
                        _settings = _settings.copyWith(frequency: value);
                      });
                    }
                  }
                : null,
          ),
          const SizedBox(height: 24),
          const Text(
            '安静时段',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Card(
            elevation: 0,
            child: Column(
              children: [
                ListTile(
                  enabled: _settings.enabled,
                  leading: const Icon(Icons.bedtime_outlined),
                  title: const Text('开始'),
                  trailing: Text(_timeLabel(_settings.quietStartMinutes)),
                  onTap: _settings.enabled ? _pickQuietStart : null,
                ),
                const Divider(height: 1),
                ListTile(
                  enabled: _settings.enabled,
                  leading: const Icon(Icons.wb_sunny_outlined),
                  title: const Text('结束'),
                  trailing: Text(_timeLabel(_settings.quietEndMinutes)),
                  onTap: _settings.enabled ? _pickQuietEnd : null,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '安静时段内不会安排提醒；例如 23:00–08:00 会把落在夜间的下一次提醒顺延到早上。',
            style: TextStyle(
              color: scheme.onSurfaceVariant,
              fontSize: 12,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
