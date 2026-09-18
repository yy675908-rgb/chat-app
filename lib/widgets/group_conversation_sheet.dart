import 'package:flutter/material.dart';

import '../models/character_profile.dart';

class GroupConversationDraft {
  const GroupConversationDraft({
    required this.title,
    required this.participantIds,
  });

  final String title;
  final List<String> participantIds;
}

Future<GroupConversationDraft?> showGroupConversationSheet({
  required BuildContext context,
  required List<CharacterProfile> characters,
  required String Function(String characterId) moodForCharacter,
}) async {
  final selectedIds = characters.map((item) => item.id).toSet();
  final titleController = TextEditingController();
  try {
    return await showModalBottomSheet<GroupConversationDraft>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              18,
              0,
              18,
              MediaQuery.viewInsetsOf(context).bottom + 18,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.78,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '创建群聊',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: titleController,
                    autofocus: false,
                    onTapOutside: (_) => FocusScope.of(context).unfocus(),
                    decoration: const InputDecoration(
                      labelText: '群聊名称（可不填）',
                      filled: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '选择角色 · 已选 ${selectedIds.length}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        for (final character in characters)
                          CheckboxListTile(
                            value: selectedIds.contains(character.id),
                            title: Text(character.name),
                            subtitle: moodForCharacter(character.id).isEmpty
                                ? null
                                : Text(moodForCharacter(character.id)),
                            onChanged: (checked) {
                              setSheetState(() {
                                if (checked == true) {
                                  selectedIds.add(character.id);
                                } else {
                                  selectedIds.remove(character.id);
                                }
                              });
                            },
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: selectedIds.length < 2
                        ? null
                        : () => Navigator.pop(
                            context,
                            GroupConversationDraft(
                              title: titleController.text.trim(),
                              participantIds: selectedIds.toList(),
                            ),
                          ),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                    icon: const Icon(Icons.groups_2_outlined),
                    label: const Text('创建群聊'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  } finally {
    titleController.dispose();
  }
}
