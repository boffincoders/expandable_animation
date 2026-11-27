import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../gestures/dismiss_drag_scope.dart';

/// How long a double-tap zoom in or out takes.
const Duration _kDoubleTapZoomDuration = Duration(milliseconds: 250);

/// Scales below `1 + _kZoomEpsilon` count as "not zoomed", so tiny rounding
/// differences after a pinch do not block drag-to-dismiss.
const double _kZoomEpsilon = 0.01;

/// Pinch-to-zoom, pan and double-tap zoom that cooperate with
/// drag-to-dismiss.
///
/// A plain [InteractiveViewer] inside an `ExpandableAnimation` claims every
/// one-finger drag, so the expanded view can no longer be dragged away.
/// [ExpandableAnimationZoomable] wraps an [InteractiveViewer] and coordinates
/// the two gestures:
///
/// * **Not zoomed** — a one-finger drag dismisses the view, exactly as it
///   does elsewhere in the expanded view.
/// * **Zoomed in** — a one-finger drag pans the content; dismissal is
///   paused until the user zooms back out.
/// * **Two fingers** — always pinch-zoom, even if a dismiss drag had just
///   started (that drag springs back).
/// * **Double tap** — zooms to [doubleTapScale] around the tapped point, or
///   back out when already zoomed.
///
/// When the expanded view collapses while zoomed (for example with the back
/// button), the content zooms back out as it shrinks.
///
/// ```dart
/// ExpandableAnimation(
///   expandedBuilder: (context) => ExpandableAnimationZoomable(
///     child: Image.asset('assets/photo.jpg', fit: BoxFit.contain),
///   ),
///   child: Image.asset('assets/photo_thumb.jpg', fit: BoxFit.cover),
/// )
/// ```
///
/// Outside an `ExpandableAnimation` it behaves like a regular zoomable
/// viewer with double-tap zoom.
class ExpandableAnimationZoomable extends StatefulWidget {
  /// Creates a zoomable area that cooperates with drag-to-dismiss.
  const ExpandableAnimationZoomable({
    super.key,
    required this.child,
    this.minScale = 1.0,
    this.maxScale = 4.0,
    this.doubleTapScale = 2.5,
    this.enableDoubleTapZoom = true,
    this.transformationController,
    this.onScaleChanged,
    this.clipBehavior = Clip.hardEdge,
  })  : assert(minScale > 0, 'minScale must be positive.'),
        assert(maxScale >= minScale, 'maxScale must be at least minScale.'),
        assert(doubleTapScale > 1, 'doubleTapScale must be greater than 1.');

  /// The content to zoom, typically an image.
  final Widget child;

  /// The smallest allowed scale. Defaults to `1.0`.
  final double minScale;

  /// The largest allowed scale. Defaults to `4.0`.
  final double maxScale;

  /// The scale a double tap zooms to, clamped to [maxScale]. Defaults to
  /// `2.5`.
  final double doubleTapScale;

  /// Whether double tapping zooms in and out. Defaults to `true`.
  final bool enableDoubleTapZoom;

  /// Controls and reports the current transformation. When `null`, an
  /// internal controller is used. An external controller is not disposed by
  /// this widget.
  final TransformationController? transformationController;

  /// Called whenever the scale changes, with the new scale.
  final ValueChanged<double>? onScaleChanged;

  /// How the zoomed content is clipped. Defaults to [Clip.hardEdge].
  final Clip clipBehavior;

  @override
  State<ExpandableAnimationZoomable> createState() =>
      _ExpandableAnimationZoomableState();
}

