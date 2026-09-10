from pathlib import Path
import re

chat = Path('lib/screens/chat_screen.dart')
text = chat.read_text()

old = """    final activeCharacter = character ?? _profile;\n    final now = DateTime.now().toLocal();\n    ChatMessage? lastReply;\n    for (var index = _messages.length - 1; index >= 0; index--) {\n      final message = _messages[index];\n      if (!_isMessageVisible(message)) continue;\n      if (message.author == MessageAuthor.character &&\n          message.text.trim().isNotEmpty) {\n        lastReply = message;\n        break;\n      }\n    }\n    final interval = lastReply == null\n        ? ''\n        : '｜间隔：${_formatElapsed(now.difference(lastReply.sentAt))}';\n    final context = '当前时间：${_formatPromptTime(now)}$interval';\n"""
new = """    final activeCharacter = character ?? _profile;\n    final now = DateTime.now().toLocal();\n    final context =\n        '\\n\\n当前本地日期和时间（以此为准）：${_formatPromptTime(now)}';\n"""
if old not in text:
    raise SystemExit('time context block not found')
text = text.replace(old, new, 1)

old_return = """        '$groupInstruction$userProfileText\\n\\n'\n        '$context$memoryText$preferenceText$worldBookText'\n        '$summaryText$previousSummaryText$stateInstruction';\n"""
new_return = """        '$groupInstruction$userProfileText'\n        '$memoryText$preferenceText$worldBookText'\n        '$summaryText$previousSummaryText$context$stateInstruction';\n"""
if old_return not in text:
    raise SystemExit('system prompt return block not found')
text = text.replace(old_return, new_return, 1)

text, count = re.subn(
    r"\n  String _formatElapsed\(Duration duration\) \{.*?\n  \}\n(?=\n  void _showMessage)",
    '',
    text,
    count=1,
    flags=re.S,
)
if count != 1:
    raise SystemExit('format elapsed helper not found')
chat.write_text(text)

pubspec = Path('pubspec.yaml')
pub = pubspec.read_text()
pub, count = re.subn(r'^version:\s*.*$', 'version: 0.9.18+28', pub, count=1, flags=re.M)
if count != 1:
    raise SystemExit('version line not found')
pubspec.write_text(pub)

print('date-time anchor applied')
