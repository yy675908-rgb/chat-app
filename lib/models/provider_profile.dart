enum ProviderProtocol { openAiCompatible, anthropic }

class ProviderProfile {
  const ProviderProfile({
    required this.id,
    required this.name,
    required this.protocol,
    required this.baseUrl,
    required this.models,
    required this.selectedModel,
    this.modelSystemPrompts = const {},
    this.modelMaxOutputTokens = const {},
  });

  static const int defaultAnthropicMaxOutputTokens = 4096;
  static const int minMaxOutputTokens = 256;
  static const int maxMaxOutputTokens = 65536;

  final String id;
  final String name;
  final ProviderProtocol protocol;
  final String baseUrl;
  final List<String> models;
  final String selectedModel;
  final Map<String, String> modelSystemPrompts;
  final Map<String, int> modelMaxOutputTokens;

  String systemPromptForModel([String? model]) {
    return modelSystemPrompts[model ?? selectedModel]?.trim() ?? '';
  }

  int maxOutputTokensForModel([String? model]) {
    final configured = modelMaxOutputTokens[model ?? selectedModel];
    if (configured == null) return defaultAnthropicMaxOutputTokens;
    return configured.clamp(minMaxOutputTokens, maxMaxOutputTokens).toInt();
  }

  factory ProviderProfile.openAi() => const ProviderProfile(
        id: 'openai-default',
        name: 'OpenAI 兼容',
        protocol: ProviderProtocol.openAiCompatible,
        baseUrl: 'https://api.openai.com/v1',
        models: [],
        selectedModel: '',
        modelSystemPrompts: {},
        modelMaxOutputTokens: {},
      );

  bool get isConfigured =>
      baseUrl.trim().isNotEmpty && selectedModel.trim().isNotEmpty;

  Uri get messagesUri {
    var value = baseUrl.trim();
    while (value.endsWith('/')) {
      value = value.substring(0, value.length - 1);
    }
    final path = protocol == ProviderProtocol.anthropic
        ? '/messages'
        : '/chat/completions';
    if (!value.endsWith(path)) value = '$value$path';
    return Uri.parse(value);
  }

  Uri get modelsUri {
    var value = baseUrl.trim();
    while (value.endsWith('/')) {
      value = value.substring(0, value.length - 1);
    }
    if (value.endsWith('/chat/completions')) {
      value = value.substring(0, value.length - '/chat/completions'.length);
    } else if (value.endsWith('/messages')) {
      value = value.substring(0, value.length - '/messages'.length);
    }
    return Uri.parse('$value/models');
  }

  ProviderProfile copyWith({
    String? name,
    ProviderProtocol? protocol,
    String? baseUrl,
    List<String>? models,
    String? selectedModel,
    Map<String, String>? modelSystemPrompts,
    Map<String, int>? modelMaxOutputTokens,
  }) {
    return ProviderProfile(
      id: id,
      name: name ?? this.name,
      protocol: protocol ?? this.protocol,
      baseUrl: baseUrl ?? this.baseUrl,
      models: models ?? this.models,
      selectedModel: selectedModel ?? this.selectedModel,
      modelSystemPrompts: modelSystemPrompts ?? this.modelSystemPrompts,
      modelMaxOutputTokens:
          modelMaxOutputTokens ?? this.modelMaxOutputTokens,
    );
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'protocol': protocol.name,
        'baseUrl': baseUrl,
        'models': models,
        'selectedModel': selectedModel,
        'modelSystemPrompts': modelSystemPrompts,
        'modelMaxOutputTokens': modelMaxOutputTokens,
      };

  factory ProviderProfile.fromJson(Map<String, Object?> json) {
    final rawMaxOutputTokens = json['modelMaxOutputTokens'] as Map?;
    final parsedMaxOutputTokens = <String, int>{};
    if (rawMaxOutputTokens != null) {
      for (final entry in rawMaxOutputTokens.entries) {
        final value = entry.value;
        final parsed = value is int ? value : int.tryParse(value.toString());
        if (parsed == null) continue;
        parsedMaxOutputTokens[entry.key.toString()] = parsed
            .clamp(minMaxOutputTokens, maxMaxOutputTokens)
            .toInt();
      }
    }
    return ProviderProfile(
      id: json['id'] as String,
      name: json['name'] as String? ?? '自定义供应商',
      protocol: ProviderProtocol.values.firstWhere(
        (value) => value.name == json['protocol'],
        orElse: () => ProviderProtocol.openAiCompatible,
      ),
      baseUrl: json['baseUrl'] as String? ?? '',
      models: (json['models'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .toList(),
      selectedModel: json['selectedModel'] as String? ?? '',
      modelSystemPrompts: (json['modelSystemPrompts'] as Map?)?.map(
            (key, value) => MapEntry(key.toString(), value.toString()),
          ) ??
          const {},
      modelMaxOutputTokens: parsedMaxOutputTokens,
    );
  }
}
