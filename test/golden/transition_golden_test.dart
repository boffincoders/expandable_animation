@Tags(<String>['golden'])
library;

// Transitions are started without awaiting so tests can pump frames.
// ignore_for_file: unawaited_futures

import 'package:expandable_animation/expandable_animation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

const Color _card = Color(0xFF3F51B5);
const Color _page = Color(0xFFFFF8E1);
const Color _accent = Color(0xFFFF7043);

Widget _app(
  ExpandableAnimationController controller, {
  ExpandableAnimationMode mode = const ExpandableAnimationMode.fullscreen(),
}) {
  return WidgetsApp(
    color: const Color(0xFFFFFFFF),
    debugShowCheckedModeBanner: false,
    pageRouteBuilder: <T>(RouteSettings settings, WidgetBuilder builder) =>
        PageRouteBuilder<T>(
      settings: settings,
      pageBuilder: (BuildContext context, _, __) => builder(context),
    ),
    home: ColoredBox(
      color: const Color(0xFFECEFF1),
      child: Center(
        child: ExpandableAnimation(
          controller: controller,
          mode: mode,
          curve: Curves.linear,
          borderRadius: BorderRadius.circular(24),
          expandedBorderRadius: BorderRadius.circular(
            mode == const ExpandableAnimationMode.fullscreen() ? 0 : 32,
          ),
          collapsedColor: _card,
          expandedColor: _page,
          backgroundOpacity: 0.4,
          expandedBuilder: (BuildContext context) => Align(
            alignment: Alignment.topCenter,
            child: Container(
              margin: const EdgeInsets.all(24),
              height: 120,
              decoration: BoxDecoration(
                color: _accent,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          child: Container(
            width: 220,
            height: 140,
            decoration: BoxDecoration(
              color: _card,
              borderRadius: BorderRadius.circular(24),
            ),
            alignment: Alignment.center,
            child: Container(width: 60, height: 60, color: _accent),
          ),
        ),
      ),
    ),
  );
}

void main() {
  late ExpandableAnimationController controller;

  setUp(() => controller = ExpandableAnimationController());
  tearDown(() => controller.dispose());

  Future<void> pumpApp(WidgetTester tester, Widget app) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app);
  }

  testWidgets('collapsed, mid-transition and expanded fullscreen',
      (WidgetTester tester) async {
    await pumpApp(tester, _app(controller));
    await expectLater(
      find.byType(WidgetsApp),
      matchesGoldenFile('goldens/fullscreen_0_collapsed.png'),
    );
    controller.expand();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await expectLater(
      find.byType(WidgetsApp),
      matchesGoldenFile('goldens/fullscreen_1_mid.png'),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(WidgetsApp),
      matchesGoldenFile('goldens/fullscreen_2_expanded.png'),
    );
  });

  testWidgets('dialog mode with scrim', (WidgetTester tester) async {
    await pumpApp(
      tester,
      _app(controller, mode: const ExpandableAnimationMode.dialog()),
    );
    controller.expand();
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(WidgetsApp),
      matchesGoldenFile('goldens/dialog_expanded.png'),
    );
  });

  testWidgets('dragging to dismiss', (WidgetTester tester) async {
    await pumpApp(tester, _app(controller));
    controller.expand();
    await tester.pumpAndSettle();
    final TestGesture gesture =
        await tester.startGesture(const Offset(180, 300));
    await gesture.moveBy(const Offset(0, 20));
    await gesture.moveBy(const Offset(0, 140));
    await tester.pump();
    await expectLater(
      find.byType(WidgetsApp),
      matchesGoldenFile('goldens/fullscreen_3_dragging.png'),
    );
    await gesture.up();
    await tester.pumpAndSettle();
  });
}
