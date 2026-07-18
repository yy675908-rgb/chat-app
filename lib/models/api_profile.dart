class ApiProfile {
  const ApiProfile({
    required this.baseUrl,
    required this.model,
  });

  final String baseUrl;
  final String model;

  bool get isConfigured =>
      baseUrl.trim().isNotEmpty && model.trim().isNotEmpty;

  Uri get chatCompletionsUri {
    var value = baseUrl.trim();
    while (value.endsWith('/')) {
      value = value.substring(0, value.length - 1);
    }
    if (!value.endsWith('/chat/completions')) {
      value = '$value/chat/completions';
    }
    return Uri.parse(value);
  }

  ApiProfile copyWith({String? baseUrl, String? model}) => ApiProfile(
        baseUrl: baseUrl ?? this.baseUrl,
        model: model ?? this.model,
      );
}
