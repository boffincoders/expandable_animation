// Renders the README/website animations frame by frame from the real example
// app. Run through scripts/record_media.sh, which loads fonts and converts the
// frames to GIFs. Skipped unless MEDIA_OUTPUT_DIR is set.
@Tags(<String>['media'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:expandable_animation_example/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const Duration _frame = Duration(milliseconds: 40); // 25 fps
const Size _phone = Size(390, 844);
const double _pixelRatio = 1.5;

final String? _outputDir = Platform.environment['MEDIA_OUTPUT_DIR'];
final String? _fontsDir = Platform.environment['MEDIA_FONTS_DIR'];

// Android uses the bundled Roboto font; iOS system fonts are not available
// to the test renderer.
final TargetPlatformVariant _android =
    TargetPlatformVariant.only(TargetPlatform.android);

Future<void> _loadFonts() async {
  Future<ByteData> read(String file) async =>
      ByteData.sublistView(File('$_fontsDir/$file').readAsBytesSync());
  final FontLoader roboto = FontLoader('Roboto');
  for (final String weight in <String>['Regular', 'Medium', 'Bold', 'Light']) {
    roboto.addFont(read('Roboto-$weight.ttf'));
  }
  await roboto.load();
  await (FontLoader('MaterialIcons')
        ..addFont(read('MaterialIcons-Regular.otf')))
      .load();
}

class _Recorder {
  _Recorder(this.tester, this.name) {
    Directory('$_outputDir/$name').createSync(recursive: true);
  }

  final WidgetTester tester;
  final String name;
  final GlobalKey boundaryKey = GlobalKey();
  int _index = 0;

  Future<void> capture() async {
    final RenderRepaintBoundary boundary = boundaryKey.currentContext!
        .findRenderObject()! as RenderRepaintBoundary;
    final ByteData? bytes = await tester.runAsync<ByteData?>(() async {
      final ui.Image image = await boundary.toImage(pixelRatio: _pixelRatio);
      final ByteData? data =
          await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      return data;
    });
    final String file =
        '$_outputDir/$name/${(_index++).toString().padLeft(4, '0')}.png';
    File(file).writeAsBytesSync(bytes!.buffer.asUint8List());
  }

  /// Advances time by [duration], capturing every frame.
  Future<void> hold(Duration duration) async {
    final int frames = duration.inMilliseconds ~/ _frame.inMilliseconds;
    for (int i = 0; i < frames; i++) {
      await tester.pump(_frame);
      await capture();
    }
  }

  Future<void> tap(Finder finder) async {
    await tester.tap(finder);
    await tester.pump();
    await capture();
  }

  /// Drags from [start] by [offset] over [duration], capturing every frame,
  /// then releases.
  Future<void> drag(Offset start, Offset offset, Duration duration) async {
    final int steps = duration.inMilliseconds ~/ _frame.inMilliseconds;
    final TestGesture gesture = await tester.startGesture(start);
    Duration time = Duration.zero;
    for (int i = 1; i <= steps; i++) {
      // Ease-in-out finger motion looks more natural than a linear drag.
      final double t = Curves.easeInOut.transform(i / steps) -
          Curves.easeInOut.transform((i - 1) / steps);
      time += _frame;
      await gesture.moveBy(offset * t, timeStamp: time);
      await tester.pump(_frame);
      await capture();
    }
    await gesture.up(timeStamp: time);
    await tester.pump();
  }
}

void main() {
  final bool enabled = _outputDir != null && _fontsDir != null;

  setUpAll(() async {
    if (enabled) {
      await _loadFonts();
    }
  });

  Future<_Recorder> start(
      WidgetTester tester, String name, String route) async {
    tester.view.physicalSize = _phone * _pixelRatio;
    tester.view.devicePixelRatio = _pixelRatio;
    tester.view.padding = const FakeViewPadding(top: 47 * _pixelRatio);
    addTearDown(tester.view.reset);
    final _Recorder recorder = _Recorder(tester, name);
    await tester.pumpWidget(
      RepaintBoundary(
        key: recorder.boundaryKey,
        child: ShowcaseApp(initialRoute: route),
      ),
    );
    await tester.pumpAndSettle();
    await recorder.hold(const Duration(milliseconds: 600));
    return recorder;
  }

  testWidgets('card to fullscreen', skip: !enabled,
      (WidgetTester tester) async {
    final _Recorder r =
        await start(tester, 'card-to-fullscreen', '/product-card');
    await r.tap(find.text('Aurora Headphones'));
    await r.hold(const Duration(milliseconds: 1400));
    await r.drag(const Offset(195, 300), const Offset(0, 260),
        const Duration(milliseconds: 700));
    await r.hold(const Duration(milliseconds: 1000));
  });

  testWidgets('music player', skip: !enabled, variant: _android,
      (WidgetTester tester) async {
    final _Recorder r =
        await start(tester, 'expandable-music-player', '/music-player');
    await r.tap(find.text('Pale Harbor').last);
    await r.hold(const Duration(milliseconds: 1400));
    await r.drag(const Offset(195, 160), const Offset(0, 300),
        const Duration(milliseconds: 700));
    await r.hold(const Duration(milliseconds: 1000));
  });

  testWidgets('fullscreen image', skip: !enabled, variant: _android,
      (WidgetTester tester) async {
    final _Recorder r =
        await start(tester, 'fullscreen-image', '/photo-gallery');
    await r.tap(find.bySemanticsLabel('Open photo 5'));
    await r.hold(const Duration(milliseconds: 1200));
    await r.drag(const Offset(195, 420), const Offset(0, 240),
        const Duration(milliseconds: 600));
    await r.hold(const Duration(milliseconds: 900));
  });

  testWidgets('app store cards', skip: !enabled, variant: _android,
      (WidgetTester tester) async {
    final _Recorder r =
        await start(tester, 'app-store-card-animation', '/app-store-cards');
    await r.tap(find.text('Designing calm interfaces'));
    await r.hold(const Duration(milliseconds: 1400));
    await r.drag(const Offset(195, 600), const Offset(0, -260),
        const Duration(milliseconds: 600));
    await r.hold(const Duration(milliseconds: 500));
    await r.drag(const Offset(195, 300), const Offset(0, 260),
        const Duration(milliseconds: 600));
    await r.drag(const Offset(195, 300), const Offset(0, 280),
        const Duration(milliseconds: 700));
    await r.hold(const Duration(milliseconds: 1000));
  });

  testWidgets('notification sheet', skip: !enabled,
      (WidgetTester tester) async {
    final _Recorder r =
        await start(tester, 'expandable-sheet', '/notifications');
    await r.tap(find.text('Design review in 15 minutes'));
    await r.hold(const Duration(milliseconds: 1300));
    await r.tap(find.text('Dismiss'));
    await r.hold(const Duration(milliseconds: 1000));
  });
}
