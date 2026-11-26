import 'package:expandable_animation/expandable_animation.dart';
import 'package:flutter/material.dart';

import '../widgets/common.dart';
import '../widgets/generated_art.dart';

const List<List<Color>> _palettes = <List<Color>>[
  <Color>[Color(0xFFFF9A9E), Color(0xFFFAD0C4)],
  <Color>[Color(0xFFA18CD1), Color(0xFFFBC2EB)],
  <Color>[Color(0xFF84FAB0), Color(0xFF8FD3F4)],
  <Color>[Color(0xFFFCCB90), Color(0xFFD57EEB)],
  <Color>[Color(0xFF43E97B), Color(0xFF38F9D7)],
  <Color>[Color(0xFFFA709A), Color(0xFFFEE140)],
  <Color>[Color(0xFF30CFD0), Color(0xFF330867)],
  <Color>[Color(0xFF5EE7DF), Color(0xFFB490CA)],
  <Color>[Color(0xFFD299C2), Color(0xFFFEF9D7)],
];

Rect _fitSquare(ExpandedBoundsContext bounds) {
  final Rect area = bounds.safeArea;
  final double side = area.shortestSide;
  return Rect.fromCenter(center: area.center, width: side, height: side);
}

/// Thumbnails that expand into an immersive fullscreen image viewer.
class PhotoGalleryDemo extends StatelessWidget {
  const PhotoGalleryDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return DemoScaffold(
      title: 'Fullscreen image transition',
      description: 'Tap a thumbnail to open it over a black background, then '
          'drag it down, tap outside it or press back to send it to its exact '
          'place in the grid.',
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 180,
          mainAxisSpacing: 6,
          crossAxisSpacing: 6,
        ),
        itemCount: 18,
        itemBuilder: (BuildContext context, int index) {
          final List<Color> colors = _palettes[index % _palettes.length];
          return ExpandableAnimation(
            // Expand to the image's final on-screen square, so the thumbnail
            // morphs straight into the full image with no cross-fade offset.
            mode: const ExpandableAnimationMode.custom(_fitSquare),
            borderRadius: BorderRadius.circular(10),
            backgroundOpacity: 1,
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
            gestureConfig: const ExpandableAnimationGestureConfig(
              minScale: 0.7,
              dragResistance: 1,
            ),
            semanticLabel: 'Open photo ${index + 1}',
            expandedBuilder: (BuildContext context) =>
                PhotoViewer(index: index, colors: colors),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: GeneratedArt(seed: 100 + index, colors: colors),
            ),
          );
        },
      ),
    );
  }
}

class PhotoViewer extends StatelessWidget {
  const PhotoViewer({super.key, required this.index, required this.colors});

  final int index;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        GeneratedArt(
          seed: 100 + index,
          colors: colors,
          semanticLabel: 'Photo ${index + 1}',
        ),
        const Positioned(
          top: 12,
          right: 12,
          child: CollapseButton(onDark: true),
        ),
        Positioned(
          left: 16,
          bottom: 16,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Text(
                'Photo ${index + 1}',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(color: Colors.white),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
