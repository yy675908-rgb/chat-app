from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if old not in text:
        raise SystemExit(f'missing anchor: {label}')
    return text.replace(old, new, 1)


chat = Path('lib/screens/chat_screen.dart')
text = chat.read_text()

# Restore the role-authored opener for every newly created single chat.
old = """  Future<List<ChatMessage>> _messagesWithGreeting(
    String conversationId,
    CharacterProfile profile, {
    bool isGroup = false,
  }) async {
    final messages = await _chatStore.loadMessages(conversationId);
    if (messages.isNotEmpty) return messages;

    if (isGroup) {
      messages.add(
        ChatMessage(
          id: 'greeting-${DateTime.now().microsecondsSinceEpoch}',
          author: MessageAuthor.system,
          text: '群聊已创建',
          sentAt: DateTime.now(),
        ),
      );
    } else {
      final conversations = await _chatStore.loadConversations(
        characterId: profile.id,
      );
      var hasPriorConversation = false;
      for (final conversation in conversations) {
        if (conversation.id == conversationId) continue;
        final priorMessages = await _chatStore.loadMessages(conversation.id);
        if (priorMessages.any(
          (message) => message.author != MessageAuthor.system,
        )) {
          hasPriorConversation = true;
          break;
        }
      }
      if (!hasPriorConversation && profile.greeting.trim().isNotEmpty) {
        messages.add(
          ChatMessage(
            id: 'greeting-${DateTime.now().microsecondsSinceEpoch}',
            author: MessageAuthor.character,
            text: profile.greeting.trim(),
            sentAt: DateTime.now(),
            speakerCharacterId: profile.id,
          ),
        );
      }
    }
    if (messages.isNotEmpty) {
      await _chatStore.saveMessages(conversationId, messages);
    }
    return messages;
  }
"""
new = """  Future<List<ChatMessage>> _messagesWithGreeting(
    String conversationId,
    CharacterProfile profile, {
    bool isGroup = false,
  }) async {
    final messages = await _chatStore.loadMessages(conversationId);
    if (messages.isNotEmpty) return messages;

    if (isGroup) {
      messages.add(
        ChatMessage(
          id: 'greeting-${DateTime.now().microsecondsSinceEpoch}',
          author: MessageAuthor.system,
          text: '群聊已创建',
          sentAt: DateTime.now(),
        ),
      );
    } else if (profile.greeting.trim().isNotEmpty) {
      messages.add(
        ChatMessage(
          id: 'greeting-${DateTime.now().microsecondsSinceEpoch}',
          author: MessageAuthor.character,
          text: profile.greeting.trim(),
          sentAt: DateTime.now(),
          speakerCharacterId: profile.id,
        ),
      );
    }
    if (messages.isNotEmpty) {
      await _chatStore.saveMessages(conversationId, messages);
    }
    return messages;
  }
"""
text = replace_once(text, old, new, 'restore greeting')

# Close the drawer immediately when creating a single chat, rather than after disk work.
old = """  Future<void> _newConversation() async {
    if (_isBusy) {
"""
new = """  Future<void> _newConversation() async {
    _scaffoldKey.currentState?.closeDrawer();
    if (_isBusy) {
"""
text = replace_once(text, old, new, 'new conversation close drawer')
text = replace_once(
    text,
    """    if (!mounted) return;
    Navigator.of(context).maybePop();
    setState(() {
      _conversations = conversations;
      _currentConversation = conversation;
""",
    """    if (!mounted) return;
    setState(() {
      _conversations = conversations;
      _currentConversation = conversation;
""",
    'remove delayed drawer pop after new conversation',
)

