import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Signature for a function that computes custom expanded bounds.
///
/// Used by [ExpandableAnimationMode.custom].
typedef ExpandedBoundsResolver = Rect Function(ExpandedBoundsContext context);

/// Layout information passed to an [ExpandableAnimationMode] when it resolves
/// the bounds of the expanded view.
@immutable
class ExpandedBoundsContext {
  /// Creates layout information for resolving expanded bounds.
  const ExpandedBoundsContext({
    required this.overlaySize,
    required this.padding,
    required this.sourceRect,
    this.viewInsets = EdgeInsets.zero,
  });

  /// The size of the navigator overlay that hosts the expanded view.
  ///
  /// This is usually the size of the whole screen or window.
  final Size overlaySize;

  /// The safe-area padding of the overlay, such as notches, status bars and
  /// system gesture areas. Taken from [MediaQueryData.padding].
  final EdgeInsets padding;

  /// The bounds of the source widget, in the overlay's coordinate space, at
  /// the moment the expansion started.
  final Rect sourceRect;

  /// The parts of the overlay obscured by system UI such as the on-screen
  /// keyboard. Taken from [MediaQueryData.viewInsets].
  final EdgeInsets viewInsets;

  /// The overlay bounds with [padding] removed.
  Rect get safeArea => padding.deflateRect(Offset.zero & overlaySize);

