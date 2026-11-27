// Transitions are started without awaiting so tests can pump individual
// frames and inspect intermediate states.
// ignore_for_file: unawaited_futures

import 'package:expandable_animation/expandable_animation.dart';
import 'package:expandable_animation/src/animation/expandable_animation_physics.dart'
    show criticallyDampedSpring, springSettleDuration;
import 'package:expandable_animation/src/transitions/surface_geometry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

/// A source anchored to the bottom of the screen (like a mini player), so a
/// downward dismiss drag moves the surface towards it.
Widget _bottomHarness(Widget child) {
  return MaterialApp(
    home: Scaffold(
      body: Align(alignment: Alignment.bottomCenter, child: child),
    ),
  );
}

Future<void> _fling(WidgetTester tester, double speed) async {
  // 240 px down in 6 steps, timed so the release velocity is `speed`.
  final TestGesture gesture = await tester.createGesture();
  Duration time = Duration.zero;
  Offset position = const Offset(200, 200);
  await gesture.down(position, timeStamp: time);
  final Duration step = Duration(microseconds: (40 / speed * 1e6).round());
  for (int i = 0; i < 6; i++) {
    time += step;
    position += const Offset(0, 40);
    await gesture.moveTo(position, timeStamp: time);
    await tester.pump(step);
  }
  await gesture.up(timeStamp: time);
}

