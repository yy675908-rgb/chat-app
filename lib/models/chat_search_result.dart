import 'chat_message.dart';
import 'conversation.dart';

class ChatSearchResult {
  const ChatSearchResult({
    required this.conversation,
    required this.message,
  });

  final Conversation conversation;
  final ChatMessage message;
}
