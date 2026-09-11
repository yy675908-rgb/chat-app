from pathlib import Path
import re


def replace_once(text, old, new, label):
    if old not in text:
        raise SystemExit(f'{label} not found')
    return text.replace(old, new, 1)

chat_path = Path('lib/screens/chat_screen.dart')
text = chat_path.read_text()

# Restore legacy status only as a fallback source for the single mood value.
text = replace_once(
    text,
    """      final mood = await _chatStore.loadCharacterMood(character.id);\n      if (mood.isNotEmpty) characterMoods[character.id] = mood;\n""",
    """      final storedMood = await _chatStore.loadCharacterMood(character.id);\n      final mood = _normalizeMood(\n        storedMood.trim().isEmpty ? character.status.trim() : storedMood,\n      );\n      if (mood.isNotEmpty) characterMoods[character.id] = mood;\n""",
    'restore mood fallback',
)

text = replace_once(
    text,
    "'“${conversation.title}”会从这台设备删除。由这段对话产生的共同记忆、回应偏好、心绪和状态也会一并清除。'",
    "'“${conversation.title}”会从这台设备删除。由这段对话产生的共同记忆、回应偏好和心绪也会一并清除。'",
    'delete copy',
)

text = replace_once(
    text,
    """      final mood = await _chatStore.loadCharacterMood(character.id);\n      if (mood.isNotEmpty) moods[character.id] = mood;\n""",
    """      final storedMood = await _chatStore.loadCharacterMood(character.id);\n      final mood = _normalizeMood(\n        storedMood.trim().isEmpty ? character.status.trim() : storedMood,\n      );\n      if (mood.isNotEmpty) moods[character.id] = mood;\n""",
    'reload mood fallback',
)

text = replace_once(
    text,
    """      nextMood = await _chatStore.loadCharacterMood(nextProfile.id);\n""",
    """      final storedMood = await _chatStore.loadCharacterMood(nextProfile.id);\n      nextMood = _normalizeMood(\n        storedMood.trim().isEmpty ? nextProfile.status.trim() : storedMood,\n      );\n""",
    'delete switch mood fallback',
)

text = replace_once(
    text,
    """    final mood = await _chatStore.loadCharacterMood(profile.id);\n""",
    """    final storedMood = await _chatStore.loadCharacterMood(profile.id);\n    final mood = _normalizeMood(\n      storedMood.trim().isEmpty ? profile.status.trim() : storedMood,\n    );\n""",
    'switch mood fallback',
)

# Group logic uses one current mood, with legacy status only as fallback data.
old_roster = """    final roster = participants\n        .map((character) {\n          final moodValue = (_characterMoods[character.id] ?? '').trim();\n          final mood = moodValue.isEmpty ? '' : '；当前心绪：$moodValue';\n          final status = character.status.trim().isEmpty\n              ? ''\n              : '；当前状态：${character.status.trim()}';\n          return '- ${character.name}$mood$status；'\n              '用户好感度：${character.userIntimacy}/100'\n              '（${_intimacyLabel(character.userIntimacy)}）';\n        })\n        .join('\\n');\n"""
new_roster = """    final roster = participants\n        .map((character) {\n          final storedMood = (_characterMoods[character.id] ?? '').trim();\n          final moodValue = _normalizeMood(\n            storedMood.isEmpty ? character.status.trim() : storedMood,\n          );\n          final mood = moodValue.isEmpty ? '' : '；当前心绪：$moodValue';\n          return '- ${character.name}$mood；'\n              '用户好感度：${character.userIntimacy}/100'\n              '（${_intimacyLabel(character.userIntimacy)}）';\n        })\n        .join('\\n');\n"""
text = replace_once(text, old_roster, new_roster, 'group roster')

