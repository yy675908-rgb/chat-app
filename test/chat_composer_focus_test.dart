import 'package:character_chat_app/widgets/chat_composer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('composer accepts focus only after a direct tap', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatComposer(
            controller: controller,
            enabled: true,
            generating: false,
            onSend: () {},
            onStop: () {},
            onNewConversation: () {},
          ),
        ),
      ),
    );

    final editable = tester.widget<EditableText>(find.byType(EditableText));
    editable.focusNode.requestFocus();
    await tester.pump();
    expect(editable.focusNode.hasFocus, isFalse);

    await tester.tap(find.byType(TextField));
    await tester.pump();
    expect(editable.focusNode.hasFocus, isTrue);
  });
}
