# Changelog

All notable changes to this package are documented here. This project follows
[Semantic Versioning](https://semver.org/).

## 0.1.0

Initial release.

- `ExpandableAnimation`: widget-to-fullscreen container transform with
  position, size, border radius and surface color interpolation.
- Expansion modes: fullscreen, dialog, sheet (partial expansion) and custom
  bounds. Dialog and sheet modes stay above the on-screen keyboard.
- Time-based motion (`duration`, `curve`) or spring physics
  (`ExpandableAnimationPhysics`) with `smooth`, `bouncy` and `snappy` presets.
- Background scrim with configurable color, opacity and optional blur.
- Interactive drag-to-dismiss with distance and velocity thresholds, spring
  settle-back, haptic feedback and scrollable-content coordination
  (`ExpandableAnimationGestureConfig`).
- `ExpandableAnimationController` with `expand`, `collapse`, `toggle`,
  `phase`, `progress` and `isDragging`; transitions can be interrupted and
  reversed in both directions.
- Lifecycle callbacks `onExpanded`, `onCollapsed` and `onPhaseChanged`.
- Back button, Escape key, `PopScope`, focus, keyboard activation, semantics
  and reduced-motion support.
- Custom layer transitions through `transitionBuilder`.
