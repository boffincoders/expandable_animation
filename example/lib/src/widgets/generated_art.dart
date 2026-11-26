import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Deterministic abstract artwork generated from a [seed].
///
/// The showcase uses this instead of photos so it ships no third-party image
/// assets and needs no network access.
class GeneratedArt extends StatelessWidget {
  const GeneratedArt({
    super.key,
    required this.seed,
    required this.colors,
    this.semanticLabel,
  });

  /// Selects the shape layout.
  final int seed;

  /// Two or more colors used for the gradient and shapes.
  final List<Color> colors;

  /// Describes the artwork for screen readers.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final Widget art = CustomPaint(
      painter: _ArtPainter(seed: seed, colors: colors),
      child: const SizedBox.expand(),
    );
    if (semanticLabel == null) {
      return ExcludeSemantics(child: art);
    }
    return Semantics(image: true, label: semanticLabel, child: art);
  }
}

class _ArtPainter extends CustomPainter {
  _ArtPainter({required this.seed, required this.colors});

  final int seed;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ).createShader(rect),
    );
    final math.Random random = math.Random(seed);
    final double base = size.shortestSide;
    for (int i = 0; i < 6; i++) {
      final Offset center = Offset(
        random.nextDouble() * size.width,
        random.nextDouble() * size.height,
      );
      final double radius = base * (0.15 + random.nextDouble() * 0.45);
      final Color color = colors[(i + 1) % colors.length];
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..shader = RadialGradient(
            colors: <Color>[
              Color.lerp(color, Colors.white, 0.35)!.withValues(alpha: 0.55),
              color.withValues(alpha: 0),
            ],
          ).createShader(Rect.fromCircle(center: center, radius: radius)),
      );
    }
    // A soft horizon line gives the abstract shapes some depth.
    final Path wave = Path()..moveTo(0, size.height * 0.75);
    for (double x = 0; x <= size.width; x += size.width / 8) {
      wave.lineTo(
        x,
        size.height *
            (0.72 + 0.05 * math.sin(x / size.width * math.pi * 2 + seed)),
      );
    }
    wave
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      wave,
      Paint()..color = Colors.black.withValues(alpha: 0.12),
    );
  }

  @override
  bool shouldRepaint(_ArtPainter oldDelegate) =>
      oldDelegate.seed != seed || oldDelegate.colors != colors;
}

/// A tiny line chart used by the dashboard demo.
class Sparkline extends StatelessWidget {
  const Sparkline({
    super.key,
    required this.values,
    required this.color,
    this.strokeWidth = 2.5,
    this.fill = true,
  });

  final List<double> values;
  final Color color;
  final double strokeWidth;
  final bool fill;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: CustomPaint(
        painter: _SparklinePainter(
          values: values,
          color: color,
          strokeWidth: strokeWidth,
          fill: fill,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter({
    required this.values,
    required this.color,
    required this.strokeWidth,
    required this.fill,
  });

  final List<double> values;
  final Color color;
  final double strokeWidth;
  final bool fill;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) {
      return;
    }
    final double minValue = values.reduce(math.min);
    final double maxValue = values.reduce(math.max);
    final double span =
        (maxValue - minValue).abs() < 1e-9 ? 1 : maxValue - minValue;
    Offset point(int i) => Offset(
          size.width * i / (values.length - 1),
          size.height -
              (values[i] - minValue) / span * size.height * 0.9 -
              size.height * 0.05,
        );
    final Path line = Path()..moveTo(point(0).dx, point(0).dy);
    for (int i = 1; i < values.length; i++) {
      final Offset previous = point(i - 1);
      final Offset current = point(i);
      final double midX = (previous.dx + current.dx) / 2;
      line.cubicTo(midX, previous.dy, midX, current.dy, current.dx, current.dy);
    }
    if (fill) {
      final Path area = Path.from(line)
        ..lineTo(size.width, size.height)
        ..lineTo(0, size.height)
        ..close();
      canvas.drawPath(
        area,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              color.withValues(alpha: 0.35),
              color.withValues(alpha: 0),
            ],
          ).createShader(Offset.zero & size),
      );
    }
    canvas.drawPath(
      line,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_SparklinePainter oldDelegate) =>
      oldDelegate.values != values || oldDelegate.color != color;
}
