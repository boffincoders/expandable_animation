import 'dart:async';

import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../animation/expandable_animation_physics.dart';
import '../controllers/expandable_animation_controller.dart';
import '../models/expandable_animation_gesture_config.dart';
import '../models/expandable_animation_mode.dart';
import '../models/expandable_animation_phase.dart';
import '../transitions/expandable_animation_route.dart';
import 'expandable_animation_scope.dart';

/// Signature for a function that composes the collapsed and expanded layers
/// of an `ExpandableAnimation` inside the morphing surface.
///
/// [animation] runs from `0.0` (collapsed) to `1.0` (expanded) and already
/// includes the configured curve or spring, clamped to `[0, 1]`.
///
/// [collapsed] and [expanded] each fill the surface. They are laid out at
/// their natural size and scaled to the surface width, top-aligned, so they
/// never re-layout while the surface animates. A builder typically stacks
/// them and fades between them:
///
/// ```dart
/// Widget fadeThrough(
///   BuildContext context,
///   Animation<double> animation,
///   Widget collapsed,
///   Widget expanded,
/// ) {
///   return Stack(
///     fit: StackFit.expand,
///     children: [
///       FadeTransition(
///         opacity: ReverseAnimation(
///           CurvedAnimation(parent: animation, curve: const Interval(0, 0.3)),
///         ),
///         child: collapsed,
///       ),
///       FadeTransition(
///         opacity: CurvedAnimation(
///           parent: animation,
///           curve: const Interval(0.3, 0.7),
///         ),
///         child: expanded,
///       ),
///     ],
///   );
/// }
/// ```
typedef ExpandableAnimationTransitionBuilder = Widget Function(
  BuildContext context,
  Animation<double> animation,
  Widget collapsed,
  Widget expanded,
);

/// Expands any widget into a fullscreen or expanded view with a smooth,
/// interruptible container-morphing animation.
///
/// [ExpandableAnimation] shows [child] in place. When the user taps it (or
/// you call [ExpandableAnimationController.expand]), the child lifts out of
/// the layout and morphs — position, size, corner radius and color — into the
/// view built by [expandedBuilder]. Collapsing reverses the motion back into
/// the child's current position.
///
/// ```dart
/// ExpandableAnimation(
///   borderRadius: BorderRadius.circular(20),
///   expandedBuilder: (context) => const ProductDetails(),
///   child: const ProductCard(),
/// )
/// ```
///
/// ## How it works
///
/// The expanded view is shown in a modal route on the nearest (by default the
/// root) [Navigator]. That means:
///
/// * The system back button, the Escape key and `Navigator.pop` collapse it.
/// * `PopScope` inside the expanded content can veto user dismissals.
/// * Focus moves into the expanded view and returns to the source when it
///   collapses.
/// * Inherited themes (`Theme`, `CupertinoTheme`, `DefaultTextStyle`,
///   `IconTheme`, ...) from the source location are carried into the
///   expanded view. Other inherited widgets, such as state-management
///   providers placed below the navigator, are not; place those above the
///   `MaterialApp`/`CupertinoApp`/`WidgetsApp` or re-provide them in
///   [expandedBuilder].
///
/// The child and the expanded content are separate widget instances. Keep
/// state that must survive the transition (for example, audio playback)
/// outside both and pass it in.
///
/// ## Gestures
///
/// With [enableDragToDismiss] (on by default) the user can drag the expanded
/// view down to dismiss it. Vertical scrollables inside the expanded view
/// keep working: the dismissal only starts when such a scrollable is pulled
/// down while already at its top. Tune the feel with [gestureConfig].
///
/// ## Accessibility
///
/// The source is exposed as a button and can be activated with Enter or
/// Space when focused. The expanded view supports the semantics dismiss
/// action. When the platform requests reduced motion and
/// [respectReducedMotion] is `true`, transitions are instant.
///
/// See also:
///
/// * [ExpandableAnimationController], to expand and collapse from code.
/// * [ExpandableAnimationMode], to expand to a dialog, a bottom sheet or
///   custom bounds instead of fullscreen.
/// * [ExpandableAnimationPhysics], for spring-driven transitions.
class ExpandableAnimation extends StatefulWidget {
  /// Creates a widget that expands [child] into the view built by
  /// [expandedBuilder].
  const ExpandableAnimation({
    super.key,
    required this.child,
    required this.expandedBuilder,
    this.controller,
    this.mode = const ExpandableAnimationMode.fullscreen(),
    this.duration = const Duration(milliseconds: 400),
    this.reverseDuration,
    this.curve = Curves.easeInOutCubic,
    this.reverseCurve,
    this.physics,
    this.borderRadius = BorderRadius.zero,
    this.expandedBorderRadius = BorderRadius.zero,
    this.collapsedColor,
    this.expandedColor,
    this.backgroundColor = const Color(0xFF000000),
    this.backgroundOpacity = 0.5,
    this.backgroundBlur = 0,
    this.dismissOnBackgroundTap = true,
    this.enableDragToDismiss = true,
    this.gestureConfig = const ExpandableAnimationGestureConfig(),
    this.expandOnTap = true,
    this.enabled = true,
    this.hideSourceWhileExpanded = true,
    this.useRootNavigator = true,
    this.respectReducedMotion = true,
    this.transitionBuilder,
    this.semanticLabel,
    this.backgroundSemanticLabel = 'Close',
    this.onExpanded,
    this.onCollapsed,
    this.onPhaseChanged,
  })  : assert(
          backgroundOpacity >= 0 && backgroundOpacity <= 1,
          'backgroundOpacity must be between 0 and 1.',
        ),
        assert(backgroundBlur >= 0, 'backgroundBlur must not be negative.');