class _ExpandableAnimationZoomableState
    extends State<ExpandableAnimationZoomable>
    with SingleTickerProviderStateMixin {
  TransformationController? _ownedController;
  late final AnimationController _zoomAnimation;
  Animation<Matrix4>? _zoomTween;
  Animation<double>? _routeAnimation;
  ExpandableDismissDragScope? _forwardingTo;

  /// Whether the current one-finger interaction may still become a forwarded
  /// dismiss drag (decided on its first movement).
  bool _mayForward = false;

  /// Pointers kept out of the dismiss drag because they went down while the
  /// content was zoomed in, so they pan instead.
  final Map<int, ExpandableDismissDragScope> _blocked =
      <int, ExpandableDismissDragScope>{};
  Offset? _doubleTapPosition;
  double _lastScale = 1;

  TransformationController get _controller =>
      widget.transformationController ??
      (_ownedController ??= TransformationController());

  double get _scale => _controller.value.getMaxScaleOnAxis();

  bool get _isZoomed => _scale > 1 + _kZoomEpsilon;

  @override
  void initState() {
    super.initState();
    _zoomAnimation = AnimationController(
      vsync: this,
      duration: _kDoubleTapZoomDuration,
    )..addListener(_applyZoomAnimation);
    _controller.addListener(_handleTransform);
    _lastScale = _scale;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final Animation<double>? routeAnimation = ModalRoute.of(context)?.animation;
    if (routeAnimation != _routeAnimation) {
      _routeAnimation?.removeStatusListener(_handleRouteStatus);
      _routeAnimation = routeAnimation?..addStatusListener(_handleRouteStatus);
    }
  }

  @override
  void didUpdateWidget(ExpandableAnimationZoomable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.transformationController != widget.transformationController) {
      (oldWidget.transformationController ?? _ownedController)
          ?.removeListener(_handleTransform);
      if (widget.transformationController != null) {
        _ownedController?.dispose();
        _ownedController = null;
      }
      _controller.addListener(_handleTransform);
      _handleTransform();
    }
  }

  @override
  void dispose() {
    for (final MapEntry<int, ExpandableDismissDragScope> entry
        in _blocked.entries) {
      entry.value.unblockPointer(entry.key);
    }
    _blocked.clear();
    // Release a dismiss drag still in progress, after the tree is unlocked.
    final ExpandableDismissDragScope? scope = _forwardingTo;
    _forwardingTo = null;
    if (scope != null) {
      SchedulerBinding.instance.addPostFrameCallback(
        (_) => scope.onEnd(Offset.zero),
      );
    }
    _routeAnimation?.removeStatusListener(_handleRouteStatus);
    _controller.removeListener(_handleTransform);
    _ownedController?.dispose();
    _zoomAnimation.dispose();
    super.dispose();
  }

  void _handleTransform() {
    final double scale = _scale;
    if (scale != _lastScale) {
      _lastScale = scale;
      widget.onScaleChanged?.call(scale);
    }
  }

  void _handleRouteStatus(AnimationStatus status) {
    // Zoom back out while the expanded view collapses.
    if (status == AnimationStatus.reverse && _isZoomed) {
      _animateTo(Matrix4.identity());
    }
  }

  // ---------------------------------------------------------------------------
  // Dismiss forwarding
  // ---------------------------------------------------------------------------

  void _handlePointerDown(PointerDownEvent event) {
    if (!_isZoomed) {
      return;
    }
    final ExpandableDismissDragScope? scope =
        ExpandableDismissDragScope.maybeOf(context);
    if (scope != null) {
      scope.blockPointer(event.pointer);
      _blocked[event.pointer] = scope;
    }
  }

  void _handlePointerUp(PointerEvent event) {
    _blocked.remove(event.pointer)?.unblockPointer(event.pointer);
  }

  void _handleInteractionStart(ScaleStartDetails details) {
    _zoomAnimation.stop();
    _mayForward = details.pointerCount == 1 && !_isZoomed;
  }

  void _handleInteractionUpdate(ScaleUpdateDetails details) {
    if (details.pointerCount > 1) {
      // A second finger turns the gesture into a pinch.
      _mayForward = false;
      _endForwarding(Offset.zero);
      return;
    }
    final Offset delta = details.focalPointDelta;
    if (_forwardingTo == null && _mayForward && delta != Offset.zero) {
      // Lock to the axis of the first movement, like a drag recognizer.
      _mayForward = false;
      final Axis axis =
          delta.dy.abs() >= delta.dx.abs() ? Axis.vertical : Axis.horizontal;
      final ExpandableDismissDragScope? scope =
          ExpandableDismissDragScope.maybeOf(context);
      if (scope != null && scope.onStart(axis)) {
        _forwardingTo = scope;
      }
    }
    _forwardingTo?.onUpdate(delta);
  }

  void _handleInteractionEnd(ScaleEndDetails details) {
    _mayForward = false;
    _endForwarding(details.velocity.pixelsPerSecond);
  }

  void _endForwarding(Offset velocity) {
    final ExpandableDismissDragScope? scope = _forwardingTo;
    _forwardingTo = null;
    scope?.onEnd(velocity);
  }

  // ---------------------------------------------------------------------------
  // Double-tap zoom
  // ---------------------------------------------------------------------------

  void _handleDoubleTap() {
    if (_isZoomed) {
      _animateTo(Matrix4.identity());
      return;
    }
    final Offset focus = _doubleTapPosition ?? Offset.zero;
    final double scale = widget.doubleTapScale.clamp(
      widget.minScale,
      widget.maxScale,
    );
    // Scale around the tapped point so it stays under the finger.
    _animateTo(
      Matrix4.diagonal3Values(scale, scale, 1)
        ..setTranslationRaw(
          -focus.dx * (scale - 1),
          -focus.dy * (scale - 1),
          0,
        ),
    );
  }

  void _animateTo(Matrix4 target) {
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _zoomAnimation.stop();
      _controller.value = target;
      return;
    }
    _zoomTween =
        Matrix4Tween(begin: _controller.value.clone(), end: target).animate(
      CurvedAnimation(parent: _zoomAnimation, curve: Curves.easeOutCubic),
    );
    _zoomAnimation.forward(from: 0);
  }

  void _applyZoomAnimation() {
    final Animation<Matrix4>? tween = _zoomTween;
    if (tween != null) {
      _controller.value = tween.value;
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget viewer = InteractiveViewer(
      transformationController: _controller,
      minScale: widget.minScale,
      maxScale: widget.maxScale,
      clipBehavior: widget.clipBehavior,
      onInteractionStart: _handleInteractionStart,
      onInteractionUpdate: _handleInteractionUpdate,
      onInteractionEnd: _handleInteractionEnd,
      child: widget.child,
    );
    viewer = Listener(
      onPointerDown: _handlePointerDown,
      onPointerUp: _handlePointerUp,
      onPointerCancel: _handlePointerUp,
      child: viewer,
    );
    if (widget.enableDoubleTapZoom) {
      viewer = GestureDetector(
        onDoubleTapDown: (TapDownDetails details) =>
            _doubleTapPosition = details.localPosition,
        onDoubleTap: _handleDoubleTap,
        child: viewer,
      );
    }
    return viewer;
  }
}
