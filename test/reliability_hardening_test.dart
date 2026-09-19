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

  test('429/502/503 is retried once before any streamed reply starts', () async {
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
  });


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
    SharedPreferences.setMockInitialValues({
      'context_token_budget_v1': 16000,
    });
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

  test('invalid full backup is rejected before local data is changed', () async {
    final store = ChatStore();
    final original = CharacterProfile.lin(DateTime.utc(2026, 1, 1)).copyWith(
      name: '原角色',
    );
    await store.saveCharacters([original]);
    await store.saveSelectedCharacterId(original.id);

    final incoming = CharacterProfile.newCharacter(
      DateTime.utc(2026, 2, 1),
    ).copyWith(name: '不应写入');
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
  });
}
