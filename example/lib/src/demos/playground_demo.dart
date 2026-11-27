import 'package:expandable_animation/expandable_animation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../widgets/common.dart';
import '../widgets/generated_art.dart';

enum PlaygroundMode { fullscreen, dialog, sheet }

enum PlaygroundMotion { curve, spring }

const Map<String, Curve> playgroundCurves = <String, Curve>{
  'easeInOutCubic': Curves.easeInOutCubic,
  'easeOutCubic': Curves.easeOutCubic,
  'fastOutSlowIn': Curves.fastOutSlowIn,
  'easeOutBack': Curves.easeOutBack,
  'linear': Curves.linear,
};

/// Immutable playground settings plus the matching Dart snippet.
@immutable
class PlaygroundSettings {
  const PlaygroundSettings({
    this.mode = PlaygroundMode.fullscreen,
    this.motion = PlaygroundMotion.curve,
    this.durationMs = 400,
    this.curveName = 'easeInOutCubic',
    this.stiffness = 200,
    this.dampingRatio = 0.8,
    this.borderRadius = 24,
    this.backgroundBlur = 0,
    this.backgroundOpacity = 0.5,
    this.enableDragToDismiss = true,
    this.dismissThreshold = 0.2,
    this.velocityThreshold = 700,
    this.minScale = 0.85,
    this.haptics = true,
    this.matchVelocity = true,
  });

  final PlaygroundMode mode;
  final PlaygroundMotion motion;
  final int durationMs;
  final String curveName;
  final double stiffness;
  final double dampingRatio;
  final double borderRadius;
  final double backgroundBlur;
  final double backgroundOpacity;
  final bool enableDragToDismiss;
  final double dismissThreshold;
  final double velocityThreshold;
  final double minScale;
  final bool haptics;
  final bool matchVelocity;

  ExpandableAnimationMode get expandableMode => switch (mode) {
        PlaygroundMode.fullscreen => const ExpandableAnimationMode.fullscreen(),
        PlaygroundMode.dialog => const ExpandableAnimationMode.dialog(),
        PlaygroundMode.sheet => const ExpandableAnimationMode.sheet(),
      };

  ExpandableAnimationPhysics? get physics => motion == PlaygroundMotion.spring
      ? ExpandableAnimationPhysics.spring(
          stiffness: stiffness,
          dampingRatio: dampingRatio,
        )
      : null;

  ExpandableAnimationGestureConfig get gestureConfig =>
      ExpandableAnimationGestureConfig(
        dismissThreshold: dismissThreshold,
        velocityThreshold: velocityThreshold,
        minScale: minScale,
        enableHapticFeedback: haptics,
        matchReleaseVelocity: matchVelocity,
      );

  PlaygroundSettings copyWith({
    PlaygroundMode? mode,
    PlaygroundMotion? motion,
    int? durationMs,
    String? curveName,
    double? stiffness,
    double? dampingRatio,
    double? borderRadius,
    double? backgroundBlur,
    double? backgroundOpacity,
    bool? enableDragToDismiss,
    double? dismissThreshold,
    double? velocityThreshold,
    double? minScale,
    bool? haptics,
    bool? matchVelocity,
  }) {
    return PlaygroundSettings(
      mode: mode ?? this.mode,
      motion: motion ?? this.motion,
      durationMs: durationMs ?? this.durationMs,
      curveName: curveName ?? this.curveName,
      stiffness: stiffness ?? this.stiffness,
      dampingRatio: dampingRatio ?? this.dampingRatio,
      borderRadius: borderRadius ?? this.borderRadius,
      backgroundBlur: backgroundBlur ?? this.backgroundBlur,
      backgroundOpacity: backgroundOpacity ?? this.backgroundOpacity,
      enableDragToDismiss: enableDragToDismiss ?? this.enableDragToDismiss,
      dismissThreshold: dismissThreshold ?? this.dismissThreshold,
      velocityThreshold: velocityThreshold ?? this.velocityThreshold,
      minScale: minScale ?? this.minScale,
      haptics: haptics ?? this.haptics,
      matchVelocity: matchVelocity ?? this.matchVelocity,
    );
  }