  /// The widget shown in place while collapsed. It is the starting point of
  /// the expansion and the end point of the collapse.
  final Widget child;

  /// Builds the expanded view.
  ///
  /// The returned widget is laid out at the expanded bounds resolved by
  /// [mode]. It is built inside a route, so `Navigator.of(context).pop()`
  /// collapses it, as does `ExpandableAnimation.of(context).collapse()`.
  final WidgetBuilder expandedBuilder;

  /// Controls the expansion from code and reports its state.
  ///
  /// When `null`, an internal controller is created; reach it from
  /// descendants with [ExpandableAnimation.of].
  final ExpandableAnimationController? controller;

  /// Where the view expands to. Defaults to
  /// `ExpandableAnimationMode.fullscreen()`.
  final ExpandableAnimationMode mode;

  /// The duration of the expansion. Defaults to 400 milliseconds.
  ///
  /// Ignored when [physics] is set.
  final Duration duration;

  /// The duration of the collapse. Defaults to [duration].
  ///
  /// Ignored when [physics] is set.
  final Duration? reverseDuration;

  /// The curve of the expansion. Defaults to [Curves.easeInOutCubic].
  ///
  /// Ignored when [physics] is set.
  final Curve curve;

  /// The curve of the collapse. Defaults to [curve].
  ///
  /// Ignored when [physics] is set.
  final Curve? reverseCurve;

  /// Spring physics for the transition. When set, overrides [duration],
  /// [reverseDuration], [curve] and [reverseCurve].
  final ExpandableAnimationPhysics? physics;

  /// The corner radius of the surface while collapsed. Match it to the
  /// child's own shape for a seamless lift-off. Defaults to square corners.
  final BorderRadius borderRadius;

  /// The corner radius of the surface while expanded. Defaults to square
  /// corners.
  final BorderRadius expandedBorderRadius;

  /// The surface color behind the collapsed layer during the transition.
  /// Defaults to transparent.
  final Color? collapsedColor;

  /// The surface color behind the expanded layer. The surface interpolates
  /// from [collapsedColor] to this color. Defaults to [collapsedColor].
  final Color? expandedColor;

  /// The color of the background scrim behind the expanded view. Defaults
  /// to black.
  final Color backgroundColor;

  /// The opacity of the background scrim when fully expanded, from 0 to 1.
  /// Multiplied with the alpha of [backgroundColor]. Defaults to `0.5`.
  final double backgroundOpacity;

