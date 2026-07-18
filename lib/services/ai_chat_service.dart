import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/chat_message.dart';
import '../models/provider_profile.dart';

class AiChatException implements Exception {
  const AiChatException(this.message);

  final String message;

  @override
  String toString() => message;
}

enum AiStreamEventKind { content, reasoning, usage }

class AiTokenUsage {
  const AiTokenUsage({
    this.promptTokens = 0,
    this.completionTokens = 0,
    this.reasoningTokens = 0,
    this.cacheHitTokens = 0,
    this.cacheMissTokens = 0,
    this.reportedTotalTokens = 0,
  });

  final int promptTokens;
  final int completionTokens;
  final int reasoningTokens;
  final int cacheHitTokens;
  final int cacheMissTokens;
  final int reportedTotalTokens;

  int get totalTokens => reportedTotalTokens > 0
      ? reportedTotalTokens
      : promptTokens + completionTokens;

  AiTokenUsage merge(AiTokenUsage other) {
    return AiTokenUsage(
      promptTokens:
          other.promptTokens > 0 ? other.promptTokens : promptTokens,
      completionTokens: other.completionTokens > 0
          ? other.completionTokens
          : completionTokens,
      reasoningTokens: other.reasoningTokens > 0
          ? other.reasoningTokens
          : reasoningTokens,
      cacheHitTokens:
          other.cacheHitTokens > 0 ? other.cacheHitTokens : cacheHitTokens,
      cacheMissTokens: other.cacheMissTokens > 0
          ? other.cacheMissTokens
          : cacheMissTokens,
      reportedTotalTokens: other.reportedTotalTokens > 0
          ? other.reportedTotalTokens
          : reportedTotalTokens,
    );
  }
}

class AiStreamEvent {
  const AiStreamEvent({
    required this.kind,
    this.text = '',
    this.usage,
  });

  final AiStreamEventKind kind;
  final String text;
  final AiTokenUsage? usage;
}

class AiChatService {
  AiChatService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Stream<String> streamReply({
    required ProviderProfile provider,
    required String apiKey,
    required String systemPrompt,
    required List<ChatMessage> history,
    double temperature = 0.85,
  }) async* {
    await for (final event in streamEvents(
      provider: provider,
      apiKey: apiKey,
      systemPrompt: systemPrompt,
      history: history,
      temperature: temperature,
    )) {
      if (event.kind == AiStreamEventKind.content && event.text.isNotEmpty) {
        yield event.text;
      }
    }
  }

  Stream<AiStreamEvent> streamEvents({
    required ProviderProfile provider,
    required String apiKey,
    required String systemPrompt,
    required List<ChatMessage> history,
    double temperature = 0.85,
  }) {
    return provider.protocol == ProviderProtocol.anthropic
        ? _streamAnthropic(
            provider: provider,
            apiKey: apiKey,
            systemPrompt: systemPrompt,
            history: history,
            temperature: temperature,
          )
        : _streamOpenAi(
            provider: provider,
            apiKey: apiKey,
            systemPrompt: systemPrompt,
            history: history,
            temperature: temperature,
          );
  }

  Stream<AiStreamEvent> _streamOpenAi({
    required ProviderProfile provider,
    required String apiKey,
    required String systemPrompt,
    required List<ChatMessage> history,
    required double temperature,
  }) async* {
    final messages = <Map<String, String>>[
      {'role': 'system', 'content': systemPrompt},
      ..._historyPayload(history),
    ];
    final response = await _send(
      uri: provider.messagesUri,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'text/event-stream',
        if (apiKey.trim().isNotEmpty)
          'Authorization': 'Bearer ${apiKey.trim()}',
      },
      body: {
        'model': provider.selectedModel.trim(),
        'messages': messages,
        'stream': true,
        'stream_options': {'include_usage': true},
        'temperature': temperature,
      },
    );

