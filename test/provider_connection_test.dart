import 'package:flutter_test/flutter_test.dart';

import 'package:character_chat_app/models/chat_message.dart';
import 'package:character_chat_app/models/provider_profile.dart';
import 'package:character_chat_app/services/ai_chat_service.dart';
import 'package:character_chat_app/services/api_error_diagnostics.dart';
import 'package:character_chat_app/services/provider_service.dart';

class _FakeAiChatService extends AiChatService {
  _FakeAiChatService(this.events);

  final List<AiStreamEvent> events;

  @override
  Stream<AiStreamEvent> streamEvents({
    required ProviderProfile provider,
    required String apiKey,
    required String systemPrompt,
    required List<ChatMessage> history,
    double temperature = 0.85,
    int contextTokenBudget = 0,
  }) {
    return Stream<AiStreamEvent>.fromIterable(events);
  }

  @override
  void close() {}
}

ProviderProfile _provider() => ProviderProfile.openAi().copyWith(
  baseUrl: 'https://example.com/v1',
  models: const ['test-model'],
  selectedModel: 'test-model',
);

void main() {
  group('ApiErrorDiagnostics', () {
    test('classifies common HTTP failures', () {
      expect(
        ApiErrorDiagnostics.describeHttpFailure(401, 'invalid key'),
        contains('API Key 无效'),
      );
      expect(
        ApiErrorDiagnostics.describeHttpFailure(403, 'forbidden'),
        contains('没有访问权限'),
      );
      expect(
        ApiErrorDiagnostics.describeHttpFailure(404, 'model not found'),
        allOf(contains('Base URL'), contains('模型 ID')),
      );
      expect(
        ApiErrorDiagnostics.describeHttpFailure(429, 'quota exceeded'),
        contains('额度不足'),
      );
      expect(
        ApiErrorDiagnostics.describeHttpFailure(503, 'temporarily unavailable'),
        contains('服务端暂时异常'),
      );
    });

    test('models 404 explains that chat may still work', () {
      final message = ApiErrorDiagnostics.describeHttpFailure(
        404,
        'not found',
        modelList: true,
      );
      expect(message, contains('不代表聊天接口不可用'));
      expect(message, contains('测试连接'));
    });
  });

  group('ProviderService.testConnection', () {
    test('returns model, latency and first text when chat endpoint works', () async {
      final service = ProviderService(
        chatServiceFactory: () => _FakeAiChatService([
          const AiStreamEvent(
            kind: AiStreamEventKind.usage,
            usage: AiTokenUsage(promptTokens: 3),
          ),
          const AiStreamEvent(kind: AiStreamEventKind.content, text: 'OK'),
        ]),
      );

      final result = await service.testConnection(_provider(), 'secret');

      expect(result.modelId, 'test-model');
      expect(result.preview, 'OK');
      expect(result.latency.inMilliseconds, greaterThanOrEqualTo(0));
    });

    test('rejects a connected endpoint that returns no text', () async {
      final service = ProviderService(
        chatServiceFactory: () => _FakeAiChatService([
          const AiStreamEvent(
            kind: AiStreamEventKind.usage,
            usage: AiTokenUsage(promptTokens: 3),
          ),
        ]),
      );

      expect(
        () => service.testConnection(_provider(), 'secret'),
        throwsA(
          isA<AiChatException>().having(
            (error) => error.message,
            'message',
            contains('没有返回文本'),
          ),
        ),
      );
    });

    test('validates model and key before opening a connection', () async {
      final service = ProviderService(
        chatServiceFactory: () => _FakeAiChatService(const []),
      );

      expect(
        () => service.testConnection(
          ProviderProfile.openAi().copyWith(
            baseUrl: 'https://example.com/v1',
          ),
          'secret',
        ),
        throwsA(isA<AiChatException>()),
      );
      expect(
        () => service.testConnection(_provider(), ''),
        throwsA(
          isA<AiChatException>().having(
            (error) => error.message,
            'message',
            contains('API Key'),
          ),
        ),
      );
    });
  });
}
