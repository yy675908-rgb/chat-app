import 'package:character_chat_app/models/chat_message.dart';
import 'package:character_chat_app/models/api_profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('chat message survives JSON round trip', () {
    final original = ChatMessage(
      id: '1',
      author: MessageAuthor.character,
      text: '我记得。',
      sentAt: DateTime.utc(2026, 7, 18, 12),
    );

    final restored = ChatMessage.fromJson(original.toJson());

    expect(restored.id, original.id);
    expect(restored.author, original.author);
    expect(restored.text, original.text);
    expect(restored.sentAt, original.sentAt);
  });

  test('api profile builds a chat completions endpoint', () {
    const profile = ApiProfile(
      baseUrl: 'https://example.com/v1/',
      model: 'demo-model',
    );

    expect(
      profile.chatCompletionsUri.toString(),
      'https://example.com/v1/chat/completions',
    );
    expect(profile.isConfigured, isTrue);
  });
}