# Only wait for the character/group picker when a drawer animation is actually running.
old = """    _scaffoldKey.currentState?.closeDrawer();
    await Future<void>.delayed(const Duration(milliseconds: 180));
    if (!mounted) return;
    final selectedIds = _characters.map((item) => item.id).toSet();
"""
new = """    final scaffold = _scaffoldKey.currentState;
    if (scaffold?.isDrawerOpen == true) {
      scaffold!.closeDrawer();
      await Future<void>.delayed(const Duration(milliseconds: 120));
      if (!mounted) return;
    }
    final selectedIds = _characters.map((item) => item.id).toSet();
"""
text = replace_once(text, old, new, 'group drawer delay')

old = """  Future<void> _selectConversation(Conversation conversation) async {
    if (_currentConversation?.id == conversation.id) {
      Navigator.of(context).maybePop();
      return;
    }
    if (_isBusy) {
"""
new = """  Future<void> _selectConversation(Conversation conversation) async {
    if (_currentConversation?.id == conversation.id) {
      _scaffoldKey.currentState?.closeDrawer();
      return;
    }
    _scaffoldKey.currentState?.closeDrawer();
    if (_isBusy) {
"""
text = replace_once(text, old, new, 'select conversation immediate close')
text = replace_once(
    text,
    """    if (!mounted) return;
    Navigator.of(context).maybePop();
    setState(() {
      _currentConversation = conversation;
      _messages = messages;
""",
    """    if (!mounted) return;
    setState(() {
      _currentConversation = conversation;
      _messages = messages;
""",
    'remove delayed drawer pop after select',
)

# A delete tap should complete after stopping generation instead of requiring a second tap.
old = """  Future<void> _deleteConversation(Conversation conversation) async {
    if (_isBusy) {
      _stopGenerating();
      return;
    }
"""
new = """  Future<void> _deleteConversation(Conversation conversation) async {
    if (_isBusy) {
      _stopGenerating();
      while (_isBusy && mounted) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      if (!mounted) return;
    }
"""
text = replace_once(text, old, new, 'delete waits after stop')

# Streaming auto-follow should not restart a 240 ms animation on every token chunk.
old = """      final position = _scrollController.position.maxScrollExtent;
      if (jump) {
        _scrollController.jumpTo(position);
      } else {
        _scrollController.animateTo(
          position,
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOut,
        );
      }
"""
new = """      final position = _scrollController.position.maxScrollExtent;
      if (jump || (_generating && !force)) {
        _scrollController.jumpTo(position);
      } else {
        _scrollController.animateTo(
          position,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
        );
      }
"""
text = replace_once(text, old, new, 'streaming scroll follow')

# Snackbars should replace each other instead of building up a queue.
old = """  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(label: '设置', onPressed: _openProviderSettings),
      ),
    );
  }
"""
new = """  void _showMessage(String message) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(milliseconds: 1600),
      ),
    );
  }

  void _showError(String message) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(label: '设置', onPressed: _openProviderSettings),
      ),
    );
  }
"""
text = replace_once(text, old, new, 'snackbar replacement')

# Character picker should open immediately from the app bar; only drawer-origin taps need a short wait.
old = """  Future<void> _showCharacterPicker() async {
    _scaffoldKey.currentState?.closeDrawer();
    await Future<void>.delayed(const Duration(milliseconds: 180));
    if (!mounted) return;
    final selectedId = await showModalBottomSheet<String>(
"""
new = """  Future<void> _showCharacterPicker() async {
    final scaffold = _scaffoldKey.currentState;
    if (scaffold?.isDrawerOpen == true) {
      scaffold!.closeDrawer();
      await Future<void>.delayed(const Duration(milliseconds: 120));
      if (!mounted) return;
    }
    final selectedId = await showModalBottomSheet<String>(
"""
text = replace_once(text, old, new, 'character picker delay')

# Keep drawer navigation visually clean when entering secondary pages.
for signature in [
    '  Future<void> _openProviderSettings() async {',
    '  Future<void> _openFavorites() async {',
    '  Future<void> _openAppSettings() async {',
    '  Future<void> _openMemories() async {',
    '  Future<void> _editCharacter() async {',
]:
    replacement = signature + "\n    _scaffoldKey.currentState?.closeDrawer();"
    text = replace_once(text, signature, replacement, f'close drawer for {signature}')

