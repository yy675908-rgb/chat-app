import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/chat_message.dart';
import 'api_error_diagnostics.dart';
import '../models/provider_profile.dart';
import 'memory_selector.dart';

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

  static const _connectTimeout = Duration(seconds: 20);
  static const _streamIdleTimeout = Duration(seconds: 60);
  static const _retryDelay = Duration(milliseconds: 700);
  static const _uiFlushInterval = Duration(milliseconds: 32);
  static const _retryableStatusCodes = <int>{429, 502, 503};
  static const _contextTokenBudgetKey = 'context_token_budget_v1';
  static const _defaultContextBudget = 32000;
  static const _defaultOutputReserveTokens = 2048;

  final http.Client _client;

  Stream<String> streamReply({
    required ProviderProfile provider,
    required String apiKey,
    required String systemPrompt,
    required List<ChatMessage> history,
    double temperature = 0.85,
    int contextTokenBudget = 0,
  }) async* {
    await for (final event in streamEvents(
      provider: provider,
      apiKey: apiKey,
      systemPrompt: systemPrompt,
      history: history,
      temperature: temperature,
      contextTokenBudget: contextTokenBudget,
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
    int contextTokenBudget = 0,
  }) {
    final source = provider.protocol == ProviderProtocol.anthropic
        ? _streamAnthropic(
            provider: provider,
            apiKey: apiKey,
            systemPrompt: systemPrompt,
            history: history,
            temperature: temperature,
            contextTokenBudget: contextTokenBudget,
          )
        : _streamOpenAi(
            provider: provider,
            apiKey: apiKey,
            systemPrompt: systemPrompt,
            history: history,
            temperature: temperature,
            contextTokenBudget: contextTokenBudget,
          );
    return _coalesceFastTextEvents(source);
  }

  Stream<AiStreamEvent> _streamOpenAi({
    required ProviderProfile provider,
    required String apiKey,
    required String systemPrompt,
    required List<ChatMessage> history,
    required double temperature,
    required int contextTokenBudget,
  }) async* {
    final requestSystemPrompt = MemorySelector.compactSystemPrompt(
      systemPrompt,
      history,
    );
    final budget = await _resolveContextBudget(contextTokenBudget);
    final safeHistory = _historyWithinSafeBudget(
      requestSystemPrompt,
      history,
      budget,
    );
    final messages = <Map<String, String>>[
      {'role': 'system', 'content': requestSystemPrompt},
      ..._historyPayload(safeHistory),
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

    await for (final line in _streamLines(response)) {
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
    required int contextTokenBudget,
  }) async* {
    final requestSystemPrompt = MemorySelector.compactSystemPrompt(
      systemPrompt,
      history,
    );
    final budget = await _resolveContextBudget(contextTokenBudget);
    final availableOutputBudget = (budget - 2048)
        .clamp(
          ProviderProfile.minMaxOutputTokens,
          ProviderProfile.maxMaxOutputTokens,
        )
        .toInt();
    final maxOutputTokens = provider
        .maxOutputTokensForModel()
        .clamp(ProviderProfile.minMaxOutputTokens, availableOutputBudget)
        .toInt();
    final safeHistory = _historyWithinSafeBudget(
      requestSystemPrompt,
      history,
      budget,
      outputReserveTokens: maxOutputTokens,
    );
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
        'system': requestSystemPrompt,
        'messages': _historyPayload(safeHistory),
        'max_tokens': maxOutputTokens,
        'stream': true,
        'temperature': temperature,
      },
    );

    await for (final line in _streamLines(response)) {
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

  Stream<String> _streamLines(http.StreamedResponse response) {
    return response.stream
        .timeout(
          _streamIdleTimeout,
          onTimeout: (sink) {
            sink.addError(
              const AiChatException('模型长时间没有返回数据，已停止本次生成'),
            );
            sink.close();
          },
        )
        .transform(utf8.decoder)
        .transform(const LineSplitter());
  }

  Stream<AiStreamEvent> _coalesceFastTextEvents(
    Stream<AiStreamEvent> source,
  ) {
    late final StreamController<AiStreamEvent> controller;
    StreamSubscription<AiStreamEvent>? subscription;
    Timer? flushTimer;
    AiStreamEventKind? bufferedKind;
    final buffer = StringBuffer();
    DateTime? lastFlush;

    void cancelFlushTimer() {
      flushTimer?.cancel();
      flushTimer = null;
    }

    void flush() {
      if (bufferedKind == null || buffer.isEmpty) {
        cancelFlushTimer();
        return;
      }
      cancelFlushTimer();
      controller.add(AiStreamEvent(kind: bufferedKind!, text: buffer.toString()));
      buffer.clear();
      bufferedKind = null;
      lastFlush = DateTime.now();
    }

    void scheduleFlush() {
      if (flushTimer != null) return;
      final previous = lastFlush;
      if (previous == null) {
        flush();
        return;
      }
      final elapsed = DateTime.now().difference(previous);
      if (elapsed >= _uiFlushInterval) {
        flush();
        return;
      }
      flushTimer = Timer(_uiFlushInterval - elapsed, flush);
    }

    controller = StreamController<AiStreamEvent>(
      sync: true,
      onListen: () {
        subscription = source.listen(
          (event) {
            if (event.kind == AiStreamEventKind.usage || event.text.isEmpty) {
              flush();
              controller.add(event);
              return;
            }
            if (bufferedKind != null && bufferedKind != event.kind) flush();
            bufferedKind = event.kind;
            buffer.write(event.text);
            scheduleFlush();
          },
          onError: (Object error, StackTrace stackTrace) {
            flush();
            controller.addError(error, stackTrace);
          },
          onDone: () {
            flush();
            controller.close();
          },
        );
      },
      onPause: () => subscription?.pause(),
      onResume: () => subscription?.resume(),
      onCancel: () async {
        cancelFlushTimer();
        await subscription?.cancel();
      },
    );
    return controller.stream;
  }

  Future<int> _resolveContextBudget(int requested) async {
    if (requested >= 2048) return requested;
    try {
      final preferences = await SharedPreferences.getInstance();
      final saved = preferences.getInt(_contextTokenBudgetKey);
      if (saved != null && saved >= 2048) return saved;
    } on Object {
      // Pure unit tests or non-Flutter callers may not have platform bindings.
    }
    return _defaultContextBudget;
  }

  List<ChatMessage> _historyWithinSafeBudget(
    String systemPrompt,
    List<ChatMessage> history,
    int contextTokenBudget, {
    int outputReserveTokens = _defaultOutputReserveTokens,
  }) {
    final safeInputLimit =
        ((contextTokenBudget * 9) ~/ 10 - outputReserveTokens)
            .clamp(2048, contextTokenBudget)
            .toInt();
    var remaining = safeInputLimit - _estimateTokens(systemPrompt);
    final candidates = history
        .where((message) => message.author != MessageAuthor.system)
        .toList();
    final selected = <ChatMessage>[];
    for (var index = candidates.length - 1; index >= 0; index--) {
      final message = candidates[index];
      final cost = _estimateTokens(message.text) + 12;
      if (selected.isNotEmpty && cost > remaining) break;
      selected.add(message);
      remaining -= cost;
      if (remaining <= 0) break;
    }
    return selected.reversed.toList();
  }

  int _estimateTokens(String text) {
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
    for (var attempt = 0; attempt < 2; attempt++) {
      final request = http.Request('POST', uri)
        ..headers.addAll(headers)
        ..body = jsonEncode(body);
      late http.StreamedResponse response;
      try {
        response = await _client.send(request).timeout(_connectTimeout);
      } on TimeoutException {
        if (attempt == 0) {
          await Future<void>.delayed(_retryDelay);
          continue;
        }
        throw const AiChatException('连接模型服务超时，请检查网络或接口状态');
      } on Exception catch (error) {
        throw AiChatException('无法连接模型服务：$error');
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return response;
      }

      final responseBody = await response.stream.bytesToString();
      if (attempt == 0 && _retryableStatusCodes.contains(response.statusCode)) {
        await Future<void>.delayed(_retryDelayFor(response));
        continue;
      }
      throw AiChatException(
        ApiErrorDiagnostics.describeHttpFailure(
          response.statusCode,
          _readError(responseBody),
        ),
      );
    }
    throw const AiChatException('模型服务暂时不可用，请稍后重试');
  }

  Duration _retryDelayFor(http.StreamedResponse response) {
    final retryAfter = int.tryParse(response.headers['retry-after'] ?? '');
    if (retryAfter == null || retryAfter <= 0) return _retryDelay;
    final seconds = retryAfter > 3 ? 3 : retryAfter;
    return Duration(seconds: seconds);
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
