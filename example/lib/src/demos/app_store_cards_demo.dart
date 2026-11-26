import 'package:expandable_animation/expandable_animation.dart';
import 'package:flutter/material.dart';

import '../widgets/common.dart';
import '../widgets/generated_art.dart';

class Story {
  const Story(this.label, this.title, this.subtitle, this.seed, this.colors);

  final String label;
  final String title;
  final String subtitle;
  final int seed;
  final List<Color> colors;
}

const List<Story> stories = <Story>[
  Story(
      'Editor’s pick',
      'Designing calm interfaces',
      'How motion can guide attention without demanding it.',
      31,
      <Color>[Color(0xFF0F2027), Color(0xFF2C5364), Color(0xFF00C9A7)]),
  Story(
      'Behind the build',
      'The physics of a good swipe',
      'Velocity, thresholds and the art of letting go.',
      47,
      <Color>[Color(0xFF42275A), Color(0xFF734B6D), Color(0xFFFFB88C)]),
  Story(
      'Weekly guide',
      'Small screens, big stories',
      'Making detail views feel like a natural continuation.',
      58,
      <Color>[Color(0xFF1D976C), Color(0xFF93F9B9), Color(0xFFFFFFFF)]),
];

/// Editorial cards that morph into fullscreen articles with a spring.
class AppStoreCardsDemo extends StatelessWidget {
  const AppStoreCardsDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return DemoScaffold(
      title: 'App Store-style cards',
      description: 'Editorial cards morph into fullscreen articles with a '
          'spring. Scroll the article normally; pull down from the top to '
          'shrink the card and send it home.',
      child: Column(
        children: <Widget>[
          for (final Story story in stories)
            Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: AspectRatio(
                    aspectRatio: 0.85,
                    child: ExpandableAnimation(
                      borderRadius: BorderRadius.circular(24),
                      physics: ExpandableAnimationPhysics.snappy,
                      backgroundBlur: 6,
                      backgroundOpacity: 0.3,
                      collapsedColor: story.colors.first,
                      expandedColor: Theme.of(context).colorScheme.surface,
                      semanticLabel: 'Read ${story.title}',
                      expandedBuilder: (BuildContext context) =>
                          ArticlePage(story: story),
                      child: StoryCard(story: story),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class StoryCard extends StatelessWidget {
  const StoryCard({super.key, required this.story});

  final Story story;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          GeneratedArt(seed: story.seed, colors: story.colors),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(story.label.toUpperCase(),
                    style: text.labelLarge?.copyWith(color: Colors.white70)),
                const SizedBox(height: 6),
                Text(story.title,
                    style: text.headlineMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    )),
                const Spacer(),
                Text(story.subtitle,
                    style: text.bodyLarge?.copyWith(color: Colors.white)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ArticlePage extends StatelessWidget {
  const ArticlePage({super.key, required this.story});

  final Story story;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final double width = MediaQuery.sizeOf(context).width;
    return Material(
      color: theme.colorScheme.surface,
      child: Stack(
        children: <Widget>[
          CustomScrollView(
            slivers: <Widget>[
              SliverToBoxAdapter(
                child: SizedBox(
                  height: width.clamp(0, 600) / 0.85,
                  child: StoryCard(story: story),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 48),
                sliver: SliverList.list(
                  children: <Widget>[
                    for (int i = 0; i < 6; i++) ...<Widget>[
                      Text(
                        _headings[i % _headings.length],
                        style: theme.textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(_paragraph, style: theme.textTheme.bodyLarge),
                      const SizedBox(height: 24),
                    ],
                  ],
                ),
              ),
            ],
          ),
          Positioned(
            top: MediaQuery.paddingOf(context).top + 12,
            right: 16,
            child: const CollapseButton(onDark: true),
          ),
        ],
      ),
    );
  }
}

const List<String> _headings = <String>[
  'Start from where the user is',
  'Keep the object, change the context',
  'Let gestures be reversible',
];

const String _paragraph = 'A transition that starts from the element the '
    'user touched keeps their sense of place. The card grows into the page, '
    'its corners relax and its content gives way to the full story. When '
    'the reader is done, the same motion runs backwards, so the card lands '
    'exactly where it came from. Scroll this article as usual: the dismiss '
    'gesture only takes over when you pull down from the very top.';