  /// Dart code that reproduces these settings. Default values are omitted.
  String toCode() {
    const PlaygroundSettings d = PlaygroundSettings();
    String n(double value) => value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(2);
    final List<String> lines = <String>[];
    switch (mode) {
      case PlaygroundMode.fullscreen:
        break;
      case PlaygroundMode.dialog:
        lines.add('mode: const ExpandableAnimationMode.dialog(),');
      case PlaygroundMode.sheet:
        lines.add('mode: const ExpandableAnimationMode.sheet(),');
    }
    if (motion == PlaygroundMotion.spring) {
      lines.add('physics: const ExpandableAnimationPhysics.spring(\n'
          '    stiffness: ${n(stiffness)},\n'
          '    dampingRatio: ${n(dampingRatio)},\n'
          '  ),');
    } else {
      if (durationMs != d.durationMs) {
        lines.add('duration: const Duration(milliseconds: $durationMs),');
      }
      if (curveName != d.curveName) {
        lines.add('curve: Curves.$curveName,');
      }
    }
    if (borderRadius > 0) {
      lines.add('borderRadius: BorderRadius.circular(${n(borderRadius)}),');
    }
    if (mode != PlaygroundMode.fullscreen) {
      lines.add('expandedBorderRadius: BorderRadius.circular(28),');
    }
    if (backgroundBlur > 0) {
      lines.add('backgroundBlur: ${n(backgroundBlur)},');
    }
    if (backgroundOpacity != d.backgroundOpacity) {
      lines.add('backgroundOpacity: ${n(backgroundOpacity)},');
    }
    if (!enableDragToDismiss) {
      lines.add('enableDragToDismiss: false,');
    } else {
      final List<String> gesture = <String>[
        if (dismissThreshold != d.dismissThreshold)
          'dismissThreshold: ${n(dismissThreshold)},',
        if (velocityThreshold != d.velocityThreshold)
          'velocityThreshold: ${n(velocityThreshold)},',
        if (minScale != d.minScale) 'minScale: ${n(minScale)},',
        if (!haptics) 'enableHapticFeedback: false,',
        if (!matchVelocity) 'matchReleaseVelocity: false,',
      ];
      if (gesture.isNotEmpty) {
        lines.add('gestureConfig: const ExpandableAnimationGestureConfig(\n'
            '${gesture.map((String g) => '    $g').join('\n')}\n'
            '  ),');
      }
    }
    lines
      ..add('expandedBuilder: (context) => const DetailsPage(),')
      ..add('child: const PreviewCard(),');
    return 'ExpandableAnimation(\n${lines.map((String l) => '  $l').join('\n')}\n)';
  }
}

/// Interactive playground: tweak every option and copy the matching code.
class PlaygroundDemo extends StatefulWidget {
  const PlaygroundDemo({super.key});

  @override
  State<PlaygroundDemo> createState() => _PlaygroundDemoState();
}

class _PlaygroundDemoState extends State<PlaygroundDemo> {
  PlaygroundSettings _settings = const PlaygroundSettings();

  void _update(PlaygroundSettings settings) =>
      setState(() => _settings = settings);

  @override
  Widget build(BuildContext context) {
    return DemoScaffold(
      title: 'Custom transitions playground',
      description: 'Adjust duration, curve, spring, corners, background and '
          'gesture settings, try the result on the preview card and copy the '
          'generated Dart code.',
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final Widget controls =
              _Controls(settings: _settings, onChanged: _update);
          final Widget preview = Column(
            children: <Widget>[
              _Preview(settings: _settings),
              const SizedBox(height: 16),
              _CodeView(code: _settings.toCode()),
            ],
          );
          if (constraints.maxWidth > 820) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(child: controls),
                const SizedBox(width: 24),
                Expanded(child: preview),
              ],
            );
          }
          return Column(
            children: <Widget>[preview, const SizedBox(height: 24), controls],
          );
        },
      ),
    );
  }
}

class _Preview extends StatelessWidget {
  const _Preview({required this.settings});

