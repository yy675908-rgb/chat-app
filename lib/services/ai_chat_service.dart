import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/api_profile.dart';
import '../models/chat_message.dart';

class AiChatException implements Exception {
  const AiChatException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AiChatService {
  AiChatService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Stream<String> streamReply({
    required ApiProfile profile,
    required String apiKey,
    required String systemPrompt,
    required List<ChatMessage> history,
  }) async* {
    final messages = <Map<String, String>>[
      {'role': 'system', 'content': systemPrompt},
      ...history
          .where((message) => message.author != MessageAuthor.system)
          .map(
            (message) => {
              'role': message.author == MessageAuthor.user
                  ? 'user'
                  : 'assistant',
              'content': message.text,
            },
          ),
    ];

    final request = http.Request('POST', profile.chatCompletionsUri)
      ..headers.addAll({
        'Content-Type': 'application/json',
        'Accept': 'text/event-stream',
        if (apiKey.trim().isNotEmpty)
          'Authorization': 'Bearer ${apiKey.trim()}',
      })
      ..body = jsonEncode({
        'model': profile.model.trim(),
        'messages': messages,
        'stream': true,
        'temperature': 0.85,
      });

    late http.StreamedResponse response;
    try {
      response = await _client.send(request);
    } on Exception catch (error) {
      throw AiChatException('无法连接模型服务：$error');
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final body = await response.stream.bytesToString();
      throw AiChatException(
        '模型服务返回 ${response.statusCode}：${_readError(body)}',
      );
    }

    await for (final line in response.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter())) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || !trimmed.startsWith('data:')) continue;
      final data = trimmed.substring(5).trim();
      if (data == '[DONE]') break;

      try {
        final payload = jsonDecode(data) as Map<String, dynamic>;
        final choices = payload['choices'] as List<dynamic>?;
        if (choices == null || choices.isEmpty) continue;
        final choice = choices.first as Map<String, dynamic>;
        final delta = choice['delta'] as Map<String, dynamic>?;
        final content = delta?['content'];
        if (content is String && content.isNotEmpty) yield content;
      } on FormatException {
        continue;
      }
    }
  }

  String _readError(String body) {
    try {
      final payload = jsonDecode(body) as Map<String, dynamic>;
      final error = payload['error'];
      if (error is Map<String, dynamic>) {
        return error['message']?.toString() ?? body;
      }
    } on FormatException {
      // Return the original response below.
    }
    final compact = body.trim().replaceAll(RegExp(r'\s+'), ' ');
    return compact.length > 180 ? '${compact.substring(0, 180)}…' : compact;
  }

  void close() => _client.close();
}
