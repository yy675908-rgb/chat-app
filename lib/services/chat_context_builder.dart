import '../models/character_profile.dart';
import '../models/chat_message.dart';
import '../models/conversation.dart';
import '../models/provider_profile.dart';
import '../models/user_profile.dart';
import '../models/world_book_entry.dart';
import 'memory_selector.dart';

class ChatContextBuilder {
  const ChatContextBuilder._();

  static String buildSystemPrompt({
    required CharacterProfile activeCharacter,
    required ProviderProfile? selectedProvider,
    required UserProfile userProfile,
    required List<String> activeMemories,
    required List<String> stylePreferences,
    required List<WorldBookEntry> worldBooks,
    required List<ChatMessage> visibleMessages,
    required Conversation? currentConversation,
    required String branchKey,
    required List<CharacterProfile> groupParticipants,
    required String savedMood,
    required List<ChatMessage>? contextMessages,
    required DateTime now,
  }) {
    final context =
        '\n\n当前本地日期和时间（以此为准）：${formatPromptTime(now)}';
    final selectedMemories = MemorySelector.selectRelevant(
      activeMemories,
      visibleMessages,
    );
    final memoryText = selectedMemories.isEmpty
        ? ''
        : '\n\n你和用户的共同记忆（仅属于你们这段关系）：\n'
              '${selectedMemories.map((memory) => '- $memory').join('\n')}';
    final preferenceText = stylePreferences.isEmpty
        ? ''
        : '\n\n用户偏好的回应方式（仅在当前情境明确吻合时轻量参考；'
              '不得覆盖角色设定或固有语气）：\n'
              '${stylePreferences.map((item) => '- $item').join('\n')}';
    final worldBookText = matchedWorldBookPrompt(
      worldBooks: worldBooks,
      visibleMessages: visibleMessages,
    );

    var currentSummary =
        currentConversation?.branchSummaries[branchKey] ?? '';
    final summarizedThrough =
        currentConversation?.summarizedThroughMessageIds[branchKey] ?? '';
    if (currentSummary.isNotEmpty &&
        summarizedThrough.isNotEmpty &&
        contextMessages != null &&
        !contextMessages.any((message) => message.id == summarizedThrough)) {
      currentSummary = '';
    }
    final summaryText = currentSummary.isEmpty
        ? ''
        : '\n\n当前对话较早内容的摘要：\n$currentSummary';

    final previousMood = savedMood.isEmpty ? '未记录' : savedMood;
    final stateInstruction =
        '\n\n角色心绪协议（强制）：读完用户最新消息并完成正文回复后，'
        '由你自己判断此刻心绪。上一轮心绪是“$previousMood”。'
        '不要为了显得有变化而强行变化；确实没有实质变化时可以延续上一轮。'
        '心绪只描述此刻感受，最多10个字符，可用文字、emoji、符号或混合表达，但不要使用颜文字。'
        '正文结束后必须另起一行，严格输出“[[心绪:……]]”。'
        '这是系统隐藏元数据：不得把它写进正文，不得改成“心绪：……”普通句子，'
        '不得添加引号、前缀、解释或其他标记。';

    final modelPrompt = selectedProvider?.systemPromptForModel() ?? '';
    final hiddenModelPrompt = modelPrompt.isEmpty
        ? ''
        : '${modelPrompt.trim()}\n\n';

    final userFields = <String>[
      if (userProfile.name.trim().isNotEmpty)
        '名字：${userProfile.name.trim()}',
      if (userProfile.gender.trim().isNotEmpty)
        '性别：${userProfile.gender.trim()}',
      if (userProfile.description.trim().isNotEmpty)
        '设定：${userProfile.description.trim()}',
    ];
    final userProfileText = userFields.isEmpty
        ? ''
        : '\n\n正在与你对话的用户资料（这是用户的信息，不是你的角色设定）：\n'
              '${userFields.join('\n')}';

    final isGroup = currentConversation?.isGroup == true;
    final intimacyInstruction = isGroup
        ? '\n\n用户对群聊各角色的好感度：\n'
              '${groupParticipants.map((item) {
                final intimacy = intimacyLabel(item.userIntimacy);
                return '- ${item.name}：${item.userIntimacy}/100（$intimacy）';
              }).join('\n')}\n'
              '好感度只是关系背景，不定义关系类型。当前角色可以按自己的性格和当前情境决定是否在意以及如何反应；'
              '不要为了体现好感度刻意迎合、增加戏剧性或改变固有说话风格。'
        : '\n\n用户对你的好感度为${activeCharacter.userIntimacy}/100'
              '（${intimacyLabel(activeCharacter.userIntimacy)}）。'
              '这只是关系背景，不定义你们的关系。你可以按自己的性格和当前情境决定是否在意以及如何反应；'
              '不要为了体现好感度刻意迎合、试探或改变固有说话风格。';

    final groupInstruction = isGroup
        ? '\n\n这是一个多人群聊。你当前只扮演“${activeCharacter.name}”，'
              '只能输出这个角色的一次自然发言，不得代替其他成员说话，也不要列出多人回复。'
              '系统判断你此刻有自然的发言动机。你可以回应用户、接住其他角色的话、'
              '对他们做出符合性格的反应，或主动开启一个合时宜的话题；不需要等待用户再次发言。'
              '若是在回应某位角色，要让对象从措辞中自然可辨，不要机械写“回复某某”。'
              '也可以自然点到另一位角色；'
              '其他角色是否接话由系统另行判断。'
              '群成员：${groupParticipants.map((item) => item.name).join('、')}。'
        : '';

    return '$hiddenModelPrompt${activeCharacter.systemPrompt}'
        '$intimacyInstruction'
        '$groupInstruction$userProfileText'
        '$memoryText$preferenceText$worldBookText'
        '$summaryText$context$stateInstruction';
  }

  static String matchedWorldBookPrompt({
    required List<WorldBookEntry> worldBooks,
    required List<ChatMessage> visibleMessages,
  }) {
    if (worldBooks.isEmpty || visibleMessages.isEmpty) return '';
    final start =
        visibleMessages.length > 4 ? visibleMessages.length - 4 : 0;
    final recentText = visibleMessages
        .sublist(start)
        .map((message) => message.text.toLowerCase())
        .join('\n');
    final matched = worldBooks.where((entry) {
      if (!entry.enabled || entry.keywords.isEmpty) return false;
      return entry.keywords.any(
        (keyword) => recentText.contains(keyword.trim().toLowerCase()),
      );
    });
    final sections = <String>[];
    var used = 0;
    for (final entry in matched) {
      final section = '【${entry.title}】\n${entry.content.trim()}';
      final cost = estimateTokens(section);
      if (sections.isNotEmpty && used + cost > 6000) break;
      sections.add(section);
      used += cost;
      if (used >= 6000) break;
    }
    return sections.isEmpty
        ? ''
        : '\n\n当前对话命中的世界书设定：\n${sections.join('\n\n')}';
  }

  static List<ChatMessage> messagesWithinBudget({
    required List<ChatMessage> messages,
    required String systemPrompt,
    required int contextTokenBudget,
    String summarizedThroughMessageId = '',
  }) {
    var candidates = messages;
    if (summarizedThroughMessageId.isNotEmpty) {
      final marker = candidates.indexWhere(
        (message) => message.id == summarizedThroughMessageId,
      );
      if (marker >= 0) candidates = candidates.sublist(marker + 1);
    }

    var remaining = contextTokenBudget - estimateTokens(systemPrompt);
    if (remaining < 2048) remaining = 2048;
    final selected = <ChatMessage>[];
    for (var index = candidates.length - 1; index >= 0; index--) {
      final message = candidates[index];
      final cost = estimateTokens(message.text) + 12;
      if (selected.isNotEmpty && cost > remaining) break;
      selected.add(message);
      remaining -= cost;
      if (remaining <= 0) break;
    }
    return selected.reversed.toList();
  }

  static int estimateTokens(String text) {
    var estimate = 0.0;
    for (final rune in text.runes) {
      if (rune <= 0x7f) {
        estimate += rune == 0x20 || rune == 0x0a ? 0.1 : 0.28;
      } else {
        estimate += 1;
      }
    }
    return estimate.ceil();
  }

  static String intimacyLabel(int value) {
    if (value < 20) return '很低';
    if (value < 40) return '偏低';
    if (value < 60) return '一般';
    if (value < 80) return '较高';
    return '很高';
  }

  static String intimacyBehavior(int value) {
    return '$value/100（${intimacyLabel(value)}）。'
        '这是用户对角色的主观好感和接受程度，不是关系类型。'
        '角色可以自行决定是否在意，以及是否想提高、维持或改变它。';
  }

  static String formatPromptTime(DateTime value) {
    String two(int number) => number.toString().padLeft(2, '0');
    return '${value.year}-${two(value.month)}-${two(value.day)} '
        '${two(value.hour)}:${two(value.minute)}';
  }
}