old_state_prompt = """      final currentMood = (_characterMoods[character.id] ?? '').trim();\n      final currentStatus = character.status.trim();\n      final statePrompt =\n          '\\n\\n你此刻的心绪：${currentMood.isEmpty ? '未记录' : currentMood}；'\n          '当前状态：${currentStatus.isEmpty ? '未记录' : currentStatus}。';\n"""
new_state_prompt = """      final storedMood = (_characterMoods[character.id] ?? '').trim();\n      final currentMood = _normalizeMood(\n        storedMood.isEmpty ? character.status.trim() : storedMood,\n      );\n      final statePrompt =\n          '\\n\\n你此刻的心绪：${currentMood.isEmpty ? '未记录' : currentMood}。';\n"""
text = replace_once(text, old_state_prompt, new_state_prompt, 'group intent mood')

# Main generation produces a single mood tag.
old_state_instruction = """    final savedMood = _characterMoods[activeCharacter.id] ?? '';\n    final previousMood = savedMood.isEmpty ? '未记录' : savedMood;\n    final previousStatus = activeCharacter.status.trim().isEmpty\n        ? '未记录'\n        : activeCharacter.status.trim();\n    final stateInstruction =\n        '\\n\\n角色状态协议（强制）：读完用户最新消息并完成正文回复后，'\n        '必须由你自己重新判断即时心绪和当前状态。上一轮心绪是“$previousMood”，'\n        '上一轮状态是“$previousStatus”。不要为了显得有变化而强行变化，也不能偷懒机械沿用；'\n        '只有你判断本轮确实没有实质变化时，才延续上一轮内容。'\n        '心绪只写1—12个字；状态由你自己决定写什么，只要真实反映你此刻的状态即可。状态最多10个字符，可用文字、emoji、符号或混合表达，但不要使用颜文字。'\n        '无论变化与否，正文结束后都必须另起两行，严格输出'\n        '“[[心绪:……]]”和“[[状态:……]]”；即使不变也要原样输出，不得省略。'\n        '这两行只供系统读取，不要在正文解释。';\n"""
new_state_instruction = """    final storedMood = (_characterMoods[activeCharacter.id] ?? '').trim();\n    final savedMood = _normalizeMood(\n      storedMood.isEmpty ? activeCharacter.status.trim() : storedMood,\n    );\n    final previousMood = savedMood.isEmpty ? '未记录' : savedMood;\n    final stateInstruction =\n        '\\n\\n角色心绪协议（强制）：读完用户最新消息并完成正文回复后，'\n        '必须由你自己重新判断此刻心绪。上一轮心绪是“$previousMood”。'\n        '不要为了显得有变化而强行变化，也不能偷懒机械沿用；'\n        '只有你判断本轮确实没有实质变化时，才延续上一轮内容。'\n        '心绪由你自己决定写什么，只要真实反映你此刻即可；最多10个字符，'\n        '可用文字、emoji、符号或混合表达，但不要使用颜文字。'\n        '无论变化与否，正文结束后都必须另起一行，严格输出“[[心绪:……]]”；'\n        '即使不变也要原样输出，不得省略。这一行只供系统读取，不要在正文解释。';\n"""
text = replace_once(text, old_state_instruction, new_state_instruction, 'main mood instruction')

old_split = """    return _TaggedReply(\n      text: text,\n      mood: _normalizeMood(moodMatch?.group(1) ?? ''),\n      status: _normalizeStatus(statusMatch?.group(1) ?? ''),\n    );\n"""
new_split = """    return _TaggedReply(\n      text: text,\n      mood: _normalizeMood(\n        moodMatch?.group(1) ?? statusMatch?.group(1) ?? '',\n      ),\n      status: '',\n    );\n"""
text = replace_once(text, old_split, new_split, 'single mood parser')

text = replace_once(
    text,
    """    if (value.characters.length > 12) {\n      value = value.characters.take(12).join();\n    }\n""",
    """    if (value.characters.length > 10) {\n      value = value.characters.take(10).join();\n    }\n""",
    'mood cap',
)

