import 'dart:math' as math;

import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/physics.dart';

/// Spring physics for an `ExpandableAnimation` transition.
///
/// By default an expansion is time-based, using `duration` and `curve`. Pass
/// an [ExpandableAnimationPhysics] as `physics` to drive the expansion with a
/// spring instead. The spring's settle time replaces `duration`, and the
/// spring shape replaces `curve`.
///
/// Springs with a [dampingRatio] below `1.0` overshoot: the expanded view
/// briefly grows past its bounds before settling, which gives a lively,
/// physical feel. Collapsing always uses a critically damped version of the
/// same spring so the view never shrinks past its source widget.
///
/// ```dart
/// ExpandableAnimation(
///   physics: ExpandableAnimationPhysics.bouncy,
///   expandedBuilder: (context) => const ArticlePage(),
///   child: const ArticleCard(),
/// )
/// ```
@immutable
class ExpandableAnimationPhysics {
  /// Creates spring physics from a mass, stiffness and damping ratio.
  ///
  /// A [dampingRatio] of `1.0` is critically damped (no overshoot). Lower
  /// values overshoot more; values above `1.0` approach the target more
  /// slowly.
  const ExpandableAnimationPhysics.spring({
    this.mass = 1.0,
    this.stiffness = 180.0,
    this.dampingRatio = 0.85,
  })  : assert(mass > 0, 'mass must be positive.'),
        assert(stiffness > 0, 'stiffness must be positive.'),
        assert(dampingRatio > 0, 'dampingRatio must be positive.');

  /// A critically damped spring that settles without overshoot.
  static const ExpandableAnimationPhysics smooth =
      ExpandableAnimationPhysics.spring(stiffness: 170, dampingRatio: 1.0);

  /// A spring with a gentle overshoot.
  static const ExpandableAnimationPhysics bouncy =
      ExpandableAnimationPhysics.spring(stiffness: 200, dampingRatio: 0.72);

  /// A stiff spring that settles quickly with a small overshoot.
  static const ExpandableAnimationPhysics snappy =
      ExpandableAnimationPhysics.spring(stiffness: 400, dampingRatio: 0.88);

  /// The mass of the simulated object. Defaults to `1.0`.
  final double mass;

  /// The spring constant. Higher values settle faster. Defaults to `180`.
  final double stiffness;

  /// The damping ratio. `1.0` is critically damped. Defaults to `0.85`.
  final double dampingRatio;

  /// The longest settle time any spring may produce, so that very soft
  /// springs cannot keep a transition running indefinitely.
  static const Duration maxSettleDuration = Duration(seconds: 3);

  /// The [SpringDescription] used for expansion.
  SpringDescription get description => SpringDescription.withDampingRatio(
        mass: mass,
        stiffness: stiffness,
        ratio: dampingRatio,
      );

  /// The [SpringDescription] used for collapse: the same spring, but never
  /// underdamped.
  SpringDescription get reverseDescription =>
      SpringDescription.withDampingRatio(
        mass: mass,
        stiffness: stiffness,
        ratio: math.max(1.0, dampingRatio),
      );

  /// How long the expansion spring takes to settle.
  Duration get settleDuration => springSettleDuration(description);

  /// How long the collapse spring takes to settle.
  Duration get reverseSettleDuration =>
      springSettleDuration(reverseDescription);

  /// A curve that follows the expansion spring over [settleDuration].
  Curve get curve => SpringCurve(description);

  /// A curve that follows the collapse spring over [reverseSettleDuration].
  ///
  /// Used as a reverse curve, which Flutter evaluates with time flowing
  /// backwards; see [SpringCurve.flipped].
  Curve get reverseCurve => SpringCurve(reverseDescription).flipped;

