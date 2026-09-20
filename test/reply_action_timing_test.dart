import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:character_chat_app/models/chat_message.dart';
import 'package:character_chat_app/widgets/chat_message_list.dart';

void main() {
  testWidgets('character actions appear exactly when generation completes', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    final message = ChatMessage(
      id: 'reply-1',
      author: MessageAuthor.character,
      text: '已经生成出的回复',
      sentAt: DateTime.utc(2026, 9, 19),
    );

    Widget buildList({required bool generating}) => MaterialApp(
      home: Scaffold(
        body: ChatMessageList(
          controller: controller,
          messages: [message],
          visibleMessageIndices: const [0],
          generating: generating,
          activeRetryIndex: null,
          activeReplyId: generating ? message.id : null,
          reasoningExpanded: false,
          providers: const [],
          speakerName: (_) => '林',
          followStreamingOutput: true,
          targetMessageId: null,
          targetRequest: 0,
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
    );

    await tester.pumpWidget(buildList(generating: true));
    expect(find.byTooltip('复制'), findsNothing);
    expect(find.byTooltip('编辑'), findsNothing);

    await tester.pumpWidget(buildList(generating: false));
    await tester.pump();
    expect(find.byTooltip('复制'), findsOneWidget);
    expect(find.byTooltip('编辑'), findsOneWidget);
  });
}
