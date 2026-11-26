import 'package:flutter/widgets.dart';

import '../controllers/expandable_animation_controller.dart';
import '../widgets/expandable_animation.dart';
import '../widgets/expanded_surface.dart';
import 'surface_geometry.dart';

/// The modal route that hosts an expanded `ExpandableAnimation`.
///
/// Using a real route (rather than a bare overlay entry) gives the expanded
/// view correct back-button and Escape handling, focus scoping, modal
/// semantics and integration with `Navigator` APIs such as `popUntil`.
///
/// Not part of the public API.
class ExpandableAnimationRoute extends PopupRoute<void> {
  /// Creates a route for an expansion that starts from [sourceRect].
  ExpandableAnimationRoute({
    required ExpandableAnimation config,
    required this.sourceRect,
    required this.measureSource,
    required CapturedThemes capturedThemes,
    required this.expandableController,
    required this.reduceMotion,
    required this.onStatusChanged,
    required this.onValueChanged,
    required this.onDisposed,
    this.initialValue = 0,
  })  : config = ValueNotifier<ExpandableAnimation>(config),
        capturedThemes = ValueNotifier<CapturedThemes>(capturedThemes),
        source = ValueNotifier<Rect?>(sourceRect);

  /// The source bounds when the expansion started, in overlay coordinates.
  final Rect sourceRect;

  /// Measures the current source bounds, or returns `null` when the source
  /// widget is no longer available.
  final Rect? Function() measureSource;

  /// The controller exposed to the expanded subtree.
  final ExpandableAnimationController expandableController;

  /// Whether the platform asked for reduced motion when the route was
  /// created. Transitions are then instant.
  final bool reduceMotion;

  /// Called whenever the route animation's status changes.
  final void Function(ExpandableAnimationRoute route, AnimationStatus status)
      onStatusChanged;

  /// Called whenever the route animation's value changes.
  final void Function(ExpandableAnimationRoute route) onValueChanged;

  /// Called when the route is disposed.
  final void Function(ExpandableAnimationRoute route) onDisposed;

  /// The value the route animation starts from. Non-zero when an expansion
  /// interrupts a collapse that was already in progress.
  final double initialValue;

  /// The widget configuration. Updated when the owning widget rebuilds.
  final ValueNotifier<ExpandableAnimation> config;

  /// Inherited themes captured from the source widget's context.
  final ValueNotifier<CapturedThemes> capturedThemes;

  /// The bounds the surface collapses back into, or `null` to use the
  /// fallback fade when the source widget is gone.
  final ValueNotifier<Rect?> source;

  /// The drag-to-dismiss progress, from 0 to 1.
  final ValueNotifier<double> dragProgress = ValueNotifier<double>(0);

  /// Whether a dismiss drag is in progress.
  final ValueNotifier<bool> isDragging = ValueNotifier<bool>(false);

  /// The geometry of the surface at the moment a dismiss drag was released.
  ///
  /// When set, the collapse animates from this geometry instead of from the
  /// expanded bounds, so the surface continues smoothly from where the finger
  /// left it.
  SurfaceGeometry? releaseGeometry;

  /// The background strength at the moment a dismiss drag was released.
  double releaseBackgroundFactor = 1;

  bool _disposed = false;

  /// Whether [dispose] has been called.
  bool get isDisposed => _disposed;

  ExpandableAnimation get _config => config.value;

  @override
  Duration get transitionDuration {
    if (reduceMotion) {
      return Duration.zero;
    }
    return _config.physics?.settleDuration ?? _config.duration;
  }

  @override
  Duration get reverseTransitionDuration {
    if (reduceMotion) {
      return Duration.zero;
    }
    return _config.physics?.reverseSettleDuration ??
        _config.reverseDuration ??
        _config.duration;
  }

  @override
  Color? get barrierColor => null;

  @override
  bool get barrierDismissible => false;

  @override
  String? get barrierLabel => null;

  @override
  bool get maintainState => true;

  @override
  bool get allowSnapshotting => false;

  @override
  AnimationController createAnimationController() {
    return super.createAnimationController()..value = initialValue;
  }

  @override
  Animation<double> createAnimation() {
    final Animation<double> animation = super.createAnimation();
    animation
      ..addStatusListener(_handleStatus)
      ..addListener(_handleValue);
    return animation;
  }

  void _handleStatus(AnimationStatus status) => onStatusChanged(this, status);

  void _handleValue() => onValueChanged(this);

  @override
  bool didPop(void result) {
    // Re-measure: the source may have moved (scrolling, rotation, resizing)
    // while the view was expanded. A missing source switches to the fallback.
    source.value = measureSource();
    return super.didPop(result);
  }

  /// Ends this route's animation immediately at the collapsed state.
  ///
  /// Used when an expansion interrupts a collapse: the collapsing route is
  /// finished instantly and a new route continues from the same position.
  void finishImmediately() {
    controller?.value = 0;
  }

  /// Pops this route in response to a user gesture, honoring `PopScope`
  /// widgets in the expanded content. Returns whether the route was popped.
  bool requestPop() {
    if (!isCurrent || _disposed) {
      return false;
    }
    if (popDisposition == RoutePopDisposition.doNotPop) {
      onPopInvokedWithResult(false, null);
      return false;
    }
    navigator!.pop();
    return true;
  }

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return ExpandedSurface(route: this);
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return child;
  }

  @override
  void dispose() {
    _disposed = true;
    onDisposed(this);
    super.dispose();
    config.dispose();
    capturedThemes.dispose();
    source.dispose();
    dragProgress.dispose();
    isDragging.dispose();
  }
}
