import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/chat_message.dart';
import '../models/provider_profile.dart';
import 'ai_chat_service.dart';
import 'api_error_diagnostics.dart';

class ProviderConnectionResult {
  const ProviderConnectionResult({
    required this.modelId,
    required this.latency,
    required this.preview,
  });

  final String modelId;
  final Duration latency;
  final String preview;
}

class ProviderService {
  ProviderService({AiChatService Function()? chatServiceFactory})
    : _chatServiceFactory = chatServiceFactory ?? AiChatService.new;

  final AiChatService Function() _chatServiceFactory;

  Future<List<String>> fetchModels(
    ProviderProfile provider,
    String apiKey,
  ) async {
    final headers = provider.protocol == ProviderProtocol.anthropic
        ? {
            'x-api-key': apiKey.trim(),
            'anthropic-version': '2023-06-01',
          }
        : {'Authorization': 'Bearer ${apiKey.trim()}'};
    late http.Response response;
    try {
      response = await http
          .get(provider.modelsUri, headers: headers)
          .timeout(const Duration(seconds: 20));
    } on Exception catch (error) {
      throw AiChatException('无法读取模型列表：$error');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AiChatException(
        ApiErrorDiagnostics.describeHttpFailure(
          response.statusCode,
          _readError(response.body),
          modelList: true,
        ),
      );
    }
    try {
      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      final data = payload['data'] as List<dynamic>? ?? const [];
      final models = data
          .map((item) => (item as Map<String, dynamic>)['id']?.toString())
          .whereType<String>()
          .where((model) => model.isNotEmpty)
          .toSet()
          .toList()
        ..sort();
      if (models.isEmpty) {
        throw const AiChatException('接口成功，但没有返回模型；请手动填写模型 ID。');
      }
      return models;
    } on AiChatException {
      rethrow;
    } on Object {
      throw const AiChatException('无法解析模型列表；请手动填写模型 ID。');
    }
  }

  Future<ProviderConnectionResult> testConnection(
    ProviderProfile provider,
    String apiKey,
  ) async {
    final uri = Uri.tryParse(provider.baseUrl.trim());
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      throw const AiChatException('Base URL 不正确');
    }
    if (provider.selectedModel.trim().isEmpty) {
      throw const AiChatException('请先填写并选择一个模型 ID');
    }
    if (apiKey.trim().isEmpty) {
      throw const AiChatException('API Key 不能为空');
    }

    final service = _chatServiceFactory();
    final stopwatch = Stopwatch()..start();
    var text = '';
    try {
      final request = ChatMessage(
        id: 'connection-test-${DateTime.now().microsecondsSinceEpoch}',
        author: MessageAuthor.user,
        text: '这是连接测试。请只回复 OK。',
        sentAt: DateTime.now(),
      );
      await for (final event in service.streamEvents(
        provider: provider,
        apiKey: apiKey,
        systemPrompt: '这是 API 连通性测试。请只完成最短的正常文本回复。',
        history: [request],
        temperature: 0,
      )) {
        if (event.kind != AiStreamEventKind.content || event.text.isEmpty) {
          continue;
        }
        text += event.text;
        if (text.trim().isNotEmpty) break;
      }
      stopwatch.stop();
      final preview = text.trim();
      if (preview.isEmpty) {
        throw const AiChatException(
          '接口已经建立连接，但模型没有返回文本。请确认该模型支持聊天与流式输出。',
        );
      }
      return ProviderConnectionResult(
        modelId: provider.selectedModel.trim(),
        latency: stopwatch.elapsed,
        preview: preview.length > 80
            ? '${preview.substring(0, 80)}…'
            : preview,
      );
    } finally {
      service.close();
    }
  }

  String _readError(String body) {
    try {
      final payload = jsonDecode(body) as Map<String, dynamic>;
      final error = payload['error'];
      if (error is Map<String, dynamic>) {
        return error['message']?.toString() ?? '';
      }
      if (error is String) return error;
      return payload['message']?.toString() ?? '';
    } on Object {
      return body;
    }
  }

}
