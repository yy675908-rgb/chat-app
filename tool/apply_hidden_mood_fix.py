from pathlib import Path
import re

path = Path('lib/screens/chat_screen.dart')
text = path.read_text()

old_load = """    final messages = await _chatStore.loadMessages(conversationId);\n    if (messages.isNotEmpty) return messages;\n"""
new_load = """    final loadedMessages = await _chatStore.loadMessages(conversationId);\n    var cleanedStoredMetadata = false;\n    final messages = <ChatMessage>[];\n    for (final message in loadedMessages) {\n      final cleaned = _sanitizeMoodMetadataInMessage(message);\n      if (_messageMoodMetadataChanged(message, cleaned)) {\n        cleanedStoredMetadata = true;\n      }\n      messages.add(cleaned);\n    }\n    if (messages.isNotEmpty) {\n      if (cleanedStoredMetadata) {\n        await _chatStore.saveMessages(conversationId, messages);\n      }\n      return messages;\n    }\n"""
if old_load not in text:
    raise SystemExit('message load block not found')
text = text.replace(old_load, new_load, 1)

old_stream = """  String _visibleReplyWhileStreaming(String raw) {\n    final marker = RegExp(r'\\n?\\[\\[(?:心绪|状态)\\s*[:：]').firstMatch(raw);\n    return (marker == null ? raw : raw.substring(0, marker.start)).trimRight();\n  }\n\n  _TaggedReply _splitMoodFromReply(String raw) {\n    final moodMatch = RegExp(\n      r'\\[\\[心绪\\s*[:：]\\s*(.*?)\\s*\\]\\]',\n      dotAll: true,\n    ).firstMatch(raw);\n    final statusMatch = RegExp(\n      r'\\[\\[状态\\s*[:：]\\s*(.*?)\\s*\\]\\]',\n      dotAll: true,\n    ).firstMatch(raw);\n    final text = raw\n        .replaceAll(\n          RegExp(r'\\[\\[(?:心绪|状态)\\s*[:：]\\s*.*?\\s*\\]\\]', dotAll: true),\n          '',\n        )\n        .trim();\n    return _TaggedReply(\n      text: text,\n      mood: _normalizeMood(\n        moodMatch?.group(1) ?? statusMatch?.group(1) ?? '',\n      ),\n      status: '',\n    );\n  }\n"""
new_stream = """  RegExp _moodMetadataTailPattern() => RegExp(\n    r'[\\s\\[\\]【】（）()「」『』\\\"“”‘’*_]*'\n    r'(心绪|状态)\\s*[:：]\\s*(.{1,40}?)'\n    r'[\\s\\[\\]【】（）()「」『』\\\"“”‘’*_。！!]*\\$',\n    dotAll: true,\n  );\n\n  String _extractMoodMetadata(String raw) {\n    var remaining = raw;\n    var mood = '';\n    for (var i = 0; i < 3; i++) {\n      final match = _moodMetadataTailPattern().firstMatch(remaining);\n      if (match == null) break;\n      final label = match.group(1) ?? '';\n      final value = _normalizeMood(match.group(2) ?? '');\n      if (label == '心绪' || mood.isEmpty) mood = value;\n      remaining = remaining.substring(0, match.start).trimRight();\n    }\n    return mood;\n  }\n\n  String _stripMoodMetadata(String raw) {\n    var remaining = raw;\n    for (var i = 0; i < 3; i++) {\n      final match = _moodMetadataTailPattern().firstMatch(remaining);\n      if (match == null) break;\n      remaining = remaining.substring(0, match.start).trimRight();\n    }\n    return remaining.trimRight();\n  }\n\n  ChatMessage _sanitizeMoodMetadataInMessage(ChatMessage message) {\n    if (message.author != MessageAuthor.character) return message;\n    final cleanedText = _stripMoodMetadata(message.text);\n    if (message.replyVariants.isEmpty) {\n      return cleanedText == message.text\n          ? message\n          : message.copyWith(text: cleanedText);\n    }\n    final variants = [\n      for (final variant in message.replyVariants)\n        variant.copyWith(text: _stripMoodMetadata(variant.text)),\n    ];\n    return message.copyWith(text: cleanedText, replyVariants: variants);\n  }\n\n  bool _messageMoodMetadataChanged(\n    ChatMessage original,\n    ChatMessage cleaned,\n  ) {\n    if (original.text != cleaned.text) return true;\n    if (original.replyVariants.length != cleaned.replyVariants.length) {\n      return true;\n    }\n    for (var i = 0; i < original.replyVariants.length; i++) {\n      if (original.replyVariants[i].text != cleaned.replyVariants[i].text) {\n        return true;\n      }\n    }\n    return false;\n  }\n\n  String _visibleReplyWhileStreaming(String raw) {\n    RegExpMatch? marker;\n    final markerPattern = RegExp(\n      r'[\\[【（(「『\\\"“”‘’*_]{0,4}\\s*(?:心绪|状态)\\s*[:：]',\n    );\n    for (final match in markerPattern.allMatches(raw)) {\n      if (raw.length - match.start <= 80) marker = match;\n    }\n    return (marker == null ? raw : raw.substring(0, marker.start)).trimRight();\n  }\n\n  _TaggedReply _splitMoodFromReply(String raw) {\n    return _TaggedReply(\n      text: _stripMoodMetadata(raw).trim(),\n      mood: _extractMoodMetadata(raw),\n      status: '',\n    );\n  }\n"""
if old_stream not in text:
    raise SystemExit('stream/parser block not found')
text = text.replace(old_stream, new_stream, 1)

old_prompt = """        '无论变化与否，正文结束后都必须另起一行，严格输出“[[心绪:……]]”；'\n        '即使不变也要原样输出，不得省略。这一行只供系统读取，不要在正文解释。';\n"""
new_prompt = """        '无论变化与否，正文结束后都必须另起一行，严格输出“[[心绪:……]]”；'\n        '即使不变也要原样输出，不得省略。这是系统隐藏元数据，绝不能把“心绪”或该标记写进可见正文，'\n        '也不要给标记额外加引号、前缀或解释。';\n"""
if old_prompt not in text:
    raise SystemExit('mood prompt block not found')
text = text.replace(old_prompt, new_prompt, 1)

path.write_text(text)

pub = Path('pubspec.yaml')
pubtext = pub.read_text()
pubtext, count = re.subn(r'^version:\s*.*$', 'version: 0.9.21+31', pubtext, count=1, flags=re.M)
if count != 1:
    raise SystemExit('version not found')
pub.write_text(pubtext)

print('hidden mood metadata fix applied')
