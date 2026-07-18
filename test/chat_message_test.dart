import 'dart:convert';

import 'package:character_chat_app/models/chat_message.dart';
import 'package:character_chat_app/models/provider_profile.dart';
import 'package:character_chat_app/services/ai_chat_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('chat message survives JSON round trip', () {
    final original = ChatMessage(
      id: '1',
      author: MessageAuthor.character,
      text: '我记得。',
      sentAt: DateTime.utc(2026, 7, 18, 12),
    );

    final restored = ChatMessage.fromJson(original.toJson());

    expect(restored.id, original.id);
    expect(restored.author, original.author);
    expect(restored.text, original.text);
    expect(restored.sentAt, original.sentAt);
  });

  test('provider profile builds a chat completions endpoint', () {
    const profile = ProviderProfile(
      id: 'test',
      name: 'Test',
      protocol: ProviderProtocol.openAiCompatible,
      baseUrl: 'https://example.com/v1/',
      models: ['demo-model'],
      selectedModel: 'demo-model',
    );

    expect(
      profile.messagesUri.toString(),
      'https://example.com/v1/chat/completions',
    );
    expect(profile.isConfigured, isTrue);
  });

  test('anthropic provider builds messages and models endpoints', () {
    const profile = ProviderProfile(
      id: 'anthropic',
      name: 'Anthropic',
      protocol: ProviderProtocol.anthropic,
      baseUrl: 'https://api.anthropic.com/v1',
      models: ['claude-test'],
      selectedModel: 'claude-test',
    );

    expect(
      profile.messagesUri.toString(),
      'https://api.anthropic.com/v1/messages',
    );
    expect(
      profile.modelsUri.toString(),
      'https://api.anthropic.com/v1/models',
    );
  });

  test('openai SSE chunks are joined into a reply', () async {
    final client = MockClient((request) async {
      expect(request.headers['authorization'], 'Bearer secret');
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body['stream'], isTrue);
      return http.Response.bytes(
        utf8.encode(
          'data: {"choices":[{"delta":{"content":"你"}}]}\n\n'
          'data: {"choices":[{"delta":{"content":"好"}}]}\n\n'
          'data: [DONE]\n\n',
        ),
        200,
        headers: {'content-type': 'text/event-stream; charset=utf-8'},
      );
    });
    final service = AiChatService(client: client);
    const provider = ProviderProfile(
      id: 'openai',
      name: 'OpenAI',
      protocol: ProviderProtocol.openAiCompatible,
      baseUrl: 'https://example.com/v1',
      models: ['model'],
      selectedModel: 'model',
    );

    final reply = await service
        .streamReply(
          provider: provider,
          apiKey: 'secret',
          systemPrompt: '你是林。',
          history: [
            ChatMessage(
              id: 'user',
              author: MessageAuthor.user,
              text: '在吗',
              sentAt: DateTime.utc(2026),
            ),
          ],
        )
        .join();

    expect(reply, '你好');
    service.close();
  });

  test('anthropic SSE chunks are joined into a reply', () async {
    final client = MockClient((request) async {
      expect(request.headers['x-api-key'], 'secret');
      expect(request.headers['anthropic-version'], '2023-06-01');
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body['system'], '你是林。');
      return http.Response.bytes(
        utf8.encode(
          'event: content_block_delta\n'
          'data: {"type":"content_block_delta","delta":{"type":"text_delta","text":"我"}}\n\n'
          'event: content_block_delta\n'
          'data: {"type":"content_block_delta","delta":{"type":"text_delta","text":"在"}}\n\n',
        ),
        200,
        headers: {'content-type': 'text/event-stream; charset=utf-8'},
      );
    });
    final service = AiChatService(client: client);
    const provider = ProviderProfile(
      id: 'anthropic',
      name: 'Anthropic',
      protocol: ProviderProtocol.anthropic,
      baseUrl: 'https://api.anthropic.com/v1',
      models: ['claude-test'],
      selectedModel: 'claude-test',
    );

    final reply = await service
        .streamReply(
          provider: provider,
          apiKey: 'secret',
          systemPrompt: '你是林。',
          history: [
            ChatMessage(
              id: 'user',
              author: MessageAuthor.user,
              text: '在吗',
              sentAt: DateTime.utc(2026),
            ),
          ],
        )
        .join();

    expect(reply, '我在');
    service.close();
  });
}
