import 'package:expandable_animation/expandable_animation.dart';
import 'package:expandable_animation/src/controllers/expandable_animation_controller.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeDelegate implements ExpandableAnimationDelegate {
  int expands = 0;
  int collapses = 0;

  @override
  Future<void> expand() async => expands++;

  @override
  Future<void> collapse() async => collapses++;
}

void main() {
  group('ExpandableAnimationController', () {
    test('starts collapsed and detached', () {
      final ExpandableAnimationController controller =
          ExpandableAnimationController();
      addTearDown(controller.dispose);
      expect(controller.phase, ExpandableAnimationPhase.collapsed);
      expect(controller.progress, 0);
      expect(controller.isCollapsed, isTrue);
      expect(controller.isExpanded, isFalse);
      expect(controller.isAnimating, isFalse);
      expect(controller.isDragging, isFalse);
      expect(controller.isAttached, isFalse);
      expect(controller.toString(), contains('collapsed'));
    });

    test('commands are no-ops while detached', () async {
      final ExpandableAnimationController controller =
          ExpandableAnimationController();
      addTearDown(controller.dispose);
      await controller.expand();
      await controller.collapse();
      await controller.toggle();
      expect(controller.phase, ExpandableAnimationPhase.collapsed);
    });

    test('forwards commands to the delegate and toggles by phase', () async {
      final ExpandableAnimationController controller =
          ExpandableAnimationController();
      addTearDown(controller.dispose);
      final _FakeDelegate delegate = _FakeDelegate();
      attachExpandableController(controller, delegate);
      expect(controller.isAttached, isTrue);

      await controller.toggle();
      expect(delegate.expands, 1);

      updateExpandableController(
        controller,
        phase: ExpandableAnimationPhase.expanding,
      );
      await controller.toggle();
      expect(delegate.collapses, 1);

      updateExpandableController(
        controller,
        phase: ExpandableAnimationPhase.expanded,
      );
      await controller.toggle();
      expect(delegate.collapses, 2);

      updateExpandableController(
        controller,
        phase: ExpandableAnimationPhase.collapsing,
      );
      await controller.toggle();
      expect(delegate.expands, 2);

      detachExpandableController(controller, delegate);
      expect(controller.isAttached, isFalse);
    });

    test('notifies only on change', () {
      final ExpandableAnimationController controller =
          ExpandableAnimationController();
      addTearDown(controller.dispose);
      int notifications = 0;
      controller.addListener(() => notifications++);

      updateExpandableController(controller, progress: 0.5);
      updateExpandableController(controller, progress: 0.5);
      updateExpandableController(controller, isDragging: true);
      updateExpandableController(controller, isDragging: true);
      updateExpandableController(
        controller,
        phase: ExpandableAnimationPhase.expanded,
      );
      expect(notifications, 3);
      expect(controller.progress, 0.5);
      expect(controller.isDragging, isTrue);
      expect(controller.isExpanded, isTrue);
    });

    test('detaching a different delegate keeps the current one', () {
      final ExpandableAnimationController controller =
          ExpandableAnimationController();
      addTearDown(controller.dispose);
      final _FakeDelegate a = _FakeDelegate();
      final _FakeDelegate b = _FakeDelegate();
      attachExpandableController(controller, a);
      detachExpandableController(controller, b);
      expect(controller.isAttached, isTrue);
    });

    test('attaching a second delegate asserts', () {
      final ExpandableAnimationController controller =
          ExpandableAnimationController();
      addTearDown(controller.dispose);
      attachExpandableController(controller, _FakeDelegate());
      expect(
        () => attachExpandableController(controller, _FakeDelegate()),
        throwsAssertionError,
      );
    });

    test('ignores updates and rejects commands after dispose', () {
      final ExpandableAnimationController controller =
          ExpandableAnimationController()..dispose();
      expect(isExpandableControllerDisposed(controller), isTrue);
      updateExpandableController(controller, progress: 1);
      expect(controller.progress, 0);
      expect(controller.expand, throwsFlutterError);
      expect(controller.collapse, throwsFlutterError);
    });
  });
}