  /// The blur sigma applied to the content behind the expanded view when
  /// fully expanded. `0` (the default) disables the blur.
  ///
  /// Background blur re-renders everything behind the view every frame. It
  /// is noticeably more expensive than a plain scrim, especially on low-end
  /// devices and on the web; profile before enabling it.
  final double backgroundBlur;

  /// Whether tapping the background outside the expanded view collapses it.
  /// Only visible with modes that do not cover the whole screen. Defaults to
  /// `true`.
  final bool dismissOnBackgroundTap;

  /// Whether the user can drag the expanded view down to dismiss it.
  /// Defaults to `true`.
  final bool enableDragToDismiss;

  /// Tunes drag-to-dismiss. See [ExpandableAnimationGestureConfig].
  final ExpandableAnimationGestureConfig gestureConfig;

  /// Whether tapping [child] expands it. Defaults to `true`. Set to `false`
  /// when expansion is triggered only through the [controller].
  final bool expandOnTap;

  /// Whether the widget can expand at all. When `false`, taps and
  /// [ExpandableAnimationController.expand] are ignored. An already expanded
  /// view can still be collapsed. Defaults to `true`.
  final bool enabled;

  /// Whether [child] is hidden in place while expanded, so the expansion
  /// appears to lift it out of the layout. Defaults to `true`.
  final bool hideSourceWhileExpanded;

  /// Whether the expanded view is pushed on the root navigator, covering
  /// bottom navigation bars and nested navigators. Defaults to `true`.
  final bool useRootNavigator;

  /// Whether transitions become instant when the platform requests reduced
  /// motion (`MediaQueryData.disableAnimations`). Defaults to `true`.
  final bool respectReducedMotion;

  /// Composes the collapsed and expanded layers inside the morphing surface.
  /// Defaults to [defaultTransitionBuilder], a cross-fade.
  final ExpandableAnimationTransitionBuilder? transitionBuilder;

  /// The semantic label of the collapsed source button, read by screen
  /// readers. When `null`, the child's own semantics are used.
  final String? semanticLabel;

  /// The semantic label of the background scrim, which acts as a close
  /// button when [dismissOnBackgroundTap] is `true`. Defaults to `'Close'`;
  /// pass a localized string in localized apps.
  final String backgroundSemanticLabel;

  /// Called once each time an expansion completes.
  final VoidCallback? onExpanded;

  /// Called once each time a collapse completes and the source widget is
  /// shown again.
  final VoidCallback? onCollapsed;

  /// Called whenever the [ExpandableAnimationPhase] changes.
  final ValueChanged<ExpandableAnimationPhase>? onPhaseChanged;

  /// The controller of the closest enclosing [ExpandableAnimation].
  ///
  /// Works from inside [child] and from inside the expanded view, which
  /// makes it convenient for close buttons:
  ///
  /// ```dart
  /// IconButton(
  ///   icon: const Icon(Icons.close),
  ///   onPressed: () => ExpandableAnimation.of(context).collapse(),
  /// )
  /// ```
  ///
  /// Throws if there is no enclosing [ExpandableAnimation]; see [maybeOf].
  static ExpandableAnimationController of(BuildContext context) {
    final ExpandableAnimationController? controller = maybeOf(context);
    assert(() {
      if (controller == null) {
        throw FlutterError(
          'ExpandableAnimation.of() called with a context that does not '
          'contain an ExpandableAnimation.\n'
          'Call it from a descendant of ExpandableAnimation.child or from '
          'inside ExpandableAnimation.expandedBuilder.',
        );
      }
      return true;
    }());
    return controller!;
  }

  /// The controller of the closest enclosing [ExpandableAnimation], or
  /// `null` if there is none.
  static ExpandableAnimationController? maybeOf(BuildContext context) =>
      ExpandableAnimationScope.maybeOf(context);

