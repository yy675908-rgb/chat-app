import 'package:flutter/material.dart';

import '../models/character_profile.dart';
import '../models/provider_profile.dart';

class ChatModelChoice {
  const ChatModelChoice({required this.provider, required this.model});

  final ProviderProfile provider;
  final String model;
}

Future<ChatModelChoice?> showChatModelPickerSheet({
  required BuildContext context,
  required List<ProviderProfile> providers,
  required ProviderProfile? selectedProvider,
  required VoidCallback onManageProviders,
}) async {
  final available = providers.where((provider) => provider.models.isNotEmpty).toList();
  if (available.isEmpty) return null;

  var providerId =
      available.any((provider) => provider.id == selectedProvider?.id)
          ? selectedProvider!.id
          : available.first.id;

  return showModalBottomSheet<ChatModelChoice>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    sheetAnimationStyle: const AnimationStyle(
      duration: Duration(milliseconds: 300),
      reverseDuration: Duration(milliseconds: 260),
    ),
    builder: (context) => StatefulBuilder(
      builder: (context, setSheetState) {
        final provider = available.firstWhere((item) => item.id == providerId);
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.72,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 10, 8),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          '选择模型',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: '管理供应商',
                        onPressed: () {
                          Navigator.pop(context);
                          onManageProviders();
                        },
                        icon: const Icon(Icons.tune_rounded),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: DropdownButtonFormField<String>(
                    initialValue: providerId,
                    decoration: const InputDecoration(
                      labelText: '供应商',
                      filled: true,
                    ),
                    items: [
                      for (final item in available)
                        DropdownMenuItem<String>(
                          value: item.id,
                          child: Text(item.name),
                        ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setSheetState(() => providerId = value);
                      }
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                  child: Text(
                    '只显示已添加且已有模型的供应商',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 11.5,
                    ),
                  ),
                ),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    padding: const EdgeInsets.fromLTRB(10, 4, 10, 18),
                    children: [
                      for (final model in provider.models)
                        ListTile(
                          leading: Icon(
                            selectedProvider?.id == provider.id &&
                                    selectedProvider?.selectedModel == model
                                ? Icons.check_circle_rounded
                                : Icons.circle_outlined,
                          ),
                          title: Text(model),
                          onTap: () => Navigator.pop(
                            context,
                            ChatModelChoice(provider: provider, model: model),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

enum ConversationSpaceAction { character, groups, add, delete }

class ConversationSpaceChoice {
  const ConversationSpaceChoice._({
    required this.action,
    this.characterId = '',
  });

  const ConversationSpaceChoice.character(String characterId)
    : this._(
        action: ConversationSpaceAction.character,
        characterId: characterId,
      );

  const ConversationSpaceChoice.groups()
    : this._(action: ConversationSpaceAction.groups);

  const ConversationSpaceChoice.add()
    : this._(action: ConversationSpaceAction.add);

  const ConversationSpaceChoice.delete(String characterId)
    : this._(
        action: ConversationSpaceAction.delete,
        characterId: characterId,
      );

  final ConversationSpaceAction action;
  final String characterId;
}

Future<ConversationSpaceChoice?> showConversationSpacePickerSheet({
  required BuildContext context,
  required List<CharacterProfile> characters,
  required CharacterProfile currentProfile,
  required bool groupScope,
}) {
  return showModalBottomSheet<ConversationSpaceChoice>(
    context: context,
    showDragHandle: true,
    sheetAnimationStyle: const AnimationStyle(
      duration: Duration(milliseconds: 300),
      reverseDuration: Duration(milliseconds: 260),
    ),
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 18),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.68,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(10, 0, 10, 8),
                child: Text(
                  '切换对话空间',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    const Padding(
                      padding: EdgeInsets.fromLTRB(10, 4, 10, 4),
                      child: Text(
                        '群聊',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    ListTile(
                      leading: const CircleAvatar(
                        child: Icon(Icons.groups_2_outlined),
                      ),
                      title: const Text('群聊'),
                      subtitle: Text(
                        groupScope ? '当前分组' : '独立于所有角色的多人对话',
                      ),
                      trailing: groupScope
                          ? const Icon(Icons.check_circle_rounded)
                          : null,
                      onTap: () => Navigator.pop(
                        context,
                        const ConversationSpaceChoice.groups(),
                      ),
                    ),
                    const Divider(height: 18),
                    const Padding(
                      padding: EdgeInsets.fromLTRB(10, 4, 10, 4),
                      child: Text(
                        '角色',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    for (final character in characters)
                      ListTile(
                        leading: CircleAvatar(
                          child: Text(
                            character.name.isEmpty
                                ? '角'
                                : character.name.characters.first,
                          ),
                        ),
                        title: Text(character.name),
                        subtitle: Text(
                          !groupScope && character.id == currentProfile.id
                              ? '当前角色'
                              : '切换到这个角色',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (!groupScope && character.id == currentProfile.id)
                              const Icon(Icons.check_circle_rounded),
                            IconButton(
                              tooltip: characters.length <= 1
                                  ? '至少保留一个角色'
                                  : '删除角色',
                              onPressed: characters.length <= 1
                                  ? null
                                  : () => Navigator.pop(
                                      context,
                                      ConversationSpaceChoice.delete(
                                        character.id,
                                      ),
                                    ),
                              icon: const Icon(Icons.delete_outline_rounded),
                            ),
                          ],
                        ),
                        onTap: () => Navigator.pop(
                          context,
                          ConversationSpaceChoice.character(character.id),
                        ),
                      ),
                    const Divider(height: 14),
                    ListTile(
                      leading: const Icon(Icons.person_add_alt_1_rounded),
                      title: const Text('添加新角色'),
                      subtitle: const Text('创建独立的角色设定与对话'),
                      onTap: () => Navigator.pop(
                        context,
                        const ConversationSpaceChoice.add(),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
