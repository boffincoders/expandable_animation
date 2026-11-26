import 'package:expandable_animation/src/widgets/expanded_surface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Key of the collapsed source card used across widget tests.
const Key sourceKey = Key('source');

/// Key of the expanded page used across widget tests.
const Key expandedKey = Key('expanded');

/// A simple collapsed card.
Widget sourceCard({String label = 'Card'}) {
  return SizedBox(
    key: sourceKey,
    width: 200,
    height: 100,
    child: ColoredBox(
      color: const Color(0xFF2196F3),
      child: Center(child: Text(label)),
    ),
  );
}

/// A simple expanded page with a close button.
Widget expandedPage(BuildContext context, {String label = 'Details'}) {
  return ColoredBox(
    key: expandedKey,
    color: const Color(0xFFFFFFFF),
    child: Center(
      child: TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: Text(label),
      ),
    ),
  );
}

/// Wraps [child] in a 400x800 MaterialApp with the source centered.
Widget harness(Widget child, {ThemeData? theme, bool center = true}) {
  return MaterialApp(
    theme: theme,
    home: Scaffold(body: center ? Center(child: child) : child),
  );
}

/// Sets a deterministic 400x800 test surface.
void usePhoneSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(400, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// Finds the morphing surface clip of the expanded route.
Finder get surfaceFinder => find
    .descendant(
      of: find.byType(ExpandedSurface),
      matching: find.byType(ClipRRect),
    )
    .first;

/// Whether an expanded route is currently in the tree.
bool isRouteShown() => find.byType(ExpandedSurface).evaluate().isNotEmpty;
