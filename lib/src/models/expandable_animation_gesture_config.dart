import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'expandable_animation_dismiss_direction.dart';

/// Configures interactive drag-to-dismiss on an expanded view.
///
/// Drag-to-dismiss is turned on with `ExpandableAnimation.enableDragToDismiss`;
/// this object tunes how it feels.
///
/// The user drags the expanded view in one of the [dismissDirections]
/// (downwards by default). The view follows the finger, shrinks towards
/// [minScale] and the background fades. When the finger lifts, the view is
/// dismissed if either:
///
/// * the drag distance is at least [dismissThreshold] times the expanded
///   size along the drag axis, or
/// * the fling velocity in the drag direction is at least
///   [velocityThreshold].
///
/// Otherwise the view springs back to its expanded state. A fast upward fling
/// always cancels the dismissal.
///
/// ```dart
/// ExpandableAnimation(
///   gestureConfig: const ExpandableAnimationGestureConfig(
///     dismissThreshold: 0.15,
///     velocityThreshold: 600,
///     enableHapticFeedback: false,
///   ),
///   expandedBuilder: (context) => const PlayerScreen(),
///   child: const MiniPlayer(),
/// )
/// ```
@immutable
class ExpandableAnimationGestureConfig {
  /// Creates a drag-to-dismiss configuration.
  const ExpandableAnimationGestureConfig({
    this.dismissThreshold = 0.2,
    this.velocityThreshold = 700.0,
    this.minScale = 0.85,
    this.dragResistance = 0.6,
    this.enableHapticFeedback = true,
    this.dismissFromScrollableContent = true,
    this.clampScrollPhysics = true,
    this.matchReleaseVelocity = true,
    this.dismissDirections = const <ExpandableAnimationDismissDirection>{
      ExpandableAnimationDismissDirection.down,
    },
  })  : assert(
          dismissThreshold > 0 && dismissThreshold <= 1,
          'dismissThreshold must be in the range (0, 1].',
        ),
        assert(velocityThreshold > 0, 'velocityThreshold must be positive.'),
        assert(
          minScale > 0 && minScale <= 1,
          'minScale must be in the range (0, 1].',
        ),
        assert(
          dragResistance > 0 && dragResistance <= 1,
          'dragResistance must be in the range (0, 1].',
        );

  /// The fraction of the expanded view's size along the drag axis (its
  /// height for vertical drags, its width for horizontal drags) the user
  /// must drag before releasing dismisses it. Defaults to `0.2`.
  final double dismissThreshold;

  /// The fling velocity in the drag direction, in logical pixels per second,
  /// that dismisses the view regardless of drag distance. Defaults to `700`.
  final double velocityThreshold;

  /// The scale the expanded view shrinks towards as the drag progresses.
  /// `1.0` disables scaling. Defaults to `0.85`.
  final double minScale;

  /// How closely the expanded view follows the finger, between 0 and 1.
  ///
  /// `1.0` moves the view one pixel per pixel dragged; smaller values make
  /// the drag feel heavier. Defaults to `0.6`.
  final double dragResistance;

  /// Whether to play a light haptic tick when the drag crosses the dismiss
  /// threshold in either direction. Has no effect on platforms without
  /// haptics. Defaults to `true`.
  final bool enableHapticFeedback;

  /// Whether pulling down on vertically scrollable content that is already
  /// scrolled to its top starts a dismissal.
  ///
  /// When `false`, only drags on non-scrolling parts of the expanded view
  /// dismiss it. Defaults to `true`.
  final bool dismissFromScrollableContent;

  /// Whether scrollables inside the expanded view that do not set explicit
  /// physics use [ClampingScrollPhysics].
  ///
  /// Clamping prevents iOS-style overscroll bounce at the top edge from
  /// competing with the dismiss gesture, so the pull-down feels like one
  /// continuous motion. Scrollables with explicit physics keep them.
  /// Defaults to `true`.
  final bool clampScrollPhysics;

