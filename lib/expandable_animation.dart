/// Widget-to-fullscreen and card expansion animations for Flutter, with
/// container morphing, spring physics and interactive drag-to-dismiss.
///
/// Wrap any widget in an [ExpandableAnimation] and provide an
/// `expandedBuilder`:
///
/// ```dart
/// import 'package:expandable_animation/expandable_animation.dart';
///
/// ExpandableAnimation(
///   borderRadius: BorderRadius.circular(20),
///   expandedBuilder: (context) => const ProductDetails(),
///   child: const ProductCard(),
/// )
/// ```
///
/// Use an [ExpandableAnimationController] to expand and collapse from code,
/// an [ExpandableAnimationMode] to choose where the view expands to, and
/// [ExpandableAnimationPhysics] for spring-driven motion.
library;

export 'src/animation/expandable_animation_physics.dart'
    show ExpandableAnimationPhysics, SpringCurve;
export 'src/controllers/expandable_animation_controller.dart'
    show ExpandableAnimationController;
export 'src/models/expandable_animation_gesture_config.dart'
    show ExpandableAnimationGestureConfig;
export 'src/models/expandable_animation_mode.dart'
    show ExpandableAnimationMode, ExpandedBoundsContext, ExpandedBoundsResolver;
export 'src/models/expandable_animation_phase.dart'
    show ExpandableAnimationPhase;
export 'src/widgets/expandable_animation.dart'
    show ExpandableAnimation, ExpandableAnimationTransitionBuilder;
export 'src/widgets/expandable_animation_zoomable.dart'
    show ExpandableAnimationZoomable;