  /// The default [transitionBuilder]: the collapsed layer fades out while the
  /// expanded layer fades in, both during the first 40% of the transition.
  static Widget defaultTransitionBuilder(
    BuildContext context,
    Animation<double> animation,
    Widget collapsed,
    Widget expanded,
  ) {
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        FadeTransition(
          opacity: animation.drive(_collapsedOpacity),
          child: collapsed,
        ),
        FadeTransition(
          opacity: animation.drive(_expandedOpacity),
          child: expanded,
        ),
      ],
    );
  }

  static final Animatable<double> _collapsedOpacity =
      Tween<double>(begin: 1, end: 0)
          .chain(CurveTween(curve: const Interval(0, 0.4)));

  static final Animatable<double> _expandedOpacity =
      CurveTween(curve: const Interval(0, 0.4));

  @override
  State<ExpandableAnimation> createState() => _ExpandableAnimationState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DiagnosticsProperty<ExpandableAnimationController>(
        'controller',
        controller,
        defaultValue: null,
      ))
      ..add(DiagnosticsProperty<ExpandableAnimationMode>('mode', mode))
      ..add(DiagnosticsProperty<Duration>('duration', duration))
      ..add(DiagnosticsProperty<Curve>('curve', curve))
      ..add(DiagnosticsProperty<ExpandableAnimationPhysics>(
        'physics',
        physics,
        defaultValue: null,
      ))
      ..add(FlagProperty(
        'enableDragToDismiss',
        value: enableDragToDismiss,
        ifFalse: 'drag-to-dismiss disabled',
      ))
      ..add(FlagProperty('enabled', value: enabled, ifFalse: 'disabled'));
  }
}

