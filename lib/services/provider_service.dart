import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/provider_profile.dart';
import 'ai_chat_service.dart';

class ProviderService {
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
        '模型列表接口返回 ${response.statusCode}。可以跳过读取，手动填写模型 ID。',
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
}
