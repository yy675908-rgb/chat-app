import 'dart:async';
import 'dart:convert';

import 'package:character_chat_app/models/character_profile.dart';
import 'package:character_chat_app/models/chat_message.dart';
import 'package:character_chat_app/models/provider_profile.dart';
import 'package:character_chat_app/services/ai_chat_service.dart';
import 'package:character_chat_app/services/backup_service.dart';
import 'package:character_chat_app/services/chat_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  const provider = ProviderProfile(
    id: 'test',
    name: 'Test',
    protocol: ProviderProtocol.openAiCompatible,
    baseUrl: 'https://example.com/v1',
    models: ['model'],
    selectedModel: 'model',
  );

  test(
    'heartbeat-only stream automatically retries without streaming',
    () async {
      final client = _HeartbeatThenJsonClient();
      final service = AiChatService(
        client: client,
        eventIdleTimeout: const Duration(milliseconds: 80),
      );
      addTearDown(service.close);

      final reply = await service
          .streamReply(
            provider: provider,
            apiKey: 'secret',
            systemPrompt: '测试',
            history: const [],
          )
          .join();
      expect(reply, '自动恢复的回复');
      expect(client.streamFlags, [true, false]);
    },
  );

  test('two stalled requests give an actionable error', () async {
    final service = AiChatService(
      client: _HeartbeatOnlyClient(),
      eventIdleTimeout: const Duration(milliseconds: 80),
    );
    addTearDown(service.close);

    await expectLater(
      service
          .streamReply(
            provider: provider,
            apiKey: 'secret',
            systemPrompt: '测试',
            history: const [],
          )
          .drain<void>(),
      throwsA(
        isA<AiChatException>().having(
          (error) => error.message,
          'message',
          contains('自动重试后接口仍没有返回回复'),
        ),
      ),
    );
  });

  test('a stalled stream never retries after receiving reply text', () async {
    final client = _PartialThenHeartbeatClient();
    final service = AiChatService(
      client: client,
      eventIdleTimeout: const Duration(milliseconds: 80),
    );
    addTearDown(service.close);
    final received = <String>[];

    await expectLater(
      service
          .streamReply(
            provider: provider,
            apiKey: 'secret',
            systemPrompt: '测试',
            history: const [],
          )
          .forEach(received.add),
      throwsA(isA<AiChatException>()),
    );
    expect(received.join(), '已收到');
    expect(client.attempts, 1);
  });

  test(
    'finish reason releases a connection that keeps sending heartbeats',
    () async {
      final client = _FinishedThenHeartbeatClient();
      final service = AiChatService(
        client: client,
        eventIdleTimeout: const Duration(milliseconds: 80),
      );
      addTearDown(service.close);
      final events = await service
          .streamEvents(
            provider: provider,
            apiKey: 'secret',
            systemPrompt: '测试',
            history: const [],
          )
          .toList()
          .timeout(const Duration(seconds: 2));
      expect(
        events
            .where((e) => e.kind == AiStreamEventKind.content)
            .map((e) => e.text)
            .join(),
        '完整回复',
      );
      expect(events.last.usage?.totalTokens, 12);
      expect(client.attempts, 1);
      expect(client.cancelled, isTrue);
    },
  );

  test(
    'JSON response to a streaming request is read without a duplicate request',
    () async {
      var attempts = 0;
      final service = AiChatService(
        client: MockClient((request) async {
          attempts++;
          return http.Response(
            jsonEncode({
              'choices': [
                {
                  'message': {'content': '直接回复'},
                },
              ],
              'usage': {
                'prompt_tokens': 5,
                'completion_tokens': 3,
                'total_tokens': 8,
              },
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      addTearDown(service.close);
      final events = await service
          .streamEvents(
            provider: provider,
            apiKey: 'secret',
            systemPrompt: '测试',
            history: const [],
          )
          .toList();
      expect(events.first.text, '直接回复');
      expect(events.last.usage?.totalTokens, 8);
      expect(attempts, 1);
    },
  );

  test(
    'OpenAI error in SSE is surfaced instead of being silently discarded',
    () async {
      var attempts = 0;
      final service = AiChatService(
        client: MockClient((request) async {
          attempts++;
          return http.Response(
            'data: {"error":{"message":"quota exhausted"}}\n\n',
            200,
          );
        }),
      );
      addTearDown(service.close);
      await expectLater(
        service
            .streamReply(
              provider: provider,
              apiKey: 'secret',
              systemPrompt: '测试',
              history: const [],
            )
            .join(),
        throwsA(
          isA<AiChatException>().having(
            (e) => e.message,
            'message',
            contains('quota exhausted'),
          ),
        ),
      );
      expect(attempts, 1);
    },
  );

  test(
    '429/502/503 is retried once before any streamed reply starts',
    () async {
      var attempts = 0;
      final client = MockClient((request) async {
        attempts += 1;
        if (attempts == 1) {
          return http.Response(
            '{"error":{"message":"temporary"}}',
            503,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response.bytes(
          utf8.encode(
            'data: {"choices":[{"delta":{"content":"恢复"}}]}\n\n'
            'data: [DONE]\n\n',
          ),
          200,
          headers: {'content-type': 'text/event-stream; charset=utf-8'},
        );
      });
      final service = AiChatService(client: client);

      final reply = await service
          .streamReply(
            provider: provider,
            apiKey: 'secret',
            systemPrompt: '测试',
            history: [
              ChatMessage(
                id: 'u1',
                author: MessageAuthor.user,
                text: '继续',
                sentAt: DateTime.utc(2026),
              ),
            ],
          )
          .join();

      expect(attempts, 2);
      expect(reply, '恢复');
      service.close();
    },
  );

  test('SSE stream without trailing newline still delivers reply', () async {
    final client = MockClient((request) async {
      return http.Response.bytes(
        utf8.encode('data: {"choices":[{"delta":{"content":"收到"}}]}'),
        200,
        headers: {'content-type': 'text/event-stream; charset=utf-8'},
      );
    });
    final service = AiChatService(client: client);

    final reply = await service
        .streamReply(
          provider: provider,
          apiKey: 'secret',
          systemPrompt: '测试',
          history: [
            ChatMessage(
              id: 'u2',
              author: MessageAuthor.user,
              text: '在吗',
              sentAt: DateTime.utc(2026),
            ),
          ],
        )
        .join();

    expect(reply, '收到');
    service.close();
  });

  test('request payload keeps output reserve and safety margin', () async {
    SharedPreferences.setMockInitialValues({'context_token_budget_v1': 16000});
    Map<String, dynamic>? sentBody;
    final client = MockClient((request) async {
      sentBody = jsonDecode(request.body) as Map<String, dynamic>;
      return http.Response.bytes(
        utf8.encode(
          'data: {"choices":[{"delta":{"content":"好"}}]}\n\n'
          'data: [DONE]\n\n',
        ),
        200,
        headers: {'content-type': 'text/event-stream; charset=utf-8'},
      );
    });
    final service = AiChatService(client: client);

    await service
        .streamReply(
          provider: provider,
          apiKey: 'secret',
          systemPrompt: '系统设定',
          history: [
            ChatMessage(
              id: 'old',
              author: MessageAuthor.character,
              text: List.filled(13000, '旧').join(),
              sentAt: DateTime.utc(2026),
            ),
            ChatMessage(
              id: 'latest',
              author: MessageAuthor.user,
              text: '最新消息',
              sentAt: DateTime.utc(2026, 1, 1, 0, 1),
            ),
          ],
        )
        .drain<void>();

    final messages = sentBody!['messages'] as List<dynamic>;
    expect(messages.length, 2);
    expect((messages.first as Map)['role'], 'system');
    expect((messages.last as Map)['content'], '最新消息');
    service.close();
  });

  test(
    'invalid full backup is rejected before local data is changed',
    () async {
      final store = ChatStore();
      final original = CharacterProfile.lin(DateTime.utc(2026, 1, 1))
          .copyWith(name: '原角色');
      await store.saveCharacters([original]);
      await store.saveSelectedCharacterId(original.id);

      final incoming = CharacterProfile.newCharacter(DateTime.utc(2026, 2, 1))
          .copyWith(name: '不应写入');
      final malformed = jsonEncode({
        'format': 'character-chat-backup',
        'version': 4,
        'scope': 'full',
        'characters': [incoming.toJson()],
        'selectedCharacterId': incoming.id,
        // conversations/messages intentionally missing
      });

      await expectLater(
        BackupService(chatStore: store).restoreBackup(malformed),
        throwsA(isA<FormatException>()),
      );

      final after = await store.loadCharacters();
      expect(after.single.id, original.id);
      expect(after.single.name, '原角色');
    },
  );
}

class _HeartbeatOnlyClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    return http.StreamedResponse(
      Stream.periodic(
        const Duration(milliseconds: 10),
        (_) => utf8.encode(': ping\n\n'),
      ),
      200,
      headers: {'content-type': 'text/event-stream'},
    );
  }
}

class _HeartbeatThenJsonClient extends http.BaseClient {
  final streamFlags = <bool>[];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final body =
        jsonDecode((request as http.Request).body) as Map<String, dynamic>;
    final streaming = body['stream'] == true;
    streamFlags.add(streaming);
    if (streaming) {
      return http.StreamedResponse(
        Stream.periodic(
          const Duration(milliseconds: 10),
          (_) => utf8.encode(': ping\n\n'),
        ),
        200,
        headers: {'content-type': 'text/event-stream'},
      );
    }
    return http.StreamedResponse(
      Stream.value(
        utf8.encode('{"choices":[{"message":{"content":"自动恢复的回复"}}]}'),
      ),
      200,
      headers: {'content-type': 'application/json'},
    );
  }
}

class _PartialThenHeartbeatClient extends http.BaseClient {
  int attempts = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    attempts++;
    Stream<List<int>> body() async* {
      yield utf8.encode('data: {"choices":[{"delta":{"content":"已收到"}}]}\n\n');
      await for (final _ in Stream.periodic(const Duration(milliseconds: 10))) {
        yield utf8.encode(': ping\n\n');
      }
    }

    return http.StreamedResponse(body(), 200);
  }
}

class _FinishedThenHeartbeatClient extends http.BaseClient {
  int attempts = 0;
  bool cancelled = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    attempts++;
    late StreamController<List<int>> controller;
    Timer? timer;
    controller = StreamController<List<int>>(
      onListen: () {
        controller.add(
          utf8.encode(
            'data: {"choices":[{"delta":{"content":"完整回复"},"finish_reason":"stop"}]}\n\n',
          ),
        );
        controller.add(
          utf8.encode('data: {"choices":[],"usage":{"total_tokens":12}}\n\n'),
        );
        timer = Timer.periodic(
          const Duration(milliseconds: 10),
          (_) => controller.add(utf8.encode(': ping\n\n')),
        );
      },
      onCancel: () {
        cancelled = true;
        timer?.cancel();
      },
    );
    return http.StreamedResponse(
      controller.stream,
      200,
      headers: {'content-type': 'text/event-stream'},
    );
  }
}
