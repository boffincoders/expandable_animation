// Transitions are started without awaiting so tests can pump frames.
// ignore_for_file: unawaited_futures

import 'package:expandable_animation/expandable_animation.dart';
import 'package:expandable_animation_example/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

ExpandableAnimationController _controllerOf(
    WidgetTester tester, Finder finder) {
  return ExpandableAnimation.of(tester.element(finder));
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> openDemo(WidgetTester tester, String route) async {
    await tester.pumpWidget(ShowcaseApp(initialRoute: route));
    await tester.pumpAndSettle();
  }

  testWidgets('home lists every demo and opens one',
      (WidgetTester tester) async {
    await openDemo(tester, '/');
    for (final Demo demo in demos.take(3)) {
      expect(find.text(demo.title), findsOneWidget);
    }
    await tester.tap(find.text(demos.first.title));
    await tester.pumpAndSettle();
    expect(find.text('Aurora Headphones'), findsOneWidget);
  });

  testWidgets('product card expands, adds to bag and collapses',
      (WidgetTester tester) async {
    await openDemo(tester, '/product-card');
    await tester.tap(find.text('Aurora Headphones'));
    await tester.pumpAndSettle();
    expect(find.text('Quantity'), findsOneWidget);

    await tester.ensureVisible(find.byTooltip('Increase quantity'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Increase quantity'));
    await tester.pump();
    expect(find.textContaining('Add to bag · \$498'), findsOneWidget);

    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.text('Quantity'), findsNothing);
  });

  testWidgets('music player keeps playback state across the transition',
      (WidgetTester tester) async {
    await openDemo(tester, '/music-player');
    await tester.tap(find.byTooltip('Play'));
    await tester.pump();
    await tester.tap(find.text('Night Drive').last);
    await tester.pumpAndSettle();
    expect(find.text('Now playing'), findsOneWidget);
    // The full player shows the same playing state as the mini player.
    expect(find.byTooltip('Pause'), findsWidgets);

    // Drag the player down to dismiss it.
    await tester.fling(find.text('Now playing'), const Offset(0, 400), 2000);
    await tester.pumpAndSettle();
    expect(find.text('Now playing'), findsNothing);
    expect(find.byTooltip('Pause'), findsOneWidget);
  });

  testWidgets('photo opens and collapses back into the grid',
      (WidgetTester tester) async {
    await openDemo(tester, '/photo-gallery');
    final Finder thumb = find.bySemanticsLabel('Open photo 2');
    final Rect before = tester.getRect(thumb);
    await tester.tap(thumb);
    await tester.pumpAndSettle();
    expect(find.text('Photo 2'), findsOneWidget);

    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.text('Photo 2'), findsNothing);
    expect(tester.getRect(thumb), before);
  });

  testWidgets('repeated and rapid expansion never stacks views',
      (WidgetTester tester) async {
    await openDemo(tester, '/profile-card');
    final Finder card = find.text('Avery Stone');
    for (int i = 0; i < 3; i++) {
      await tester.tap(card.first);
      await tester.pumpAndSettle();
      expect(find.text('Follow'), findsOneWidget);
      // Tapping the dimmed background closes the dialog-mode panel.
      await tester.tapAt(const Offset(5, 300));
      await tester.pumpAndSettle();
      expect(find.text('Follow'), findsNothing);
    }
    // Rapid taps may open and close the panel, but never stack panels.
    for (int i = 0; i < 6; i++) {
      await tester.tap(card.first, warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 30));
      expect(find.text('Follow').evaluate().length, lessThanOrEqualTo(1));
    }
    await tester.pumpAndSettle();
    expect(find.text('Follow').evaluate().length, lessThanOrEqualTo(1));
  });

  testWidgets('navigating back during a transition cleans up',
      (WidgetTester tester) async {
    await openDemo(tester, '/app-store-cards');
    final Finder card = find.text('Designing calm interfaces');
    final ExpandableAnimationController controller =
        _controllerOf(tester, card.first);
    controller.expand();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(controller.isAnimating, isTrue);

    // System back while expanding collapses the card.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(controller.isCollapsed, isTrue);

    // A second back leaves the demo page entirely.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Expandable Animation'), findsWidgets);
  });

  testWidgets('playground generates code for the selected options',
      (WidgetTester tester) async {
    await openDemo(tester, '/playground');
    String code() => tester
        .widget<SelectableText>(find.byKey(const Key('playground-code')))
        .data!;
    expect(code(), startsWith('ExpandableAnimation('));
    expect(code(), isNot(contains('physics')));
    await tester.ensureVisible(find.text('Spring'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Spring'));
    await tester.pumpAndSettle();
    expect(code(), contains('ExpandableAnimationPhysics.spring'));
    await tester.ensureVisible(find.text('Tap to expand'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tap to expand'));
    await tester.pumpAndSettle();
    expect(find.text('Expanded view'), findsOneWidget);
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.text('Expanded view'), findsNothing);
  });
}