# Rename the compatibility writer so the old profile field is clearly only a mirror.
text = text.replace('_applyGeneratedStatus', '_mirrorMoodToLegacyStatus')
old_mirror = """  Future<void> _mirrorMoodToLegacyStatus({\n    required CharacterProfile character,\n    required String status,\n    required String conversationId,\n  }) async {\n    final value = _normalizeStatus(status);\n"""
new_mirror = """  Future<void> _mirrorMoodToLegacyStatus({\n    required CharacterProfile character,\n    required String mood,\n    required String conversationId,\n  }) async {\n    final value = _normalizeStatus(mood);\n"""
text = replace_once(text, old_mirror, new_mirror, 'legacy mirror signature')

# Main reply stores only mood, then mirrors it into the legacy profile field for old backups/screens.
old_previous = """        final previousMood = _characterMoods[speakingCharacter.id] ?? '';\n        final previousStatus = speakingCharacter.status.trim();\n"""
new_previous = """        final storedPreviousMood =\n            (_characterMoods[speakingCharacter.id] ?? '').trim();\n        final previousMood = _normalizeMood(\n          storedPreviousMood.isEmpty\n              ? speakingCharacter.status.trim()\n              : storedPreviousMood,\n        );\n"""
text = replace_once(text, old_previous, new_previous, 'previous mood')

old_after_mood = """        if (parsedReply.mood.isNotEmpty) {\n          unawaited(\n            _chatStore.saveCharacterMood(\n              parsedReply.mood,\n              speakingCharacter.id,\n            ),\n          );\n          if (replyConversationId.isNotEmpty) {\n            unawaited(\n              _chatStore.saveCharacterMoodSource(\n                speakingCharacter.id,\n                replyConversationId,\n              ),\n            );\n          }\n        }\n        if (parsedReply.status.isNotEmpty && replyConversationId.isNotEmpty) {\n          await _mirrorMoodToLegacyStatus(\n            character: speakingCharacter,\n            status: parsedReply.status,\n            conversationId: replyConversationId,\n          );\n        }\n        if ((parsedReply.mood.isEmpty || parsedReply.status.isEmpty) &&\n            replyConversationId.isNotEmpty) {\n          unawaited(\n            _repairStateFromLatestTurn(\n              provider: provider,\n              apiKey: apiKey,\n              contextMessages: contextMessages,\n              replyText: replyText,\n              character: speakingCharacter,\n              conversationId: replyConversationId,\n              sourceReplyId: isRetry ? originalReply!.id : newReply!.id,\n              previousMood: previousMood,\n              previousStatus: previousStatus,\n              repairMood: parsedReply.mood.isEmpty,\n              repairStatus: parsedReply.status.isEmpty,\n            ),\n          );\n        }\n"""
new_after_mood = """        if (parsedReply.mood.isNotEmpty) {\n          unawaited(\n            _chatStore.saveCharacterMood(\n              parsedReply.mood,\n              speakingCharacter.id,\n            ),\n          );\n          if (replyConversationId.isNotEmpty) {\n            unawaited(\n              _chatStore.saveCharacterMoodSource(\n                speakingCharacter.id,\n                replyConversationId,\n              ),\n            );\n            await _mirrorMoodToLegacyStatus(\n              character: speakingCharacter,\n              mood: parsedReply.mood,\n              conversationId: replyConversationId,\n            );\n          }\n        }\n        if (parsedReply.mood.isEmpty && replyConversationId.isNotEmpty) {\n          unawaited(\n            _repairMoodFromLatestTurn(\n              provider: provider,\n              apiKey: apiKey,\n              contextMessages: contextMessages,\n              replyText: replyText,\n              character: speakingCharacter,\n              conversationId: replyConversationId,\n              sourceReplyId: isRetry ? originalReply!.id : newReply!.id,\n              previousMood: previousMood,\n            ),\n          );\n        }\n"""
text = replace_once(text, old_after_mood, new_after_mood, 'main mood persistence')

