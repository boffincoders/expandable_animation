import 'package:expandable_animation/expandable_animation.dart';
import 'package:flutter/material.dart';

/// A round close button that collapses the nearest [ExpandableAnimation].
class CollapseButton extends StatelessWidget {
  const CollapseButton(
      {super.key, this.icon = Icons.close, this.onDark = false});

  final IconData icon;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return IconButton.filledTonal(
      tooltip: 'Close',
      style: onDark
          ? IconButton.styleFrom(
              backgroundColor: Colors.black.withValues(alpha: 0.4),
              foregroundColor: Colors.white,
            )
          : IconButton.styleFrom(
              backgroundColor:
                  scheme.surfaceContainerHighest.withValues(alpha: 0.9),
            ),
      onPressed: () => ExpandableAnimation.of(context).collapse(),
      icon: Icon(icon),
    );
  }
}

/// A small pill-shaped drag handle that hints at drag-to-dismiss.
class DragHandle extends StatelessWidget {
  const DragHandle({super.key, this.color});

  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 40,
        height: 5,
        margin: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color ??
              Theme.of(context)
                  .colorScheme
                  .onSurfaceVariant
                  .withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(3),
        ),
      ),
    );
  }
}

/// Scaffold used by every demo page: title, description and a centered,
/// width-limited body.
class DemoScaffold extends StatelessWidget {
  const DemoScaffold({
    super.key,
    required this.title,
    required this.description,
    required this.child,
    this.bottom,
  });

  final String title;
  final String description;
  final Widget child;
  final Widget? bottom;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      bottomNavigationBar: bottom,
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: CustomScrollView(
            slivers: <Widget>[
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                sliver: SliverToBoxAdapter(
                  child: Text(
                    description,
                    style: text.bodyLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                sliver: SliverToBoxAdapter(child: child),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