  /// The overlay bounds with both [padding] and [viewInsets] removed: the
  /// area that is neither under system bars nor under the keyboard.
  Rect get visibleArea {
    final Rect safe = safeArea;
    return Rect.fromLTRB(
      safe.left,
      safe.top,
      safe.right,
      math.max(safe.top,
          math.min(safe.bottom, overlaySize.height - viewInsets.bottom)),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ExpandedBoundsContext &&
      other.overlaySize == overlaySize &&
      other.padding == padding &&
      other.sourceRect == sourceRect &&
      other.viewInsets == viewInsets;

  @override
  int get hashCode => Object.hash(overlaySize, padding, sourceRect, viewInsets);

  @override
  String toString() => 'ExpandedBoundsContext(overlaySize: $overlaySize, '
      'padding: $padding, sourceRect: $sourceRect, viewInsets: $viewInsets)';
}

/// Describes where an `ExpandableAnimation` expands to.
///
/// Use one of the constructors:
///
/// * [ExpandableAnimationMode.fullscreen] — the expanded view fills the
///   screen. This is the default and suits card-to-detail and image viewer
///   transitions.
/// * [ExpandableAnimationMode.dialog] — the expanded view is a centered panel
///   with a margin and a maximum size, over a dimmed background.
/// * [ExpandableAnimationMode.sheet] — the expanded view is anchored to the
///   bottom edge and covers part of the screen (partial expansion).
/// * [ExpandableAnimationMode.custom] — you compute the bounds yourself.
///
/// ```dart
/// ExpandableAnimation(
///   mode: const ExpandableAnimationMode.dialog(maxSize: Size(480, 640)),
///   expandedBuilder: (context) => const DetailsPanel(),
///   child: const SummaryTile(),
/// )
/// ```
@immutable
abstract class ExpandableAnimationMode {
  /// Abstract const constructor for subclasses.
  const ExpandableAnimationMode();

  /// Expands to fill the whole overlay.
  ///
  /// When [useSafeArea] is `true` the expanded view stops at the safe-area
  /// insets instead of drawing behind status bars and notches. Leave it
  /// `false` (the default) when the expanded content handles insets itself,
  /// for example with a `Scaffold` or `SafeArea`.
  const factory ExpandableAnimationMode.fullscreen({bool useSafeArea}) =
      _FullscreenMode;

  /// Expands to a centered panel.
  ///
  /// The panel is inset from the safe area by [margin] and never grows beyond
  /// [maxSize]. On a phone this is close to fullscreen; on a tablet or desktop
  /// window it becomes a floating panel. It shrinks to stay above the
  /// on-screen keyboard.
  const factory ExpandableAnimationMode.dialog({
    EdgeInsets margin,
    Size maxSize,
  }) = _DialogMode;

  /// Expands to a panel anchored to the bottom edge.
  ///
  /// [heightFactor] is the fraction of the overlay height the panel covers,
  /// between 0 and 1. The panel never extends above the top safe-area inset,
  /// and it rides on top of the on-screen keyboard when one is shown.
  /// [maxWidth] limits the width on wide screens; the panel is centered
  /// horizontally.
  const factory ExpandableAnimationMode.sheet({
    double heightFactor,
    double maxWidth,
  }) = _SheetMode;

  /// Expands to bounds computed by [resolver].
  ///
  /// The resolver is called on every layout of the expanded view, so it can
  /// react to window resizing and orientation changes. Return a rectangle in
  /// the overlay's coordinate space.
  ///
  /// ```dart
  /// ExpandableAnimationMode.custom(
  ///   (bounds) => Alignment.topRight.inscribe(
  ///     const Size(360, 480),
  ///     bounds.safeArea.deflate(16),
  ///   ),
  /// )
  /// ```
  const factory ExpandableAnimationMode.custom(
      ExpandedBoundsResolver resolver) = _CustomMode;

  /// Computes the expanded bounds for the given layout [context].
  Rect resolve(ExpandedBoundsContext context);
}

class _FullscreenMode extends ExpandableAnimationMode {
  const _FullscreenMode({this.useSafeArea = false});

  final bool useSafeArea;

  @override
  Rect resolve(ExpandedBoundsContext context) {
    return useSafeArea ? context.safeArea : Offset.zero & context.overlaySize;
  }

  @override
  bool operator ==(Object other) =>
      other is _FullscreenMode && other.useSafeArea == useSafeArea;

  @override
  int get hashCode => Object.hash(_FullscreenMode, useSafeArea);

  @override
  String toString() =>
      'ExpandableAnimationMode.fullscreen(useSafeArea: $useSafeArea)';
}

class _DialogMode extends ExpandableAnimationMode {
  const _DialogMode({
    this.margin = const EdgeInsets.all(24),
    this.maxSize = const Size(560, 720),
  });

  final EdgeInsets margin;
  final Size maxSize;

  @override
  Rect resolve(ExpandedBoundsContext context) {
    final Rect available = margin.deflateRect(context.visibleArea);
    final Size size = Size(
      math.max(0, math.min(maxSize.width, available.width)),
      math.max(0, math.min(maxSize.height, available.height)),
    );
    return Rect.fromCenter(
      center: available.center,
      width: size.width,
      height: size.height,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is _DialogMode &&
      other.margin == margin &&
      other.maxSize == maxSize;

  @override
  int get hashCode => Object.hash(_DialogMode, margin, maxSize);

  @override
  String toString() =>
      'ExpandableAnimationMode.dialog(margin: $margin, maxSize: $maxSize)';
}

class _SheetMode extends ExpandableAnimationMode {
  const _SheetMode({this.heightFactor = 0.6, this.maxWidth = 640})
      : assert(heightFactor > 0 && heightFactor <= 1),
        assert(maxWidth > 0);

  final double heightFactor;
  final double maxWidth;

  @override
  Rect resolve(ExpandedBoundsContext context) {
    final Size size = context.overlaySize;
    final double width = math.min(maxWidth, size.width);
    final double bottom = size.height - context.viewInsets.bottom;
    final double top = math.min(
      bottom,
      math.max(context.padding.top, bottom - size.height * heightFactor),
    );
    final double left = (size.width - width) / 2;
    return Rect.fromLTRB(left, top, left + width, bottom);
  }

  @override
  bool operator ==(Object other) =>
      other is _SheetMode &&
      other.heightFactor == heightFactor &&
      other.maxWidth == maxWidth;

  @override
  int get hashCode => Object.hash(_SheetMode, heightFactor, maxWidth);

  @override
  String toString() => 'ExpandableAnimationMode.sheet('
      'heightFactor: $heightFactor, maxWidth: $maxWidth)';
}

class _CustomMode extends ExpandableAnimationMode {
  const _CustomMode(this.resolver);

  final ExpandedBoundsResolver resolver;

  @override
  Rect resolve(ExpandedBoundsContext context) => resolver(context);

  @override
  bool operator ==(Object other) =>
      other is _CustomMode && other.resolver == resolver;

  @override
  int get hashCode => Object.hash(_CustomMode, resolver);

  @override
  String toString() => 'ExpandableAnimationMode.custom($resolver)';
}