# Replace two-field repair with mood-only repair.
pattern = re.compile(
    r"\n  Future<void> _repairStateFromLatestTurn\(\{.*?\n  \}\n\n  Future<void> _maybeExtractRelationshipMemory",
    re.S,
)
replacement = """
  Future<void> _repairMoodFromLatestTurn({
    required ProviderProfile provider,
    required String apiKey,
    required List<ChatMessage> contextMessages,
    required String replyText,
    required CharacterProfile character,
    required String conversationId,
    required String sourceReplyId,
    required String previousMood,
  }) async {
    if (replyText.trim().isEmpty) return;
    ChatMessage? latestUser;
    for (var index = contextMessages.length - 1; index >= 0; index--) {
      if (contextMessages[index].author == MessageAuthor.user) {
        latestUser = contextMessages[index];
        break;
      }
    }
    if (latestUser == null) return;

    final service = AiChatService();
    var raw = '';
    try {
      final request = ChatMessage(
        id: 'mood-repair-${DateTime.now().microsecondsSinceEpoch}',
        author: MessageAuthor.user,
        text:
            '上一轮心绪：${previousMood.isEmpty ? '未记录' : previousMood}\\n\\n'
            '用户最新消息：${latestUser.text}\\n\\n'
            '${character.name}的本轮回复：$replyText',
        sentAt: DateTime.now(),
      );
      await for (final chunk in service.streamReply(
        provider: provider,
        apiKey: apiKey,
        systemPrompt:
            '主回复已经完成，你只补齐遗漏的角色心绪，不生成正文。'
            '必须根据这一轮真实对话重新判断，不能为了变化而强行变化，也不能机械沿用。'
            '心绪由角色自己决定写什么，只要真实反映此刻即可；最多10个字符，'
            '可用文字、emoji、符号或混合表达，但不要使用颜文字。'
            '若上一轮已有心绪且你判断本轮没有实质变化，输出 SAME；上一轮未记录时不得输出 SAME。'
            '严格只输出“[[心绪:结果]]”，不解释，不添加其他文字。',
        history: [request],
        temperature: 0.1,
      )) {
        raw += chunk;
      }
      if (!mounted || _currentConversation?.id != conversationId) return;
      ChatMessage? currentLatestUser;
      for (var index = _messages.length - 1; index >= 0; index--) {
        if (_messages[index].author == MessageAuthor.user) {
          currentLatestUser = _messages[index];
          break;
        }
      }
      if (currentLatestUser?.id != latestUser.id) return;
      ChatMessage? currentReply;
      for (final message in _messages) {
        if (message.id == sourceReplyId) {
          currentReply = message;
          break;
        }
      }
      if (currentReply == null || currentReply.text.trim() != replyText.trim()) {
        return;
      }

      final repaired = _splitMoodFromReply(raw);
      if (repaired.mood.isEmpty) return;
      final mood = repaired.mood.toUpperCase() == 'SAME'
          ? previousMood
          : repaired.mood;
      if (mood.isEmpty) return;
      setState(() {
        _characterMoods = {..._characterMoods, character.id: mood};
        if (_profile.id == character.id) _characterMood = mood;
      });
      await _chatStore.saveCharacterMood(mood, character.id);
      await _chatStore.saveCharacterMoodSource(character.id, conversationId);
      await _mirrorMoodToLegacyStatus(
        character: character,
        mood: mood,
        conversationId: conversationId,
      );
    } on Object {
      // Keep the last valid mood when the optional repair request fails.
    } finally {
      service.close();
    }
  }

  Future<void> _maybeExtractRelationshipMemory"""
text, count = pattern.subn(replacement, text, count=1)
if count != 1:
    raise SystemExit('mood repair function not replaced')

# Header and drawer both show the same single mood. Busy text is transient and not appended to mood.
old_header = """    final mood = _characterMood.trim();\n    final status = _profile.status.trim();\n    final stateParts = <String>[\n      if (mood.isNotEmpty) mood,\n      if (status.isNotEmpty && status != '在这里' && status != mood) status,\n    ];\n    final restingCharacterState = stateParts.join(' · ');\n    final characterStatus = isGroup\n        ? (_currentConversation == null\n              ? '暂无群聊'\n              : (_evaluatingGroupIntents\n                    ? '角色正在判断是否接话…'\n                    : (_generating\n                          ? '群聊中…'\n                          : '${_groupParticipants.length} 位角色')))\n        : (_isBusy\n              ? (restingCharacterState.isEmpty\n                    ? '正在回复…'\n                    : '$restingCharacterState · 正在回复…')\n              : restingCharacterState);\n"""
new_header = """    final mood = _normalizeMood(\n      _characterMood.trim().isEmpty ? _profile.status.trim() : _characterMood,\n    );\n    final characterStatus = isGroup\n        ? (_currentConversation == null\n              ? '暂无群聊'\n              : (_evaluatingGroupIntents\n                    ? '角色正在判断是否接话…'\n                    : (_generating\n                          ? '群聊中…'\n                          : '${_groupParticipants.length} 位角色')))\n        : (_isBusy ? '正在回复…' : mood);\n"""
text = replace_once(text, old_header, new_header, 'header mood display')

