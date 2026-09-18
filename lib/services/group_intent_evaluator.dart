import '../models/character_profile.dart';
import '../models/chat_message.dart';
import '../models/provider_profile.dart';
import 'ai_chat_service.dart';
import 'group_reply_policy.dart';

class GroupIntentEvaluator {
  GroupIntentEvaluator({AiChatService Function()? serviceFactory})
    : _serviceFactory = serviceFactory ?? AiChatService.new;

  final AiChatService Function() _serviceFactory;
  final Set<AiChatService> _activeServices = {};

  Future<Map<String, GroupReplyIntent>> evaluateCandidates({
    required List<CharacterProfile> candidates,
    required ProviderProfile provider,
    required String apiKey,
    required String transcript,
    required String roster,
    required String spokenNames,
    required String lastSpeakerName,
    required Map<String, List<String>> characterMemories,
    required String Function(String characterId) moodForCharacter,
    required String Function(int value) intimacyBehavior,
  }) async {
    final evaluations = await Future.wait([
      for (final character in candidates)
        _evaluateCharacter(
          character: character,
          provider: provider,
          apiKey: apiKey,
          transcript: transcript,
          roster: roster,
          spokenNames: spokenNames,
          lastSpeakerName: lastSpeakerName,
          memories: characterMemories[character.id] ?? const <String>[],
          currentMood: moodForCharacter(character.id),
          intimacyBehavior: intimacyBehavior(character.userIntimacy),
        ),
    ]);
    return {for (final entry in evaluations) entry.key: entry.value};
  }

  Future<MapEntry<String, GroupReplyIntent>> _evaluateCharacter({
    required CharacterProfile character,
    required ProviderProfile provider,
    required String apiKey,
    required String transcript,
    required String roster,
    required String spokenNames,
    required String lastSpeakerName,
    required List<String> memories,
    required String currentMood,
    required String intimacyBehavior,
  }) async {
    final service = _serviceFactory();
    _activeServices.add(service);
    var raw = '';
    try {
      final modelPrompt = provider.systemPromptForModel().trim();
      final memoryPrompt = memories.isEmpty
          ? ''
          : '\n\n你和用户的共同记忆：\n'
                '${memories.map((item) => '- $item').join('\n')}';
      final statePrompt =
          '\n\n你此刻的心绪：${currentMood.isEmpty ? '未记录' : currentMood}。';
      final request = ChatMessage(
        id:
            'group-intent-${character.id}-'
            '${DateTime.now().microsecondsSinceEpoch}',
        author: MessageAuthor.user,
        text:
            '用户对群聊各角色的好感度：\n$roster\n\n'
            '最近对话：\n$transcript\n\n'
            '本段已发言角色：${spokenNames.isEmpty ? '无' : spokenNames}\n'
            '上一位发言角色：${lastSpeakerName.isEmpty ? '无' : lastSpeakerName}\n\n'
            '请只判断“${character.name}”此刻是否自然想接话。',
        sentAt: DateTime.now(),
      );
      await for (final chunk in service.streamReply(
        provider: provider,
        apiKey: apiKey,
        systemPrompt:
            '${modelPrompt.isEmpty ? '' : '$modelPrompt\n\n'}'
            '${character.systemPrompt}$memoryPrompt$statePrompt\n\n'
            '【群聊内部意愿判断】你现在不是正式发言，也不生成回复正文。'
            '请完全依据“${character.name}”的完整设定、当前关系和最近对话，'
            '用户对这个角色的好感度：$intimacyBehavior'
            '好感度可以影响角色是否想主动接话、争取注意或改变用户观感，'
            '但它不是关系定义；具体权重由角色性格、真实关系和当前情境决定。'
            '由这个角色自己判断是否想回应用户、回应其他角色或主动接续话题。'
            '被点名、在意、吃醋、反驳、安慰或不愿让用户的话落空，都可以构成接话动机；'
            '没有自然动机时可以沉默。不要替其他角色判断。'
            '严格只输出 REPLY|0-100 或 PASS|0-100；数字表示此刻发言意愿强度。',
        history: [request],
        temperature: 0.1,
      )) {
        raw += chunk;
      }
      return MapEntry(character.id, GroupReplyPolicy.parseIntent(raw));
    } on Object {
      return MapEntry(
        character.id,
        const GroupReplyIntent(wantsToReply: false, priority: 0),
      );
    } finally {
      _activeServices.remove(service);
      service.close();
    }
  }

  void cancel() {
    for (final service in _activeServices.toList()) {
      service.close();
    }
    _activeServices.clear();
  }

  void dispose() => cancel();
}
