import '../models/character_profile.dart';

class BackupMigrator {
  static const currentVersion = 4;
  static const supportedVersions = <int>{1, 2, 3, 4};

  static Map<String, Object?> migrate(Map<String, Object?> source) {
    final version = source['version'];
    if (version is! int || !supportedVersions.contains(version)) {
      throw const FormatException('不是受支持的聊天备份文件');
    }

    var data = Map<String, Object?>.from(source);
    var current = version;
    while (current < currentVersion) {
      data = switch (current) {
        1 => _v1ToV2(data),
        2 => _v2ToV3(data),
        3 => _v3ToV4(data),
        _ => throw const FormatException('不是受支持的聊天备份文件'),
      };
      current += 1;
      data['version'] = current;
    }
    return data;
  }

  static Map<String, Object?> _v1ToV2(Map<String, Object?> source) {
    final data = Map<String, Object?>.from(source);
    final characters = data['characters'];
    final profileRaw = data['profile'];
    final selectedRaw = data['selectedCharacterId'];
    String? selectedCharacterId = selectedRaw is String ? selectedRaw : null;

    if ((characters == null || (characters is List && characters.isEmpty)) &&
        profileRaw is Map) {
      final profile = CharacterProfile.fromJson(
        Map<String, Object?>.from(profileRaw),
      );
      data['characters'] = [Map<String, Object?>.from(profileRaw)];
      selectedCharacterId ??= profile.id;
      data['selectedCharacterId'] = selectedCharacterId;
    }

    final memories = data['memories'];
    if (data['characterMemories'] == null &&
        memories is List &&
        selectedCharacterId != null) {
      data['characterMemories'] = <String, Object?>{
        selectedCharacterId: List<Object?>.from(memories),
      };
    }
    return data;
  }

  static Map<String, Object?> _v2ToV3(Map<String, Object?> source) {
    final data = Map<String, Object?>.from(source);
    data.putIfAbsent(
      'characterMemorySources',
      () => <String, Object?>{},
    );
    data.putIfAbsent('stylePreferenceSources', () => <String, Object?>{});
    data.putIfAbsent('characterStatusSources', () => <String, Object?>{});
    return data;
  }

  static Map<String, Object?> _v3ToV4(Map<String, Object?> source) {
    final data = Map<String, Object?>.from(source);
    data.putIfAbsent(
      'scope',
      () => data.containsKey('conversations') ? 'full' : 'configuration',
    );
    data.putIfAbsent('apiKeysIncluded', () => false);
    return data;
  }
}
