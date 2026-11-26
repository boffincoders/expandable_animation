import 'package:expandable_animation/expandable_animation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const ExpandedBoundsContext phone = ExpandedBoundsContext(
    overlaySize: Size(400, 800),
    padding: EdgeInsets.only(top: 40, bottom: 20),
    sourceRect: Rect.fromLTWH(20, 300, 360, 200),
  );

  group('ExpandedBoundsContext', () {
    test('safeArea removes padding', () {
      expect(phone.safeArea, const Rect.fromLTRB(0, 40, 400, 780));
    });

    test('equality and hashCode', () {
      const ExpandedBoundsContext copy = ExpandedBoundsContext(
        overlaySize: Size(400, 800),
        padding: EdgeInsets.only(top: 40, bottom: 20),
        sourceRect: Rect.fromLTWH(20, 300, 360, 200),
      );
      expect(copy, phone);
      expect(copy.hashCode, phone.hashCode);
      expect(phone.toString(), contains('overlaySize'));
    });
  });

  group('ExpandableAnimationMode', () {
    test('fullscreen covers the overlay', () {
      expect(
        const ExpandableAnimationMode.fullscreen().resolve(phone),
        const Rect.fromLTWH(0, 0, 400, 800),
      );
    });

    test('fullscreen with safe area stops at insets', () {
      expect(
        const ExpandableAnimationMode.fullscreen(useSafeArea: true)
            .resolve(phone),
        const Rect.fromLTRB(0, 40, 400, 780),
      );
    });

    test('dialog is centered, inset and capped', () {
      final Rect rect = const ExpandableAnimationMode.dialog(
        margin: EdgeInsets.all(20),
        maxSize: Size(300, 2000),
      ).resolve(phone);
      expect(rect.width, 300);
      expect(rect.height, 740 - 40);
      expect(rect.center, phone.safeArea.center);
    });

    test('dialog never has a negative size', () {
      final Rect rect = const ExpandableAnimationMode.dialog(
        margin: EdgeInsets.all(500),
      ).resolve(phone);
      expect(rect.width, 0);
      expect(rect.height, 0);
    });

    test('sheet is bottom anchored and respects the top inset', () {
      final Rect half =
          const ExpandableAnimationMode.sheet(heightFactor: 0.5).resolve(phone);
      expect(half, const Rect.fromLTRB(0, 400, 400, 800));

      final Rect tall =
          const ExpandableAnimationMode.sheet(heightFactor: 1).resolve(phone);
      expect(tall.top, 40);
    });

    test('sheet is centered and capped on wide screens', () {
      const ExpandedBoundsContext wide = ExpandedBoundsContext(
        overlaySize: Size(1200, 800),
        padding: EdgeInsets.zero,
        sourceRect: Rect.zero,
      );
      final Rect rect =
          const ExpandableAnimationMode.sheet(maxWidth: 600).resolve(wide);
      expect(rect.width, 600);
      expect(rect.left, 300);
    });

    test('dialog and sheet stay above the keyboard', () {
      const ExpandedBoundsContext withKeyboard = ExpandedBoundsContext(
        overlaySize: Size(400, 800),
        padding: EdgeInsets.only(top: 40, bottom: 20),
        viewInsets: EdgeInsets.only(bottom: 300),
        sourceRect: Rect.zero,
      );
      expect(withKeyboard.visibleArea, const Rect.fromLTRB(0, 40, 400, 500));
      final Rect sheet = const ExpandableAnimationMode.sheet(heightFactor: 0.5)
          .resolve(withKeyboard);
      expect(sheet.bottom, 500);
      expect(sheet.top, 100);
      final Rect dialog = const ExpandableAnimationMode.dialog(
        margin: EdgeInsets.zero,
      ).resolve(withKeyboard);
      expect(dialog.bottom, lessThanOrEqualTo(500));

      const ExpandedBoundsContext tiny = ExpandedBoundsContext(
        overlaySize: Size(400, 800),
        padding: EdgeInsets.only(top: 40),
        viewInsets: EdgeInsets.only(bottom: 790),
        sourceRect: Rect.zero,
      );
      expect(tiny.visibleArea.height, 0);
      expect(
        const ExpandableAnimationMode.sheet().resolve(tiny).height,
        0,
      );
    });

    test('custom delegates to the resolver', () {
      Rect resolver(ExpandedBoundsContext context) =>
          context.sourceRect.inflate(10);
      expect(
        ExpandableAnimationMode.custom(resolver).resolve(phone),
        const Rect.fromLTWH(10, 290, 380, 220),
      );
      expect(
        ExpandableAnimationMode.custom(resolver),
        ExpandableAnimationMode.custom(resolver),
      );
    });

    test('equality, hashCode and toString', () {
      expect(
        const ExpandableAnimationMode.fullscreen(),
        const ExpandableAnimationMode.fullscreen(),
      );
      expect(
        const ExpandableAnimationMode.fullscreen().hashCode,
        const ExpandableAnimationMode.fullscreen().hashCode,
      );
      expect(
        const ExpandableAnimationMode.fullscreen(),
        isNot(const ExpandableAnimationMode.fullscreen(useSafeArea: true)),
      );
      expect(
        const ExpandableAnimationMode.dialog(),
        const ExpandableAnimationMode.dialog(),
      );
      expect(
        const ExpandableAnimationMode.dialog().hashCode,
        const ExpandableAnimationMode.dialog().hashCode,
      );
      expect(
        const ExpandableAnimationMode.sheet(),
        const ExpandableAnimationMode.sheet(),
      );
      expect(
        const ExpandableAnimationMode.sheet().hashCode,
        const ExpandableAnimationMode.sheet().hashCode,
      );
      for (final ExpandableAnimationMode mode in <ExpandableAnimationMode>[
        const ExpandableAnimationMode.fullscreen(),
        const ExpandableAnimationMode.dialog(),
        const ExpandableAnimationMode.sheet(),
        ExpandableAnimationMode.custom((_) => Rect.zero),
      ]) {
        expect(mode.toString(), startsWith('ExpandableAnimationMode.'));
        expect(mode.hashCode, isA<int>());
      }
    });
  });

  group('ExpandableAnimationGestureConfig', () {
    test('has sensible defaults', () {
      const ExpandableAnimationGestureConfig config =
          ExpandableAnimationGestureConfig();
      expect(config.dismissThreshold, 0.2);
      expect(config.velocityThreshold, 700);
      expect(config.minScale, 0.85);
      expect(config.enableHapticFeedback, isTrue);
      expect(config.dismissFromScrollableContent, isTrue);
      expect(config.clampScrollPhysics, isTrue);
    });

    test('copyWith replaces only given fields', () {
      const ExpandableAnimationGestureConfig config =
          ExpandableAnimationGestureConfig();
      final ExpandableAnimationGestureConfig copy = config.copyWith(
        dismissThreshold: 0.4,
        enableHapticFeedback: false,
      );
      expect(copy.dismissThreshold, 0.4);
      expect(copy.enableHapticFeedback, isFalse);
      expect(copy.velocityThreshold, config.velocityThreshold);
      expect(config.copyWith(), config);
      expect(config.copyWith().hashCode, config.hashCode);
      expect(copy, isNot(config));
      expect(config.toString(), contains('dismissThreshold: 0.2'));
    });

    test('rejects invalid values', () {
      expect(
        () => ExpandableAnimationGestureConfig(dismissThreshold: 0),
        throwsAssertionError,
      );
      expect(
        () => ExpandableAnimationGestureConfig(velocityThreshold: -1),
        throwsAssertionError,
      );
      expect(
        () => ExpandableAnimationGestureConfig(minScale: 1.5),
        throwsAssertionError,
      );
      expect(
        () => ExpandableAnimationGestureConfig(dragResistance: 0),
        throwsAssertionError,
      );
    });
  });

  group('ExpandableAnimationPhase', () {
    test('isOpen and isAnimating', () {
      expect(ExpandableAnimationPhase.collapsed.isOpen, isFalse);
      expect(ExpandableAnimationPhase.expanding.isOpen, isTrue);
      expect(ExpandableAnimationPhase.expanded.isOpen, isTrue);
      expect(ExpandableAnimationPhase.collapsing.isOpen, isTrue);
      expect(ExpandableAnimationPhase.expanding.isAnimating, isTrue);
      expect(ExpandableAnimationPhase.collapsing.isAnimating, isTrue);
      expect(ExpandableAnimationPhase.expanded.isAnimating, isFalse);
      expect(ExpandableAnimationPhase.collapsed.isAnimating, isFalse);
    });
  });
}
