import '../models/character_profile.dart';
import '../models/chat_message.dart';
import '../models/conversation.dart';
import '../models/provider_profile.dart';
import '../models/user_profile.dart';
import '../models/world_book_entry.dart';

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
    String? currentPlace,
    bool locationEnabled = false,
  }) {
    final context =
        '\n\n当前本地日期和时间（以此为准）：${formatPromptTime(now)}';
    final locationText = !locationEnabled
        ? ''
        : currentPlace == null || currentPlace.trim().isEmpty
        ? '\n\n本次回复前未能取得用户设备的实时位置。历史对话中提到的地点不能当作用户现在的位置；被问到当前位置时如实说明这次未取得。'
        : '\n\n应用在本次回复前获取的用户设备位置：${currentPlace.trim()}。'
              '这是用户的位置，不代表你也在那里；不能据此推断用户正在做什么、住在哪里或周围环境。'
              '这次获取的地点优先于历史对话里提过的地点，不要称它为先前的定位。'
              '如果用户问你是否知道他/她的位置，直接据此回答，不要说自己无法读取。'
              '这次定位不代表能持续追踪用户移动，不能声称知道接下来会去哪里。'
              '如果只有坐标而没有地点名称，不要凭空说出具体街道或建筑。'
              '其他时候仅在对话确有意义时自然使用，不必每次提地点。';
    final characterFacts = buildCharacterFacts(
      userProfile: userProfile,
      activeMemories: activeMemories,
      stylePreferences: stylePreferences,
      worldBooks: worldBooks,
      visibleMessages: visibleMessages,
    );

    final currentSummary = summaryForContext(
      conversation: currentConversation,
      branchKey: branchKey,
      messages: contextMessages ?? visibleMessages,
    );
    final summaryText = currentSummary.isEmpty
        ? ''
        : '\n\n当前对话较早内容的摘要：\n$currentSummary';

    final previousMood = savedMood.isEmpty ? '未记录' : savedMood;
    final stateInstruction =
        '\n\n角色心绪协议（强制）：读完${currentConversation?.isGroup == true ? '群聊当前内容' : '用户最新消息'}并完成正文回复后，'
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

    final isGroup = currentConversation?.isGroup == true;
    final intimacyInstruction = isGroup
        ? '\n\n用户对群聊各角色的亲密度（用户对各角色的主观感受）：\n'
              '${groupParticipants.map((item) {
                final intimacy = intimacyLabel(item.userIntimacy);
                return '- ${item.name}：${item.userIntimacy}/100（$intimacy）';
              }).join('\n')}\n'
              '亲密度与实际关系远近是独立的：关系亲近时用户仍可能亲密度低，关系疏远时也可能亲密度高。'
              '你知道这些感受，可以按性格、对话和关系自然回应；不要据此推断关系或刻意迎合。'
        : '\n\n用户对你的亲密度为${activeCharacter.userIntimacy}/100'
              '（${intimacyLabel(activeCharacter.userIntimacy)}）。'
              '这是用户对你的主观感受，与实际关系远近独立：关系亲近时也可能很低，关系疏远时也可能很高。'
              '你知道用户的感受，可按自己的性格和当前情境自然回应，但不要据此推断或改写关系，也不要刻意迎合。';

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
        '\n\n当前角色的名字是“${activeCharacter.name}”，以角色资料中的名字为准。'
        '$intimacyInstruction'
        '$groupInstruction$characterFacts'
        '$summaryText$context$locationText$stateInstruction'
        '${isGroup
            ? '\n\n群聊中回应用户时用“你”称呼用户；回应其他角色时直接称呼对方。'
                  '不要把其他角色的话误当作用户说的，也不要替其他角色发言。'
            : '\n\n你正在直接和用户说话。正文里无论是对话、叙述还是动作描写，'
                  '都用“你”指代正在聊天的用户，不要用“她”“他”或“用户”来称呼对方。'
                  '提及真正的第三方时才用第三人称。'}';
  }

  static String summaryForContext({
    required Conversation? conversation,
    required String branchKey,
    required List<ChatMessage> messages,
  }) {
    final summary = conversation?.branchSummaries[branchKey]?.trim() ?? '';
    final marker =
        conversation?.summarizedThroughMessageIds[branchKey] ?? '';
    if (summary.isEmpty ||
        marker.isEmpty ||
        !messages.any((message) => message.id == marker)) {
      return '';
    }
    return summary;
  }

  static String buildCharacterFacts({
    required UserProfile userProfile,
    required List<String> activeMemories,
    required List<String> stylePreferences,
    required List<WorldBookEntry> worldBooks,
    required List<ChatMessage> visibleMessages,
  }) {
    final memoryText = activeMemories.isEmpty
        ? ''
        : '\n\n你和用户的共同记忆（仅属于你们这段关系）：\n'
              '${activeMemories.map((memory) => '- $memory').join('\n')}\n'
              '这些是已保存的事实。情境相关时据此行动，不能因近期聊天没提到就当作不存在；'
              '记忆若明确说无需某个动作，不得按惯常情节要求用户做那个动作。'
              '不要机械复述。若用户在当前对话明确更新事实，以新信息为准。';
    final preferenceText = stylePreferences.isEmpty
        ? ''
        : '\n\n用户偏好的回应方式（仅在当前情境明确吻合时轻量参考；'
              '不得覆盖角色设定或固有语气）：\n'
              '${stylePreferences.map((item) => '- $item').join('\n')}';
    final worldBookText = matchedWorldBookPrompt(
      worldBooks: worldBooks,
      visibleMessages: visibleMessages,
    );

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

    return '$userProfileText$memoryText$preferenceText$worldBookText';
  }

  static String matchedWorldBookPrompt({
    required List<WorldBookEntry> worldBooks,
    required List<ChatMessage> visibleMessages,
  }) {
    if (worldBooks.isEmpty) return '';
    final start =
        visibleMessages.length > 4 ? visibleMessages.length - 4 : 0;
    final recentText = visibleMessages
        .sublist(start)
        .map((message) => message.text.toLowerCase())
        .join('\n');
    bool applies(WorldBookEntry entry) {
      if (!entry.enabled || entry.content.trim().isEmpty) return false;
      if (entry.keywords.isEmpty) return true;
      return entry.keywords.any(
        (keyword) =>
            keyword.trim().isNotEmpty &&
            recentText.contains(keyword.trim().toLowerCase()),
      );
    }
    // Keep permanent entries ahead of keyword matches when the prompt is long.
    final matched = [
      ...worldBooks.where((entry) => entry.keywords.isEmpty && applies(entry)),
      ...worldBooks.where((entry) => entry.keywords.isNotEmpty && applies(entry)),
    ];
    final sections = <String>[];
    var used = 0;
    for (final entry in matched) {
      final section = '【${entry.title}】\n${entry.content.trim()}';
      final cost = estimateTokens(section);
      if (entry.keywords.isNotEmpty && used + cost > 6000) continue;
      sections.add(section);
      used += cost;
    }
    return sections.isEmpty
        ? ''
        : '\n\n当前生效的世界书设定：\n${sections.join('\n\n')}';
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
        '这是用户对角色的主观亲密感受，与实际关系远近独立。'
        '角色知道这个感受，可以按性格和情境自然回应，不要据此推断关系。';
  }

  static String formatPromptTime(DateTime value) {
    String two(int number) => number.toString().padLeft(2, '0');
    return '${value.year}-${two(value.month)}-${two(value.day)} '
        '${two(value.hour)}:${two(value.minute)}';
  }
}