  final PlaygroundSettings settings;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final BorderRadius radius = BorderRadius.circular(settings.borderRadius);
    return Center(
      child: SizedBox(
        width: 300,
        height: 190,
        child: ExpandableAnimation(
          key: const Key('playground-preview'),
          mode: settings.expandableMode,
          duration: Duration(milliseconds: settings.durationMs),
          curve: playgroundCurves[settings.curveName]!,
          physics: settings.physics,
          borderRadius: radius,
          expandedBorderRadius: settings.mode == PlaygroundMode.fullscreen
              ? BorderRadius.zero
              : BorderRadius.circular(28),
          backgroundBlur: settings.backgroundBlur,
          backgroundOpacity: settings.backgroundOpacity,
          enableDragToDismiss: settings.enableDragToDismiss,
          gestureConfig: settings.gestureConfig,
          collapsedColor: scheme.primaryContainer,
          expandedColor: scheme.surfaceContainer,
          semanticLabel: 'Open preview',
          expandedBuilder: (BuildContext context) => const _PreviewDetails(),
          child: ClipRRect(
            borderRadius: radius,
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                const GeneratedArt(
                  seed: 9,
                  colors: <Color>[Color(0xFF4568DC), Color(0xFFB06AB3)],
                ),
                Center(
                  child: Text(
                    'Tap to expand',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PreviewDetails extends StatelessWidget {
  const _PreviewDetails();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Material(
      type: MaterialType.transparency,
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: <Widget>[
            const DragHandle(),
            Row(
              children: <Widget>[
                Expanded(
                  child: Text('Expanded view',
                      style: theme.textTheme.headlineSmall),
                ),
                const CollapseButton(),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Drag down to dismiss, tap outside in dialog and sheet mode, '
              'press Escape or use the back button.',
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            for (int i = 1; i <= 20; i++)
              ListTile(
                leading: CircleAvatar(child: Text('$i')),
                title: Text('Scrollable row $i'),
              ),
          ],
        ),
      ),
    );
  }
}

class _CodeView extends StatelessWidget {
  const _CodeView({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child:
                    Text('Generated code', style: theme.textTheme.titleSmall),
              ),
              TextButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: code));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Code copied')),
                    );
                  }
                },
                icon: const Icon(Icons.copy_rounded, size: 18),
                label: const Text('Copy'),
              ),
            ],
          ),
          SelectableText(
            code,
            key: const Key('playground-code'),
            style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({required this.settings, required this.onChanged});

  final PlaygroundSettings settings;
  final ValueChanged<PlaygroundSettings> onChanged;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final PlaygroundSettings s = settings;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('Expansion mode', style: text.titleMedium),
        const SizedBox(height: 8),
        SegmentedButton<PlaygroundMode>(
          segments: const <ButtonSegment<PlaygroundMode>>[
            ButtonSegment<PlaygroundMode>(
                value: PlaygroundMode.fullscreen, label: Text('Fullscreen')),
            ButtonSegment<PlaygroundMode>(
                value: PlaygroundMode.dialog, label: Text('Dialog')),
            ButtonSegment<PlaygroundMode>(
                value: PlaygroundMode.sheet, label: Text('Sheet')),
          ],
          selected: <PlaygroundMode>{s.mode},
          onSelectionChanged: (Set<PlaygroundMode> value) =>
              onChanged(s.copyWith(mode: value.first)),
        ),
        const SizedBox(height: 20),
        Text('Motion', style: text.titleMedium),
        const SizedBox(height: 8),
        SegmentedButton<PlaygroundMotion>(
          segments: const <ButtonSegment<PlaygroundMotion>>[
            ButtonSegment<PlaygroundMotion>(
                value: PlaygroundMotion.curve, label: Text('Duration + curve')),
            ButtonSegment<PlaygroundMotion>(
                value: PlaygroundMotion.spring, label: Text('Spring')),
          ],
          selected: <PlaygroundMotion>{s.motion},
          onSelectionChanged: (Set<PlaygroundMotion> value) =>
              onChanged(s.copyWith(motion: value.first)),
        ),
        const SizedBox(height: 8),
        if (s.motion == PlaygroundMotion.curve) ...<Widget>[
          _SliderTile(
            label: 'Duration',
            value: s.durationMs.toDouble(),
            min: 100,
            max: 1500,
            divisions: 28,
            format: (double v) => '${v.round()} ms',
            onChanged: (double v) =>
                onChanged(s.copyWith(durationMs: v.round())),
          ),
          InputDecorator(
            decoration: const InputDecoration(labelText: 'Curve'),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: s.curveName,
                isDense: true,
                isExpanded: true,
                items: <DropdownMenuItem<String>>[
                  for (final String name in playgroundCurves.keys)
                    DropdownMenuItem<String>(value: name, child: Text(name)),
                ],
                onChanged: (String? v) => onChanged(s.copyWith(curveName: v)),
              ),
            ),
          ),
        ] else ...<Widget>[
          _SliderTile(
            label: 'Stiffness',
            value: s.stiffness,
            min: 50,
            max: 800,
            divisions: 30,
            format: (double v) => v.toStringAsFixed(0),
            onChanged: (double v) => onChanged(s.copyWith(stiffness: v)),
          ),
          _SliderTile(
            label: 'Damping ratio',
            value: s.dampingRatio,
            min: 0.4,
            max: 1.2,
            divisions: 16,
            format: (double v) => v.toStringAsFixed(2),
            onChanged: (double v) => onChanged(s.copyWith(dampingRatio: v)),
          ),
        ],
        const SizedBox(height: 12),
        Text('Shape and background', style: text.titleMedium),
        _SliderTile(
          label: 'Border radius',
          value: s.borderRadius,
          min: 0,
          max: 48,
          divisions: 12,
          format: (double v) => v.toStringAsFixed(0),
          onChanged: (double v) => onChanged(s.copyWith(borderRadius: v)),
        ),
        _SliderTile(
          label: 'Background blur',
          value: s.backgroundBlur,
          min: 0,
          max: 20,
          divisions: 20,
          format: (double v) => v.toStringAsFixed(0),
          onChanged: (double v) => onChanged(s.copyWith(backgroundBlur: v)),
        ),
        _SliderTile(
          label: 'Background opacity',
          value: s.backgroundOpacity,
          min: 0,
          max: 1,
          divisions: 20,
          format: (double v) => v.toStringAsFixed(2),
          onChanged: (double v) => onChanged(s.copyWith(backgroundOpacity: v)),
        ),
        const SizedBox(height: 12),
        Text('Gestures', style: text.titleMedium),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Drag to dismiss'),
          value: s.enableDragToDismiss,
          onChanged: (bool v) => onChanged(s.copyWith(enableDragToDismiss: v)),
        ),
        if (s.enableDragToDismiss) ...<Widget>[
          _SliderTile(
            label: 'Dismiss threshold',
            value: s.dismissThreshold,
            min: 0.05,
            max: 0.6,
            divisions: 11,
            format: (double v) => '${(v * 100).round()}% of height',
            onChanged: (double v) => onChanged(s.copyWith(dismissThreshold: v)),
          ),
          _SliderTile(
            label: 'Velocity threshold',
            value: s.velocityThreshold,
            min: 200,
            max: 2000,
            divisions: 18,
            format: (double v) => '${v.round()} px/s',
            onChanged: (double v) =>
                onChanged(s.copyWith(velocityThreshold: v)),
          ),
          _SliderTile(
            label: 'Minimum scale',
            value: s.minScale,
            min: 0.5,
            max: 1,
            divisions: 10,
            format: (double v) => v.toStringAsFixed(2),
            onChanged: (double v) => onChanged(s.copyWith(minScale: v)),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Haptic feedback'),
            value: s.haptics,
            onChanged: (bool v) => onChanged(s.copyWith(haptics: v)),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Carry flick speed into the collapse'),
            value: s.matchVelocity,
            onChanged: (bool v) => onChanged(s.copyWith(matchVelocity: v)),
          ),
        ],
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => onChanged(const PlaygroundSettings()),
            icon: const Icon(Icons.restart_alt),
            label: const Text('Reset to defaults'),
          ),
        ),
      ],
    );
  }
}

class _SliderTile extends StatelessWidget {
  const _SliderTile({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.format,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String Function(double value) format;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(child: Text(label)),
              Text(format(value)),
            ],
          ),
          Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: divisions,
            label: format(value),
            semanticFormatterCallback: format,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
