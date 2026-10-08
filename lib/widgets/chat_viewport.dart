import 'package:flutter/material.dart';

/// Keeps the header fixed and gives keyboards that report one final inset
/// a smooth transition, without rebuilding the conversation on each frame.
class ChatViewport extends StatelessWidget {
  const ChatViewport({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: MediaQuery.removeViewInsets(
        context: context,
        removeBottom: true,
        child: child,
      ),
    );
  }
}

/// Corrects the offset during layout, rather than starting a new scroll
/// animation for every keyboard frame or streamed fragment.
class ChatScrollPhysics extends ClampingScrollPhysics {
  const ChatScrollPhysics({required this.shouldFollow, super.parent});

  final bool Function() shouldFollow;

  @override
  ChatScrollPhysics applyTo(ScrollPhysics? ancestor) => ChatScrollPhysics(
    shouldFollow: shouldFollow,
    parent: buildParent(ancestor),
  );

  @override
  double adjustPositionForNewDimensions({
    required ScrollMetrics oldPosition,
    required ScrollMetrics newPosition,
    required bool isScrolling,
    required double velocity,
  }) {
    if (shouldFollow() && !isScrolling && oldPosition.extentAfter <= 1) {
      return newPosition.maxScrollExtent;
    }
    return super.adjustPositionForNewDimensions(
      oldPosition: oldPosition,
      newPosition: newPosition,
      isScrolling: isScrolling,
      velocity: velocity,
    );
  }
}
