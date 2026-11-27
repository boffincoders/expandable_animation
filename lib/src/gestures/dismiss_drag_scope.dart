import 'package:flutter/widgets.dart';

/// Lets widgets inside an expanded view drive the drag-to-dismiss gesture
/// themselves.
///
/// Widgets that win the gesture arena for one-finger drags (such as
/// `InteractiveViewer`) prevent the surface's own drag detector from ever
/// seeing the drag. They can instead forward the drag here. Used by
/// `ExpandableAnimationZoomable`. Not part of the public API.
class ExpandableDismissDragScope extends InheritedWidget {
  /// Creates a scope that forwards drags to the enclosing expanded surface.
  const ExpandableDismissDragScope({
    super.key,
    required this.onStart,
    required this.onUpdate,
    required this.onEnd,
    required this.blockPointer,
    required this.unblockPointer,
    required super.child,
  });

  /// Starts a dismiss drag along an axis. Returns whether the drag was
  /// accepted; it is rejected while the view is still animating, when no
  /// dismiss direction lies on that axis, or when drag-to-dismiss is off.
  final bool Function(Axis axis) onStart;

  /// Moves the dismiss drag by a screen-space delta in logical pixels.
  final ValueChanged<Offset> onUpdate;

  /// Ends the dismiss drag with a screen-space velocity in logical pixels
  /// per second.
  final ValueChanged<Offset> onEnd;

  /// Keeps the surface's own dismiss drag from competing for [pointer],
  /// for example while content is zoomed in and should pan instead.
  /// Must be called from a pointer-down handler below the surface, which
  /// runs before the surface's recognizer sees the pointer.
  final ValueChanged<int> blockPointer;

  /// Releases a pointer passed to [blockPointer] once it lifts or cancels.
  final ValueChanged<int> unblockPointer;

  /// The closest enclosing scope, or `null` outside an expanded view.
  ///
  /// Does not create a dependency: the callbacks are only read when a gesture
  /// starts.
  static ExpandableDismissDragScope? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<ExpandableDismissDragScope>();

  @override
  bool updateShouldNotify(ExpandableDismissDragScope oldWidget) => false;
}
