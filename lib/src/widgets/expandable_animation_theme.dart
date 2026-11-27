import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../animation/expandable_animation_physics.dart';
import '../models/expandable_animation_gesture_config.dart';
import '../models/expandable_animation_mode.dart';
import 'expandable_animation.dart';

/// Default values for every `ExpandableAnimation` below an
/// [ExpandableAnimationTheme].
///
/// Every field is optional. A widget parameter that is left `null` falls back
/// to the nearest theme's value, and then to the package default documented
/// on the matching `ExpandableAnimation` parameter.
///
/// ```dart
/// ExpandableAnimationTheme(
///   data: const ExpandableAnimationThemeData(
///     physics: ExpandableAnimationPhysics.snappy,
///     borderRadius: BorderRadius.all(Radius.circular(20)),
///     backgroundBlur: 8,
///     hoverScale: 1.02,
///   ),
///   child: MaterialApp(home: const HomePage()),
/// )
/// ```
@immutable
class ExpandableAnimationThemeData with Diagnosticable {
  /// Creates theme data. Fields left `null` use the package defaults.
  const ExpandableAnimationThemeData({
    this.mode,
    this.duration,
    this.reverseDuration,
    this.curve,
    this.reverseCurve,
    this.physics,
    this.borderRadius,
    this.expandedBorderRadius,
    this.collapsedColor,
    this.expandedColor,
    this.backgroundColor,
    this.backgroundOpacity,
    this.backgroundBlur,
    this.dismissOnBackgroundTap,
    this.enableDragToDismiss,
    this.gestureConfig,
    this.hideSourceWhileExpanded,
    this.useRootNavigator,
    this.respectReducedMotion,
    this.transitionBuilder,
    this.backgroundSemanticLabel,
    this.hoverScale,
  })  : assert(
          backgroundOpacity == null ||
              (backgroundOpacity >= 0 && backgroundOpacity <= 1),
          'backgroundOpacity must be between 0 and 1.',
        ),
        assert(
          backgroundBlur == null || backgroundBlur >= 0,
          'backgroundBlur must not be negative.',
        ),
        assert(
          hoverScale == null || hoverScale > 0,
          'hoverScale must be positive.',
        );

  /// Default for `ExpandableAnimation.mode`.
  final ExpandableAnimationMode? mode;

  /// Default for `ExpandableAnimation.duration`.
  final Duration? duration;

  /// Default for `ExpandableAnimation.reverseDuration`.
  final Duration? reverseDuration;

  /// Default for `ExpandableAnimation.curve`.
  final Curve? curve;

  /// Default for `ExpandableAnimation.reverseCurve`.
  final Curve? reverseCurve;

  /// Default for `ExpandableAnimation.physics`.
  final ExpandableAnimationPhysics? physics;

  /// Default for `ExpandableAnimation.borderRadius`.
  final BorderRadius? borderRadius;

  /// Default for `ExpandableAnimation.expandedBorderRadius`.
  final BorderRadius? expandedBorderRadius;

  /// Default for `ExpandableAnimation.collapsedColor`.
  final Color? collapsedColor;

  /// Default for `ExpandableAnimation.expandedColor`.
  final Color? expandedColor;

  /// Default for `ExpandableAnimation.backgroundColor`.
  final Color? backgroundColor;

  /// Default for `ExpandableAnimation.backgroundOpacity`.
  final double? backgroundOpacity;

  /// Default for `ExpandableAnimation.backgroundBlur`.
  final double? backgroundBlur;

  /// Default for `ExpandableAnimation.dismissOnBackgroundTap`.
  final bool? dismissOnBackgroundTap;

  /// Default for `ExpandableAnimation.enableDragToDismiss`.
  final bool? enableDragToDismiss;

  /// Default for `ExpandableAnimation.gestureConfig`.
  final ExpandableAnimationGestureConfig? gestureConfig;

  /// Default for `ExpandableAnimation.hideSourceWhileExpanded`.
  final bool? hideSourceWhileExpanded;

  /// Default for `ExpandableAnimation.useRootNavigator`.
  final bool? useRootNavigator;

  /// Default for `ExpandableAnimation.respectReducedMotion`.
  final bool? respectReducedMotion;

  /// Default for `ExpandableAnimation.transitionBuilder`.
  final ExpandableAnimationTransitionBuilder? transitionBuilder;

  /// Default for `ExpandableAnimation.backgroundSemanticLabel`.
  final String? backgroundSemanticLabel;

  /// Default for `ExpandableAnimation.hoverScale`.
  final double? hoverScale;

