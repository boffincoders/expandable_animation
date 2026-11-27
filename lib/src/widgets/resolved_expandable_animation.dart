import 'package:flutter/widgets.dart';

import '../animation/expandable_animation_physics.dart';
import '../models/expandable_animation_gesture_config.dart';
import '../models/expandable_animation_mode.dart';
import 'expandable_animation.dart';
import 'expandable_animation_theme.dart';

/// The package defaults, used when neither the widget nor the theme sets a
/// value. Documented on the matching `ExpandableAnimation` parameters.
abstract final class ExpandableAnimationDefaults {
  /// Default expansion mode.
  static const ExpandableAnimationMode mode =
      ExpandableAnimationMode.fullscreen();

  /// Default expansion duration.
  static const Duration duration = Duration(milliseconds: 400);

  /// Default expansion curve.
  static const Curve curve = Curves.easeInOutCubic;

  /// Default scrim color.
  static const Color backgroundColor = Color(0xFF000000);

  /// Default scrim opacity.
  static const double backgroundOpacity = 0.5;

  /// Default background blur (off).
  static const double backgroundBlur = 0;

  /// Default label of the background close button.
  static const String backgroundSemanticLabel = 'Close';

  /// Default hover and focus scale (no effect).
  static const double hoverScale = 1.0;

  /// Default gesture configuration.
  static const ExpandableAnimationGestureConfig gestureConfig =
      ExpandableAnimationGestureConfig();
}

/// An `ExpandableAnimation` configuration with widget values, theme values
/// and package defaults merged, so every option has a concrete value.
///
/// Not part of the public API.
@immutable
class ResolvedExpandableAnimation {
  /// Merges [widget] over [theme] over the package defaults.
  factory ResolvedExpandableAnimation.resolve(
    ExpandableAnimation widget,
    ExpandableAnimationThemeData theme,
  ) {
    return ResolvedExpandableAnimation._(
      child: widget.child,
      expandedBuilder: widget.expandedBuilder,
      mode: widget.mode ?? theme.mode ?? ExpandableAnimationDefaults.mode,
      duration: widget.duration ??
          theme.duration ??
          ExpandableAnimationDefaults.duration,
      reverseDuration: widget.reverseDuration ?? theme.reverseDuration,
      curve: widget.curve ?? theme.curve ?? ExpandableAnimationDefaults.curve,
      reverseCurve: widget.reverseCurve ?? theme.reverseCurve,
      physics: widget.physics ?? theme.physics,
      borderRadius:
          widget.borderRadius ?? theme.borderRadius ?? BorderRadius.zero,
      expandedBorderRadius: widget.expandedBorderRadius ??
          theme.expandedBorderRadius ??
          BorderRadius.zero,
      collapsedColor: widget.collapsedColor ?? theme.collapsedColor,
      expandedColor: widget.expandedColor ?? theme.expandedColor,
      backgroundColor: widget.backgroundColor ??
          theme.backgroundColor ??
          ExpandableAnimationDefaults.backgroundColor,
      backgroundOpacity: widget.backgroundOpacity ??
          theme.backgroundOpacity ??
          ExpandableAnimationDefaults.backgroundOpacity,
      backgroundBlur: widget.backgroundBlur ??
          theme.backgroundBlur ??
          ExpandableAnimationDefaults.backgroundBlur,
      dismissOnBackgroundTap:
          widget.dismissOnBackgroundTap ?? theme.dismissOnBackgroundTap ?? true,
      enableDragToDismiss:
          widget.enableDragToDismiss ?? theme.enableDragToDismiss ?? true,
      gestureConfig: widget.gestureConfig ??
          theme.gestureConfig ??
          ExpandableAnimationDefaults.gestureConfig,
      hideSourceWhileExpanded: widget.hideSourceWhileExpanded ??
          theme.hideSourceWhileExpanded ??
          true,
      useRootNavigator:
          widget.useRootNavigator ?? theme.useRootNavigator ?? true,
      respectReducedMotion:
          widget.respectReducedMotion ?? theme.respectReducedMotion ?? true,
      transitionBuilder: widget.transitionBuilder ?? theme.transitionBuilder,
      backgroundSemanticLabel: widget.backgroundSemanticLabel ??
          theme.backgroundSemanticLabel ??
          ExpandableAnimationDefaults.backgroundSemanticLabel,
      hoverScale: widget.hoverScale ??
          theme.hoverScale ??
          ExpandableAnimationDefaults.hoverScale,
    );
  }

  const ResolvedExpandableAnimation._({
    required this.child,
    required this.expandedBuilder,
    required this.mode,
    required this.duration,
    required this.reverseDuration,
    required this.curve,
    required this.reverseCurve,
    required this.physics,
    required this.borderRadius,
    required this.expandedBorderRadius,
    required this.collapsedColor,
    required this.expandedColor,
    required this.backgroundColor,
    required this.backgroundOpacity,
    required this.backgroundBlur,
    required this.dismissOnBackgroundTap,
    required this.enableDragToDismiss,
    required this.gestureConfig,
    required this.hideSourceWhileExpanded,
    required this.useRootNavigator,
    required this.respectReducedMotion,
    required this.transitionBuilder,
    required this.backgroundSemanticLabel,
    required this.hoverScale,
  });

  /// See `ExpandableAnimation.child`.
  final Widget child;

  /// See `ExpandableAnimation.expandedBuilder`.
  final WidgetBuilder expandedBuilder;

  /// See `ExpandableAnimation.mode`.
  final ExpandableAnimationMode mode;

  /// See `ExpandableAnimation.duration`.
  final Duration duration;

  /// See `ExpandableAnimation.reverseDuration`.
  final Duration? reverseDuration;

  /// See `ExpandableAnimation.curve`.
  final Curve curve;

  /// See `ExpandableAnimation.reverseCurve`.
  final Curve? reverseCurve;

  /// See `ExpandableAnimation.physics`.
  final ExpandableAnimationPhysics? physics;

  /// See `ExpandableAnimation.borderRadius`.
  final BorderRadius borderRadius;

  /// See `ExpandableAnimation.expandedBorderRadius`.
  final BorderRadius expandedBorderRadius;

  /// See `ExpandableAnimation.collapsedColor`.
  final Color? collapsedColor;

  /// See `ExpandableAnimation.expandedColor`.
  final Color? expandedColor;

  /// See `ExpandableAnimation.backgroundColor`.
  final Color backgroundColor;

  /// See `ExpandableAnimation.backgroundOpacity`.
  final double backgroundOpacity;

  /// See `ExpandableAnimation.backgroundBlur`.
  final double backgroundBlur;

  /// See `ExpandableAnimation.dismissOnBackgroundTap`.
  final bool dismissOnBackgroundTap;

  /// See `ExpandableAnimation.enableDragToDismiss`.
  final bool enableDragToDismiss;

  /// See `ExpandableAnimation.gestureConfig`.
  final ExpandableAnimationGestureConfig gestureConfig;

  /// See `ExpandableAnimation.hideSourceWhileExpanded`.
  final bool hideSourceWhileExpanded;

  /// See `ExpandableAnimation.useRootNavigator`.
  final bool useRootNavigator;

  /// See `ExpandableAnimation.respectReducedMotion`.
  final bool respectReducedMotion;

  /// See `ExpandableAnimation.transitionBuilder`.
  final ExpandableAnimationTransitionBuilder? transitionBuilder;

  /// See `ExpandableAnimation.backgroundSemanticLabel`.
  final String backgroundSemanticLabel;

  /// See `ExpandableAnimation.hoverScale`.
  final double hoverScale;
}
