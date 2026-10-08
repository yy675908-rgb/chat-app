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

  testWidgets('hiding the keyboard revokes focus until another tap', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    addTearDown(tester.view.resetViewInsets);
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
    await tester.tap(find.byType(TextField));
    await tester.pump();
    final focus = tester
        .widget<EditableText>(find.byType(EditableText))
        .focusNode;
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pump();
    expect(focus.hasFocus, isTrue);
    tester.view.viewInsets = const FakeViewPadding();
    await tester.pump();
    expect(focus.hasFocus, isFalse);
    focus.requestFocus();
    await tester.pump();
    expect(focus.hasFocus, isFalse);
    await tester.tap(find.byType(TextField));
    await tester.pump();
    expect(focus.hasFocus, isTrue);
  });

  testWidgets('returning from a modal does not restore composer focus', (
    tester,
  ) async {
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
    await tester.tap(find.byType(TextField));
    await tester.pump();
    final focus = tester
        .widget<EditableText>(find.byType(EditableText))
        .focusNode;
    final context = tester.element(find.byType(ChatComposer));
    showDialog<void>(
      context: context,
      builder: (_) => const AlertDialog(content: Text('modal')),
    );
    await tester.pumpAndSettle();
    Navigator.of(context).pop();
    await tester.pumpAndSettle();
    expect(focus.hasFocus, isFalse);
    focus.requestFocus();
    await tester.pump();
    expect(focus.hasFocus, isFalse);
  });
}
