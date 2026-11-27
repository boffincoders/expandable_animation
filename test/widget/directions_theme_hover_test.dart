// Transitions are started without awaiting so tests can pump individual
// frames and inspect intermediate states.
// ignore_for_file: unawaited_futures

import 'package:expandable_animation/expandable_animation.dart';
import 'package:expandable_animation/src/transitions/surface_geometry.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

const Set<ExpandableAnimationDismissDirection> _horizontal =
    <ExpandableAnimationDismissDirection>{
  ExpandableAnimationDismissDirection.left,
  ExpandableAnimationDismissDirection.right,
};

Future<void> _drag(WidgetTester tester, Offset from, Offset by) async {
  final TestGesture gesture = await tester.startGesture(from);
  final Offset step = by / 6;
  for (int i = 0; i < 6; i++) {
    await gesture.moveBy(step);
    await tester.pump(const Duration(milliseconds: 16));
  }
  // Hold still so the release velocity is ~0 and only distance counts.
  await tester.pump(const Duration(seconds: 1));
  await gesture.up();
}

void main() {
  group('dismiss directions', () {
    Future<ExpandableAnimationController> pumpExpanded(
      WidgetTester tester,
      Set<ExpandableAnimationDismissDirection> directions, {
      WidgetBuilder? expandedBuilder,
    }) async {
      usePhoneSurface(tester);
      final ExpandableAnimationController controller =
          ExpandableAnimationController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        harness(
          ExpandableAnimation(
            controller: controller,
            gestureConfig:
                ExpandableAnimationGestureConfig(dismissDirections: directions),
            expandedBuilder: expandedBuilder ?? expandedPage,
            child: sourceCard(),
          ),
        ),
      );
      controller.expand();
      await tester.pumpAndSettle();
      return controller;
    }

    testWidgets('up only: dragging up dismisses, dragging down does not',
        (WidgetTester tester) async {
      final ExpandableAnimationController controller = await pumpExpanded(
        tester,
        <ExpandableAnimationDismissDirection>{
          ExpandableAnimationDismissDirection.up,
        },
      );
      await _drag(tester, const Offset(200, 500), const Offset(0, 300));
      await tester.pumpAndSettle();
      expect(controller.isExpanded, isTrue);

      final TestGesture gesture =
          await tester.startGesture(const Offset(200, 600));
      for (int i = 0; i < 6; i++) {
        await gesture.moveBy(const Offset(0, -50));
        await tester.pump(const Duration(milliseconds: 16));
      }
      // Anchored at the bottom edge and moving up.
      final Rect dragged = tester.getRect(surfaceFinder);
      expect(dragged.bottom, lessThan(800));
      expect(dragged.width, lessThan(400));
      await tester.pump(const Duration(seconds: 1));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(controller.isCollapsed, isTrue);
    });

    testWidgets('left and right dismiss with horizontal drags',
        (WidgetTester tester) async {
      for (final Offset by in <Offset>[
        const Offset(250, 0),
        const Offset(-250, 0),
      ]) {
        final ExpandableAnimationController controller =
            await pumpExpanded(tester, _horizontal);
        final TestGesture gesture =
            await tester.startGesture(const Offset(200, 400));
        for (int i = 0; i < 5; i++) {
          await gesture.moveBy(by / 5);
          await tester.pump(const Duration(milliseconds: 16));
        }
        final Rect dragged = tester.getRect(surfaceFinder);
        expect(by.dx > 0 ? dragged.left : -dragged.right + 400, greaterThan(0));
        await tester.pump(const Duration(seconds: 1));
        await gesture.up();
        await tester.pumpAndSettle();
        expect(controller.isCollapsed, isTrue, reason: 'drag by $by');
      }
    });

    testWidgets('down only ignores horizontal drags',
        (WidgetTester tester) async {
      final ExpandableAnimationController controller = await pumpExpanded(
        tester,
        const ExpandableAnimationGestureConfig().dismissDirections,
      );
      await _drag(tester, const Offset(50, 400), const Offset(300, 0));
      await tester.pumpAndSettle();
      expect(controller.isExpanded, isTrue);
    });

    testWidgets('an empty set disables dragging', (WidgetTester tester) async {
      final ExpandableAnimationController controller =
          await pumpExpanded(tester, <ExpandableAnimationDismissDirection>{});
      await _drag(tester, const Offset(200, 200), const Offset(0, 300));
      await tester.pumpAndSettle();
      expect(controller.isExpanded, isTrue);
    });

    testWidgets('up and down: the drag can reverse through its start',
        (WidgetTester tester) async {
      final ExpandableAnimationController controller = await pumpExpanded(
        tester,
        <ExpandableAnimationDismissDirection>{
          ExpandableAnimationDismissDirection.up,
          ExpandableAnimationDismissDirection.down,
        },
      );
      final TestGesture gesture =
          await tester.startGesture(const Offset(200, 400));
      for (int i = 0; i < 4; i++) {
        await gesture.moveBy(const Offset(0, 40));
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(tester.getRect(surfaceFinder).top, greaterThan(0));
      for (int i = 0; i < 10; i++) {
        await gesture.moveBy(const Offset(0, -40));
        await tester.pump(const Duration(milliseconds: 16));
      }
      // Now dragged upwards: anchored at the bottom, top edge unchanged-ish.
      final Rect up = tester.getRect(surfaceFinder);
      expect(up.bottom, lessThan(800));
      await tester.pump(const Duration(seconds: 1));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(controller.isCollapsed, isTrue);
    });

    testWidgets('a vertical list dismisses upwards from its bottom',
        (WidgetTester tester) async {
      final ScrollController scroll = ScrollController();
      addTearDown(scroll.dispose);
      final ExpandableAnimationController controller = await pumpExpanded(
        tester,
        <ExpandableAnimationDismissDirection>{
          ExpandableAnimationDismissDirection.up,
        },
        expandedBuilder: (BuildContext context) => ListView.builder(
          key: const Key('list'),
          controller: scroll,
          itemCount: 30,
          itemBuilder: (BuildContext context, int i) =>
              SizedBox(height: 50, child: Text('Row $i')),
        ),
      );
      // Jump to the end; reaching it without a drag must not dismiss.
      scroll.jumpTo(scroll.position.maxScrollExtent);
      await tester.pumpAndSettle();
      expect(controller.isExpanded, isTrue);
      // Pull up past the end.
      await _drag(tester, const Offset(200, 600), const Offset(0, -320));
      await tester.pumpAndSettle();
      expect(controller.isCollapsed, isTrue);
    });

    testWidgets('a PageView dismisses when swiped past its last page',
        (WidgetTester tester) async {
      final ExpandableAnimationController controller = await pumpExpanded(
        tester,
        _horizontal,
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

      await _drag(tester, const Offset(350, 400), const Offset(-300, 0));
      await tester.pumpAndSettle();
      expect(controller.isCollapsed, isTrue);
    });

    testWidgets('zoomable content forwards horizontal dismiss drags',
        (WidgetTester tester) async {
      final ExpandableAnimationController controller = await pumpExpanded(
        tester,
        _horizontal,
        expandedBuilder: (BuildContext context) =>
            const ExpandableAnimationZoomable(child: SizedBox.expand()),
      );
      await _drag(tester, const Offset(100, 400), const Offset(260, 30));
      await tester.pumpAndSettle();
      expect(controller.isCollapsed, isTrue);
    });

    test('drag geometry anchors at the edge it moves away from', () {
      const ExpandableAnimationGestureConfig config =
          ExpandableAnimationGestureConfig();
      const SurfaceGeometry expanded = SurfaceGeometry(
        rect: Rect.fromLTWH(0, 0, 400, 800),
        borderRadius: BorderRadius.zero,
      );
      Rect rect(ExpandableAnimationDismissDirection d, double offset) =>
          dragSurfaceGeometry(
            expanded: expanded,
            offset: offset,
            direction: d,
            collapsedRadius: BorderRadius.zero,
            config: config,
          ).rect;

      final Rect up = rect(ExpandableAnimationDismissDirection.up, 400);
      expect(up.bottom, closeTo(800 - 400 * config.dragResistance, 0.01));
      expect(up.center.dx, 200);

      final Rect right = rect(ExpandableAnimationDismissDirection.right, 200);
      expect(right.left, closeTo(200 * config.dragResistance, 0.01));
      expect(right.center.dy, 400);

      final Rect left = rect(ExpandableAnimationDismissDirection.left, 200);
      expect(left.right, closeTo(400 - 200 * config.dragResistance, 0.01));
      expect(
        dragExtent(expanded.rect, ExpandableAnimationDismissDirection.left),
        400,
      );
    });

    test('direction helpers and config equality', () {
      expect(ExpandableAnimationDismissDirection.down.axis, Axis.vertical);
      expect(ExpandableAnimationDismissDirection.left.axis, Axis.horizontal);
      expect(ExpandableAnimationDismissDirection.up.unit, const Offset(0, -1));
      expect(
        ExpandableAnimationDismissDirection.fromDelta(Axis.horizontal, -3),
        ExpandableAnimationDismissDirection.left,
      );
      expect(
        ExpandableAnimationDismissDirection.fromDelta(Axis.vertical, 3),
        ExpandableAnimationDismissDirection.down,
      );
      const ExpandableAnimationGestureConfig a =
          ExpandableAnimationGestureConfig(dismissDirections: _horizontal);
      final ExpandableAnimationGestureConfig b =
          const ExpandableAnimationGestureConfig().copyWith(
        dismissDirections: <ExpandableAnimationDismissDirection>{
          ExpandableAnimationDismissDirection.right,
          ExpandableAnimationDismissDirection.left,
        },
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a.allowsAxis(Axis.horizontal), isTrue);
      expect(a.allowsAxis(Axis.vertical), isFalse);
      expect(a.toString(), contains('dismissDirections: left, right'));
    });
  });

  group('ExpandableAnimationTheme', () {
    testWidgets('provides defaults that widgets can override',
        (WidgetTester tester) async {
      usePhoneSurface(tester);
      final ExpandableAnimationController themed =
          ExpandableAnimationController();
      final ExpandableAnimationController overridden =
          ExpandableAnimationController();
      addTearDown(themed.dispose);
      addTearDown(overridden.dispose);
      await tester.pumpWidget(
        ExpandableAnimationTheme(
          data: const ExpandableAnimationThemeData(
            duration: Duration(milliseconds: 1000),
            curve: Curves.linear,
            mode: ExpandableAnimationMode.dialog(maxSize: Size(300, 300)),
            backgroundOpacity: 0.2,
          ),
          child: harness(
            Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                ExpandableAnimation(
                  controller: themed,
                  expandedBuilder: expandedPage,
                  child: sourceCard(label: 'Themed'),
                ),
                ExpandableAnimation(
                  controller: overridden,
                  duration: const Duration(milliseconds: 200),
                  expandedBuilder: expandedPage,
                  child: sourceCard(label: 'Overridden'),
                ),
              ],
            ),
          ),
        ),
      );
      themed.expand();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(themed.progress, closeTo(0.5, 0.05), reason: 'theme duration');
      await tester.pumpAndSettle();
      expect(tester.getRect(surfaceFinder).size, const Size(300, 300));
      final Iterable<ColoredBox> scrims = tester
          .widgetList<ColoredBox>(find.byType(ColoredBox))
          .where((ColoredBox box) =>
              box.color.r == 0 && box.color.g == 0 && box.color.b == 0);
      expect(
        scrims.any((ColoredBox box) => (box.color.a - 0.2).abs() < 0.01),
        isTrue,
        reason: 'theme backgroundOpacity',
      );
      themed.collapse();
      await tester.pumpAndSettle();

      overridden.expand();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(overridden.progress, closeTo(0.5, 0.05),
          reason: 'widget duration wins');
      await tester.pumpAndSettle();
    });

    testWidgets('is carried into expanded views and updates live',
        (WidgetTester tester) async {
      usePhoneSurface(tester);
      late StateSetter setOuter;
      double hoverScale = 1.1;
      late ExpandableAnimationThemeData innerTheme;
      await tester.pumpWidget(
        StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            setOuter = setState;
            return ExpandableAnimationTheme(
              data: ExpandableAnimationThemeData(hoverScale: hoverScale),
              child: harness(
                ExpandableAnimation(
                  expandedBuilder: (BuildContext context) {
                    innerTheme = ExpandableAnimationTheme.of(context);
                    return const SizedBox.expand();
                  },
                  child: sourceCard(),
                ),
              ),
            );
          },
        ),
      );
      await tester.tap(find.byKey(sourceKey));
      await tester.pumpAndSettle();
      expect(innerTheme.hoverScale, 1.1);
      setOuter(() => hoverScale = 1.2);
      await tester.pump();
      await tester.pump();
      expect(innerTheme.hoverScale, 1.2);
    });

    test('data copyWith, merge, equality and diagnostics', () {
      const ExpandableAnimationThemeData empty = ExpandableAnimationThemeData();
      const ExpandableAnimationThemeData data = ExpandableAnimationThemeData(
        duration: Duration(milliseconds: 300),
        backgroundBlur: 4,
      );
      expect(empty.merge(null), empty);
      expect(empty.merge(data), data);
      expect(data.copyWith(), data);
      expect(data.copyWith().hashCode, data.hashCode);
      expect(data.copyWith(hoverScale: 1.05).hoverScale, 1.05);
      expect(data, isNot(empty));
      final ExpandableAnimationThemeData full = empty.merge(
        ExpandableAnimationThemeData(
          mode: const ExpandableAnimationMode.sheet(),
          duration: const Duration(milliseconds: 1),
          reverseDuration: const Duration(milliseconds: 2),
          curve: Curves.linear,
          reverseCurve: Curves.easeIn,
          physics: ExpandableAnimationPhysics.smooth,
          borderRadius: BorderRadius.circular(1),
          expandedBorderRadius: BorderRadius.circular(2),
          collapsedColor: const Color(0xFF000001),
          expandedColor: const Color(0xFF000002),
          backgroundColor: const Color(0xFF000003),
          backgroundOpacity: 0.1,
          backgroundBlur: 1,
          dismissOnBackgroundTap: false,
          enableDragToDismiss: false,
          gestureConfig: const ExpandableAnimationGestureConfig(minScale: 0.5),
          hideSourceWhileExpanded: false,
          useRootNavigator: false,
          respectReducedMotion: false,
          transitionBuilder: ExpandableAnimation.defaultTransitionBuilder,
          backgroundSemanticLabel: 'Dismiss',
          hoverScale: 1.03,
        ),
      );
      expect(full.backgroundSemanticLabel, 'Dismiss');
      expect(full.useRootNavigator, isFalse);
      final DiagnosticPropertiesBuilder builder = DiagnosticPropertiesBuilder();
      full.debugFillProperties(builder);
      expect(builder.properties.map((DiagnosticsNode n) => n.name),
          contains('hoverScale'));
      expect(
        () => ExpandableAnimationThemeData(backgroundOpacity: 2),
        throwsAssertionError,
      );
      expect(
        () => ExpandableAnimationThemeData(backgroundBlur: -1),
        throwsAssertionError,
      );
      expect(
        () => ExpandableAnimationThemeData(hoverScale: 0),
        throwsAssertionError,
      );
    });

    testWidgets('of returns defaults without a theme',
        (WidgetTester tester) async {
      late ExpandableAnimationThemeData data;
      await tester.pumpWidget(Builder(builder: (BuildContext context) {
        data = ExpandableAnimationTheme.of(context);
        return const SizedBox();
      }));
      expect(data, const ExpandableAnimationThemeData());
    });
  });

  group('hover and focus effect', () {
    double scaleOfSource(WidgetTester tester) => tester
        .widget<AnimatedScale>(
          find
              .ancestor(
                of: find.byKey(sourceKey).first,
                matching: find.byType(AnimatedScale),
              )
              .first,
        )
        .scale;

    testWidgets('hovering scales the source and expansion starts from it',
        (WidgetTester tester) async {
      usePhoneSurface(tester);
      await tester.pumpWidget(
        harness(
          ExpandableAnimation(
            hoverScale: 1.1,
            curve: Curves.linear,
            expandedBuilder: expandedPage,
            child: sourceCard(),
          ),
        ),
      );
      expect(scaleOfSource(tester), 1.0);
      // Desktop platforms start in traditional (pointer) highlight mode; the
      // test platform defaults to touch, where hover effects are not shown.
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTraditional;
      addTearDown(() => FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.automatic);
      final TestGesture mouse =
          await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      await mouse.moveTo(const Offset(200, 400));
      await tester.pumpAndSettle();
      expect(scaleOfSource(tester), 1.1);
      final Rect scaled = tester.getRect(find.byKey(sourceKey));
      expect(scaled.width, closeTo(220, 0.5));

      await tester.tapAt(const Offset(200, 400), kind: PointerDeviceKind.mouse);
      await tester.pump();
      expect(tester.getRect(surfaceFinder), rectMoreOrLessEquals(scaled));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      await mouse.moveTo(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(scaleOfSource(tester), 1.0);
    });

    testWidgets('keyboard focus scales the source; disabled does not',
        (WidgetTester tester) async {
      usePhoneSurface(tester);
      Future<void> pump({required bool enabled}) => tester.pumpWidget(
            harness(
              ExpandableAnimation(
                hoverScale: 1.05,
                enabled: enabled,
                expandedBuilder: expandedPage,
                child: sourceCard(),
              ),
            ),
          );
      await pump(enabled: true);
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTraditional;
      addTearDown(() => FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.automatic);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(scaleOfSource(tester), 1.05);

      await pump(enabled: false);
      await tester.pumpAndSettle();
      expect(scaleOfSource(tester), 1.0);
    });
  });
}
