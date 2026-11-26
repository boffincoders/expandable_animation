# Expandable Animation showcase

A Flutter app that demonstrates the
[`expandable_animation`](https://pub.dev/packages/expandable_animation)
package: widget-to-fullscreen transitions, container morphing and
interactive drag-to-dismiss.

| Demo | What it shows |
| --- | --- |
| Product card to fullscreen | Grid cards that morph into a product page |
| Expandable music player | Mini player to full player with shared playback state |
| Fullscreen image transition | Thumbnails that open into an image viewer (custom bounds) |
| App Store-style cards | Editorial cards that spring open into scrollable articles |
| Expandable profile card | Dialog mode with background blur |
| Dashboard widget expansion | Dialog on wide windows, fullscreen on phones |
| Expandable notifications | Sheet mode (partial expansion) with a text field |
| Transitions playground | Every option, live, with generated Dart code |

All artwork is generated in code; the app uses no network or image assets.

```bash
cd example
flutter run            # any device
flutter run -d chrome  # web
```

Deep links work on the web, for example `#/music-player` or `#/playground`.
