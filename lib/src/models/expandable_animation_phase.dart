/// The lifecycle phase of an `ExpandableAnimation`.
///
/// A transition always moves through the phases in this order:
///
/// ```text
/// collapsed -> expanding -> expanded -> collapsing -> collapsed
/// ```
///
/// An expansion can be interrupted: calling `collapse()` while
/// [expanding] moves straight to [collapsing], and calling `expand()` while
/// [collapsing] moves straight back to [expanding].
///
/// Interactive drag-to-dismiss is not a separate phase. While the user drags
/// an expanded view the phase stays [expanded] and
/// `ExpandableAnimationController.isDragging` is `true`.
enum ExpandableAnimationPhase {
  /// The source widget is shown in place and nothing is expanded.
  collapsed,

  /// The source widget is animating towards its expanded bounds.
  expanding,

  /// The expanded view is fully shown and interactive.
  expanded,

  /// The expanded view is animating back into the source widget.
  collapsing;

  /// Whether an expanded view is on screen in any form.
  ///
  /// This is `true` for every phase except [collapsed].
  bool get isOpen => this != ExpandableAnimationPhase.collapsed;

  /// Whether a transition is currently running.
  bool get isAnimating =>
      this == ExpandableAnimationPhase.expanding ||
      this == ExpandableAnimationPhase.collapsing;
}
