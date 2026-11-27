import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/gestures.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../animation/expandable_animation_physics.dart';
import '../gestures/dismiss_drag_scope.dart';
import '../models/expandable_animation_dismiss_direction.dart';
import '../models/expandable_animation_gesture_config.dart';
import '../models/expandable_animation_mode.dart';
import '../transitions/expandable_animation_route.dart';
import '../transitions/surface_geometry.dart';
import 'expandable_animation.dart';
import 'expandable_animation_scope.dart';
import 'resolved_expandable_animation.dart';

/// The spring used to settle a cancelled dismiss drag back into place.
const SpringDescription _kSettleSpring = SpringDescription(
  mass: 1,
  stiffness: 500,
  damping: 2 * 22.36, // Critically damped for stiffness 500 and mass 1.
);

/// The page of an [ExpandableAnimationRoute]: background, morphing surface
/// and drag-to-dismiss handling.
///
/// Not part of the public API.
class ExpandedSurface extends StatefulWidget {
  /// Creates the expanded surface for [route].
  const ExpandedSurface({super.key, required this.route});

  /// The route that owns this surface.
  final ExpandableAnimationRoute route;

  @override
  State<ExpandedSurface> createState() => _ExpandedSurfaceState();
}

class _ExpandedSurfaceState extends State<ExpandedSurface>
    with SingleTickerProviderStateMixin {
  // Created in initState, never lazily: a lazy controller would first be
  // created inside dispose() when no drag happened, which looks up the
  // (already deactivated) TickerMode.
  late final AnimationController _settleController;

  final ValueNotifier<double> _dragOffset = ValueNotifier<double>(0);

  late CurvedAnimation _curved;
  late _ClampedAnimation _clamped;

  // The configuration the current curves were created from.
  Object? _curvePhysics;
  Curve? _curveCurve;
  Curve? _curveReverse;

  bool _dragging = false;

  /// The axis the current drag is locked to.
  Axis? _dragAxis;

  /// The direction the current drag dismisses in, once it has moved.
  ExpandableAnimationDismissDirection? _dragDirection;

  /// Pointers that descendants asked to keep out of the dismiss drag.
  final Set<int> _blockedPointers = <int>{};
  bool _pastThreshold = false;

  /// The expanded bounds from the most recent layout.
  Rect _target = Rect.zero;

  ExpandableAnimationRoute get _route => widget.route;

  /// The transition value used for geometry: curved normally, linear while a
  /// velocity-matched spring drives the collapse (the spring already shapes
  /// the motion, so applying the reverse curve on top would distort it).
  double get _progress =>
      _route.isSpringCollapse ? _route.animation!.value : _curved.value;
  ResolvedExpandableAnimation get _config => _route.config.value;
  ExpandableAnimationGestureConfig get _gestures => _config.gestureConfig;

  @override
  void initState() {
    super.initState();
    _settleController = AnimationController.unbounded(vsync: this)
      ..addListener(_handleSettle);
    _createCurves();
    _route.config.addListener(_handleConfigChanged);
    _route.capturedThemes.addListener(_handleConfigChanged);
    _route.source.addListener(_handleConfigChanged);
  }

  void _createCurves() {
    final ResolvedExpandableAnimation config = _config;
    final bool spring = config.physics != null && !_route.reduceMotion;
    _curvePhysics = config.physics;
    _curveCurve = config.curve;
    _curveReverse = config.reverseCurve;
    _curved = CurvedAnimation(
      parent: _route.animation!,
      curve: spring ? config.physics!.curve : config.curve,
      reverseCurve: spring ? config.physics!.reverseCurve : config.reverseCurve,
    );
    _clamped = _ClampedAnimation(_curved, () => _progress);
  }

  void _handleConfigChanged() {
    final ResolvedExpandableAnimation config = _config;
    if (_curvePhysics != config.physics ||
        _curveCurve != config.curve ||
        _curveReverse != config.reverseCurve) {
      _curved.dispose();
      _createCurves();
    }
    setState(() {});
  }

  @override
  void dispose() {
    if (!_route.isDisposed) {
      _route.config.removeListener(_handleConfigChanged);
      _route.capturedThemes.removeListener(_handleConfigChanged);
      _route.source.removeListener(_handleConfigChanged);
    }
    _curved.dispose();
    _settleController.dispose();
    _dragOffset.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Drag to dismiss
  // ---------------------------------------------------------------------------

  bool get _canDrag =>
      _config.enableDragToDismiss &&
      _route.isCurrent &&
      _route.animation!.status == AnimationStatus.completed &&
      _route.releaseGeometry == null;

  /// The size of the expanded surface along the current drag axis.
  double get _dragExtent => dragExtent(
        _target,
        _dragDirection ?? ExpandableAnimationDismissDirection.down,
      );

  void _handleSettle() {
    _dragOffset.value = math.max(0, _settleController.value);
    _reportDragProgress();
  }

  void _reportDragProgress() {
    if (_route.isDisposed) {
      return;
    }
    _route.dragProgress.value =
        dragProgress(offset: _dragOffset.value, extent: _dragExtent);
  }

  /// Starts a dismiss drag along [axis]. Returns whether it was accepted.
  bool _startDrag(Axis axis) {
    if (_dragging) {
      return _dragAxis == axis;
    }
    if (!_canDrag || !_gestures.allowsAxis(axis)) {
      return false;
    }
    if (_dragOffset.value > 0 && _dragAxis != axis) {
      // Still settling back from a drag along the other axis.
      return false;
    }
    _settleController.stop();
    _dragging = true;
    _dragAxis = axis;
    _pastThreshold = _isPastThreshold(_dragOffset.value);
    _route.isDragging.value = true;
    return true;
  }

  bool _isPastThreshold(double offset) =>
      offset >= _dragExtent * _gestures.dismissThreshold;

  /// The component of a screen-space vector in the current drag direction.
  double _alongDirection(Offset vector) {
    final ExpandableAnimationDismissDirection? direction = _dragDirection;
    if (direction == null) {
      return 0;
    }
    final Offset unit = direction.unit;
    return vector.dx * unit.dx + vector.dy * unit.dy;
  }

  /// Moves the drag by a screen-space [delta].
  void _updateDrag(Offset delta) {
    if (!_dragging) {
      return;
    }
    final Axis axis = _dragAxis!;
    if (_dragDirection == null) {
      final double component = axis == Axis.vertical ? delta.dy : delta.dx;
      if (component == 0) {
        return;
      }
      final ExpandableAnimationDismissDirection direction =
          ExpandableAnimationDismissDirection.fromDelta(axis, component);
      if (!_gestures.dismissDirections.contains(direction)) {
        return;
      }
      _dragDirection = direction;
    }
    final double next = _dragOffset.value + _alongDirection(delta);
    if (next <= 0) {
      // Back at the start: the next movement may pick the other direction.
      _dragOffset.value = 0;
      _dragDirection = null;
    } else {
      _dragOffset.value = next;
    }
    _reportDragProgress();
    final bool past = _isPastThreshold(_dragOffset.value);
    if (past != _pastThreshold) {
      _pastThreshold = past;
      if (_gestures.enableHapticFeedback) {
        HapticFeedback.selectionClick();
      }
    }
  }

  /// Ends the drag with a screen-space [velocity] in logical pixels per
  /// second.
  void _endDrag(Offset velocity) {
    if (!_dragging) {
      return;
    }
    _dragging = false;
    if (!_route.isDisposed) {
      _route.isDragging.value = false;
    }
    final double offset = _dragOffset.value;
    final double along = _alongDirection(velocity);
    final bool dismiss = shouldDismissDrag(
      offset: offset,
      velocity: along,
      extent: _dragExtent,
      config: _gestures,
    );
    if (dismiss && _dismissFromDrag(offset, velocity)) {
      return;
    }
    _settleBack(offset, along);
  }

  bool _dismissFromDrag(double offset, Offset velocity) {
    final ResolvedExpandableAnimation config = _config;
    final ExpandableAnimationDismissDirection direction = _dragDirection!;
    final SurfaceGeometry released = dragSurfaceGeometry(
      expanded: SurfaceGeometry(
        rect: _target,
        borderRadius: config.expandedBorderRadius,
      ),
      offset: offset,
      direction: direction,
      collapsedRadius: config.borderRadius,
      config: _gestures,
    );
    final double backgroundFactor =
        1 - dragProgress(offset: offset, extent: _dragExtent);
    _route
      ..releaseGeometry = released
      ..releaseBackgroundFactor = backgroundFactor;
    if (!_route.requestPop()) {
      _route
        ..releaseGeometry = null
        ..releaseBackgroundFactor = 1;
      return false;
    }
    _resetDrag();
    if (_gestures.matchReleaseVelocity && !_route.reduceMotion) {
      _route.collapseWithSpring(
        config.physics?.reverseDescription ??
            criticallyDampedSpring(_route.reverseTransitionDuration),
        releaseProgressVelocity(
          released: released.rect,
          source: _route.source.value,
          fingerVelocity: velocity,
          dragResistance: _gestures.dragResistance,
        ),
      );
    }
    return true;
  }

  void _settleBack(double offset, double velocity) {
    if (offset <= 0) {
      _resetDrag();
      return;
    }
    _settleController.value = offset;
    _settleController
        .animateWith(SpringSimulation(_kSettleSpring, offset, 0, velocity))
        // Springs approach their rest point asymptotically; snap exactly to
        // zero once settled. Not called when a new drag interrupts.
        .then((_) => _resetDrag());
  }

  void _resetDrag() {
    if (!mounted) {
      return;
    }
    _dragOffset.value = 0;
    _reportDragProgress();
    _dragDirection = null;
    _dragAxis = null;
  }

  /// Converts a change in scroll position into the finger movement that
  /// caused it, in screen coordinates.
  static Offset _fingerDelta(ScrollMetrics metrics, double scrollDelta) {
    return switch (metrics.axisDirection) {
      AxisDirection.down => Offset(0, -scrollDelta),
      AxisDirection.up => Offset(0, scrollDelta),
      AxisDirection.right => Offset(-scrollDelta, 0),
      AxisDirection.left => Offset(scrollDelta, 0),
    };
  }

  bool _allowsFingerDelta(Axis axis, Offset delta) {
    final double component = axis == Axis.vertical ? delta.dy : delta.dx;
    return component != 0 &&
        _gestures.dismissDirections.contains(
          ExpandableAnimationDismissDirection.fromDelta(axis, component),
        );
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    final ScrollMetrics metrics = notification.metrics;
    final Axis axis = metrics.axis;
    if (!_gestures.dismissFromScrollableContent ||
        notification.depth != 0 ||
        !_gestures.allowsAxis(axis) ||
        (_dragging && _dragAxis != axis)) {
      return false;
    }
    if (notification is OverscrollNotification) {
      if (notification.dragDetails == null) {
        return false;
      }
      final Offset delta = _fingerDelta(metrics, notification.overscroll);
      if (!_dragging && _allowsFingerDelta(axis, delta)) {
        _startDrag(axis);
      }
      _updateDrag(delta);
    } else if (notification is ScrollUpdateNotification) {
      if (notification.dragDetails == null) {
        return false;
      }
      final double scrollDelta = notification.scrollDelta ?? 0;
      final Offset delta = _fingerDelta(metrics, scrollDelta);
      if (_dragging) {
        _updateDrag(delta);
      } else if ((metrics.pixels < metrics.minScrollExtent &&
              scrollDelta < 0) ||
          (metrics.pixels > metrics.maxScrollExtent && scrollDelta > 0)) {
        // Content with bouncing physics pulled past one of its edges.
        if (_allowsFingerDelta(axis, delta) && _startDrag(axis)) {
          _updateDrag(delta);
        }
      }
    } else if (notification is ScrollEndNotification) {
      _endDrag(
          notification.dragDetails?.velocity.pixelsPerSecond ?? Offset.zero);
    }
    return false;
  }

  bool _handleIndicatorNotification(
    OverscrollIndicatorNotification notification,
  ) {
    final Set<ExpandableAnimationDismissDirection> directions =
        _gestures.dismissDirections;
    // The leading edge of a regular scrollable is its top or start: pulling
    // past it moves the finger down or right.
    final bool edgeAllowed = notification.leading
        ? directions.contains(ExpandableAnimationDismissDirection.down) ||
            directions.contains(ExpandableAnimationDismissDirection.right)
        : directions.contains(ExpandableAnimationDismissDirection.up) ||
            directions.contains(ExpandableAnimationDismissDirection.left);
    if (notification.depth == 0 &&
        (_dragging ||
            (_canDrag &&
                edgeAllowed &&
                _gestures.dismissFromScrollableContent))) {
      notification.disallowIndicator();
    }
    return false;
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  void _close() {
    _route.requestPop();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      onDismiss: _close,
      child: CallbackShortcuts(
        bindings: <ShortcutActivator, VoidCallback>{
          const SingleActivator(LogicalKeyboardKey.escape): _close,
        },
        child: Focus(
          autofocus: true,
          child: LayoutBuilder(builder: _buildLayout),
        ),
      ),
    );
  }

  Widget _buildLayout(BuildContext context, BoxConstraints constraints) {
    final ResolvedExpandableAnimation config = _config;
    final Size overlaySize = constraints.biggest;
    final MediaQueryData mediaQuery = MediaQuery.of(context);
    final Rect target = config.mode.resolve(
      ExpandedBoundsContext(
        overlaySize: overlaySize,
        padding: mediaQuery.padding,
        viewInsets: mediaQuery.viewInsets,
        sourceRect: _route.sourceRect,
      ),
    );
    _target = target;

    final Widget collapsedLayer = _TopAlignedFit(
      size: (_route.source.value ?? _route.sourceRect).size,
      child: IgnorePointer(
        child: ExcludeSemantics(
          child: _OffstageWhenExpanded(
            animation: _clamped,
            child: _wrapInherited(config.child),
          ),
        ),
      ),
    );

    Widget expanded = Builder(builder: config.expandedBuilder);
    if (config.enableDragToDismiss && _gestures.clampScrollPhysics) {
      expanded = ScrollConfiguration(
        behavior: ScrollConfiguration.of(context)
            .copyWith(physics: const ClampingScrollPhysics()),
        child: expanded,
      );
    }
    if (config.enableDragToDismiss) {
      expanded = ExpandableDismissDragScope(
        onStart: _startDrag,
        onUpdate: _updateDrag,
        onEnd: _endDrag,
        blockPointer: _blockedPointers.add,
        unblockPointer: _blockedPointers.remove,
        child: expanded,
      );
    }
    expanded = MediaQuery(
      data: mediaQuery.copyWith(
        padding: paddingWithinRect(mediaQuery.padding, target, overlaySize),
        viewPadding:
            paddingWithinRect(mediaQuery.viewPadding, target, overlaySize),
        viewInsets:
            paddingWithinRect(mediaQuery.viewInsets, target, overlaySize),
      ),
      child: expanded,
    );
    final Widget expandedLayer = _TopAlignedFit(
      size: target.size,
      child: _InteractiveWhenSettled(
        animation: _route.animation!,
        child: _wrapInherited(expanded),
      ),
    );

    final ExpandableAnimationTransitionBuilder transitionBuilder =
        config.transitionBuilder ??
            ExpandableAnimation.defaultTransitionBuilder;
    Widget surfaceContent = transitionBuilder(
      context,
      _clamped,
      collapsedLayer,
      expandedLayer,
    );

    if (config.enableDragToDismiss) {
      surfaceContent = NotificationListener<OverscrollIndicatorNotification>(
        onNotification: _handleIndicatorNotification,
        child: NotificationListener<ScrollNotification>(
          onNotification: _handleScrollNotification,
          child: RawGestureDetector(
            // Blank areas of the surface are draggable too.
            behavior: HitTestBehavior.opaque,
            gestures: <Type, GestureRecognizerFactory>{
              if (_gestures.allowsAxis(Axis.vertical))
                _VerticalDismissRecognizer:
                    GestureRecognizerFactoryWithHandlers<
                        _VerticalDismissRecognizer>(
                  () => _VerticalDismissRecognizer(
                    isBlocked: _blockedPointers.contains,
                    debugOwner: this,
                  ),
                  (_VerticalDismissRecognizer recognizer) =>
                      _configureRecognizer(recognizer, Axis.vertical),
                ),
              if (_gestures.allowsAxis(Axis.horizontal))
                _HorizontalDismissRecognizer:
                    GestureRecognizerFactoryWithHandlers<
                        _HorizontalDismissRecognizer>(
                  () => _HorizontalDismissRecognizer(
                    isBlocked: _blockedPointers.contains,
                    debugOwner: this,
                  ),
                  (_HorizontalDismissRecognizer recognizer) =>
                      _configureRecognizer(recognizer, Axis.horizontal),
                ),
            },
            child: surfaceContent,
          ),
        ),
      );
    }

    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[_curved, _dragOffset]),
      builder: (BuildContext context, Widget? child) =>
          _buildFrame(config, target, child!),
      child: surfaceContent,
    );
  }

  void _configureRecognizer(DragGestureRecognizer recognizer, Axis axis) {
    recognizer
      ..onStart = ((DragStartDetails details) => _startDrag(axis))
      ..onUpdate = ((DragUpdateDetails details) => _updateDrag(details.delta))
      ..onEnd = ((DragEndDetails details) =>
          _endDrag(details.velocity.pixelsPerSecond))
      ..onCancel = (() => _endDrag(Offset.zero));
  }

  Widget _wrapInherited(Widget child) {
    return _route.capturedThemes.value.wrap(
      ExpandableAnimationScope(
        controller: _route.expandableController,
        child: child,
      ),
    );
  }

  Widget _buildFrame(
      ResolvedExpandableAnimation config, Rect target, Widget content) {
    final double t = _progress;
    final SurfaceGeometry? released = _route.releaseGeometry;
    final Rect destination = released?.rect ?? target;
    final BorderRadius destinationRadius =
        released?.borderRadius ?? config.expandedBorderRadius;

    SurfaceGeometry geometry = lerpSurfaceGeometry(
      source: _route.source.value,
      destination: destination,
      sourceRadius: config.borderRadius,
      destinationRadius: destinationRadius,
      t: t,
    );

    double backgroundFactor = t.clamp(0.0, 1.0);
    final double offset = _dragOffset.value;
    if (released != null) {
      backgroundFactor *= _route.releaseBackgroundFactor;
    } else if (offset > 0) {
      final ExpandableAnimationDismissDirection direction =
          _dragDirection ?? ExpandableAnimationDismissDirection.down;
      geometry = dragSurfaceGeometry(
        expanded: geometry,
        offset: offset,
        direction: direction,
        collapsedRadius: config.borderRadius,
        config: _gestures,
      );
      backgroundFactor *= 1 -
          dragProgress(offset: offset, extent: dragExtent(target, direction));
    }

    final Color collapsedColor =
        config.collapsedColor ?? const Color(0x00000000);
    final Color expandedColor = config.expandedColor ?? collapsedColor;
    final Color surfaceColor =
        Color.lerp(collapsedColor, expandedColor, t.clamp(0.0, 1.0))!;

    return Stack(
      children: <Widget>[
        Positioned.fill(child: _buildBackground(config, backgroundFactor)),
        Positioned.fromRect(
          rect: geometry.rect,
          child: Opacity(
            opacity: geometry.opacity,
            child: ClipRRect(
              borderRadius: geometry.borderRadius,
              child: ColoredBox(color: surfaceColor, child: content),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBackground(ResolvedExpandableAnimation config, double factor) {
    final Color base = config.backgroundColor;
    Widget background = ColoredBox(
      color: base.withValues(alpha: base.a * config.backgroundOpacity * factor),
    );
    if (config.backgroundBlur > 0) {
      final double sigma = config.backgroundBlur * factor;
      background = ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
          child: background,
        ),
      );
    }
    if (!config.dismissOnBackgroundTap) {
      return background;
    }
    return Semantics(
      label: config.backgroundSemanticLabel,
      button: true,
      onTap: _close,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _close,
        excludeFromSemantics: true,
        child: background,
      ),
    );
  }
}

/// The surface's vertical dismiss recognizer, which ignores pointers that
/// descendants have blocked (see [ExpandableDismissDragScope.blockPointer]).
class _VerticalDismissRecognizer extends VerticalDragGestureRecognizer {
  _VerticalDismissRecognizer({required this.isBlocked, super.debugOwner});

  final bool Function(int pointer) isBlocked;

  @override
  bool isPointerAllowed(PointerEvent event) =>
      !isBlocked(event.pointer) && super.isPointerAllowed(event);
}

/// The horizontal counterpart of [_VerticalDismissRecognizer].
class _HorizontalDismissRecognizer extends HorizontalDragGestureRecognizer {
  _HorizontalDismissRecognizer({required this.isBlocked, super.debugOwner});

  final bool Function(int pointer) isBlocked;

  @override
  bool isPointerAllowed(PointerEvent event) =>
      !isBlocked(event.pointer) && super.isPointerAllowed(event);
}

/// Lays [child] out at its natural [size], then scales it to the available
/// width and aligns it to the top, clipping any overflow.
///
/// Because the child always receives the same tight constraints, it is not
/// re-laid-out while the surface around it animates; only the scale changes.
class _TopAlignedFit extends StatelessWidget {
  const _TopAlignedFit({required this.size, required this.child});

  final Size size;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.fitWidth,
        alignment: Alignment.topCenter,
        clipBehavior: Clip.hardEdge,
        child: SizedBox(
          width: math.max(1, size.width),
          height: math.max(1, size.height),
          child: child,
        ),
      ),
    );
  }
}

