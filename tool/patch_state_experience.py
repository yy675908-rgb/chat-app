from pathlib import Path


path = Path('lib/screens/chat_screen.dart')
text = path.read_text()

old_fields = """  bool _compressionPromptActive = false;
  int _compressionPromptedAtCount = 0;
  bool _pointerHoldingMessages = false;
"""
new_fields = """  bool _compressionPromptActive = false;
  final Map<String, int> _compressionPromptedAtCounts = {};
  bool _memoryPromptActive = false;
  bool _pointerHoldingMessages = false;
"""
if old_fields not in text:
    raise SystemExit('prompt coordination fields anchor not found')
text = text.replace(old_fields, new_fields, 1)

old_memory_guard = """    if (!_autoMemoryEnabled || apiKey.trim().isEmpty) return;
"""
new_memory_guard = """    if (!_autoMemoryEnabled || apiKey.trim().isEmpty || _memoryPromptActive) {
      return;
    }
"""
if old_memory_guard not in text:
    raise SystemExit('memory guard anchor not found')
text = text.replace(old_memory_guard, new_memory_guard, 1)

old_marker = """    final marker = '$conversationId|$userTurns';
    if (!_autoMemoryExtractionMarkers.add(marker)) return;

    final start = visible.length > 40 ? visible.length - 40 : 0;
"""
new_marker = """    final marker = '$conversationId|$userTurns';
    if (!_autoMemoryExtractionMarkers.add(marker)) return;
    final sourceBranchKey = _currentBranchKey();
    _memoryPromptActive = true;

    final start = visible.length > 40 ? visible.length - 40 : 0;
"""
if old_marker not in text:
    raise SystemExit('memory marker anchor not found')
text = text.replace(old_marker, new_marker, 1)

old_before_dialog = """      if (memory.isEmpty || !mounted) return;
      if (_currentConversation?.id != conversationId) return;

      final controller = TextEditingController(text: memory);
"""
new_before_dialog = """      if (memory.isEmpty || !mounted) return;
      if (_currentConversation?.id != conversationId ||
          _currentBranchKey() != sourceBranchKey) {
        return;
      }
      final currentUserTurns = _messages
          .where(_isMessageVisible)
          .where((message) => message.author == MessageAuthor.user)
          .length;
      if (currentUserTurns != userTurns) return;

      final controller = TextEditingController(text: memory);
"""
if old_before_dialog not in text:
    raise SystemExit('memory freshness anchor not found')
text = text.replace(old_before_dialog, new_before_dialog, 1)

old_memory_finally = """    } finally {
      service.close();
    }
  }

  List<ChatMessage> _messagesWithinBudget(
"""
new_memory_finally = """    } finally {
      service.close();
      _memoryPromptActive = false;
    }
  }

  List<ChatMessage> _messagesWithinBudget(
"""
if old_memory_finally not in text:
    raise SystemExit('memory finally anchor not found')
text = text.replace(old_memory_finally, new_memory_finally, 1)

old_compression_start = """  Future<void> _maybeOfferCompression() async {
    if (!mounted || _loading || _isBusy || _compressionPromptActive) {
      return;
    }
    final visible = _messages.where(_isMessageVisible).toList();
    if (visible.length < 20 ||
        visible.length < _compressionPromptedAtCount + 10) {
      return;
    }
    final current = _currentConversation;
    if (current == null) return;
    final markerId =
        current.summarizedThroughMessageIds[_currentBranchKey()] ?? '';
"""
new_compression_start = """  Future<void> _maybeOfferCompression() async {
    if (!mounted ||
        _loading ||
        _isBusy ||
        _compressionPromptActive ||
        _memoryPromptActive) {
      return;
    }
    final current = _currentConversation;
    if (current == null) return;
    final visible = _messages.where(_isMessageVisible).toList();
    final branchKey = _currentBranchKey();
    final promptKey = '${current.id}|$branchKey';
    final promptedAt = _compressionPromptedAtCounts[promptKey] ?? 0;
    if (visible.length < 20 || visible.length < promptedAt + 10) {
      return;
    }
    final markerId = current.summarizedThroughMessageIds[branchKey] ?? '';
"""
if old_compression_start not in text:
    raise SystemExit('compression start anchor not found')
text = text.replace(old_compression_start, new_compression_start, 1)

old_compression_mark = """    _compressionPromptActive = true;
    _compressionPromptedAtCount = visible.length;
    try {
"""
new_compression_mark = """    _compressionPromptActive = true;
    _compressionPromptedAtCounts[promptKey] = visible.length;
    try {
"""
if old_compression_mark not in text:
    raise SystemExit('compression prompt count anchor not found')
text = text.replace(old_compression_mark, new_compression_mark, 1)

path.write_text(text)

pubspec = Path('pubspec.yaml')
pubspec_text = pubspec.read_text()
if 'version: 0.9.9+19' in pubspec_text:
    pubspec_text = pubspec_text.replace('version: 0.9.9+19', 'version: 0.9.10+20', 1)
elif 'version: 0.9.10+20' not in pubspec_text:
    raise SystemExit('unexpected pubspec version')
pubspec.write_text(pubspec_text)
