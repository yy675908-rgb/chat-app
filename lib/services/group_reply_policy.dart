import '../models/chat_message.dart';

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
  }) {
    if (participantIds.isEmpty) return null;
    var hash = 0;
    for (final unit in seed.codeUnits) {
      hash = (hash * 31 + unit) & 0x7fffffff;
    }
    var index = hash % participantIds.length;
    if (participantIds.length > 1 &&
        participantIds[index] == lastSpeakerId) {
      index = (index + 1) % participantIds.length;
    }
    return participantIds[index];
  }
}