void main() {
  group('velocity-matched collapse', () {
    Future<double> progressShortlyAfterFling(
      WidgetTester tester, {
      required bool matchVelocity,
    }) async {
      usePhoneSurface(tester);
      final ExpandableAnimationController controller =
          ExpandableAnimationController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _bottomHarness(
          ExpandableAnimation(
            controller: controller,
            gestureConfig: ExpandableAnimationGestureConfig(
              matchReleaseVelocity: matchVelocity,
            ),
            expandedBuilder: expandedPage,
            child: sourceCard(),
          ),
        ),
      );
      controller.expand();
      await tester.pumpAndSettle();
      await _fling(tester, 3000);
      await tester.pump();
      expect(controller.phase, ExpandableAnimationPhase.collapsing);
      await tester.pump(const Duration(milliseconds: 60));
      final double progress = controller.progress;
      await tester.pumpAndSettle();
      expect(controller.isCollapsed, isTrue);
      expect(isRouteShown(), isFalse);
      return progress;
    }

    testWidgets('a fast flick collapses faster than the plain reverse',
        (WidgetTester tester) async {
      final double matched =
          await progressShortlyAfterFling(tester, matchVelocity: true);
      final double plain =
          await progressShortlyAfterFling(tester, matchVelocity: false);
      expect(matched, lessThan(plain));
    });

    testWidgets('uses the configured physics for the collapse spring',
        (WidgetTester tester) async {
      usePhoneSurface(tester);
      final ExpandableAnimationController controller =
          ExpandableAnimationController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _bottomHarness(
          ExpandableAnimation(
            controller: controller,
            physics: ExpandableAnimationPhysics.snappy,
            expandedBuilder: expandedPage,
            child: sourceCard(),
          ),
        ),
      );
      controller.expand();
      await tester.pumpAndSettle();
      await _fling(tester, 2500);
      await tester.pumpAndSettle();
      expect(controller.isCollapsed, isTrue);
    });

    testWidgets('reduced motion still collapses instantly after a drag',
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
              body: Align(
                alignment: Alignment.bottomCenter,
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
      await _fling(tester, 3000);
      await tester.pump();
      await tester.pump();
      expect(controller.isCollapsed, isTrue);
    });

    test('releaseProgressVelocity heads towards the source only', () {
      const Rect released = Rect.fromLTWH(0, 100, 400, 700);
      expect(
        releaseProgressVelocity(
          released: released,
          source: const Rect.fromLTWH(100, 800, 200, 100),
          fingerVelocity: 1000,
          dragResistance: 1,
        ),
        lessThan(0),
        reason: 'source below: a downward flick speeds up the collapse',
      );
      expect(
        releaseProgressVelocity(
          released: released,
          source: const Rect.fromLTWH(100, 0, 200, 50),
          fingerVelocity: 1000,
          dragResistance: 1,
        ),
        0,
        reason: 'source above: never push the surface away from it',
      );
      expect(
        releaseProgressVelocity(
          released: released,
          source: null,
          fingerVelocity: 1000,
          dragResistance: 1,
        ),
        0,
      );
      expect(
        releaseProgressVelocity(
          released: released,
          source: const Rect.fromLTWH(100, 800, 200, 100),
          fingerVelocity: 1e9,
          dragResistance: 1,
        ),
        -kMaxReleaseProgressVelocity,
      );
    });

    test('criticallyDampedSpring settles in about the requested time', () {
      for (final int ms in <int>[200, 400, 800]) {
        final Duration settle = springSettleDuration(
            criticallyDampedSpring(Duration(milliseconds: ms)));
        expect(settle.inMilliseconds, closeTo(ms, ms * 0.1));
      }
      expect(
        springSettleDuration(criticallyDampedSpring(Duration.zero)),
        lessThan(const Duration(milliseconds: 20)),
      );
    });

    test('gesture config exposes matchReleaseVelocity', () {
      const ExpandableAnimationGestureConfig config =
          ExpandableAnimationGestureConfig();
      expect(config.matchReleaseVelocity, isTrue);
      final ExpandableAnimationGestureConfig off =
          config.copyWith(matchReleaseVelocity: false);
      expect(off.matchReleaseVelocity, isFalse);
      expect(off, isNot(config));
      expect(off.toString(), contains('matchReleaseVelocity: false'));
    });
  });

  group('ExpandableAnimationZoomable', () {
    late TransformationController transform;

    setUp(() => transform = TransformationController());
    tearDown(() => transform.dispose());

    Future<ExpandableAnimationController> pumpViewer(
      WidgetTester tester, {
      ValueChanged<double>? onScaleChanged,
    }) async {
      usePhoneSurface(tester);
      final ExpandableAnimationController controller =
          ExpandableAnimationController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        harness(
          ExpandableAnimation(
            controller: controller,
            expandedBuilder: (BuildContext context) =>
                ExpandableAnimationZoomable(
              transformationController: transform,
              onScaleChanged: onScaleChanged,
              child: const ColoredBox(
                key: Key('photo'),
                color: Color(0xFF00897B),
                child: SizedBox.expand(),
              ),
            ),
            child: sourceCard(),
          ),
        ),
      );
      controller.expand();
      await tester.pumpAndSettle();
      return controller;
    }

    double scaleOf(TransformationController c) => c.value.getMaxScaleOnAxis();

    testWidgets('a one-finger drag dismisses when not zoomed',
        (WidgetTester tester) async {
      final ExpandableAnimationController controller = await pumpViewer(tester);
      final TestGesture gesture =
          await tester.startGesture(const Offset(200, 300));
      for (int i = 0; i < 6; i++) {
        await gesture.moveBy(const Offset(0, 50));
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(controller.isDragging, isTrue);
      expect(tester.getRect(surfaceFinder).top, greaterThan(0));
      await tester.pump(const Duration(seconds: 1));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(controller.isCollapsed, isTrue);
    });

    testWidgets('a one-finger drag pans instead of dismissing when zoomed',
        (WidgetTester tester) async {
      final ExpandableAnimationController controller = await pumpViewer(tester);
      transform.value = Matrix4.diagonal3Values(2, 2, 1)
        ..setTranslationRaw(-200, -400, 0);
      await tester.pump();
      final double ty = transform.value.getTranslation().y;
      final TestGesture gesture =
          await tester.startGesture(const Offset(200, 300));
      for (int i = 0; i < 6; i++) {
        await gesture.moveBy(const Offset(0, 30));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await gesture.up();
      await tester.pumpAndSettle();
      expect(controller.isExpanded, isTrue);
      expect(controller.isDragging, isFalse);
      expect(transform.value.getTranslation().y, greaterThan(ty));
    });

    testWidgets('two fingers pinch-zoom and never dismiss',
        (WidgetTester tester) async {
      final List<double> scales = <double>[];
      final ExpandableAnimationController controller =
          await pumpViewer(tester, onScaleChanged: scales.add);
      final TestGesture a = await tester.startGesture(const Offset(150, 400));
      final TestGesture b =
          await tester.startGesture(const Offset(250, 400), pointer: 2);
      for (int i = 0; i < 5; i++) {
        await a.moveBy(const Offset(-20, 10));
        await b.moveBy(const Offset(20, 10));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await a.up();
      await b.up();
      await tester.pumpAndSettle();
      expect(scaleOf(transform), greaterThan(1.5));
      expect(scales, isNotEmpty);
      expect(controller.isExpanded, isTrue);
    });

    testWidgets('a second finger turns a dismiss drag into a pinch',
        (WidgetTester tester) async {
      final ExpandableAnimationController controller = await pumpViewer(tester);
      final TestGesture a = await tester.startGesture(const Offset(200, 300));
      for (int i = 0; i < 3; i++) {
        await a.moveBy(const Offset(0, 40));
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(controller.isDragging, isTrue);
      final TestGesture b =
          await tester.startGesture(const Offset(260, 420), pointer: 2);
      for (int i = 0; i < 4; i++) {
        await b.moveBy(const Offset(25, 25));
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(controller.isDragging, isFalse);
      await a.up();
      await b.up();
      await tester.pumpAndSettle();
      expect(controller.isExpanded, isTrue);
      expect(
          tester.getRect(surfaceFinder), const Rect.fromLTWH(0, 0, 400, 800));
    });

    testWidgets('double tap zooms in around the tap and back out',
        (WidgetTester tester) async {
      await pumpViewer(tester);
      Future<void> doubleTap(Offset at) async {
        await tester.tapAt(at);
        await tester.pump(const Duration(milliseconds: 50));
        await tester.tapAt(at);
        await tester.pumpAndSettle();
      }

      await doubleTap(const Offset(100, 200));
      expect(scaleOf(transform), closeTo(2.5, 0.01));
      // The tapped point stays under the finger.
      final Offset mapped = MatrixUtils.transformPoint(
        transform.value,
        const Offset(100, 200),
      );
      expect(mapped.dx, closeTo(100, 0.5));
      expect(mapped.dy, closeTo(200, 0.5));

      await doubleTap(const Offset(100, 200));
      expect(scaleOf(transform), closeTo(1, 0.001));
    });

    testWidgets('zooms back out while the view collapses',
        (WidgetTester tester) async {
      final ExpandableAnimationController controller = await pumpViewer(tester);
      transform.value = Matrix4.diagonal3Values(3, 3, 1);
      await tester.pump();
      controller.collapse();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(scaleOf(transform), closeTo(1, 0.001));
      await tester.pumpAndSettle();
      expect(controller.isCollapsed, isTrue);
    });

    testWidgets('works on its own with reduced motion and controller swaps',
        (WidgetTester tester) async {
      usePhoneSurface(tester);
      final TransformationController other = TransformationController();
      addTearDown(other.dispose);

      Widget build(TransformationController? controller) => MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(disableAnimations: true),
              child: ExpandableAnimationZoomable(
                transformationController: controller,
                maxScale: 2,
                child: const SizedBox.expand(),
              ),
            ),
          );

      await tester.pumpWidget(build(null));
      await tester.tapAt(const Offset(200, 400));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(const Offset(200, 400));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Swapping to an external controller keeps working and is not disposed.
      await tester.pumpWidget(build(other));
      await tester.tapAt(const Offset(200, 400));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(const Offset(200, 400));
      await tester.pump();
      // Reduced motion: applied immediately; clamped to maxScale.
      expect(scaleOf(other), closeTo(2, 0.01));
      await tester.pumpWidget(build(null));
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 500));
      expect(() => other.value = Matrix4.identity(), returnsNormally);
    });

    test('rejects invalid scales', () {
      expect(
        () => ExpandableAnimationZoomable(minScale: 0, child: const SizedBox()),
        throwsAssertionError,
      );
      expect(
        () => ExpandableAnimationZoomable(
          minScale: 2,
          maxScale: 1,
          child: const SizedBox(),
        ),
        throwsAssertionError,
      );
      expect(
        () => ExpandableAnimationZoomable(
          doubleTapScale: 1,
          child: const SizedBox(),
        ),
        throwsAssertionError,
      );
    });
  });
}
