import 'package:flutter/widgets.dart';

/// A direction in which the user can drag an expanded view to dismiss it.
///
/// Set the allowed directions with
/// `ExpandableAnimationGestureConfig.dismissDirections`. The default is
/// [down] only.
///
/// ```dart
/// const ExpandableAnimationGestureConfig(
///   dismissDirections: {
///     ExpandableAnimationDismissDirection.down,
///     ExpandableAnimationDismissDirection.left,
///     ExpandableAnimationDismissDirection.right,
///   },
/// )
/// ```
enum ExpandableAnimationDismissDirection {
  /// Drag downwards. Pairs with vertically scrolling content: dismissal
  /// starts when the content is pulled down at its top.
  down,

  /// Drag upwards. With vertically scrolling content, dismissal starts when
  /// the content is pulled up at its bottom.
  up,

  /// Drag towards the left edge. With horizontally scrolling content, such as
  /// a `PageView`, dismissal starts when the content is pulled past its end.
  left,

  /// Drag towards the right edge. With horizontally scrolling content,
  /// dismissal starts when the content is pulled past its start.
  right;

  /// The axis the drag moves along.
  Axis get axis => switch (this) {
        down || up => Axis.vertical,
        left || right => Axis.horizontal,
      };

  /// A unit vector pointing in this direction, in screen coordinates
  /// (positive y is down).
  Offset get unit => switch (this) {
        down => const Offset(0, 1),
        up => const Offset(0, -1),
        left => const Offset(-1, 0),
        right => const Offset(1, 0),
      };

  /// The direction along [axis] that a movement of [delta] (positive is down
  /// or right) points to.
  static ExpandableAnimationDismissDirection fromDelta(
      Axis axis, double delta) {
    return switch (axis) {
      Axis.vertical => delta >= 0 ? down : up,
      Axis.horizontal => delta >= 0 ? right : left,
    };
  }
}
