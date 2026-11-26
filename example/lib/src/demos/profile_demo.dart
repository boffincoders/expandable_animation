import 'package:expandable_animation/expandable_animation.dart';
import 'package:flutter/material.dart';

import '../widgets/common.dart';
import '../widgets/generated_art.dart';

class Person {
  const Person(this.name, this.role, this.location, this.seed, this.colors);

  final String name;
  final String role;
  final String location;
  final int seed;
  final List<Color> colors;

  String get initials =>
      name.split(' ').map((String part) => part.characters.first).join();
}

const List<Person> people = <Person>[
  Person('Avery Stone', 'Product designer', 'Lisbon', 61,
      <Color>[Color(0xFFFF512F), Color(0xFFDD2476)]),
  Person('Jordan Lee', 'Mobile engineer', 'Toronto', 72,
      <Color>[Color(0xFF1FA2FF), Color(0xFF12D8FA), Color(0xFFA6FFCB)]),
  Person('Sam Rivera', 'Motion designer', 'Mexico City', 83,
      <Color>[Color(0xFF7F00FF), Color(0xFFE100FF)]),
];

/// Compact profile cards that expand into a centered profile panel.
class ProfileDemo extends StatelessWidget {
  const ProfileDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return DemoScaffold(
      title: 'Expandable profile card',
      description: 'A compact profile expands into a detailed profile panel '
          'using dialog mode: centered, size-capped on large screens and over '
          'a blurred background. Tap outside the panel to close it.',
      child: Wrap(
        spacing: 16,
        runSpacing: 16,
        children: <Widget>[
          for (final Person person in people)
            SizedBox(
              width: 320,
              child: ExpandableAnimation(
                mode: const ExpandableAnimationMode.dialog(
                  maxSize: Size(440, 620),
                ),
                borderRadius: BorderRadius.circular(16),
                expandedBorderRadius: BorderRadius.circular(28),
                collapsedColor:
                    Theme.of(context).colorScheme.surfaceContainerHigh,
                expandedColor: Theme.of(context).colorScheme.surfaceContainer,
                backgroundBlur: 8,
                backgroundOpacity: 0.35,
                semanticLabel: 'Open profile of ${person.name}',
                expandedBuilder: (BuildContext context) =>
                    ProfileDetails(person: person),
                child: ProfileTile(person: person),
              ),
            ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.person, required this.size});

  final Person person;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: SizedBox.square(
        dimension: size,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            GeneratedArt(seed: person.seed, colors: person.colors),
            Center(
              child: Text(
                person.initials,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: size * 0.36,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ProfileTile extends StatelessWidget {
  const ProfileTile({super.key, required this.person});

  final Person person;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: <Widget>[
          _Avatar(person: person, size: 52),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(person.name, style: theme.textTheme.titleMedium),
                Text(person.role, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
          const Icon(Icons.chevron_right),
        ],
      ),
    );
  }
}

class ProfileDetails extends StatelessWidget {
  const ProfileDetails({super.key, required this.person});

  final Person person;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Material(
      type: MaterialType.transparency,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        children: <Widget>[
          const Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: <Widget>[CollapseButton()],
          ),
          Center(child: _Avatar(person: person, size: 112)),
          const SizedBox(height: 16),
          Text(person.name,
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall),
          Text('${person.role} · ${person.location}',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 24),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: <Widget>[
              _Stat(label: 'Projects', value: '48'),
              _Stat(label: 'Followers', value: '12.4k'),
              _Stat(label: 'Following', value: '310'),
            ],
          ),
          const SizedBox(height: 24),
          Text('About', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            'Loves crafting interfaces that feel physical and alive. '
            'Currently exploring gesture-driven navigation and spring '
            'physics for mobile and desktop apps.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          Row(
            children: <Widget>[
              Expanded(
                child: FilledButton(
                  onPressed: () {},
                  child: const Text('Follow'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: () {},
                  child: const Text('Message'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return Column(
      children: <Widget>[
        Text(value, style: text.titleLarge),
        Text(label, style: text.bodySmall),
      ],
    );
  }
}
