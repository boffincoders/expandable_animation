import 'package:flutter/widgets.dart';

import '../controllers/expandable_animation_controller.dart';

/// Exposes the controller of the nearest `ExpandableAnimation` to both its
/// source subtree and its expanded subtree.
///
/// Read it with `ExpandableAnimation.of(context)`. Not part of the public
/// API.
class ExpandableAnimationScope extends InheritedWidget {
  /// Creates a scope that exposes [controller].
  const ExpandableAnimationScope({
    super.key,
    required this.controller,
    required super.child,
  });

  /// The controller of the enclosing `ExpandableAnimation`.
  final ExpandableAnimationController controller;

  /// Returns the controller of the closest enclosing scope, if any.
  static ExpandableAnimationController? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<ExpandableAnimationScope>()
        ?.controller;
  }

  @override
  bool updateShouldNotify(ExpandableAnimationScope oldWidget) =>
      controller != oldWidget.controller;
}