  /// Creates a copy of this theme data with the given fields replaced.
  ExpandableAnimationThemeData copyWith({
    ExpandableAnimationMode? mode,
    Duration? duration,
    Duration? reverseDuration,
    Curve? curve,
    Curve? reverseCurve,
    ExpandableAnimationPhysics? physics,
    BorderRadius? borderRadius,
    BorderRadius? expandedBorderRadius,
    Color? collapsedColor,
    Color? expandedColor,
    Color? backgroundColor,
    double? backgroundOpacity,
    double? backgroundBlur,
    bool? dismissOnBackgroundTap,
    bool? enableDragToDismiss,
    ExpandableAnimationGestureConfig? gestureConfig,
    bool? hideSourceWhileExpanded,
    bool? useRootNavigator,
    bool? respectReducedMotion,
    ExpandableAnimationTransitionBuilder? transitionBuilder,
    String? backgroundSemanticLabel,
    double? hoverScale,
  }) {
    return ExpandableAnimationThemeData(
      mode: mode ?? this.mode,
      duration: duration ?? this.duration,
      reverseDuration: reverseDuration ?? this.reverseDuration,
      curve: curve ?? this.curve,
      reverseCurve: reverseCurve ?? this.reverseCurve,
      physics: physics ?? this.physics,
      borderRadius: borderRadius ?? this.borderRadius,
      expandedBorderRadius: expandedBorderRadius ?? this.expandedBorderRadius,
      collapsedColor: collapsedColor ?? this.collapsedColor,
      expandedColor: expandedColor ?? this.expandedColor,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      backgroundOpacity: backgroundOpacity ?? this.backgroundOpacity,
      backgroundBlur: backgroundBlur ?? this.backgroundBlur,
      dismissOnBackgroundTap:
          dismissOnBackgroundTap ?? this.dismissOnBackgroundTap,
      enableDragToDismiss: enableDragToDismiss ?? this.enableDragToDismiss,
      gestureConfig: gestureConfig ?? this.gestureConfig,
      hideSourceWhileExpanded:
          hideSourceWhileExpanded ?? this.hideSourceWhileExpanded,
      useRootNavigator: useRootNavigator ?? this.useRootNavigator,
      respectReducedMotion: respectReducedMotion ?? this.respectReducedMotion,
      transitionBuilder: transitionBuilder ?? this.transitionBuilder,
      backgroundSemanticLabel:
          backgroundSemanticLabel ?? this.backgroundSemanticLabel,
      hoverScale: hoverScale ?? this.hoverScale,
    );
  }

  /// Returns a copy where every field set in [other] replaces this one.
  ExpandableAnimationThemeData merge(ExpandableAnimationThemeData? other) {
    if (other == null) {
      return this;
    }
    return copyWith(
      mode: other.mode,
      duration: other.duration,
      reverseDuration: other.reverseDuration,
      curve: other.curve,
      reverseCurve: other.reverseCurve,
      physics: other.physics,
      borderRadius: other.borderRadius,
      expandedBorderRadius: other.expandedBorderRadius,
      collapsedColor: other.collapsedColor,
      expandedColor: other.expandedColor,
      backgroundColor: other.backgroundColor,
      backgroundOpacity: other.backgroundOpacity,
      backgroundBlur: other.backgroundBlur,
      dismissOnBackgroundTap: other.dismissOnBackgroundTap,
      enableDragToDismiss: other.enableDragToDismiss,
      gestureConfig: other.gestureConfig,
      hideSourceWhileExpanded: other.hideSourceWhileExpanded,
      useRootNavigator: other.useRootNavigator,
      respectReducedMotion: other.respectReducedMotion,
      transitionBuilder: other.transitionBuilder,
      backgroundSemanticLabel: other.backgroundSemanticLabel,
      hoverScale: other.hoverScale,
    );
  }

  List<Object?> get _props => <Object?>[
        mode,
        duration,
        reverseDuration,
        curve,
        reverseCurve,
        physics,
        borderRadius,
        expandedBorderRadius,
        collapsedColor,
        expandedColor,
        backgroundColor,
        backgroundOpacity,
        backgroundBlur,
        dismissOnBackgroundTap,
        enableDragToDismiss,
        gestureConfig,
        hideSourceWhileExpanded,
        useRootNavigator,
        respectReducedMotion,
        transitionBuilder,
        backgroundSemanticLabel,
        hoverScale,
      ];

  @override
  bool operator ==(Object other) =>
      other is ExpandableAnimationThemeData && listEquals(other._props, _props);

  @override
  int get hashCode => Object.hashAll(_props);

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DiagnosticsProperty<ExpandableAnimationMode>('mode', mode,
          defaultValue: null))
      ..add(DiagnosticsProperty<Duration>('duration', duration,
          defaultValue: null))
      ..add(DiagnosticsProperty<Curve>('curve', curve, defaultValue: null))
      ..add(DiagnosticsProperty<ExpandableAnimationPhysics>('physics', physics,
          defaultValue: null))
      ..add(DiagnosticsProperty<BorderRadius>('borderRadius', borderRadius,
          defaultValue: null))
      ..add(
          DoubleProperty('backgroundBlur', backgroundBlur, defaultValue: null))
      ..add(DoubleProperty('hoverScale', hoverScale, defaultValue: null));
  }
}

/// Provides [ExpandableAnimationThemeData] defaults to every
/// `ExpandableAnimation` below it.
///
/// Place it above your app widget to set app-wide defaults, or around a
/// subtree to style one section differently. The nearest theme wins; to
/// adjust an outer theme, read it with [ExpandableAnimationTheme.of] and
/// pass a `copyWith` of it.
///
/// The theme is an [InheritedTheme], so it is carried into expanded views:
/// an `ExpandableAnimation` nested inside another one's expanded view uses
/// the same theme.
class ExpandableAnimationTheme extends InheritedTheme {
  /// Creates a theme that provides [data] to its descendants.
  const ExpandableAnimationTheme({
    super.key,
    required this.data,
    required super.child,
  });

  /// The defaults provided to descendants.
  final ExpandableAnimationThemeData data;

  /// The nearest theme's data, or empty data (all package defaults) when
  /// there is no theme.
  static ExpandableAnimationThemeData of(BuildContext context) =>
      maybeOf(context) ?? const ExpandableAnimationThemeData();

  /// The nearest theme's data, or `null` when there is no theme.
  static ExpandableAnimationThemeData? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<ExpandableAnimationTheme>()
      ?.data;

  @override
  Widget wrap(BuildContext context, Widget child) =>
      ExpandableAnimationTheme(data: data, child: child);

  @override
  bool updateShouldNotify(ExpandableAnimationTheme oldWidget) =>
      data != oldWidget.data;
}
