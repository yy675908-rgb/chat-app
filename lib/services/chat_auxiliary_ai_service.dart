import 'package:flutter/material.dart';

import '../models/character_profile.dart';
import '../models/chat_message.dart';
import '../models/provider_profile.dart';
import '../models/user_profile.dart';
import 'ai_chat_service.dart';
import 'mood_codec.dart';

class ChatAuxiliaryAiService {
  const ChatAuxiliaryAiService();

  Future<String> suggestRelationshipMemory({
    required ProviderProfile provider,
    required String apiKey,
    required String existingText,
    required String transcript,
  }) async {
    final service = AiChatService();
    var raw = '';
    try {
      final request = ChatMessage(
        id: 'memory-${DateTime.now().microsecondsSinceEpoch}',
        author: MessageAuthor.user,
        text: '已有共同记忆：\n$existingText\n\n最近一段较长对话：\n$transcript',
        sentAt: DateTime.now(),
      );
      await for (final chunk in service.streamReply(
        provider: provider,
        apiKey: apiKey,
        systemPrompt:
            '从较长一段对话中判断是否有一条真正值得长期保留的共同记忆。'
            '只记录用户明确表达或双方明确发生的稳定事实，例如持续偏好、重要事件、约定、关系变化或长期未完成事项。'
            '不要记录临时情绪、普通寒暄、模型推测或已经存在的同义记忆。'
            '没有合适内容时只输出 NONE；有则只输出一条简洁事实，不编号、不解释，最多60个汉字。',
        history: [request],
        temperature: 0.1,
      )) {
        raw += chunk;
      }
      return normalizeMemoryCandidate(raw);
    } finally {
      service.close();
    }
  }

  Future<String> extractStylePreference({
    required ProviderProfile provider,
    required String apiKey,
    required String userContext,
    required String likedReplyText,
  }) async {
    final service = AiChatService();
    var raw = '';
    try {
      final request = ChatMessage(
        id: 'preference-${DateTime.now().microsecondsSinceEpoch}',
        author: MessageAuthor.user,
        text: '用户当时说：$userContext\n用户喜欢的角色回复：$likedReplyText',
        sentAt: DateTime.now(),
      );
      await for (final chunk in service.streamReply(
        provider: provider,
        apiKey: apiKey,
        systemPrompt:
            '把用户喜欢的一次回复提炼为一条可复用的说话偏好。'
            '只输出一行，格式必须为“当……时：……”。'
            '写清适用情境和回应方式，不复述原话，不写分析，不超过45个汉字。',
        history: [request],
        temperature: 0.2,
      )) {
        raw += chunk;
      }
      return normalizeStylePreference(raw);
    } finally {
      service.close();
    }
  }

  Future<String> summarizeConversation({
    required ProviderProfile provider,
    required String apiKey,
    required String previousSummary,
    required String transcript,
  }) async {
    final service = AiChatService();
    var raw = '';
    try {
      final request = ChatMessage(
        id: 'summary-${DateTime.now().microsecondsSinceEpoch}',
        author: MessageAuthor.user,
        text:
            '${previousSummary.isEmpty ? '' : '已有摘要：\n$previousSummary\n\n'}'
            '新增对话：\n$transcript',
        sentAt: DateTime.now(),
      );
      await for (final chunk in service.streamReply(
        provider: provider,
        apiKey: apiKey,
        systemPrompt:
            '把对话整理成可供角色继续交流的紧凑事实摘要。'
            '保留关系变化、约定、重要事件、用户偏好、未完成事项和必要语境；'
            '删除寒暄、重复和措辞细节。只输出摘要，不超过600个汉字。',
        history: [request],
        temperature: 0.2,
      )) {
        raw += chunk;
      }
      final summary = normalizeSummaryResponse(raw);
      if (summary.isEmpty) {
        throw const AiChatException('模型没有返回摘要');
      }
      return summary;
    } finally {
      service.close();
    }
  }

  Future<String> generateProactiveMessage({
    required ProviderProfile provider,
    required String apiKey,
    required CharacterProfile character,
    required UserProfile userProfile,
    required List<String> memories,
    required String recentTranscript,
    required String currentMood,
  }) async {
    final service = AiChatService();
    var raw = '';
    try {
      final userFields = <String>[
        if (userProfile.name.trim().isNotEmpty)
          '名字：${userProfile.name.trim()}',
        if (userProfile.gender.trim().isNotEmpty)
          '性别：${userProfile.gender.trim()}',
        if (userProfile.description.trim().isNotEmpty)
          '设定：${userProfile.description.trim()}',
      ];
      final request = ChatMessage(
        id: 'proactive-${DateTime.now().microsecondsSinceEpoch}',
        author: MessageAuthor.user,
        text:
            '最近单聊：\n'
            '${recentTranscript.trim().isEmpty ? '暂无最近对话' : recentTranscript.trim()}\n\n'
            '共同记忆：\n'
            '${memories.isEmpty ? '暂无' : memories.map((item) => '- $item').join('\n')}\n\n'
            '用户资料：\n'
            '${userFields.isEmpty ? '暂无' : userFields.join('\n')}',
        sentAt: DateTime.now(),
      );
      final modelPrompt = provider.systemPromptForModel().trim();
      await for (final chunk in service.streamReply(
        provider: provider,
        apiKey: apiKey,
        systemPrompt:
            '${modelPrompt.isEmpty ? '' : '$modelPrompt\n\n'}'
            '${character.systemPrompt}\n\n'
            '【主动消息】现在不是在回复用户刚发来的新消息，而是你隔了一段时间后自然地主动找用户。'
            '根据你的性格、共同记忆和最近单聊，决定此刻最自然的一句话。'
            '可以接续未完话题、问候、想起某件事、表达惦记或提出新的小话题；'
            '不要机械说“系统让我主动联系你”，不要解释机制，不要为了显得亲密而强行暧昧。'
            '用户对你的好感度为${character.userIntimacy}/100，但它只表示主观好感，不定义关系。'
            '你上一轮心绪是“${currentMood.trim().isEmpty ? '未记录' : currentMood.trim()}”。'
            '只输出一条自然聊天正文，不加姓名前缀，不输出心绪标记，不超过80个汉字。',
        history: [request],
        temperature: 0.8,
      )) {
        raw += chunk;
      }
      final text = MoodCodec.stripMetadata(raw).trim();
      if (text.isEmpty) {
        throw const AiChatException('模型没有返回主动消息');
      }
      return text;
    } finally {
      service.close();
    }
  }

  static String normalizeMemoryCandidate(String raw) {
    var value = raw
        .replaceAll(RegExp(r'[\r\n]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (value.isEmpty || value.toUpperCase() == 'NONE') return '';
    if (value.startsWith('“') && value.endsWith('”') && value.length > 2) {
      value = value.substring(1, value.length - 1).trim();
    }
    if (value.characters.length > 60) {
      value = value.characters.take(60).join();
    }
    return value.trim();
  }

  static String normalizeStylePreference(String raw) {
    var value = raw
        .trim()
        .replaceAll(RegExp(r'^[-•*#\s]+'), '')
        .replaceAll(RegExp(r'\s+'), ' ');
    if (value.startsWith('“') && value.endsWith('”') && value.length > 2) {
      value = value.substring(1, value.length - 1);
    }
    if (value.characters.length > 70) {
      value = value.characters.take(70).join();
    }
    return value;
  }

  static String normalizeSummaryResponse(String raw) {
    return MoodCodec.parse(raw).text.trim();
  }
}
