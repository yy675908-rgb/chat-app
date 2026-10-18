import '../models/character_profile.dart';
import '../models/chat_message.dart';

class GroupReplyIntent {
  const GroupReplyIntent({
    required this.wantsToReply,
    required this.priority,
  });

  final bool wantsToReply;
  final int priority;
}

class GroupReplyPolicy {
  const GroupReplyPolicy._();

  static bool latestUserNeedsReply(Iterable<ChatMessage> messages) {
    var waitingForReply = false;
    for (final message in messages) {
      if (message.author == MessageAuthor.user) {
        waitingForReply = true;
      } else if (message.author == MessageAuthor.character) {
        waitingForReply = false;
      }
    }
    return waitingForReply;
  }

  static String? fallbackSpeakerId(
    List<String> participantIds, {
    required String lastSpeakerId,
    required String seed,
    List<String> addressedIds = const [],
  }) {
    if (participantIds.isEmpty) return null;
    final addressed = participantIds
        .where((id) => addressedIds.contains(id))
        .toList();
    final eligible = addressed.isNotEmpty
        ? addressed
        : participantIds.where((id) => id != lastSpeakerId).toList();
    final choices = eligible.isEmpty ? participantIds : eligible;
    var hash = 0;
    for (final unit in seed.codeUnits) {
      hash = (hash * 31 + unit) & 0x7fffffff;
    }
    return choices[hash % choices.length];
  }

  static List<String> addressedCharacterIds(
    List<CharacterProfile> participants,
    String message,
  ) => [
    for (final character in participants)
      if (character.name.trim().isNotEmpty &&
          message.contains(character.name.trim()))
        character.id,
  ];

  static GroupReplyIntent parseIntent(String raw) {
    final normalized = raw.trim().toUpperCase();
    final scoreMatch = RegExp(r'(?<!\d)(100|[0-9]{1,2})(?!\d)')
        .firstMatch(normalized);
    final score = int.tryParse(scoreMatch?.group(1) ?? '') ?? 0;
    final passes = normalized.startsWith('PASS') ||
        normalized.startsWith('NONE') ||
        normalized.contains('沉默');
    final replies = normalized.startsWith('REPLY') ||
        normalized.startsWith('TALK') ||
        normalized.contains('接话');
    return GroupReplyIntent(
      wantsToReply: replies && !passes,
      priority: score.clamp(0, 100).toInt(),
    );
  }

  static List<String> rankWillingSpeakers(
    Map<String, GroupReplyIntent> intents, {
    required List<String> spokenIds,
    required String lastSpeakerId,
    required String seed,
    bool allowLastSpeaker = false,
    List<String> addressedIds = const [],
  }) {
    final entries = intents.entries
        .where(
          (entry) =>
              entry.value.wantsToReply &&
              (allowLastSpeaker || entry.key != lastSpeakerId),
        )
        .toList();
    entries.sort((a, b) {
      final aAddressed = addressedIds.contains(a.key);
      final bAddressed = addressedIds.contains(b.key);
      if (aAddressed != bAddressed) return aAddressed ? -1 : 1;
      final byPriority = b.value.priority.compareTo(a.value.priority);
      if (byPriority != 0) return byPriority;
      final aSpoke = spokenIds.contains(a.key);
      final bSpoke = spokenIds.contains(b.key);
      if (aSpoke != bSpoke) return aSpoke ? 1 : -1;
      return _stableHash('$seed|${b.key}')
          .compareTo(_stableHash('$seed|${a.key}'));
    });
    return entries.map((entry) => entry.key).toList();
  }

  static int _stableHash(String value) {
    var hash = 0;
    for (final unit in value.codeUnits) {
      hash = (hash * 31 + unit) & 0x7fffffff;
    }
    return hash;
  }
}
