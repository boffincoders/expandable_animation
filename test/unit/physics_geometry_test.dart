import 'package:expandable_animation/expandable_animation.dart';
import 'package:expandable_animation/src/animation/expandable_animation_physics.dart'
    show springSettleDuration;
import 'package:expandable_animation/src/transitions/surface_geometry.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ExpandableAnimationPhysics', () {
    test('presets are valid and distinct', () {
      expect(ExpandableAnimationPhysics.smooth.dampingRatio, 1.0);
      expect(ExpandableAnimationPhysics.bouncy.dampingRatio, lessThan(1));
      expect(
        ExpandableAnimationPhysics.snappy.settleDuration,
        lessThan(ExpandableAnimationPhysics.smooth.settleDuration),
      );
    });

    test('settle duration is positive and capped', () {
      expect(
        ExpandableAnimationPhysics.smooth.settleDuration,
        greaterThan(Duration.zero),
      );
      const ExpandableAnimationPhysics soft =
          ExpandableAnimationPhysics.spring(stiffness: 0.5);
      expect(
        soft.settleDuration,
        ExpandableAnimationPhysics.maxSettleDuration,
      );
      expect(
        springSettleDuration(ExpandableAnimationPhysics.snappy.description),
        ExpandableAnimationPhysics.snappy.settleDuration,
      );
    });

    test('reverse spring is never underdamped', () {
      expect(
        ExpandableAnimationPhysics.bouncy.reverseDescription.damping,
        greaterThan(ExpandableAnimationPhysics.bouncy.description.damping),
      );
      expect(
        ExpandableAnimationPhysics.smooth.reverseDescription.damping,
        closeTo(ExpandableAnimationPhysics.smooth.description.damping, 1e-9),
      );
    });

    test('curve starts at 0, ends at 1 and overshoots when underdamped', () {
      final Curve curve = ExpandableAnimationPhysics.bouncy.curve;
      expect(curve.transform(0), 0);
      expect(curve.transform(1), 1);
      double peak = 0;
      for (int i = 1; i < 100; i++) {
        final double value = curve.transform(i / 100);
        if (value > peak) {
          peak = value;
        }
      }
      expect(peak, greaterThan(1));
    });

    test('critically damped curve is monotonic and stays within 0..1', () {
      final Curve curve = ExpandableAnimationPhysics.smooth.curve;
      double previous = 0;
      for (int i = 1; i <= 100; i++) {
        final double value = curve.transform(i / 100);
        expect(value, greaterThanOrEqualTo(previous - 1e-9));
        expect(value, lessThanOrEqualTo(1 + 1e-6));
        previous = value;
      }
    });

    test('reverse curve maps 1 to 1 and 0 to 0', () {
      final Curve reverse = ExpandableAnimationPhysics.bouncy.reverseCurve;
      expect(reverse.transform(0), 0);
      expect(reverse.transform(1), 1);
    });

    test('copyWith, equality and toString', () {
      const ExpandableAnimationPhysics physics =
          ExpandableAnimationPhysics.spring();
      expect(physics.copyWith(), physics);
      expect(physics.copyWith().hashCode, physics.hashCode);
      expect(physics.copyWith(stiffness: 10).stiffness, 10);
      expect(physics.copyWith(mass: 2), isNot(physics));
      expect(physics.toString(), contains('stiffness: 180.0'));
      expect(SpringCurve(physics.description).toString(), contains('Spring'));
    });

    test('rejects invalid values', () {
      expect(
        () => ExpandableAnimationPhysics.spring(mass: 0),
        throwsAssertionError,
      );
      expect(
        () => ExpandableAnimationPhysics.spring(stiffness: -1),
        throwsAssertionError,
      );
      expect(
        () => ExpandableAnimationPhysics.spring(dampingRatio: 0),
        throwsAssertionError,
      );
    });
  });

  group('lerpSurfaceGeometry', () {
    const Rect source = Rect.fromLTWH(10, 100, 100, 50);
    const Rect destination = Rect.fromLTWH(0, 0, 400, 800);

    test('interpolates rect and radius', () {
      final SurfaceGeometry start = lerpSurfaceGeometry(
        source: source,
        destination: destination,
        sourceRadius: BorderRadius.circular(20),
        destinationRadius: BorderRadius.zero,
        t: 0,
      );
      expect(start.rect, source);
      expect(start.borderRadius, BorderRadius.circular(20));
      expect(start.opacity, 1);

      final SurfaceGeometry end = lerpSurfaceGeometry(
        source: source,
        destination: destination,
        sourceRadius: BorderRadius.circular(20),
        destinationRadius: BorderRadius.zero,
        t: 1,
      );
      expect(end.rect, destination);
      expect(end.borderRadius, BorderRadius.zero);

      final SurfaceGeometry mid = lerpSurfaceGeometry(
        source: source,
        destination: destination,
        sourceRadius: BorderRadius.circular(20),
        destinationRadius: BorderRadius.zero,
        t: 0.5,
      );
      expect(mid.rect, Rect.lerp(source, destination, 0.5));
      expect(mid.borderRadius, BorderRadius.circular(10));
    });

    test('overshoot extrapolates the rect but never inverts corners', () {
      final SurfaceGeometry over = lerpSurfaceGeometry(
        source: source,
        destination: destination,
        sourceRadius: BorderRadius.circular(20),
        destinationRadius: BorderRadius.zero,
        t: 1.1,
      );
      expect(over.rect.width, greaterThan(destination.width));
      expect(over.borderRadius.topLeft.x, 0);
    });

    test('falls back to fade and scale without a source', () {
      final SurfaceGeometry start = lerpSurfaceGeometry(
        source: null,
        destination: destination,
        sourceRadius: BorderRadius.zero,
        destinationRadius: BorderRadius.circular(8),
        t: 0,
      );
      expect(start.opacity, 0);
      expect(start.rect.center, destination.center);
      expect(start.rect.width, destination.width * kFallbackScale);

      final SurfaceGeometry end = lerpSurfaceGeometry(
        source: null,
        destination: destination,
        sourceRadius: BorderRadius.zero,
        destinationRadius: BorderRadius.circular(8),
        t: 1.2,
      );
      expect(end.opacity, 1);
      expect(end.rect, destination);
    });

    test('equality and toString', () {
      const SurfaceGeometry a = SurfaceGeometry(
        rect: source,
        borderRadius: BorderRadius.zero,
      );
      const SurfaceGeometry b = SurfaceGeometry(
        rect: source,
        borderRadius: BorderRadius.zero,
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a.toString(), contains('SurfaceGeometry'));
    });
  });

  group('drag geometry', () {
    const ExpandableAnimationGestureConfig config =
        ExpandableAnimationGestureConfig();
    const SurfaceGeometry expanded = SurfaceGeometry(
      rect: Rect.fromLTWH(0, 0, 400, 800),
      borderRadius: BorderRadius.zero,
    );

    test('dragProgress is clamped and relative to the extent', () {
      expect(dragProgress(offset: 0, extent: 800), 0);
      expect(dragProgress(offset: 200, extent: 800), 0.5);
      expect(dragProgress(offset: 2000, extent: 800), 1);
      expect(dragProgress(offset: 10, extent: 0), 0);
    });

    test('no offset leaves the geometry unchanged', () {
      expect(
        dragSurfaceGeometry(
          expanded: expanded,
          offset: 0,
          collapsedRadius: BorderRadius.zero,
          config: config,
        ),
        expanded,
      );
    });

    test('scales, moves and rounds while dragging', () {
      final SurfaceGeometry full = dragSurfaceGeometry(
        expanded: expanded,
        offset: 400,
        collapsedRadius: BorderRadius.zero,
        config: config,
      );
      expect(full.rect.width, 400 * config.minScale);
      expect(full.rect.top, 400 * config.dragResistance);
      expect(full.rect.center.dx, 200);
      expect(full.borderRadius, BorderRadius.circular(kDragCornerRadius));

      final SurfaceGeometry withRadius = dragSurfaceGeometry(
        expanded: expanded,
        offset: 400,
        collapsedRadius: BorderRadius.circular(12),
        config: config,
      );
      expect(withRadius.borderRadius, BorderRadius.circular(12));
    });

    test('shouldDismissDrag uses distance and velocity', () {
      bool decide(double offset, double velocity) => shouldDismissDrag(
            offset: offset,
            velocity: velocity,
            extent: 800,
            config: config,
          );
      expect(decide(0, 5000), isFalse, reason: 'no drag');
      expect(decide(100, 0), isFalse, reason: 'below threshold');
      expect(decide(160, 0), isTrue, reason: 'at threshold');
      expect(decide(20, 900), isTrue, reason: 'fast fling down');
      expect(decide(300, -900), isFalse, reason: 'fast fling back up');
    });
  });

  test('paddingWithinRect keeps only overlapping insets', () {
    const EdgeInsets padding = EdgeInsets.fromLTRB(10, 40, 10, 30);
    const Size overlay = Size(400, 800);
    expect(
      paddingWithinRect(padding, Offset.zero & overlay, overlay),
      padding,
    );
    expect(
      paddingWithinRect(
        padding,
        const Rect.fromLTRB(20, 100, 380, 700),
        overlay,
      ),
      EdgeInsets.zero,
    );
    expect(
      paddingWithinRect(padding, const Rect.fromLTRB(0, 20, 400, 800), overlay),
      const EdgeInsets.fromLTRB(10, 20, 10, 30),
    );
  });
}
