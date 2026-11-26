import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../models/expandable_animation_gesture_config.dart';
import '../models/expandable_animation_mode.dart';
import '../transitions/expandable_animation_route.dart';
import '../transitions/surface_geometry.dart';
import 'expandable_animation.dart';
import 'expandable_animation_scope.dart';

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
  bool _pastThreshold = false;

  /// The expanded bounds from the most recent layout.
  Rect _target = Rect.zero;

  ExpandableAnimationRoute get _route => widget.route;
  ExpandableAnimation get _config => _route.config.value;
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
    final ExpandableAnimation config = _config;
    final bool spring = config.physics != null && !_route.reduceMotion;
    _curvePhysics = config.physics;
    _curveCurve = config.curve;
    _curveReverse = config.reverseCurve;
    _curved = CurvedAnimation(
      parent: _route.animation!,
      curve: spring ? config.physics!.curve : config.curve,
      reverseCurve: spring ? config.physics!.reverseCurve : config.reverseCurve,
    );
    _clamped = _ClampedAnimation(_curved);
  }

  void _handleConfigChanged() {
    final ExpandableAnimation config = _config;
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

  void _handleSettle() {
    _dragOffset.value = math.max(0, _settleController.value);
    _reportDragProgress();
  }

  void _reportDragProgress() {
    if (_route.isDisposed) {
      return;
    }
    _route.dragProgress.value =
        dragProgress(offset: _dragOffset.value, extent: _target.height);
  }

  void _startDrag() {
    if (_dragging || !_canDrag) {
      return;
    }
    _settleController.stop();
    _dragging = true;
    _pastThreshold = _isPastThreshold(_dragOffset.value);
    _route.isDragging.value = true;
  }

  bool _isPastThreshold(double offset) =>
      offset >= _target.height * _gestures.dismissThreshold;

  void _updateDrag(double delta) {
    if (!_dragging) {
      return;
    }
    final double offset = math.max(0, _dragOffset.value + delta);
    _dragOffset.value = offset;
    _reportDragProgress();
    final bool past = _isPastThreshold(offset);
    if (past != _pastThreshold) {
      _pastThreshold = past;
      if (_gestures.enableHapticFeedback) {
        HapticFeedback.selectionClick();
      }
    }
  }

  void _endDrag(double velocity) {
    if (!_dragging) {
      return;
    }
    _dragging = false;
    if (!_route.isDisposed) {
      _route.isDragging.value = false;
    }
    final double offset = _dragOffset.value;
    final bool dismiss = shouldDismissDrag(
      offset: offset,
      velocity: velocity,
      extent: _target.height,
      config: _gestures,
    );
    if (dismiss && _dismissFromDrag(offset)) {
      return;
    }
    _settleBack(offset, velocity);
  }

  bool _dismissFromDrag(double offset) {
    final ExpandableAnimation config = _config;
    final SurfaceGeometry released = dragSurfaceGeometry(
      expanded: SurfaceGeometry(
        rect: _target,
        borderRadius: config.expandedBorderRadius,
      ),
      offset: offset,
      collapsedRadius: config.borderRadius,
      config: _gestures,
    );
    final double backgroundFactor =
        1 - dragProgress(offset: offset, extent: _target.height);
    _route
      ..releaseGeometry = released
      ..releaseBackgroundFactor = backgroundFactor;
    if (!_route.requestPop()) {
      _route
        ..releaseGeometry = null
        ..releaseBackgroundFactor = 1;
      return false;
    }
    _dragOffset.value = 0;
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
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    if (!_gestures.dismissFromScrollableContent ||
        notification.depth != 0 ||
        notification.metrics.axis != Axis.vertical) {
      return false;
    }
    final ScrollMetrics metrics = notification.metrics;
    if (notification is OverscrollNotification) {
      if (notification.dragDetails == null) {
        return false;
      }
      if (!_dragging &&
          notification.overscroll < 0 &&
          metrics.pixels <= metrics.minScrollExtent) {
        _startDrag();
      }
      _updateDrag(-notification.overscroll);
    } else if (notification is ScrollUpdateNotification) {
      if (notification.dragDetails == null) {
        return false;
      }
      final double delta = notification.scrollDelta ?? 0;
      if (_dragging) {
        _updateDrag(-delta);
      } else if (delta < 0 && metrics.pixels < metrics.minScrollExtent) {
        // Content with bouncing physics pulled past its top edge.
        _startDrag();
        _updateDrag(-delta);
      }
    } else if (notification is ScrollEndNotification) {
      _endDrag(notification.dragDetails?.velocity.pixelsPerSecond.dy ?? 0);
    }
    return false;
  }

  bool _handleIndicatorNotification(
    OverscrollIndicatorNotification notification,
  ) {
    if (notification.depth == 0 &&
        notification.leading &&
        (_dragging || (_canDrag && _gestures.dismissFromScrollableContent))) {
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
    final ExpandableAnimation config = _config;
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
          child: GestureDetector(
            // Blank areas of the surface are draggable too.
            behavior: HitTestBehavior.opaque,
            onVerticalDragStart: (_) => _startDrag(),
            onVerticalDragUpdate: (DragUpdateDetails details) =>
                _updateDrag(details.delta.dy),
            onVerticalDragEnd: (DragEndDetails details) =>
                _endDrag(details.primaryVelocity ?? 0),
            onVerticalDragCancel: () => _endDrag(0),
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

  Widget _wrapInherited(Widget child) {
    return _route.capturedThemes.value.wrap(
      ExpandableAnimationScope(
        controller: _route.expandableController,
        child: child,
      ),
    );
  }

  Widget _buildFrame(ExpandableAnimation config, Rect target, Widget content) {
    final double t = _curved.value;
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
      geometry = dragSurfaceGeometry(
        expanded: geometry,
        offset: offset,
        collapsedRadius: config.borderRadius,
        config: _gestures,
      );
      backgroundFactor *=
          1 - dragProgress(offset: offset, extent: target.height);
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

  Widget _buildBackground(ExpandableAnimation config, double factor) {
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

/// An animation that clamps its parent's value to `[0, 1]`.
///
/// Springs may overshoot past `1.0`; geometry uses the raw value so the
/// overshoot is visible, while opacity-based transition builders receive the
/// clamped value.
class _ClampedAnimation extends Animation<double>
    with AnimationWithParentMixin<double> {
  _ClampedAnimation(this.parent);

  @override
  final Animation<double> parent;

  @override
  double get value => parent.value.clamp(0.0, 1.0);
}
