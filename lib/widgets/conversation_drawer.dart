import 'dart:async';

import 'package:flutter/material.dart';

import '../models/character_profile.dart';
import '../models/conversation.dart';

class ConversationDrawer extends StatelessWidget {
  const ConversationDrawer({
    super.key,
    required this.profile,
    required this.currentMood,
    required this.groupScope,
    required this.conversations,
    required this.selectedId,
    required this.onNew,
    required this.onNewGroup,
    required this.onSearch,
    required this.onSelect,
    required this.onDelete,
    required this.onRename,
    required this.onCharacterPicker,
    required this.onIntimacyChanged,
    required this.onEditCharacter,
    required this.onFavorites,
    required this.onMemoryWorld,
    required this.onSettings,
    required this.onAppSettings,
  });

  final CharacterProfile profile;
  final String currentMood;
  final bool groupScope;
  final List<Conversation> conversations;
  final String? selectedId;
  final VoidCallback onNew;
  final VoidCallback onNewGroup;
  final VoidCallback onSearch;
  final ValueChanged<Conversation> onSelect;
  final ValueChanged<Conversation> onDelete;
  final ValueChanged<Conversation> onRename;
  final VoidCallback onCharacterPicker;
  final Future<void> Function(int value) onIntimacyChanged;
  final VoidCallback onEditCharacter;
  final VoidCallback onFavorites;
  final VoidCallback onMemoryWorld;
  final VoidCallback onSettings;
  final VoidCallback onAppSettings;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final drawerMoodRaw = currentMood.trim();
    final drawerMood = drawerMoodRaw.characters.length > 10
        ? drawerMoodRaw.characters.take(10).join()
        : drawerMoodRaw;
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 10, 8),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: scheme.secondaryContainer,
                    child: groupScope
                        ? Icon(
                            Icons.groups_2_outlined,
                            color: scheme.onSecondaryContainer,
                          )
                        : Text(
                            profile.name.isEmpty
                                ? '林'
                                : profile.name.characters.first,
                            style: TextStyle(
                              color: scheme.onSecondaryContainer,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: InkWell(
                      onTap: onCharacterPicker,
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              groupScope ? '群聊' : profile.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              groupScope
                                  ? '点击切换到角色或其他分组'
                                  : (drawerMood.isEmpty
                                        ? '点击切换角色或进入群聊'
                                        : drawerMood),
                              style: TextStyle(
                                color: scheme.onSurfaceVariant,
                                fontSize: 11.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: '切换对话空间',
                    onPressed: onCharacterPicker,
                    icon: const Icon(Icons.unfold_more_rounded, size: 20),
                  ),
                ],
              ),
            ),
            if (!groupScope)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 2, 12, 8),
                child: _IntimacyControl(
                  value: profile.userIntimacy,
                  onChanged: (value) {
                    unawaited(onIntimacyChanged(value));
                  },
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 6),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: groupScope ? onNewGroup : onNew,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(42),
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                      ),
                      icon: Icon(
                        groupScope
                            ? Icons.group_add_outlined
                            : Icons.add_comment_outlined,
                        size: 18,
                      ),
                      label: Text(
                        groupScope ? '新群聊' : '新对话',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onSearch,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(42),
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                      ),
                      icon: const Icon(Icons.search_rounded, size: 18),
                      label: const Text(
                        '搜索记录',
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 16, 6),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  groupScope ? '群聊会话' : '最近对话',
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                itemCount: conversations.length,
                itemBuilder: (context, index) {
                  final conversation = conversations[index];
                  final selected = conversation.id == selectedId;
                  return ListTile(
                    selected: selected,
                    selectedTileColor: scheme.secondaryContainer,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    leading: Icon(
                      conversation.isGroup
                          ? Icons.groups_2_outlined
                          : Icons.chat_bubble_outline_rounded,
                      size: 19,
                    ),
                    title: Text(
                      conversation.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14),
                    ),
                    trailing: PopupMenuButton<String>(
                      tooltip: '对话操作',
                      onSelected: (value) {
                        if (value == 'rename') onRename(conversation);
                        if (value == 'delete') onDelete(conversation);
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'rename', child: Text('修改名称')),
                        PopupMenuItem(value: 'delete', child: Text('删除对话')),
                      ],
                    ),
                    onTap: () => onSelect(conversation),
                  );
                },
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _DrawerShortcut(
                          icon: Icons.favorite_border_rounded,
                          label: '收藏',
                          onTap: onFavorites,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _DrawerShortcut(
                          icon: Icons.menu_book_outlined,
                          label: '记忆与世界',
                          onTap: onMemoryWorld,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _DrawerShortcut(
                          icon: groupScope
                              ? Icons.people_alt_outlined
                              : Icons.manage_accounts_outlined,
                          label: groupScope ? '角色与好感度' : '角色设定',
                          onTap: groupScope
                              ? onCharacterPicker
                              : onEditCharacter,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _DrawerShortcut(
                          icon: Icons.tune_rounded,
                          label: '模型供应商',
                          onTap: onSettings,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _DrawerShortcut(
                    icon: Icons.settings_outlined,
                    label: '设置与数据',
                    onTap: onAppSettings,
                    wide: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }
}

class _IntimacyControl extends StatefulWidget {
  const _IntimacyControl({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  State<_IntimacyControl> createState() => _IntimacyControlState();
}

class _IntimacyControlState extends State<_IntimacyControl> {
  late int _value;

  @override
  void initState() {
    super.initState();
    _value = widget.value;
  }

  @override
  void didUpdateWidget(covariant _IntimacyControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) _value = widget.value;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 7, 8, 6),
        child: Column(
          children: [
            Row(
              children: [
                const Text(
                  '用户好感度',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                ),
                const SizedBox(width: 2),
                Tooltip(
                  message:
                      '表示你对这个角色的好感，不等于关系类型；角色能感知这个数值，并会按自己的性格决定如何反应。',
                  child: Icon(
                    Icons.info_outline_rounded,
                    size: 15,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                Text(
                  '$_value · ${_intimacyLabel(_value)}',
                  style: TextStyle(
                    color: scheme.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            SizedBox(
              height: 30,
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 3,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 7.5,
                  ),
                  overlayShape: const RoundSliderOverlayShape(
                    overlayRadius: 14,
                  ),
                ),
                child: Slider(
                  value: _value.toDouble(),
                  min: 0,
                  max: 100,
                  divisions: 100,
                  label: '$_value',
                  onChanged: (value) {
                    setState(() => _value = value.round());
                  },
                  onChangeEnd: (value) {
                    widget.onChanged(value.round());
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _intimacyLabel(int value) {
  if (value < 20) return '很低';
  if (value < 40) return '偏低';
  if (value < 60) return '一般';
  if (value < 80) return '较高';
  return '很高';
}

class _DrawerShortcut extends StatelessWidget {
  const _DrawerShortcut({
    required this.icon,
    required this.label,
    required this.onTap,
    this.wide = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(15),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 48,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: wide ? 14 : 10),
            child: Row(
              mainAxisAlignment: wide
                  ? MainAxisAlignment.start
                  : MainAxisAlignment.center,
              children: [
                Icon(icon, size: 19, color: scheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
