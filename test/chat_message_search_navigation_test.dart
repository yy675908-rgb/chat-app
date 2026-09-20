import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:character_chat_app/models/chat_message.dart';
import 'package:character_chat_app/widgets/chat_message_list.dart';

void main() {
  testWidgets('search target scrolls an off-screen message into view', (
    tester,
  ) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);

    final now = DateTime.utc(2026, 9, 18);
    final messages = [
      for (var index = 0; index < 90; index++)
        ChatMessage(
          id: 'm$index',
          author: MessageAuthor.user,
          text: index == 70
              ? '目标消息 70'
              : '普通消息 $index ${index % 4 == 0 ? '这是一段稍微长一点的测试文本，用来制造不同的消息高度。' : ''}',
          sentAt: now.add(Duration(minutes: index)),
        ),
    ];
    final visible = List<int>.generate(messages.length, (index) => index);

    Widget buildList({String? targetMessageId, int targetRequest = 0}) {
      return MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 560,
            child: ChatMessageList(
              controller: controller,
              messages: messages,
              visibleMessageIndices: visible,
              generating: false,
              activeRetryIndex: null,
              activeReplyId: null,
              reasoningExpanded: false,
              providers: const [],
              speakerName: (_) => '林',
              followStreamingOutput: false,
              targetMessageId: targetMessageId,
              targetRequest: targetRequest,
              onPointerHoldingChanged: (_) {},
              onScrollActivity: () {},
              onResumeStreamingFollow: () {},
              onEdit: (_) async {},
              onMoveVariant: (_, _) async {},
              onLike: (_) async {},
              onLearnStyle: (_, _) async {},
              onRetryWithModel: (_, _) async {},
            ),
          ),
        ),
      );
    }

    await tester.pumpWidget(buildList());
    await tester.pump();
    const targetKey = ValueKey<String>('chat-message-m70');
    expect(find.byKey(targetKey), findsNothing);

    await tester.pumpWidget(
      buildList(targetMessageId: 'm70', targetRequest: 1),
    );
    await tester.pump();
    await tester.pumpAndSettle(const Duration(milliseconds: 100));

    expect(find.byKey(targetKey), findsOneWidget);
    expect(controller.offset, greaterThan(0));
  });
}