    await for (final line in response.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter())) {
      final data = _sseData(line);
      if (data == null) continue;
      if (data == '[DONE]') break;
      try {
        final payload = jsonDecode(data) as Map<String, dynamic>;
        final usage = payload['usage'];
        if (usage is Map<String, dynamic>) {
          final details =
              usage['completion_tokens_details'] as Map<String, dynamic>?;
          yield AiStreamEvent(
            kind: AiStreamEventKind.usage,
            usage: AiTokenUsage(
              promptTokens: usage['prompt_tokens'] as int? ?? 0,
              completionTokens: usage['completion_tokens'] as int? ?? 0,
              reasoningTokens: details?['reasoning_tokens'] as int? ?? 0,
              cacheHitTokens:
                  usage['prompt_cache_hit_tokens'] as int? ?? 0,
              cacheMissTokens:
                  usage['prompt_cache_miss_tokens'] as int? ?? 0,
              reportedTotalTokens: usage['total_tokens'] as int? ?? 0,
            ),
          );
        }
        final choices = payload['choices'] as List<dynamic>?;
        if (choices == null || choices.isEmpty) continue;
        final choice = choices.first as Map<String, dynamic>;
        final delta = choice['delta'] as Map<String, dynamic>?;
        final reasoning = delta?['reasoning_content'];
        if (reasoning is String && reasoning.isNotEmpty) {
          yield AiStreamEvent(
            kind: AiStreamEventKind.reasoning,
            text: reasoning,
          );
        }
        final content = delta?['content'];
        if (content is String && content.isNotEmpty) {
          yield AiStreamEvent(
            kind: AiStreamEventKind.content,
            text: content,
          );
        }
      } on Object {
        continue;
      }
    }
  }

  Stream<AiStreamEvent> _streamAnthropic({
    required ProviderProfile provider,
    required String apiKey,
    required String systemPrompt,
    required List<ChatMessage> history,
    required double temperature,
  }) async* {
    final response = await _send(
      uri: provider.messagesUri,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'text/event-stream',
        'x-api-key': apiKey.trim(),
        'anthropic-version': '2023-06-01',
      },
      body: {
        'model': provider.selectedModel.trim(),
        'system': systemPrompt,
        'messages': _historyPayload(history),
        'max_tokens': 2048,
        'stream': true,
        'temperature': temperature,
      },
    );

    await for (final line in response.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter())) {
      final data = _sseData(line);
      if (data == null) continue;
      try {
        final payload = jsonDecode(data) as Map<String, dynamic>;
        if (payload['type'] == 'error') {
          final error = payload['error'] as Map<String, dynamic>?;
          throw AiChatException(
            error?['message']?.toString() ?? 'Anthropic 返回了未知错误',
          );
        }
        if (payload['type'] == 'message_start') {
          final message = payload['message'] as Map<String, dynamic>?;
          final usage = message?['usage'] as Map<String, dynamic>?;
          if (usage != null) {
            yield AiStreamEvent(
              kind: AiStreamEventKind.usage,
              usage: AiTokenUsage(
                promptTokens: usage['input_tokens'] as int? ?? 0,
                completionTokens: usage['output_tokens'] as int? ?? 0,
              ),
            );
          }
          continue;
        }
        if (payload['type'] == 'message_delta') {
          final usage = payload['usage'] as Map<String, dynamic>?;
          if (usage != null) {
            yield AiStreamEvent(
              kind: AiStreamEventKind.usage,
              usage: AiTokenUsage(
                completionTokens: usage['output_tokens'] as int? ?? 0,
              ),
            );
          }
          continue;
        }
        if (payload['type'] != 'content_block_delta') continue;
        final delta = payload['delta'] as Map<String, dynamic>?;
        if (delta?['type'] == 'thinking_delta') {
          final thinking = delta?['thinking'];
          if (thinking is String && thinking.isNotEmpty) {
            yield AiStreamEvent(
              kind: AiStreamEventKind.reasoning,
              text: thinking,
            );
          }
        } else if (delta?['type'] == 'text_delta') {
          final text = delta?['text'];
          if (text is String && text.isNotEmpty) {
            yield AiStreamEvent(
              kind: AiStreamEventKind.content,
              text: text,
            );
          }
        }
      } on AiChatException {
        rethrow;
      } on Object {
        continue;
      }
    }
  }

  List<Map<String, String>> _historyPayload(List<ChatMessage> history) {
    return history
        .where((message) => message.author != MessageAuthor.system)
        .map(
          (message) => {
            'role': message.author == MessageAuthor.user ? 'user' : 'assistant',
            'content': message.text,
          },
        )
        .toList();
  }

  Future<http.StreamedResponse> _send({
    required Uri uri,
    required Map<String, String> headers,
    required Map<String, Object?> body,
  }) async {
    final request = http.Request('POST', uri)
      ..headers.addAll(headers)
      ..body = jsonEncode(body);
    late http.StreamedResponse response;
    try {
      response = await _client.send(request);
    } on Exception catch (error) {
      throw AiChatException('无法连接模型服务：$error');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final body = await response.stream.bytesToString();
      throw AiChatException(
        '接口返回 ${response.statusCode}：${_readError(body)}',
      );
    }
    return response;
  }

  String? _sseData(String line) {
    final trimmed = line.trim();
    if (trimmed.isEmpty || !trimmed.startsWith('data:')) return null;
    return trimmed.substring(5).trim();
  }

  String _readError(String body) {
    try {
      final payload = jsonDecode(body) as Map<String, dynamic>;
      final error = payload['error'];
      if (error is Map<String, dynamic>) {
        return error['message']?.toString() ?? body;
      }
      if (error is String) return error;
      return payload['message']?.toString() ?? body;
    } on Object {
      final compact = body.trim().replaceAll(RegExp(r'\s+'), ' ');
      return compact.length > 180 ? '${compact.substring(0, 180)}…' : compact;
    }
  }

  void close() => _client.close();
}