/// Hides the collapsed copy once the expansion has fully completed so it no
/// longer paints or costs anything beyond keeping its state.
class _OffstageWhenExpanded extends AnimatedWidget {
  const _OffstageWhenExpanded({
    required Animation<double> animation,
    required this.child,
  }) : super(listenable: animation);

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final Animation<double> animation = listenable as Animation<double>;
    return Offstage(offstage: animation.value >= 1.0, child: child);
  }
}

/// Blocks pointer input and semantics for the expanded content until the
/// expansion has completed, so taps during the transition cannot reach
/// half-visible controls.
class _InteractiveWhenSettled extends StatefulWidget {
  const _InteractiveWhenSettled({required this.animation, required this.child});

  final Animation<double> animation;
  final Widget child;

  @override
  State<_InteractiveWhenSettled> createState() =>
      _InteractiveWhenSettledState();
}

class _InteractiveWhenSettledState extends State<_InteractiveWhenSettled> {
  @override
  void initState() {
    super.initState();
    widget.animation.addStatusListener(_handleStatus);
  }

  @override
  void didUpdateWidget(_InteractiveWhenSettled oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animation != widget.animation) {
      oldWidget.animation.removeStatusListener(_handleStatus);
      widget.animation.addStatusListener(_handleStatus);
    }
  }

  @override
  void dispose() {
    widget.animation.removeStatusListener(_handleStatus);
    super.dispose();
  }

  void _handleStatus(AnimationStatus status) => setState(() {});

  @override
  Widget build(BuildContext context) {
    final bool settled = widget.animation.status == AnimationStatus.completed;
    return IgnorePointer(
      ignoring: !settled,
      child: ExcludeSemantics(excluding: !settled, child: widget.child),
    );
  }
}

/// An animation that clamps a transition value to `[0, 1]`, notifying when
/// its [parent] does.
///
/// Springs may overshoot past `1.0`; geometry uses the raw value so the
/// overshoot is visible, while opacity-based transition builders receive the
/// clamped value.
class _ClampedAnimation extends Animation<double>
    with AnimationWithParentMixin<double> {
  _ClampedAnimation(this.parent, this._read);

  @override
  final Animation<double> parent;

  final double Function() _read;

  @override
  double get value => _read().clamp(0.0, 1.0);
}
