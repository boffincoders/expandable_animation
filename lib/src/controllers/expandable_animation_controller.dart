import 'package:flutter/foundation.dart';

import '../models/expandable_animation_phase.dart';

/// The object an [ExpandableAnimationController] drives.
///
/// Implemented by the `ExpandableAnimation` widget state. Not part of the
/// public API.
abstract interface class ExpandableAnimationDelegate {
  /// Starts expanding. Completes when the expansion ends or is interrupted.
  Future<void> expand();

  /// Starts collapsing. Completes when the collapse ends or is interrupted.
  Future<void> collapse();
}

/// Controls an `ExpandableAnimation` programmatically and reports its state.
///
/// Create a controller, pass it to exactly one `ExpandableAnimation`, and
/// dispose it in the `State` that owns it:
///
/// ```dart
/// class _ProductTileState extends State<ProductTile> {
///   final controller = ExpandableAnimationController();
///
///   @override
///   void dispose() {
///     controller.dispose();
///     super.dispose();
///   }
///
///   @override
///   Widget build(BuildContext context) {
///     return ExpandableAnimation(
///       controller: controller,
///       expandedBuilder: (context) => ProductDetails(
///         onClose: controller.collapse,
///       ),
///       child: const ProductCard(),
///     );
///   }
/// }
/// ```
///
/// The controller is a [ChangeNotifier]. It notifies listeners when [phase]
/// or [isDragging] changes and on every frame while [progress] changes, so it
/// can drive a `ListenableBuilder`.
///
/// If you do not pass a controller, `ExpandableAnimation` creates one
/// internally. Descendants of the source widget and of the expanded view can
/// reach it with `ExpandableAnimation.of(context)`.
///
/// ## Interruption semantics
///
/// * [expand] while [ExpandableAnimationPhase.expanding] or
///   [ExpandableAnimationPhase.expanded] does nothing and returns a future
///   that completes when the current expansion ends.
/// * [expand] while [ExpandableAnimationPhase.collapsing] reverses the
///   collapse from its current position.
/// * [collapse] while [ExpandableAnimationPhase.expanding] reverses the
///   expansion from its current position.
/// * [collapse] while collapsed does nothing.
///
/// Every returned future completes, never with an error, once the requested
/// transition finishes or is interrupted by an opposite request.
class ExpandableAnimationController extends ChangeNotifier {
  /// Creates a controller for an `ExpandableAnimation`.
  ExpandableAnimationController();

  ExpandableAnimationDelegate? _delegate;
  ExpandableAnimationPhase _phase = ExpandableAnimationPhase.collapsed;
  double _progress = 0;
  bool _isDragging = false;
  bool _disposed = false;

  /// The current lifecycle phase.
  ExpandableAnimationPhase get phase => _phase;

  /// How far the transition has progressed, from `0.0` (collapsed) to `1.0`
  /// (expanded).
  ///
  /// This is linear in time; the visual position also depends on the curve
  /// or spring. While the user drags to dismiss, progress decreases as the
  /// drag approaches its full extent.
  double get progress => _progress;

  /// Whether the user is currently dragging the expanded view to dismiss it.
  bool get isDragging => _isDragging;

  /// Whether the expanded view is fully expanded.
  bool get isExpanded => _phase == ExpandableAnimationPhase.expanded;

  /// Whether nothing is expanded.
  bool get isCollapsed => _phase == ExpandableAnimationPhase.collapsed;

  /// Whether a transition is currently running.
  bool get isAnimating => _phase.isAnimating;

  /// Whether this controller is attached to a mounted `ExpandableAnimation`.
  bool get isAttached => _delegate != null;

  /// Expands the attached widget.
  ///
  /// Returns a future that completes when the expansion finishes or is
  /// interrupted. Does nothing when the controller is not attached.
  Future<void> expand() {
    assert(_debugAssertNotDisposed());
    return _delegate?.expand() ?? Future<void>.value();
  }

  /// Collapses the attached widget back into its source position.
  ///
  /// Returns a future that completes when the collapse finishes or is
  /// interrupted. Does nothing when the controller is not attached.
  Future<void> collapse() {
    assert(_debugAssertNotDisposed());
    return _delegate?.collapse() ?? Future<void>.value();
  }

  /// Expands when collapsed or collapsing; collapses otherwise.
  Future<void> toggle() {
    switch (_phase) {
      case ExpandableAnimationPhase.collapsed:
      case ExpandableAnimationPhase.collapsing:
        return expand();
      case ExpandableAnimationPhase.expanding:
      case ExpandableAnimationPhase.expanded:
        return collapse();
    }
  }

  bool _debugAssertNotDisposed() {
    assert(() {
      if (_disposed) {
        throw FlutterError(
          'An ExpandableAnimationController was used after being disposed.\n'
          'Once you have called dispose() on a controller, it can no longer '
          'be used.',
        );
      }
      return true;
    }());
    return true;
  }

  void _update({
    ExpandableAnimationPhase? phase,
    double? progress,
    bool? isDragging,
  }) {
    if (_disposed) {
      return;
    }
    bool changed = false;
    if (phase != null && phase != _phase) {
      _phase = phase;
      changed = true;
    }
    if (progress != null && progress != _progress) {
      _progress = progress;
      changed = true;
    }
    if (isDragging != null && isDragging != _isDragging) {
      _isDragging = isDragging;
      changed = true;
    }
    if (changed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _delegate = null;
    super.dispose();
  }

  @override
  String toString() => '${describeIdentity(this)}(phase: ${_phase.name}, '
      'progress: ${_progress.toStringAsFixed(3)}, isDragging: $_isDragging)';
}

/// Attaches [controller] to [delegate]. Internal; not exported.
void attachExpandableController(
  ExpandableAnimationController controller,
  ExpandableAnimationDelegate delegate,
) {
  assert(
    controller._delegate == null || identical(controller._delegate, delegate),
    'An ExpandableAnimationController can only be attached to one '
    'ExpandableAnimation at a time.',
  );
  controller._delegate = delegate;
}

/// Detaches [controller] from [delegate] if it is still attached to it.
/// Internal; not exported.
void detachExpandableController(
  ExpandableAnimationController controller,
  ExpandableAnimationDelegate delegate,
) {
  if (identical(controller._delegate, delegate)) {
    controller._delegate = null;
  }
}

/// Pushes new state into [controller]. Internal; not exported.
void updateExpandableController(
  ExpandableAnimationController controller, {
  ExpandableAnimationPhase? phase,
  double? progress,
  bool? isDragging,
}) {
  controller._update(phase: phase, progress: progress, isDragging: isDragging);
}

/// Whether [controller] has been disposed. Internal; not exported.
bool isExpandableControllerDisposed(ExpandableAnimationController controller) =>
    controller._disposed;
