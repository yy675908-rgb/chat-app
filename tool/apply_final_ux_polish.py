from pathlib import Path

path = Path('lib/screens/chat_screen.dart')
text = path.read_text()

old = """    final roster = participants
        .map((character) {
          final status = character.status.trim().isEmpty
              ? ''
              : '；当前状态：${character.status.trim()}';
          return '- ${character.name}$status；'
              '关系亲密度：${character.userIntimacy}/100'
              '（${_intimacyLabel(character.userIntimacy)}）';
        })
        .join('\\n');
"""
new = """    final roster = participants
        .map((character) {
          final moodValue = (_characterMoods[character.id] ?? '').trim();
          final mood = moodValue.isEmpty ? '' : '；当前心绪：$moodValue';
          final status = character.status.trim().isEmpty
              ? ''
              : '；当前状态：${character.status.trim()}';
          return '- ${character.name}$mood$status；'
              '关系亲密度：${character.userIntimacy}/100'
              '（${_intimacyLabel(character.userIntimacy)}）';
        })
        .join('\\n');
"""
if old not in text:
    raise SystemExit('group roster state anchor missing')
text = text.replace(old, new, 1)

old = """      final memories = _characterMemories[character.id] ?? const <String>[];
      final memoryPrompt = memories.isEmpty
          ? ''
          : '\\n\\n你和用户的共同记忆：\\n'
                '${memories.map((item) => '- $item').join('\\n')}';
"""
new = """      final memories = _characterMemories[character.id] ?? const <String>[];
      final memoryPrompt = memories.isEmpty
          ? ''
          : '\\n\\n你和用户的共同记忆：\\n'
                '${memories.map((item) => '- $item').join('\\n')}';
      final currentMood = (_characterMoods[character.id] ?? '').trim();
      final currentStatus = character.status.trim();
      final statePrompt = '\\n\\n你此刻的心绪：${currentMood.isEmpty ? '未记录' : currentMood}；'
          '当前状态：${currentStatus.isEmpty ? '未记录' : currentStatus}。';
"""
if old not in text:
    raise SystemExit('group intent memory anchor missing')
text = text.replace(old, new, 1)

old = """            '${character.systemPrompt}$memoryPrompt\\n\\n'
            '【群聊内部意愿判断】你现在不是正式发言，也不生成回复正文。'
"""
new = """            '${character.systemPrompt}$memoryPrompt$statePrompt\\n\\n'
            '【群聊内部意愿判断】你现在不是正式发言，也不生成回复正文。'
"""
if old not in text:
    raise SystemExit('group intent state prompt anchor missing')
text = text.replace(old, new, 1)

old = """        content: Text('“${conversation.title}”会从这台设备删除。'),
"""
new = """        content: Text(
          '“${conversation.title}”会从这台设备删除。由这段对话产生的共同记忆、回应偏好、心绪和状态也会一并清除。',
        ),
"""
if old not in text:
    raise SystemExit('delete conversation copy anchor missing')
text = text.replace(old, new, 1)

path.write_text(text)

pubspec = Path('pubspec.yaml')
p = pubspec.read_text()
if 'version: 0.9.11+21' in p:
    p = p.replace('version: 0.9.11+21', 'version: 0.9.12+22', 1)
elif 'version: 0.9.12+22' not in p:
    raise SystemExit('unexpected version')
pubspec.write_text(p)
