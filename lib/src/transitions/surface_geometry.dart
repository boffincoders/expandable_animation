import 'dart:ui' show lerpDouble;

import 'package:flutter/widgets.dart';

import '../models/expandable_animation_gesture_config.dart';

/// The fraction of the expanded height that corresponds to a full drag.
///
/// Dragging this far moves the drag progress to `1.0`, at which point the
/// surface has reached `minScale` and the background has fully faded.
const double kFullDragExtentFraction = 0.5;

/// The corner radius the surface rounds towards while dragged, when the
/// collapsed widget has square corners.
const double kDragCornerRadius = 24.0;

/// The scale the surface starts from (and fades out to) when the source
/// widget is unavailable, for example because it was disposed while the view
/// was expanded.
const double kFallbackScale = 0.92;

/// The position, size and shape of the morphing surface at one frame.
@immutable
class SurfaceGeometry {
  /// Creates a surface geometry.
  const SurfaceGeometry({
    required this.rect,
    required this.borderRadius,
    this.opacity = 1.0,
  });

  /// The bounds of the surface in overlay coordinates.
  final Rect rect;

  /// The corner radius of the surface.
  final BorderRadius borderRadius;

  /// The opacity of the whole surface. Only below `1.0` in the fallback
  /// transition used when the source widget is unavailable.
  final double opacity;

  @override
  bool operator ==(Object other) =>
      other is SurfaceGeometry &&
      other.rect == rect &&
      other.borderRadius == borderRadius &&
      other.opacity == opacity;

  @override
  int get hashCode => Object.hash(rect, borderRadius, opacity);

  @override
  String toString() =>
      'SurfaceGeometry(rect: $rect, borderRadius: $borderRadius, '
      'opacity: $opacity)';
}

/// Computes the surface geometry for transition value [t].
///
/// [t] is the curved transition value: `0.0` at the source, `1.0` at the
/// destination. It may fall outside `[0, 1]` for overshooting springs.
///
/// When [source] is `null` the source widget is unavailable and the surface
/// fades and scales around the destination instead.
SurfaceGeometry lerpSurfaceGeometry({
  required Rect? source,
  required Rect destination,
  required BorderRadius sourceRadius,
  required BorderRadius destinationRadius,
  required double t,
}) {
  if (source == null) {
    final double clamped = t.clamp(0.0, 1.0);
    final double scale = lerpDouble(kFallbackScale, 1.0, clamped)!;
    return SurfaceGeometry(
      rect: Rect.fromCenter(
        center: destination.center,
        width: destination.width * scale,
        height: destination.height * scale,
      ),
      borderRadius: destinationRadius,
      opacity: clamped,
    );
  }
  return SurfaceGeometry(
    rect: Rect.lerp(source, destination, t)!,
    borderRadius:
        _nonNegative(BorderRadius.lerp(sourceRadius, destinationRadius, t)!),
  );
}

BorderRadius _nonNegative(BorderRadius radius) {
  Radius clamp(Radius r) => Radius.elliptical(
        r.x < 0 ? 0 : r.x,
        r.y < 0 ? 0 : r.y,
      );
  return BorderRadius.only(
    topLeft: clamp(radius.topLeft),
    topRight: clamp(radius.topRight),
    bottomLeft: clamp(radius.bottomLeft),
    bottomRight: clamp(radius.bottomRight),
  );
}

/// The drag progress, from `0.0` to `1.0`, for a downward drag of [offset]
/// logical pixels on a surface [extent] pixels tall.
double dragProgress({required double offset, required double extent}) {
  if (extent <= 0) {
    return 0;
  }
  return (offset / (extent * kFullDragExtentFraction)).clamp(0.0, 1.0);
}

/// Computes the geometry of an expanded surface being dragged downwards.
///
/// The surface scales around its top center towards
/// [ExpandableAnimationGestureConfig.minScale] and moves down by the drag
/// [offset] multiplied by [ExpandableAnimationGestureConfig.dragResistance].
/// Its corners round towards [collapsedRadius], or [kDragCornerRadius] when
/// the collapsed widget has square corners.
SurfaceGeometry dragSurfaceGeometry({
  required SurfaceGeometry expanded,
  required double offset,
  required BorderRadius collapsedRadius,
  required ExpandableAnimationGestureConfig config,
}) {
  if (offset <= 0) {
    return expanded;
  }
  final Rect rect = expanded.rect;
  final double progress = dragProgress(offset: offset, extent: rect.height);
  final double scale = lerpDouble(1.0, config.minScale, progress)!;
  final double width = rect.width * scale;
  final double height = rect.height * scale;
  final double top = rect.top + offset * config.dragResistance;
  final BorderRadius dragRadius = collapsedRadius == BorderRadius.zero
      ? BorderRadius.circular(kDragCornerRadius)
      : collapsedRadius;
  return SurfaceGeometry(
    rect: Rect.fromLTWH(rect.center.dx - width / 2, top, width, height),
    borderRadius:
        BorderRadius.lerp(expanded.borderRadius, dragRadius, progress)!,
    opacity: expanded.opacity,
  );
}

/// Decides whether releasing a dismiss drag should dismiss the view.
///
/// [offset] is the downward drag distance and [velocity] the vertical
/// release velocity in logical pixels per second (positive is downwards).
/// [extent] is the expanded surface height.
bool shouldDismissDrag({
  required double offset,
  required double velocity,
  required double extent,
  required ExpandableAnimationGestureConfig config,
}) {
  if (offset <= 0) {
    return false;
  }
  if (velocity <= -config.velocityThreshold) {
    return false;
  }
  if (velocity >= config.velocityThreshold) {
    return true;
  }
  return offset >= extent * config.dismissThreshold;
}

/// Removes the parts of [padding] that fall outside [rect] inside an
/// overlay of [overlaySize], so content laid out in [rect] only sees the
/// insets that actually overlap it.
EdgeInsets paddingWithinRect(EdgeInsets padding, Rect rect, Size overlaySize) {
  double overlap(double inset, double distanceFromEdge) {
    final double value = inset - distanceFromEdge;
    return value > 0 ? value : 0;
  }

  return EdgeInsets.fromLTRB(
    overlap(padding.left, rect.left),
    overlap(padding.top, rect.top),
    overlap(padding.right, overlaySize.width - rect.right),
    overlap(padding.bottom, overlaySize.height - rect.bottom),
  );
}