# Memory confirmation should not force-open the keyboard unless the user actually wants to edit.
text = replace_once(
    text,
    """            controller: controller,
            autofocus: true,
            minLines: 2,
""",
    """            controller: controller,
            autofocus: false,
            minLines: 2,
""",
    'memory dialog autofocus',
)

# Animate mood/status text changes instead of snapping them in place.
old = """                        if (characterStatus.isNotEmpty)
                          Text(
                            characterStatus,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
"""
new = """                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 160),
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeInCubic,
                          child: characterStatus.isEmpty
                              ? const SizedBox.shrink()
                              : Text(
                                  characterStatus,
                                  key: ValueKey(characterStatus),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                        ),
"""
text = replace_once(text, old, new, 'animated header state')

# Composer: dismiss keyboard naturally on outside taps, tactile send/stop, and disable empty send taps.
old = """                  child: TextField(
                    controller: controller,
                    enabled: enabled,
                    minLines: 1,
                    maxLines: 6,
                    textInputAction: TextInputAction.newline,
                    decoration: InputDecoration(
"""
new = """                  child: TextField(
                    controller: controller,
                    enabled: enabled,
                    minLines: 1,
                    maxLines: 6,
                    textInputAction: TextInputAction.newline,
                    onTapOutside: (_) => FocusScope.of(context).unfocus(),
                    decoration: InputDecoration(
"""
text = replace_once(text, old, new, 'composer tap outside')

old = """                      onPressed: onStop,
                      icon: const Icon(Icons.stop_rounded, size: 20),
"""
new = """                      onPressed: () {
                        HapticFeedback.selectionClick();
                        onStop();
                      },
                      icon: const Icon(Icons.stop_rounded, size: 20),
"""
text = replace_once(text, old, new, 'stop haptic')

old = """                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: IconButton.filled(
                    tooltip: '发送',
                    style: IconButton.styleFrom(
                      minimumSize: const Size(42, 42),
                    ),
                    onPressed: enabled ? onSend : null,
                    icon: const Icon(Icons.arrow_upward_rounded, size: 21),
                  ),
                ),
"""
new = """                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: ValueListenableBuilder<TextEditingValue>(
                    valueListenable: controller,
                    builder: (context, value, _) {
                      final canSend = enabled && value.text.trim().isNotEmpty;
                      return IconButton.filled(
                        tooltip: '发送',
                        style: IconButton.styleFrom(
                          minimumSize: const Size(42, 42),
                        ),
                        onPressed: canSend
                            ? () {
                                HapticFeedback.selectionClick();
                                onSend();
                              }
                            : null,
                        icon: const Icon(Icons.arrow_upward_rounded, size: 21),
                      );
                    },
                  ),
                ),
"""
text = replace_once(text, old, new, 'composer send enabled')

chat.write_text(text)

character = Path('lib/screens/character_screen.dart')
c = character.read_text()
c = replace_once(c, "const _SectionLabel('第一次对话')", "const _SectionLabel('开场白')", 'character opener label')
c = replace_once(c, "hintText: '角色第一次开始聊天时先说的话'", "hintText: '每次新建对话时，角色先说的话'", 'character opener hint')
c = replace_once(
    c,
    "'只在这个角色第一次开始聊天时使用；之后新建对话不会反复重播开场白。'",
    "'每次新建单聊时都会先显示这段开场白，让角色先开口；内容完全由你自己决定。'",
    'character opener help',
)
character.write_text(c)

pubspec = Path('pubspec.yaml')
p = pubspec.read_text()
if 'version: 0.9.12+22' in p:
    p = p.replace('version: 0.9.12+22', 'version: 0.9.13+23', 1)
elif 'version: 0.9.13+23' not in p:
    raise SystemExit('unexpected version')
pubspec.write_text(p)
