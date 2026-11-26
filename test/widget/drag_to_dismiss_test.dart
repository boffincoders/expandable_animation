import 'package:expandable_animation/expandable_animation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

void main() {
  Future<ExpandableAnimationController> pumpExpanded(
    WidgetTester tester, {
    WidgetBuilder? expandedBuilder,
    bool enableDragToDismiss = true,
    ExpandableAnimationGestureConfig gestureConfig =
        const ExpandableAnimationGestureConfig(),
  }) async {
    usePhoneSurface(tester);
    final ExpandableAnimationController controller =
        ExpandableAnimationController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      harness(
        ExpandableAnimation(
          controller: controller,
          enableDragToDismiss: enableDragToDismiss,
          gestureConfig: gestureConfig,
          borderRadius: BorderRadius.circular(16),
          expandedBuilder: expandedBuilder ?? expandedPage,
          child: sourceCard(),
        ),
      ),
    );
    controller.expand();
    await tester.pumpAndSettle();
    expect(controller.isExpanded, isTrue);
    return controller;
  }

  Widget scrollingPage(BuildContext context, {ScrollPhysics? physics}) {
    return ListView.builder(
      key: const Key('list'),
      physics: physics,
      itemCount: 60,
      itemBuilder: (BuildContext context, int index) =>
          SizedBox(height: 50, child: Text('Item $index')),
    );
  }

  testWidgets('dragging past the threshold dismisses',
      (WidgetTester tester) async {
    final ExpandableAnimationController controller = await pumpExpanded(tester);
    final TestGesture gesture =
        await tester.startGesture(const Offset(200, 200));
    await gesture.moveBy(const Offset(0, 40));
    await gesture.moveBy(const Offset(0, 100));
    await tester.pump();
    expect(controller.isDragging, isTrue);
    expect(controller.progress, lessThan(1));
    final Rect dragged = tester.getRect(surfaceFinder);
    expect(dragged.width, lessThan(400));
    expect(dragged.top, greaterThan(0));

    await gesture.moveBy(const Offset(0, 100));
    await tester.pump(const Duration(seconds: 1));
    await gesture.up();
    await tester.pump();
    expect(controller.isDragging, isFalse);
    expect(controller.phase, ExpandableAnimationPhase.collapsing);
    // The collapse continues from where the finger released the surface.
    expect(
      tester.getRect(surfaceFinder).width,
      lessThan(400),
    );
    await tester.pumpAndSettle();
    expect(controller.isCollapsed, isTrue);
    expect(isRouteShown(), isFalse);
  });

  testWidgets('a short drag settles back', (WidgetTester tester) async {
    final ExpandableAnimationController controller = await pumpExpanded(tester);
    final TestGesture gesture =
        await tester.startGesture(const Offset(200, 200));
    await gesture.moveBy(const Offset(0, 30));
    await gesture.moveBy(const Offset(0, 30));
    await tester.pump(const Duration(seconds: 1));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(controller.isExpanded, isTrue);
    expect(tester.getRect(surfaceFinder), const Rect.fromLTWH(0, 0, 400, 800));
    expect(controller.progress, 1);
  });

  testWidgets('a fast downward fling dismisses', (WidgetTester tester) async {
    final ExpandableAnimationController controller = await pumpExpanded(tester);
    await tester.flingFrom(const Offset(200, 200), const Offset(0, 80), 2000);
    await tester.pumpAndSettle();
    expect(controller.isCollapsed, isTrue);
  });

  testWidgets('flinging back up cancels the dismissal',
      (WidgetTester tester) async {
    final ExpandableAnimationController controller = await pumpExpanded(tester);
    final TestGesture gesture = await tester.createGesture();
    Duration time = Duration.zero;
    await gesture.down(const Offset(200, 200), timeStamp: time);
    Offset position = const Offset(200, 200);
    // Slowly drag well past the threshold...
    for (int i = 0; i < 15; i++) {
      time += const Duration(milliseconds: 50);
      position += const Offset(0, 20);
      await gesture.moveTo(position, timeStamp: time);
      await tester.pump(const Duration(milliseconds: 50));
    }
    // ...then flick back up quickly before releasing.
    for (int i = 0; i < 5; i++) {
      time += const Duration(milliseconds: 10);
      position -= const Offset(0, 15);
      await gesture.moveTo(position, timeStamp: time);
      await tester.pump(const Duration(milliseconds: 10));
    }
    await gesture.up(timeStamp: time + const Duration(milliseconds: 5));
    await tester.pumpAndSettle();
    expect(controller.isExpanded, isTrue);
  });

  testWidgets('upward drags never move the surface',
      (WidgetTester tester) async {
    await pumpExpanded(tester);
    final TestGesture gesture =
        await tester.startGesture(const Offset(200, 600));
    await gesture.moveBy(const Offset(0, -40));
    await gesture.moveBy(const Offset(0, -100));
    await tester.pump();
    expect(tester.getRect(surfaceFinder), const Rect.fromLTWH(0, 0, 400, 800));
    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('drag-to-dismiss can be disabled', (WidgetTester tester) async {
    final ExpandableAnimationController controller =
        await pumpExpanded(tester, enableDragToDismiss: false);
    await tester.flingFrom(const Offset(200, 200), const Offset(0, 300), 2000);
    await tester.pumpAndSettle();
    expect(controller.isExpanded, isTrue);
  });

  testWidgets('a cancelled pointer ends the drag like a release',
      (WidgetTester tester) async {
    final ExpandableAnimationController controller = await pumpExpanded(tester);
    final TestGesture gesture =
        await tester.startGesture(const Offset(200, 200));
    await gesture.moveBy(const Offset(0, 40));
    await gesture.moveBy(const Offset(0, 40));
    await tester.pump(const Duration(seconds: 1));
    await gesture.cancel();
    await tester.pumpAndSettle();
    expect(controller.isDragging, isFalse);
    expect(controller.isExpanded, isTrue);
    expect(tester.getRect(surfaceFinder), const Rect.fromLTWH(0, 0, 400, 800));
  });

  testWidgets('haptic feedback fires when crossing the threshold',
      (WidgetTester tester) async {
    final List<MethodCall> calls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (MethodCall call) async {
        calls.add(call);
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null),
    );
    await pumpExpanded(tester);
    final TestGesture gesture =
        await tester.startGesture(const Offset(200, 200));
    await gesture.moveBy(const Offset(0, 40));
    await gesture.moveBy(const Offset(0, 200));
    await tester.pump();
    expect(
      calls.where((MethodCall c) => c.method == 'HapticFeedback.vibrate'),
      isNotEmpty,
    );
    await gesture.moveBy(const Offset(0, -220));
    await tester.pump(const Duration(seconds: 1));
    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('scrolling content scrolls instead of dismissing',
      (WidgetTester tester) async {
    final ExpandableAnimationController controller =
        await pumpExpanded(tester, expandedBuilder: scrollingPage);
    // Scroll down the list (finger moves up).
    await tester.drag(find.byKey(const Key('list')), const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(find.text('Item 0'), findsNothing);
    expect(controller.isExpanded, isTrue);

    // Dragging down while not at the top scrolls back instead of dismissing.
    final TestGesture gesture =
        await tester.startGesture(const Offset(200, 400));
    await gesture.moveBy(const Offset(0, 20));
    await gesture.moveBy(const Offset(0, 200));
    await tester.pump();
    expect(controller.isDragging, isFalse);
    expect(tester.getRect(surfaceFinder), const Rect.fromLTWH(0, 0, 400, 800));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(controller.isExpanded, isTrue);
  });

  testWidgets('pulling down scrollable content at its top dismisses',
      (WidgetTester tester) async {
    final ExpandableAnimationController controller =
        await pumpExpanded(tester, expandedBuilder: scrollingPage);
    final TestGesture gesture =
        await tester.startGesture(const Offset(200, 300));
    await gesture.moveBy(const Offset(0, 20));
    await gesture.moveBy(const Offset(0, 150));
    await gesture.moveBy(const Offset(0, 150));
    await tester.pump();
    expect(controller.isDragging, isTrue);
    expect(tester.getRect(surfaceFinder).top, greaterThan(0));
    await tester.pump(const Duration(seconds: 1));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(controller.isCollapsed, isTrue);
  });

  testWidgets('bouncing scrollables also dismiss from their top',
      (WidgetTester tester) async {
    final ExpandableAnimationController controller = await pumpExpanded(
      tester,
      expandedBuilder: (BuildContext context) =>
          scrollingPage(context, physics: const BouncingScrollPhysics()),
    );
    final TestGesture gesture =
        await tester.startGesture(const Offset(200, 300));
    await gesture.moveBy(const Offset(0, 20));
    await gesture.moveBy(const Offset(0, 200));
    await gesture.moveBy(const Offset(0, 200));
    await tester.pump();
    expect(controller.isDragging, isTrue);
    await tester.pump(const Duration(seconds: 1));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(controller.isCollapsed, isTrue);
  });

  testWidgets('dismissFromScrollableContent false keeps scrollables in charge',
      (WidgetTester tester) async {
    final ExpandableAnimationController controller = await pumpExpanded(
      tester,
      expandedBuilder: scrollingPage,
      gestureConfig: const ExpandableAnimationGestureConfig(
        dismissFromScrollableContent: false,
      ),
    );
    await tester.flingFrom(const Offset(200, 300), const Offset(0, 400), 2000);
    await tester.pumpAndSettle();
    expect(controller.isExpanded, isTrue);
  });

  testWidgets('horizontal scrollables do not trigger dismissal',
      (WidgetTester tester) async {
    final ExpandableAnimationController controller = await pumpExpanded(
      tester,
      expandedBuilder: (BuildContext context) => PageView(
        children: const <Widget>[
          Center(child: Text('Page 1')),
          Center(child: Text('Page 2')),
        ],
      ),
    );
    await tester.fling(find.text('Page 1'), const Offset(-300, 0), 1500);
    await tester.pumpAndSettle();
    expect(find.text('Page 2'), findsOneWidget);
    expect(controller.isExpanded, isTrue);

    // A vertical drag on the page view still dismisses.
    await tester.flingFrom(const Offset(200, 200), const Offset(0, 200), 2000);
    await tester.pumpAndSettle();
    expect(controller.isCollapsed, isTrue);
  });

  testWidgets('PopScope can veto a drag dismissal',
      (WidgetTester tester) async {
    int vetoed = 0;
    final ExpandableAnimationController controller = await pumpExpanded(
      tester,
      expandedBuilder: (BuildContext context) => PopScope<void>(
        canPop: false,
        onPopInvokedWithResult: (bool didPop, void result) {
          if (!didPop) {
            vetoed++;
          }
        },
        child: const SizedBox.expand(),
      ),
    );
    await tester.flingFrom(const Offset(200, 200), const Offset(0, 300), 2000);
    await tester.pumpAndSettle();
    expect(vetoed, 1);
    expect(controller.isExpanded, isTrue);
    expect(tester.getRect(surfaceFinder), const Rect.fromLTWH(0, 0, 400, 800));

    // Programmatic collapse still works.
    controller.collapse();
    await tester.pumpAndSettle();
    expect(controller.isCollapsed, isTrue);
  });

  testWidgets('drags are ignored while the expansion is still animating',
      (WidgetTester tester) async {
    usePhoneSurface(tester);
    final ExpandableAnimationController controller =
        ExpandableAnimationController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      harness(
        ExpandableAnimation(
          controller: controller,
          expandedBuilder: expandedPage,
          child: sourceCard(),
        ),
      ),
    );
    controller.expand();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final TestGesture gesture =
        await tester.startGesture(const Offset(200, 400));
    await gesture.moveBy(const Offset(0, 40));
    await gesture.moveBy(const Offset(0, 200));
    expect(controller.isDragging, isFalse);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(controller.isExpanded, isTrue);
  });
}