class _ExpandableAnimationState extends State<ExpandableAnimation>
    implements ExpandableAnimationDelegate {
  ExpandableAnimationController? _ownedController;
  ExpandableAnimationRoute? _route;
  ExpandableAnimationPhase _phase = ExpandableAnimationPhase.collapsed;
  Completer<void>? _expandCompleter;
  Completer<void>? _collapseCompleter;
  bool _configUpdateScheduled = false;

  ExpandableAnimationController get _controller =>
      widget.controller ?? _ownedController!;

  @override
  void initState() {
    super.initState();
    if (widget.controller == null) {
      _ownedController = ExpandableAnimationController();
    }
    attachExpandableController(_controller, this);
  }

  @override
  void didUpdateWidget(ExpandableAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      final ExpandableAnimationController previous =
          oldWidget.controller ?? _ownedController!;
      detachExpandableController(previous, this);
      if (widget.controller != null && _ownedController != null) {
        // Keep the owned controller alive while an expanded route still
        // exposes it; it is disposed together with the route.
        if (_route == null) {
          _ownedController!.dispose();
        }
        _ownedController = null;
      } else if (widget.controller == null) {
        _ownedController = ExpandableAnimationController();
      }
      attachExpandableController(_controller, this);
      _syncController();
    }
    if (_route != null) {
      _scheduleRouteConfigUpdate();
    }
  }

  /// Pushes the latest widget configuration into the expanded route after
  /// the current frame, because the route's subtree cannot be marked dirty
  /// while this widget is building.
  void _scheduleRouteConfigUpdate() {
    if (_configUpdateScheduled) {
      return;
    }
    _configUpdateScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _configUpdateScheduled = false;
      final ExpandableAnimationRoute? route = _route;
      if (!mounted || route == null || route.isDisposed) {
        return;
      }
      route.config.value = widget;
      final NavigatorState? navigator = route.navigator;
      if (navigator != null) {
        route.capturedThemes.value =
            InheritedTheme.capture(from: context, to: navigator.context);
      }
    });
  }

  @override
  void dispose() {
    detachExpandableController(_controller, this);
    final ExpandableAnimationRoute? route = _route;
    if (route != null && !route.isDisposed) {
      // The source is gone but the expanded view is still on screen. Let the
      // controller keep collapsing it; the collapse fades out in place.
      attachExpandableController(_controller, _OrphanedRouteDelegate(route));
    } else {
      _ownedController?.dispose();
    }
    _completeExpand();
    _completeCollapse();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Delegate
  // ---------------------------------------------------------------------------

  @override
  Future<void> expand() {
    if (!mounted || !widget.enabled) {
      return Future<void>.value();
    }
    double initialValue = 0;
    final ExpandableAnimationRoute? current = _route;
    if (current != null && !current.isDisposed) {
      switch (current.animation!.status) {
        case AnimationStatus.forward:
        case AnimationStatus.completed:
          return _expandCompleter?.future ?? Future<void>.value();
        case AnimationStatus.reverse:
          // Interrupt the collapse: finish the old route instantly and
          // continue from the same position in a new one.
          initialValue = current.animation!.value;
          _route = null;
          current.finishImmediately();
        case AnimationStatus.dismissed:
          _route = null;
      }
    }

    final NavigatorState navigator =
        Navigator.of(context, rootNavigator: widget.useRootNavigator);
    final Rect? sourceRect = _measureSource(navigator);
    if (sourceRect == null) {
      return Future<void>.value();
    }

    final ExpandableAnimationRoute route = ExpandableAnimationRoute(
      config: widget,
      sourceRect: sourceRect,
      measureSource: () => _measureSource(navigator),
      capturedThemes:
          InheritedTheme.capture(from: context, to: navigator.context),
      expandableController: _controller,
      reduceMotion: widget.respectReducedMotion &&
          (MediaQuery.maybeDisableAnimationsOf(context) ?? false),
      initialValue: initialValue,
      onStatusChanged: _handleRouteStatus,
      onValueChanged: _handleRouteValue,
      onDisposed: _handleRouteDisposed,
    );
    route.dragProgress.addListener(() => _handleRouteValue(route));
    route.isDragging.addListener(() => _handleDragging(route));

    _completeCollapse();
    _expandCompleter = Completer<void>();
    final Future<void> result = _expandCompleter!.future;
    setState(() => _route = route);
    unawaited(navigator.push(route));
    // A route that starts part-way (after an interrupted collapse) is already
    // in the forward status before listeners attach, so sync it explicitly.
    final AnimationStatus? status = route.animation?.status;
    if (status != null && status != AnimationStatus.dismissed) {
      _handleRouteStatus(route, status);
    }
    return result;
  }

  @override
  Future<void> collapse() {
    final ExpandableAnimationRoute? route = _route;
    if (route == null || route.isDisposed) {
      return Future<void>.value();
    }
    final AnimationStatus status = route.animation!.status;
    if (status == AnimationStatus.reverse ||
        status == AnimationStatus.dismissed) {
      return _collapseCompleter?.future ?? Future<void>.value();
    }
    _collapseCompleter ??= Completer<void>();
    final Future<void> result = _collapseCompleter!.future;
    _popRoute(route);
    return result;
  }

  // ---------------------------------------------------------------------------
  // Route events
  // ---------------------------------------------------------------------------

  void _handleRouteStatus(
      ExpandableAnimationRoute route, AnimationStatus status) {
    if (!identical(route, _route)) {
      return;
    }
    switch (status) {
      case AnimationStatus.forward:
        _setPhase(ExpandableAnimationPhase.expanding);
      case AnimationStatus.completed:
        _setPhase(ExpandableAnimationPhase.expanded);
        _completeExpand();
        if (mounted) {
          widget.onExpanded?.call();
        }
      case AnimationStatus.reverse:
        _completeExpand();
        _setPhase(ExpandableAnimationPhase.collapsing);
      case AnimationStatus.dismissed:
        _finishCollapse();
    }
  }

  void _handleRouteValue(ExpandableAnimationRoute route) {
    if (!identical(route, _route) || route.isDisposed) {
      return;
    }
    final double drag = route.dragProgress.value;
    final double value = route.animation?.value ?? 0;
    updateExpandableController(
      _controller,
      progress: drag > 0 ? 1 - drag : value,
    );
  }

  void _handleDragging(ExpandableAnimationRoute route) {
    if (!identical(route, _route) || route.isDisposed) {
      return;
    }
    updateExpandableController(_controller, isDragging: route.isDragging.value);
  }

  void _handleRouteDisposed(ExpandableAnimationRoute route) {
    if (identical(route, _route)) {
      // Removed without finishing its animation, e.g. by removeRoute.
      _finishCollapse();
    }
  }

  void _finishCollapse() {
    final bool wasOpen = _phase != ExpandableAnimationPhase.collapsed;
    _route = null;
    _completeExpand();
    updateExpandableController(_controller, progress: 0, isDragging: false);
    _setPhase(ExpandableAnimationPhase.collapsed);
    _completeCollapse();
    if (mounted) {
      setState(() {});
      if (wasOpen) {
        widget.onCollapsed?.call();
      }
    } else {
      // The source was disposed while expanded; the owned controller
      // outlived it only to serve the expanded route.
      _ownedController?.dispose();
      _ownedController = null;
    }
  }

  void _setPhase(ExpandableAnimationPhase phase) {
    if (phase == _phase) {
      return;
    }
    _phase = phase;
    updateExpandableController(_controller, phase: phase);
    if (mounted) {
      widget.onPhaseChanged?.call(phase);
    }
  }

  void _syncController() {
    final ExpandableAnimationRoute? route = _route;
    updateExpandableController(
      _controller,
      phase: _phase,
      progress:
          route == null || route.isDisposed ? 0 : (route.animation?.value ?? 0),
      isDragging: route != null && !route.isDisposed && route.isDragging.value,
    );
  }

  void _completeExpand() {
    final Completer<void>? completer = _expandCompleter;
    _expandCompleter = null;
    if (completer != null && !completer.isCompleted) {
      completer.complete();
    }
  }

  void _completeCollapse() {
    final Completer<void>? completer = _collapseCompleter;
    _collapseCompleter = null;
    if (completer != null && !completer.isCompleted) {
      completer.complete();
    }
  }

  // ---------------------------------------------------------------------------
  // Source
  // ---------------------------------------------------------------------------

  Rect? _measureSource(NavigatorState navigator) {
    if (!mounted) {
      return null;
    }
    final RenderObject? box = context.findRenderObject();
    final RenderObject? overlay = navigator.overlay?.context.findRenderObject();
    if (box is! RenderBox ||
        !box.attached ||
        !box.hasSize ||
        overlay is! RenderBox ||
        !overlay.attached) {
      return null;
    }
    return MatrixUtils.transformRect(
      box.getTransformTo(overlay),
      Offset.zero & box.size,
    );
  }

  void _handleTap() {
    unawaited(expand());
  }

  @override
  Widget build(BuildContext context) {
    final bool hidden = widget.hideSourceWhileExpanded && _route != null;
    Widget child = ExpandableAnimationScope(
      controller: _controller,
      child: Visibility(
        visible: !hidden,
        maintainState: true,
        maintainAnimation: true,
        maintainSize: true,
        // Keep the hidden source tappable so a tap during a collapse can
        // reverse it.
        maintainInteractivity: true,
        child: widget.child,
      ),
    );
    if (widget.expandOnTap) {
      child = Semantics(
        button: true,
        enabled: widget.enabled,
        label: widget.semanticLabel,
        child: FocusableActionDetector(
          enabled: widget.enabled,
          mouseCursor:
              widget.enabled ? SystemMouseCursors.click : MouseCursor.defer,
          actions: <Type, Action<Intent>>{
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (_) {
                _handleTap();
                return null;
              },
            ),
          },
          child: GestureDetector(
            onTap: widget.enabled ? _handleTap : null,
            child: child,
          ),
        ),
      );
    }
    return child;
  }
}

/// Keeps an [ExpandableAnimationController] working for an expanded route
/// whose source widget has been disposed.
class _OrphanedRouteDelegate implements ExpandableAnimationDelegate {
  _OrphanedRouteDelegate(this.route);

  final ExpandableAnimationRoute route;

  @override
  Future<void> expand() => Future<void>.value();

  @override
  Future<void> collapse() {
    if (!route.isDisposed) {
      _popRoute(route);
    }
    return Future<void>.value();
  }
}

void _popRoute(ExpandableAnimationRoute route) {
  final NavigatorState? navigator = route.navigator;
  if (navigator == null) {
    return;
  }
  if (route.isCurrent) {
    navigator.pop();
  } else if (route.isActive) {
    // Another route is on top; remove ours without an animation.
    navigator.removeRoute(route);
  }
}
