enum ProactiveFrequency { occasional, balanced, frequent }

class ProactiveMessageSettings {
  const ProactiveMessageSettings({
    this.enabled = false,
    this.enabledCharacterIds = const <String>[],
    this.frequency = ProactiveFrequency.balanced,
    this.quietStartMinutes = 23 * 60,
    this.quietEndMinutes = 8 * 60,
  });

  final bool enabled;
  final List<String> enabledCharacterIds;
  final ProactiveFrequency frequency;
  final int quietStartMinutes;
  final int quietEndMinutes;

  int get intervalHours => switch (frequency) {
    ProactiveFrequency.occasional => 48,
    ProactiveFrequency.balanced => 24,
    ProactiveFrequency.frequent => 8,
  };

  ProactiveMessageSettings copyWith({
    bool? enabled,
    List<String>? enabledCharacterIds,
    ProactiveFrequency? frequency,
    int? quietStartMinutes,
    int? quietEndMinutes,
  }) {
    return ProactiveMessageSettings(
      enabled: enabled ?? this.enabled,
      enabledCharacterIds: enabledCharacterIds ?? this.enabledCharacterIds,
      frequency: frequency ?? this.frequency,
      quietStartMinutes: quietStartMinutes ?? this.quietStartMinutes,
      quietEndMinutes: quietEndMinutes ?? this.quietEndMinutes,
    );
  }

  Map<String, Object?> toJson() => {
    'enabled': enabled,
    'enabledCharacterIds': enabledCharacterIds,
    'frequency': frequency.name,
    'quietStartMinutes': quietStartMinutes,
    'quietEndMinutes': quietEndMinutes,
  };

  factory ProactiveMessageSettings.fromJson(Map<String, Object?> json) {
    final start = (json['quietStartMinutes'] as num? ?? 23 * 60)
        .round()
        .clamp(0, 1439)
        .toInt();
    final end = (json['quietEndMinutes'] as num? ?? 8 * 60)
        .round()
        .clamp(0, 1439)
        .toInt();
    return ProactiveMessageSettings(
      enabled: json['enabled'] as bool? ?? false,
      enabledCharacterIds:
          (json['enabledCharacterIds'] as List<dynamic>? ?? const [])
              .map((item) => item.toString())
              .where((item) => item.isNotEmpty)
              .toSet()
              .toList(),
      frequency: ProactiveFrequency.values.firstWhere(
        (value) => value.name == json['frequency'],
        orElse: () => ProactiveFrequency.balanced,
      ),
      quietStartMinutes: start,
      quietEndMinutes: end,
    );
  }
}

class ProactiveMessagePlan {
  const ProactiveMessagePlan({
    required this.characterId,
    required this.characterName,
    required this.dueAt,
  });

  final String characterId;
  final String characterName;
  final DateTime dueAt;

  Map<String, Object?> toJson() => {
    'characterId': characterId,
    'characterName': characterName,
    'dueAt': dueAt.toIso8601String(),
  };

  factory ProactiveMessagePlan.fromJson(Map<String, Object?> json) {
    return ProactiveMessagePlan(
      characterId: json['characterId']?.toString() ?? '',
      characterName: json['characterName']?.toString() ?? '',
      dueAt:
          DateTime.tryParse(json['dueAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}
