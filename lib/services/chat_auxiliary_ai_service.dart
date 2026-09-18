import 'package:flutter/material.dart';

import '../models/chat_message.dart';
import '../models/provider_profile.dart';
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