  /// Whether a drag that dismisses the view hands its speed to the collapse.
  ///
  /// When `true`, the collapse starts moving at the speed the finger left
  /// the screen and eases into the source with a critically damped spring
  /// (the configured `physics`, or one that settles in about the reverse
  /// duration). A quick flick therefore collapses faster than a slow release.
  /// When `false`, the collapse always uses the regular reverse animation.
  /// Defaults to `true`.
  final bool matchReleaseVelocity;

  /// The directions in which a drag dismisses the view. Defaults to
  /// [ExpandableAnimationDismissDirection.down]. An empty set disables
  /// dragging, like `ExpandableAnimation.enableDragToDismiss: false`.
  ///
  /// Each drag locks to the axis it starts on. When both directions of an
  /// axis are allowed (for example up and down), the drag can switch
  /// between them by passing back through the starting point.
  final Set<ExpandableAnimationDismissDirection> dismissDirections;

  /// Whether any direction along [axis] is allowed.
  bool allowsAxis(Axis axis) => dismissDirections.any(
        (ExpandableAnimationDismissDirection d) => d.axis == axis,
      );

  /// Creates a copy of this configuration with the given fields replaced.
  ExpandableAnimationGestureConfig copyWith({
    double? dismissThreshold,
    double? velocityThreshold,
    double? minScale,
    double? dragResistance,
    bool? enableHapticFeedback,
    bool? dismissFromScrollableContent,
    bool? clampScrollPhysics,
    bool? matchReleaseVelocity,
    Set<ExpandableAnimationDismissDirection>? dismissDirections,
  }) {
    return ExpandableAnimationGestureConfig(
      dismissThreshold: dismissThreshold ?? this.dismissThreshold,
      velocityThreshold: velocityThreshold ?? this.velocityThreshold,
      minScale: minScale ?? this.minScale,
      dragResistance: dragResistance ?? this.dragResistance,
      enableHapticFeedback: enableHapticFeedback ?? this.enableHapticFeedback,
      dismissFromScrollableContent:
          dismissFromScrollableContent ?? this.dismissFromScrollableContent,
      clampScrollPhysics: clampScrollPhysics ?? this.clampScrollPhysics,
      matchReleaseVelocity: matchReleaseVelocity ?? this.matchReleaseVelocity,
      dismissDirections: dismissDirections ?? this.dismissDirections,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ExpandableAnimationGestureConfig &&
      other.dismissThreshold == dismissThreshold &&
      other.velocityThreshold == velocityThreshold &&
      other.minScale == minScale &&
      other.dragResistance == dragResistance &&
      other.enableHapticFeedback == enableHapticFeedback &&
      other.dismissFromScrollableContent == dismissFromScrollableContent &&
      other.clampScrollPhysics == clampScrollPhysics &&
      other.matchReleaseVelocity == matchReleaseVelocity &&
      setEquals(other.dismissDirections, dismissDirections);

  @override
  int get hashCode => Object.hash(
        dismissThreshold,
        velocityThreshold,
        minScale,
        dragResistance,
        enableHapticFeedback,
        dismissFromScrollableContent,
        clampScrollPhysics,
        matchReleaseVelocity,
        Object.hashAllUnordered(dismissDirections),
      );

  @override
  String toString() => 'ExpandableAnimationGestureConfig('
      'dismissThreshold: $dismissThreshold, '
      'velocityThreshold: $velocityThreshold, minScale: $minScale, '
      'dragResistance: $dragResistance, '
      'enableHapticFeedback: $enableHapticFeedback, '
      'dismissFromScrollableContent: $dismissFromScrollableContent, '
      'clampScrollPhysics: $clampScrollPhysics, '
      'matchReleaseVelocity: $matchReleaseVelocity, '
      'dismissDirections: ${dismissDirections.map((ExpandableAnimationDismissDirection d) => d.name).join(', ')})';
}
