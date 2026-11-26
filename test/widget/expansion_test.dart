import 'package:expandable_animation/expandable_animation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

void main() {
  const Duration duration = Duration(milliseconds: 400);

  testWidgets('tap expands to fullscreen and morphs the surface',
      (WidgetTester tester) async {
    usePhoneSurface(tester);
    final List<ExpandableAnimationPhase> phases = <ExpandableAnimationPhase>[];
    int expanded = 0;
    await tester.pumpWidget(
      harness(
        ExpandableAnimation(
          curve: Curves.linear,
          borderRadius: BorderRadius.circular(16),
          onPhaseChanged: phases.add,
          onExpanded: () => expanded++,
          expandedBuilder: expandedPage,
          child: sourceCard(),
        ),
      ),
    );
    final Rect source = tester.getRect(find.byKey(sourceKey));
    expect(source, const Rect.fromLTWH(100, 350, 200, 100));

    await tester.tap(find.byKey(sourceKey));
    await tester.pump();
    expect(isRouteShown(), isTrue);
    expect(tester.getRect(surfaceFinder), source);

    await tester.pump(duration ~/ 2);
    final Rect mid = tester.getRect(surfaceFinder);
    expect(mid, rectMoreOrLessEquals(
      Rect.lerp(source, const Rect.fromLTWH(0, 0, 400, 800), 0.5)!,
      epsilon: 1,
    ));

    await tester.pumpAndSettle();
    expect(tester.getRect(surfaceFinder), const Rect.fromLTWH(0, 0, 400, 800));
    expect(find.text('Details'), findsOneWidget);
    expect(phases, <ExpandableAnimationPhase>[
      ExpandableAnimationPhase.expanding,
      ExpandableAnimationPhase.expanded,
    ]);
    expect(expanded, 1);
  });

  testWidgets('source is hidden while expanded and restored after collapse',
      (WidgetTester tester) async {
    usePhoneSurface(tester);
    int collapsed = 0;
    await tester.pumpWidget(
      harness(
        ExpandableAnimation(
          onCollapsed: () => collapsed++,
          expandedBuilder: expandedPage,
          child: sourceCard(),
        ),
      ),
    );

    Visibility sourceVisibility() => tester.widget<Visibility>(
          find
              .ancestor(
                of: find.byKey(sourceKey).first,
                matching: find.byType(Visibility),
              )
              .first,
        );

    expect(sourceVisibility().visible, isTrue);
    await tester.tap(find.byKey(sourceKey));
    await tester.pumpAndSettle();
    expect(sourceVisibility().visible, isFalse);

    await tester.tap(find.text('Details'));
    await tester.pumpAndSettle();
    expect(isRouteShown(), isFalse);
    expect(sourceVisibility().visible, isTrue);
    expect(collapsed, 1);
  });

  testWidgets('hideSourceWhileExpanded false keeps the source visible',
      (WidgetTester tester) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(
      harness(
        ExpandableAnimation(
          hideSourceWhileExpanded: false,
          expandedBuilder: expandedPage,
          child: sourceCard(),
        ),
      ),
    );
    await tester.tap(find.byKey(sourceKey));
    await tester.pumpAndSettle();
    final Visibility visibility = tester.widget<Visibility>(
      find
          .ancestor(
            of: find.byKey(sourceKey).first,
            matching: find.byType(Visibility),
          )
          .first,
    );
    expect(visibility.visible, isTrue);
  });

  testWidgets('controller expand, collapse and toggle with futures',
      (WidgetTester tester) async {
    usePhoneSurface(tester);
    final ExpandableAnimationController controller =
        ExpandableAnimationController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      harness(
        ExpandableAnimation(
          controller: controller,
          expandOnTap: false,
          expandedBuilder: expandedPage,
          child: sourceCard(),
        ),
      ),
    );
    expect(controller.isAttached, isTrue);

    bool expandDone = false;
    controller.expand().then((_) => expandDone = true);
    await tester.pump();
    expect(controller.phase, ExpandableAnimationPhase.expanding);
    await tester.pump(duration ~/ 2);
    expect(controller.progress, closeTo(0.5, 0.05));
    await tester.pumpAndSettle();
    expect(expandDone, isTrue);
    expect(controller.isExpanded, isTrue);
    expect(controller.progress, 1);

    // Expanding again is a no-op that completes immediately.
    await controller.expand();

    bool collapseDone = false;
    controller.collapse().then((_) => collapseDone = true);
    await tester.pump();
    expect(controller.phase, ExpandableAnimationPhase.collapsing);
    await tester.pumpAndSettle();
    expect(collapseDone, isTrue);
    expect(controller.isCollapsed, isTrue);
    expect(controller.progress, 0);

    // Collapsing while collapsed is a no-op.
    await controller.collapse();

    controller.toggle();
    await tester.pumpAndSettle();
    expect(controller.isExpanded, isTrue);
    controller.toggle();
    await tester.pumpAndSettle();
    expect(controller.isCollapsed, isTrue);
  });

  testWidgets('expandOnTap false ignores taps', (WidgetTester tester) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(
      harness(
        ExpandableAnimation(
          expandOnTap: false,
          expandedBuilder: expandedPage,
          child: sourceCard(),
        ),
      ),
    );
    await tester.tap(find.byKey(sourceKey));
    await tester.pumpAndSettle();
    expect(isRouteShown(), isFalse);
  });

  testWidgets('enabled false blocks taps and controller expansion',
      (WidgetTester tester) async {
    usePhoneSurface(tester);
    final ExpandableAnimationController controller =
        ExpandableAnimationController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      harness(
        ExpandableAnimation(
          controller: controller,
          enabled: false,
          expandedBuilder: expandedPage,
          child: sourceCard(),
        ),
      ),
    );
    await tester.tap(find.byKey(sourceKey));
    await controller.expand();
    await tester.pumpAndSettle();
    expect(isRouteShown(), isFalse);
  });

  testWidgets('collapse during expansion reverses from the current position',
      (WidgetTester tester) async {
    usePhoneSurface(tester);
    final ExpandableAnimationController controller =
        ExpandableAnimationController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      harness(
        ExpandableAnimation(
          controller: controller,
          curve: Curves.linear,
          expandedBuilder: expandedPage,
          child: sourceCard(),
        ),
      ),
    );
    final Future<void> expand = controller.expand();
    await tester.pump();
    await tester.pump(duration ~/ 2);
    final double progress = controller.progress;
    expect(progress, closeTo(0.5, 0.05));

    controller.collapse();
    await expand; // Interrupted expansions still complete their future.
    await tester.pump();
    expect(controller.phase, ExpandableAnimationPhase.collapsing);
    await tester.pump(duration ~/ 4);
    expect(controller.progress, lessThan(progress));
    await tester.pumpAndSettle();
    expect(controller.isCollapsed, isTrue);
    expect(isRouteShown(), isFalse);
  });

  testWidgets('expand during collapse continues from the current position',
      (WidgetTester tester) async {
    usePhoneSurface(tester);
    final ExpandableAnimationController controller =
        ExpandableAnimationController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      harness(
        ExpandableAnimation(
          controller: controller,
          curve: Curves.linear,
          expandedBuilder: expandedPage,
          child: sourceCard(),
        ),
      ),
    );
    controller.expand();
    await tester.pumpAndSettle();

    controller.collapse();
    await tester.pump();
    await tester.pump(duration ~/ 2);
    final double progress = controller.progress;
    expect(progress, closeTo(0.5, 0.05));

    controller.expand();
    await tester.pump();
    expect(controller.phase, ExpandableAnimationPhase.expanding);
    expect(controller.progress, closeTo(progress, 0.05));
    await tester.pumpAndSettle();
    expect(controller.isExpanded, isTrue);
    // Exactly one expanded route remains.
    expect(find.byKey(expandedKey), findsOneWidget);
  });

  testWidgets('rapid repeated taps never stack routes',
      (WidgetTester tester) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(
      harness(
        ExpandableAnimation(
          expandedBuilder: expandedPage,
          child: sourceCard(),
        ),
      ),
    );
    for (int i = 0; i < 5; i++) {
      await tester.tap(find.byKey(sourceKey).first, warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 16));
    }
    await tester.pumpAndSettle();
    expect(find.byKey(expandedKey), findsOneWidget);
  });

  testWidgets('system back collapses the expanded view',
      (WidgetTester tester) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(
      harness(
        ExpandableAnimation(
          expandedBuilder: expandedPage,
          child: sourceCard(),
        ),
      ),
    );
    await tester.tap(find.byKey(sourceKey));
    await tester.pumpAndSettle();
    expect(isRouteShown(), isTrue);

    final bool handled = await tester.binding.handlePopRoute();
    expect(handled, isTrue);
    await tester.pumpAndSettle();
    expect(isRouteShown(), isFalse);
  });

  testWidgets('Escape collapses the expanded view',
      (WidgetTester tester) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(
      harness(
        ExpandableAnimation(
          expandedBuilder: expandedPage,
          child: sourceCard(),
        ),
      ),
    );
    await tester.tap(find.byKey(sourceKey));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(isRouteShown(), isFalse);
  });

  testWidgets('Enter on the focused source expands it',
      (WidgetTester tester) async {
    usePhoneSurface(tester);
    final FocusNode focus = FocusNode();
    addTearDown(focus.dispose);
    await tester.pumpWidget(
      harness(
        ExpandableAnimation(
          expandedBuilder: expandedPage,
          child: Focus(focusNode: focus, child: sourceCard()),
        ),
      ),
    );
    // Move focus to the FocusableActionDetector that wraps the source.
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(isRouteShown(), isTrue);
  });

  testWidgets('dialog mode: background tap dismisses, blur and scrim',
      (WidgetTester tester) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(
      harness(
        ExpandableAnimation(
          mode: const ExpandableAnimationMode.dialog(
            margin: EdgeInsets.all(20),
            maxSize: Size(300, 400),
          ),
          backgroundBlur: 8,
          backgroundOpacity: 0.4,
          expandedBorderRadius: BorderRadius.circular(24),
          expandedBuilder: expandedPage,
          child: sourceCard(),
        ),
      ),
    );
    await tester.tap(find.byKey(sourceKey));
    await tester.pumpAndSettle();
    expect(
      tester.getRect(surfaceFinder),
      Rect.fromCenter(center: const Offset(200, 400), width: 300, height: 400),
    );
    expect(find.byType(BackdropFilter), findsOneWidget);
    final ColoredBox scrim = tester.widget<ColoredBox>(
      find
          .descendant(
            of: find.byType(BackdropFilter),
            matching: find.byType(ColoredBox),
          )
          .first,
    );
    expect(scrim.color.a, closeTo(0.4, 0.01));

    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(isRouteShown(), isFalse);
  });

  testWidgets('dismissOnBackgroundTap false keeps the view open',
      (WidgetTester tester) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(
      harness(
        ExpandableAnimation(
          mode: const ExpandableAnimationMode.sheet(heightFactor: 0.5),
          dismissOnBackgroundTap: false,
          expandedBuilder: expandedPage,
          child: sourceCard(),
        ),
      ),
    );
    await tester.tap(find.byKey(sourceKey));
    await tester.pumpAndSettle();
    expect(tester.getRect(surfaceFinder), const Rect.fromLTWH(0, 400, 400, 400));
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(isRouteShown(), isTrue);
  });

  testWidgets('surface color interpolates between collapsed and expanded',
      (WidgetTester tester) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(
      harness(
        ExpandableAnimation(
          curve: Curves.linear,
          collapsedColor: const Color(0xFF000000),
          expandedColor: const Color(0xFFFFFFFF),
          expandedBuilder: expandedPage,
          child: sourceCard(),
        ),
      ),
    );
    await tester.tap(find.byKey(sourceKey));
    await tester.pump();
    await tester.pump(duration ~/ 2);
    final ColoredBox surface = tester.widget<ColoredBox>(
      find.descendant(of: surfaceFinder, matching: find.byType(ColoredBox)).first,
    );
    expect(surface.color.r, closeTo(0.5, 0.02));
  });

  testWidgets('reduced motion makes transitions instant',
      (WidgetTester tester) async {
    usePhoneSurface(tester);
    final ExpandableAnimationController controller =
        ExpandableAnimationController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Scaffold(
            body: Center(
              child: ExpandableAnimation(
                controller: controller,
                expandedBuilder: expandedPage,
                child: sourceCard(),
              ),
            ),
          ),
        ),
      ),
    );
    controller.expand();
    await tester.pump();
    await tester.pump();
    expect(controller.isExpanded, isTrue);
    controller.collapse();
    await tester.pump();
    await tester.pump();
    expect(controller.isCollapsed, isTrue);
  });

  testWidgets('spring physics expands and collapses',
      (WidgetTester tester) async {
    usePhoneSurface(tester);
    final ExpandableAnimationController controller =
        ExpandableAnimationController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      harness(
        ExpandableAnimation(
          controller: controller,
          physics: ExpandableAnimationPhysics.bouncy,
          expandedBuilder: expandedPage,
          child: sourceCard(),
        ),
      ),
    );
    controller.expand();
    await tester.pump();
    // Sample the whole expansion and record the widest surface.
    double widest = 0;
    final int frames =
        ExpandableAnimationPhysics.bouncy.settleDuration.inMilliseconds ~/ 16;
    for (int i = 0; i < frames; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      final double width = tester.getRect(surfaceFinder).width;
      if (width > widest) {
        widest = width;
      }
    }
    await tester.pumpAndSettle();
    expect(widest, greaterThan(400), reason: 'underdamped spring overshoots');
    expect(controller.isExpanded, isTrue);
    expect(tester.getRect(surfaceFinder), const Rect.fromLTWH(0, 0, 400, 800));

    controller.collapse();
    await tester.pumpAndSettle();
    expect(controller.isCollapsed, isTrue);
  });

  testWidgets('ExpandableAnimation.of works in both subtrees',
      (WidgetTester tester) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(
      harness(
        ExpandableAnimation(
          expandOnTap: false,
          expandedBuilder: (BuildContext context) => Center(
            child: TextButton(
              onPressed: () => ExpandableAnimation.of(context).collapse(),
              child: const Text('Close'),
            ),
          ),
          child: Builder(
            builder: (BuildContext context) => TextButton(
              onPressed: () => ExpandableAnimation.of(context).expand(),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(isRouteShown(), isTrue);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(isRouteShown(), isFalse);
  });

  testWidgets('ExpandableAnimation.of throws outside a scope',
      (WidgetTester tester) async {
    late BuildContext captured;
    await tester.pumpWidget(
      Builder(
        builder: (BuildContext context) {
          captured = context;
          return const SizedBox();
        },
      ),
    );
    expect(ExpandableAnimation.maybeOf(captured), isNull);
    expect(() => ExpandableAnimation.of(captured), throwsFlutterError);
  });

  testWidgets('inherited themes are carried into the expanded view',
      (WidgetTester tester) async {
    usePhoneSurface(tester);
    late Color seen;
    await tester.pumpWidget(
      harness(
        Theme(
          data: ThemeData(primaryColor: const Color(0xFF123456)),
          child: ExpandableAnimation(
            expandedBuilder: (BuildContext context) {
              seen = Theme.of(context).primaryColor;
              return const SizedBox.expand();
            },
            child: sourceCard(),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(sourceKey));
    await tester.pumpAndSettle();
    expect(seen, const Color(0xFF123456));
  });

  testWidgets('parent rebuilds update the expanded content',
      (WidgetTester tester) async {
    usePhoneSurface(tester);
    late StateSetter setOuterState;
    String label = 'One';
    await tester.pumpWidget(
      harness(
        StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            setOuterState = setState;
            return ExpandableAnimation(
              expandedBuilder: (BuildContext context) =>
                  expandedPage(context, label: label),
              child: sourceCard(),
            );
          },
        ),
      ),
    );
    await tester.tap(find.byKey(sourceKey));
    await tester.pumpAndSettle();
    expect(find.text('One'), findsOneWidget);

    setOuterState(() => label = 'Two');
    await tester.pump();
    await tester.pump();
    expect(find.text('Two'), findsOneWidget);
  });

  testWidgets('multiple instances expand independently',
      (WidgetTester tester) async {
    usePhoneSurface(tester);
    final ExpandableAnimationController a = ExpandableAnimationController();
    final ExpandableAnimationController b = ExpandableAnimationController();
    addTearDown(a.dispose);
    addTearDown(b.dispose);
    await tester.pumpWidget(
      harness(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ExpandableAnimation(
              controller: a,
              expandedBuilder: (BuildContext context) =>
                  expandedPage(context, label: 'A'),
              child: sourceCard(label: 'Card A'),
            ),
            ExpandableAnimation(
              controller: b,
              expandedBuilder: (BuildContext context) =>
                  expandedPage(context, label: 'B'),
              child: sourceCard(label: 'Card B'),
            ),
          ],
        ),
      ),
    );
    await tester.tap(find.text('Card B'));
    await tester.pumpAndSettle();
    expect(a.isCollapsed, isTrue);
    expect(b.isExpanded, isTrue);
    expect(find.text('B'), findsOneWidget);
    expect(find.text('A'), findsNothing);
  });

  testWidgets('nested expansion inside an expanded view',
      (WidgetTester tester) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(
      harness(
        ExpandableAnimation(
          expandedBuilder: (BuildContext context) => Center(
            child: ExpandableAnimation(
              expandedBuilder: (BuildContext context) =>
                  expandedPage(context, label: 'Inner'),
              child: sourceCard(label: 'Nested'),
            ),
          ),
          child: sourceCard(label: 'Outer'),
        ),
      ),
    );
    await tester.tap(find.text('Outer'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nested').last);
    await tester.pumpAndSettle();
    expect(find.text('Inner'), findsOneWidget);

    await tester.tap(find.text('Inner'));
    await tester.pumpAndSettle();
    expect(find.text('Inner'), findsNothing);
    expect(find.text('Nested'), findsWidgets);
  });

  testWidgets('expanded bounds follow window resizes',
      (WidgetTester tester) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(
      harness(
        ExpandableAnimation(
          expandedBuilder: expandedPage,
          child: sourceCard(),
        ),
      ),
    );
    await tester.tap(find.byKey(sourceKey));
    await tester.pumpAndSettle();
    tester.view.physicalSize = const Size(800, 400);
    await tester.pumpAndSettle();
    expect(tester.getRect(surfaceFinder), const Rect.fromLTWH(0, 0, 800, 400));
    // Collapsing re-measures the moved source.
    await tester.tap(find.text('Details'));
    await tester.pump();
    await tester.pumpAndSettle();
    expect(isRouteShown(), isFalse);
    expect(
      tester.getRect(find.byKey(sourceKey)),
      const Rect.fromLTWH(300, 150, 200, 100),
    );
  });

  testWidgets('safe area padding is only kept where it overlaps',
      (WidgetTester tester) async {
    usePhoneSurface(tester);
    tester.view.padding = const FakeViewPadding(top: 40, bottom: 20);
    late EdgeInsets fullscreenPadding;
    late EdgeInsets safePadding;
    Widget build(ExpandableAnimationMode mode, void Function(EdgeInsets) out) {
      return harness(
        ExpandableAnimation(
          mode: mode,
          expandedBuilder: (BuildContext context) {
            out(MediaQuery.paddingOf(context));
            return const SizedBox.expand();
          },
          child: sourceCard(),
        ),
      );
    }

    await tester.pumpWidget(
      build(
        const ExpandableAnimationMode.fullscreen(),
        (EdgeInsets p) => fullscreenPadding = p,
      ),
    );
    await tester.tap(find.byKey(sourceKey));
    await tester.pumpAndSettle();
    expect(fullscreenPadding, const EdgeInsets.only(top: 40, bottom: 20));
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    await tester.pumpWidget(
      build(
        const ExpandableAnimationMode.fullscreen(useSafeArea: true),
        (EdgeInsets p) => safePadding = p,
      ),
    );
    await tester.tap(find.byKey(sourceKey));
    await tester.pumpAndSettle();
    expect(safePadding, EdgeInsets.zero);
    expect(tester.getRect(surfaceFinder), const Rect.fromLTRB(0, 40, 400, 780));
  });

  testWidgets('custom transition builder is used',
      (WidgetTester tester) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(
      harness(
        ExpandableAnimation(
          transitionBuilder: (
            BuildContext context,
            Animation<double> animation,
            Widget collapsed,
            Widget expanded,
          ) {
            return KeyedSubtree(key: const Key('custom'), child: expanded);
          },
          expandedBuilder: expandedPage,
          child: sourceCard(),
        ),
      ),
    );
    await tester.tap(find.byKey(sourceKey));
    await tester.pump();
    expect(find.byKey(const Key('custom')), findsOneWidget);
    await tester.pumpAndSettle();
  });

  testWidgets('swapping controllers keeps the widget working',
      (WidgetTester tester) async {
    usePhoneSurface(tester);
    final ExpandableAnimationController first = ExpandableAnimationController();
    final ExpandableAnimationController second =
        ExpandableAnimationController();
    addTearDown(first.dispose);
    addTearDown(second.dispose);

    Widget build(ExpandableAnimationController? controller) => harness(
          ExpandableAnimation(
            controller: controller,
            expandedBuilder: expandedPage,
            child: sourceCard(),
          ),
        );

    await tester.pumpWidget(build(null));
    await tester.pumpWidget(build(first));
    expect(first.isAttached, isTrue);
    await tester.pumpWidget(build(second));
    expect(first.isAttached, isFalse);
    expect(second.isAttached, isTrue);
    await tester.pumpWidget(build(null));
    expect(second.isAttached, isFalse);

    await tester.tap(find.byKey(sourceKey));
    await tester.pumpAndSettle();
    expect(isRouteShown(), isTrue);
    // Switch to an external controller while expanded.
    await tester.pumpWidget(build(first));
    await tester.pump();
    expect(first.isExpanded, isTrue);
    first.collapse();
    await tester.pumpAndSettle();
    expect(isRouteShown(), isFalse);
  });

  testWidgets('disposing the source while expanded collapses with a fade',
      (WidgetTester tester) async {
    usePhoneSurface(tester);
    final ExpandableAnimationController controller =
        ExpandableAnimationController();
    addTearDown(controller.dispose);
    late StateSetter setOuterState;
    bool showSource = true;
    await tester.pumpWidget(
      harness(
        StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            setOuterState = setState;
            return showSource
                ? ExpandableAnimation(
                    controller: controller,
                    expandedBuilder: expandedPage,
                    child: sourceCard(),
                  )
                : const SizedBox();
          },
        ),
      ),
    );
    controller.expand();
    await tester.pumpAndSettle();

    setOuterState(() => showSource = false);
    await tester.pump();
    expect(isRouteShown(), isTrue);
    expect(controller.isAttached, isTrue, reason: 'orphaned route delegate');

    controller.collapse();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    final Opacity opacity = tester.widget<Opacity>(
      find.ancestor(of: surfaceFinder, matching: find.byType(Opacity)).first,
    );
    expect(opacity.opacity, lessThan(1));
    await tester.pumpAndSettle();
    expect(isRouteShown(), isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('disposing the source with an internal controller',
      (WidgetTester tester) async {
    usePhoneSurface(tester);
    late StateSetter setOuterState;
    bool showSource = true;
    await tester.pumpWidget(
      harness(
        StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            setOuterState = setState;
            return showSource
                ? ExpandableAnimation(
                    expandedBuilder: (BuildContext context) => Center(
                      child: TextButton(
                        onPressed: () =>
                            ExpandableAnimation.of(context).collapse(),
                        child: const Text('Close'),
                      ),
                    ),
                    child: sourceCard(),
                  )
                : const SizedBox();
          },
        ),
      ),
    );
    await tester.tap(find.byKey(sourceKey));
    await tester.pumpAndSettle();
    setOuterState(() => showSource = false);
    await tester.pump();
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(isRouteShown(), isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('collapse removes the route when another route is on top',
      (WidgetTester tester) async {
    usePhoneSurface(tester);
    final ExpandableAnimationController controller =
        ExpandableAnimationController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      harness(
        ExpandableAnimation(
          controller: controller,
          expandedBuilder: (BuildContext context) => Center(
            child: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const Scaffold(body: Text('Pushed')),
                ),
              ),
              child: const Text('Push'),
            ),
          ),
          child: sourceCard(),
        ),
      ),
    );
    controller.expand();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Push'));
    await tester.pumpAndSettle();
    expect(find.text('Pushed'), findsOneWidget);

    controller.collapse();
    await tester.pumpAndSettle();
    expect(controller.isCollapsed, isTrue);
    expect(isRouteShown(), isFalse);
    expect(find.text('Pushed'), findsOneWidget);
  });

  testWidgets('expanded content ignores taps until the expansion settles',
      (WidgetTester tester) async {
    usePhoneSurface(tester);
    int taps = 0;
    await tester.pumpWidget(
      harness(
        ExpandableAnimation(
          expandedBuilder: (BuildContext context) => GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => taps++,
            child: const SizedBox.expand(),
          ),
          child: sourceCard(),
        ),
      ),
    );
    await tester.tap(find.byKey(sourceKey));
    await tester.pump();
    await tester.pump(duration ~/ 2);
    await tester.tapAt(const Offset(200, 400));
    expect(taps, 0);
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(200, 400));
    expect(taps, 1);
  });

  testWidgets('semantics: source is a button and the view is dismissible',
      (WidgetTester tester) async {
    usePhoneSurface(tester);
    final SemanticsHandle handle = tester.ensureSemantics();
    await tester.pumpWidget(
      harness(
        ExpandableAnimation(
          semanticLabel: 'Open product',
          expandedBuilder: expandedPage,
          child: sourceCard(),
        ),
      ),
    );
    expect(
      tester.getSemantics(find.bySemanticsLabel(RegExp('Open product'))),
      matchesSemantics(
        label: 'Open product\nCard',
        isButton: true,
        hasEnabledState: true,
        isEnabled: true,
        isFocusable: true,
        hasTapAction: true,
        hasFocusAction: true,
      ),
    );
    await tester.tap(find.byKey(sourceKey));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Close'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('debugFillProperties describes the configuration',
      (WidgetTester tester) async {
    final DiagnosticPropertiesBuilder builder = DiagnosticPropertiesBuilder();
    ExpandableAnimation(
      enabled: false,
      enableDragToDismiss: false,
      expandedBuilder: expandedPage,
      child: const SizedBox(),
    ).debugFillProperties(builder);
    final List<String> description = builder.properties
        .where((DiagnosticsNode node) => !node.isFiltered(DiagnosticLevel.info))
        .map((DiagnosticsNode node) => node.toString())
        .toList();
    expect(description, contains('disabled'));
    expect(description, contains('drag-to-dismiss disabled'));
  });
}
