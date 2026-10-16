import 'package:character_chat_app/models/chat_message.dart';
import 'package:character_chat_app/widgets/message_bubble.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final reply = ChatMessage(
    id: 'reply',
    author: MessageAuthor.character,
    text: '你好',
    sentAt: DateTime.utc(2026),
  );

  Widget view({bool pending = false, bool learned = false}) => MaterialApp(
    home: Scaffold(
      body: MessageBubble(
        message: reply,
        characterName: '阿野',
        showActions: true,
        onEdit: () {},
        onLearnStyle: () {},
        styleExtractionPending: pending,
        styleExtractionLearned: learned,
      ),
    ),
  );

  testWidgets('edit is first and style extraction shows immediate progress', (
    tester,
  ) async {
    await tester.pumpWidget(view(pending: true));
    expect(
      tester.getTopLeft(find.byIcon(Icons.edit_outlined)).dx,
      lessThan(tester.getTopLeft(find.byIcon(Icons.copy_rounded)).dx),
    );
    final pendingButton = find.byTooltip('正在提炼回应偏好');
    expect(pendingButton, findsOneWidget);
    expect(
      find.descendant(
        of: pendingButton,
        matching: find.byType(CircularProgressIndicator),
      ),
      findsOneWidget,
    );
    final pendingBackground = tester.widget<Container>(
      find.descendant(of: pendingButton, matching: find.byType(Container)),
    );
    expect((pendingBackground.decoration as BoxDecoration).color, isNotNull);

    await tester.pumpWidget(view(learned: true));
    expect(find.byTooltip('已提炼回应偏好'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
