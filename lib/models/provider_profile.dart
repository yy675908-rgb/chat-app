enum ProviderProtocol { openAiCompatible, anthropic }

class ProviderProfile {
  const ProviderProfile({
    required this.id,
    required this.name,
    required this.protocol,
    required this.baseUrl,
    required this.models,
    required this.selectedModel,
  });

  final String id;
  final String name;
  final ProviderProtocol protocol;
  final String baseUrl;
  final List<String> models;
  final String selectedModel;

  factory ProviderProfile.openAi() => const ProviderProfile(
        id: 'openai-default',
        name: 'OpenAI 兼容',
        protocol: ProviderProtocol.openAiCompatible,
        baseUrl: 'https://api.openai.com/v1',
        models: [],
        selectedModel: '',
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
  }) {
    return ProviderProfile(
      id: id,
      name: name ?? this.name,
      protocol: protocol ?? this.protocol,
      baseUrl: baseUrl ?? this.baseUrl,
      models: models ?? this.models,
      selectedModel: selectedModel ?? this.selectedModel,
    );
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'protocol': protocol.name,
        'baseUrl': baseUrl,
        'models': models,
        'selectedModel': selectedModel,
      };

  factory ProviderProfile.fromJson(Map<String, Object?> json) {
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
    );
  }
}
