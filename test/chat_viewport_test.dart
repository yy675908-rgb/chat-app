import 'package:character_chat_app/widgets/chat_viewport.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'keyboard animates only the body and keeps the latest message anchored',
    (tester) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            resizeToAvoidBottomInset: false,
            appBar: AppBar(title: const Text('header')),
            body: ChatViewport(
              child: Column(
                children: [
                  Expanded(
                    child: ListView.builder(
                      controller: controller,
                      physics: ChatScrollPhysics(shouldFollow: () => true),
                      itemCount: 40,
                      itemExtent: 80,
                      itemBuilder: (_, index) => Text('message $index'),
                    ),
                  ),
                  const SizedBox(key: ValueKey('composer'), height: 56),
                ],
              ),
            ),
          ),
        ),
      );
      controller.jumpTo(controller.position.maxScrollExtent);
      await tester.pump();
      final headerTop = tester.getTopLeft(find.byType(AppBar)).dy;
      final originalBottom = tester
          .getBottomRight(find.byKey(const ValueKey('composer')))
          .dy;
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pump();
      expect(
        tester.getBottomRight(find.byKey(const ValueKey('composer'))).dy,
        originalBottom,
      );
      await tester.pump(const Duration(milliseconds: 90));
      final halfway = tester
          .getBottomRight(find.byKey(const ValueKey('composer')))
          .dy;
      expect(halfway, lessThan(originalBottom));
      expect(halfway, greaterThan(originalBottom - 300));
      expect(controller.position.extentAfter, closeTo(0, 1));
      expect(tester.getTopLeft(find.byType(AppBar)).dy, headerTop);
      await tester.pumpAndSettle();
      expect(
        tester.getBottomRight(find.byKey(const ValueKey('composer'))).dy,
        closeTo(originalBottom - 300, 1),
      );
      expect(controller.position.extentAfter, closeTo(0, 1));
      tester.view.viewInsets = const FakeViewPadding();
      await tester.pumpAndSettle();
      expect(controller.position.extentAfter, closeTo(0, 1));
      controller.jumpTo(500);
      await tester.pumpAndSettle();
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle();
      expect(controller.offset, closeTo(500, 1));
      expect(tester.takeException(), isNull);
    },
  );
}