  /// Creates a copy of these physics with the given fields replaced.
  ExpandableAnimationPhysics copyWith({
    double? mass,
    double? stiffness,
    double? dampingRatio,
  }) {
    return ExpandableAnimationPhysics.spring(
      mass: mass ?? this.mass,
      stiffness: stiffness ?? this.stiffness,
      dampingRatio: dampingRatio ?? this.dampingRatio,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ExpandableAnimationPhysics &&
      other.mass == mass &&
      other.stiffness == stiffness &&
      other.dampingRatio == dampingRatio;

  @override
  int get hashCode => Object.hash(mass, stiffness, dampingRatio);

  @override
  String toString() => 'ExpandableAnimationPhysics.spring(mass: $mass, '
      'stiffness: $stiffness, dampingRatio: $dampingRatio)';
}

/// The tolerance used to decide when a transition spring has settled, in
/// units of transition progress (0 to 1).
const Tolerance _settleTolerance = Tolerance(distance: 0.001, velocity: 0.01);

/// The time step used when searching for a spring's settle time.
const double _settleStepSeconds = 1 / 240;

/// Returns how long a unit spring (from 0 to 1, at rest) takes to settle
/// within a 0.1% tolerance, capped at
/// [ExpandableAnimationPhysics.maxSettleDuration].
@visibleForTesting
Duration springSettleDuration(SpringDescription spring) {
  final SpringSimulation simulation = SpringSimulation(
    spring,
    0,
    1,
    0,
    tolerance: _settleTolerance,
  );
  final double maxSeconds =
      ExpandableAnimationPhysics.maxSettleDuration.inMicroseconds /
          Duration.microsecondsPerSecond;
  double t = _settleStepSeconds;
  while (t < maxSeconds && !simulation.isDone(t)) {
    t += _settleStepSeconds;
  }
  return Duration(
    microseconds:
        (math.min(t, maxSeconds) * Duration.microsecondsPerSecond).round(),
  );
}

/// Bounds, in radians per second, for the natural frequency searched by
/// [criticallyDampedSpring].
const double _kMinOmega = 0.5;
const double _kMaxOmega = 2000;

/// Returns a critically damped spring (mass 1) that settles from rest in
/// about [settle], using the same tolerance as [springSettleDuration].
///
/// Used for velocity-matched collapses when no [ExpandableAnimationPhysics]
/// is configured, so the configured reverse duration keeps its meaning.
SpringDescription criticallyDampedSpring(Duration settle) {
  SpringDescription spring(double omega) =>
      SpringDescription.withDampingRatio(mass: 1, stiffness: omega * omega);
  // Settle time decreases monotonically as the frequency rises.
  double low = _kMinOmega;
  double high = _kMaxOmega;
  for (int i = 0; i < 24; i++) {
    final double mid = math.sqrt(low * high);
    if (springSettleDuration(spring(mid)) > settle) {
      low = mid;
    } else {
      high = mid;
    }
  }
  return spring(high);
}

/// The duration and curve of a spring that moves a transition value from
/// `from` to 0, starting at `velocity` (value per second).
///
/// Expressed as a curve over a fixed duration so it can drive
/// `AnimationController.animateBack`, which (unlike `animateBackWith`) is
/// available on every supported Flutter version.
({Duration duration, Curve curve}) springCollapseMotion(
  SpringDescription spring, {
  required double from,
  required double velocity,
}) {
  final SpringSimulation simulation = SpringSimulation(
    spring,
    from,
    0,
    velocity,
    tolerance: _settleTolerance,
  );
  final double maxSeconds =
      ExpandableAnimationPhysics.maxSettleDuration.inMicroseconds /
          Duration.microsecondsPerSecond;
  double t = _settleStepSeconds;
  while (t < maxSeconds && !simulation.isDone(t)) {
    t += _settleStepSeconds;
  }
  final double seconds = math.min(t, maxSeconds);
  return (
    duration: Duration(
      microseconds: (seconds * Duration.microsecondsPerSecond).round(),
    ),
    curve: _CollapseSpringCurve(simulation, seconds, from),
  );
}

/// Maps normalized time to the fraction of the way from `from` to 0 that a
/// spring simulation has travelled.
class _CollapseSpringCurve extends Curve {
  const _CollapseSpringCurve(this.simulation, this.seconds, this.from);

  final SpringSimulation simulation;
  final double seconds;
  final double from;

  @override
  double transformInternal(double t) {
    if (from <= 0) {
      return 1;
    }
    return (from - simulation.x(t * seconds)) / from;
  }
}

/// A [Curve] that follows a spring moving from 0 to 1 starting at rest.
///
/// The curve is stretched over the spring's settle time (see
/// [springSettleDuration]), so pair it with that duration for physically
/// accurate motion. Underdamped springs produce values above `1.0` while they
/// overshoot.
class SpringCurve extends Curve {
  /// Creates a curve that follows [spring].
  SpringCurve(this.spring)
      : _simulation = SpringSimulation(
          spring,
          0,
          1,
          0,
          tolerance: _settleTolerance,
        ),
        _seconds = springSettleDuration(spring).inMicroseconds /
            Duration.microsecondsPerSecond;

  /// The spring this curve follows.
  final SpringDescription spring;

  final SpringSimulation _simulation;
  final double _seconds;

  @override
  double transformInternal(double t) => _simulation.x(t * _seconds);

  @override
  String toString() => 'SpringCurve($spring)';
}