text = replace_once(
    text,
    """          profile: _profile,\n          groupScope: _groupScope,\n""",
    """          profile: _profile,\n          currentMood: mood,\n          groupScope: _groupScope,\n""",
    'drawer mood argument',
)
text = replace_once(
    text,
    """    required this.profile,\n    required this.groupScope,\n""",
    """    required this.profile,\n    required this.currentMood,\n    required this.groupScope,\n""",
    'drawer constructor',
)
text = replace_once(
    text,
    """  final CharacterProfile profile;\n  final bool groupScope;\n""",
    """  final CharacterProfile profile;\n  final String currentMood;\n  final bool groupScope;\n""",
    'drawer field',
)
text = replace_once(
    text,
    """  Widget build(BuildContext context) {\n    final scheme = Theme.of(context).colorScheme;\n    return Drawer(\n""",
    """  Widget build(BuildContext context) {\n    final scheme = Theme.of(context).colorScheme;\n    final drawerMoodRaw = currentMood.trim().isEmpty\n        ? profile.status.trim()\n        : currentMood.trim();\n    final drawerMood = drawerMoodRaw.characters.length > 10\n        ? drawerMoodRaw.characters.take(10).join()\n        : drawerMoodRaw;\n    return Drawer(\n""",
    'drawer mood local',
)
text = replace_once(
    text,
    """                                  : (profile.status.trim().isEmpty\n                                        ? '点击切换角色或进入群聊'\n                                        : profile.status.trim()),\n""",
    """                                  : (drawerMood.isEmpty\n                                        ? '点击切换角色或进入群聊'\n                                        : drawerMood),\n""",
    'drawer mood text',
)

# Character settings receives the same mood snapshot instead of an older legacy value.
text = replace_once(
    text,
    """        builder: (_) => CharacterScreen(profile: _profile),\n""",
    """        builder: (_) => CharacterScreen(\n          profile: _profile.copyWith(\n            status: _characterMood.trim().isEmpty\n                ? _profile.status\n                : _normalizeMood(_characterMood),\n          ),\n        ),\n""",
    'character screen mood snapshot',
)

chat_path.write_text(text)

character_path = Path('lib/screens/character_screen.dart')
character = character_path.read_text()
character = replace_once(
    character,
    "title: const Text('当前状态由角色自行生成'),",
    "title: const Text('当前心绪由角色自行生成'),",
    'character mood title',
)
character = replace_once(
    character,
    "? '角色会随实际对话自行判断；确实没变化时会延续上一轮状态'",
    "? '角色会随实际对话自行判断；确实没变化时会延续上一轮心绪'",
    'character mood helper',
)
character_path.write_text(character)

pubspec = Path('pubspec.yaml')
pub = pubspec.read_text()
pub, count = re.subn(r'^version:\s*.*$', 'version: 0.9.20+30', pub, count=1, flags=re.M)
if count != 1:
    raise SystemExit('version line not found')
pubspec.write_text(pub)

# Guard against the dual concept returning in active generation/UI copy.
for forbidden in [
    '上一轮状态是',
    '当前状态：',
    '心绪和状态也会一并清除',
    '[[状态:……]]',
    '状态由你自己决定写什么',
]:
    if forbidden in text:
        raise SystemExit(f'forbidden dual-state wording remains: {forbidden}')

print('unified mood applied')
