import 'dart:async';

import 'package:expandable_animation/expandable_animation.dart';
import 'package:flutter/material.dart';

import '../widgets/common.dart';
import '../widgets/generated_art.dart';

class Track {
  const Track(this.title, this.artist, this.seconds, this.seed, this.colors);

  final String title;
  final String artist;
  final int seconds;
  final int seed;
  final List<Color> colors;
}

const List<Track> tracks = <Track>[
  Track('Night Drive', 'Pale Harbor', 214, 5,
      <Color>[Color(0xFF141E30), Color(0xFF243B55), Color(0xFF8E54E9)]),
  Track('Glass Gardens', 'Mira Vale', 187, 13,
      <Color>[Color(0xFF00B4DB), Color(0xFF0083B0), Color(0xFFB2FEFA)]),
  Track('Slow Orbit', 'Northbound', 243, 21,
      <Color>[Color(0xFFEE0979), Color(0xFFFF6A00), Color(0xFFFFE259)]),
  Track('Paper Moons', 'The Quiet Hours', 199, 2,
      <Color>[Color(0xFF654EA3), Color(0xFFEAAFC8), Color(0xFFFFFFFF)]),
];

/// Playback state that lives outside the transition, so the mini player and
/// the full player always show the same track and position, and playback
/// continues while the player expands or collapses.
class PlaybackModel extends ChangeNotifier {
  int _index = 0;
  int _position = 42;
  bool _playing = false;
  Timer? _timer;

  Track get track => tracks[_index];
  int get position => _position;
  bool get isPlaying => _playing;

  void toggle() {
    _playing = !_playing;
    _timer?.cancel();
    if (_playing) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        _position++;
        if (_position >= track.seconds) {
          next();
        }
        notifyListeners();
      });
    }
    notifyListeners();
  }

  void select(int index) {
    _index = index;
    _position = 0;
    notifyListeners();
  }

  void next() => select((_index + 1) % tracks.length);

  void previous() => select((_index - 1 + tracks.length) % tracks.length);

  void seek(double fraction) {
    _position = (fraction * track.seconds).round();
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

String _time(int seconds) =>
    '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';

/// A mini player that expands into a fullscreen music player.
class MusicPlayerDemo extends StatefulWidget {
  const MusicPlayerDemo({super.key});

  @override
  State<MusicPlayerDemo> createState() => _MusicPlayerDemoState();
}

class _MusicPlayerDemoState extends State<MusicPlayerDemo> {
  final PlaybackModel _playback = PlaybackModel();
  final ExpandableAnimationController _controller =
      ExpandableAnimationController();

  @override
  void dispose() {
    _playback.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return DemoScaffold(
      title: 'Expandable music player',
      description: 'The mini player expands into a fullscreen player with '
          'artwork and controls. Playback state is shared, so music keeps '
          'playing while it expands and collapses. Drag the player down to '
          'dismiss it.',
      bottom: SafeArea(
        minimum: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: ExpandableAnimation(
          controller: _controller,
          borderRadius: BorderRadius.circular(18),
          collapsedColor: theme.colorScheme.surfaceContainerHighest,
          expandedColor: const Color(0xFF0E0E14),
          physics: ExpandableAnimationPhysics.smooth,
          semanticLabel: 'Open player',
          expandedBuilder: (BuildContext context) =>
              FullPlayer(playback: _playback),
          child: MiniPlayer(playback: _playback),
        ),
      ),
      child: Column(
        children: <Widget>[
          for (int i = 0; i < tracks.length; i++)
            ListTile(
              contentPadding: const EdgeInsets.symmetric(vertical: 4),
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox.square(
                  dimension: 52,
                  child: GeneratedArt(
                      seed: tracks[i].seed, colors: tracks[i].colors),
                ),
              ),
              title: Text(tracks[i].title),
              subtitle: Text(tracks[i].artist),
              trailing: Text(_time(tracks[i].seconds)),
              onTap: () {
                _playback.select(i);
                if (!_playback.isPlaying) {
                  _playback.toggle();
                }
                _controller.expand();
              },
            ),
        ],
      ),
    );
  }
}

class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key, required this.playback});

  final PlaybackModel playback;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return ListenableBuilder(
      listenable: playback,
      builder: (BuildContext context, Widget? child) {
        final Track track = playback.track;
        return Container(
          height: 68,
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(18),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            children: <Widget>[
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox.square(
                  dimension: 48,
                  child: GeneratedArt(seed: track.seed, colors: track.colors),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(track.title,
                        style: theme.textTheme.titleSmall, maxLines: 1),
                    Text(track.artist,
                        style: theme.textTheme.bodySmall, maxLines: 1),
                  ],
                ),
              ),
              IconButton(
                tooltip: playback.isPlaying ? 'Pause' : 'Play',
                onPressed: playback.toggle,
                icon: Icon(playback.isPlaying
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded),
              ),
              IconButton(
                tooltip: 'Next track',
                onPressed: playback.next,
                icon: const Icon(Icons.skip_next_rounded),
              ),
            ],
          ),
        );
      },
    );
  }
}

class FullPlayer extends StatelessWidget {
  const FullPlayer({super.key, required this.playback});

  final PlaybackModel playback;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = ThemeData(
      brightness: Brightness.dark,
      colorSchemeSeed: const Color(0xFF8E54E9),
    );
    return Theme(
      data: theme,
      child: Material(
        color: const Color(0xFF0E0E14),
        child: SafeArea(
          child: ListenableBuilder(
            listenable: playback,
            builder: (BuildContext context, Widget? child) {
              final Track track = playback.track;
              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            const CollapseButton(
                                icon: Icons.keyboard_arrow_down_rounded),
                            Expanded(
                              child: Text(
                                'Now playing',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.titleSmall,
                              ),
                            ),
                            const SizedBox(width: 48),
                          ],
                        ),
                        // The artwork takes whatever height is left, so the
                        // player fits short landscape and desktop windows.
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Center(
                              child: AspectRatio(
                                aspectRatio: 1,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(28),
                                  child: GeneratedArt(
                                    seed: track.seed,
                                    colors: track.colors,
                                    semanticLabel: 'Artwork for ${track.title}',
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Text(track.title, style: theme.textTheme.headlineSmall),
                        const SizedBox(height: 4),
                        Text(track.artist,
                            style: theme.textTheme.titleMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant)),
                        const SizedBox(height: 20),
                        Slider(
                          value: (playback.position / track.seconds)
                              .clamp(0.0, 1.0),
                          onChanged: playback.seek,
                          semanticFormatterCallback: (double value) =>
                              _time((value * track.seconds).round()),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: <Widget>[
                              Text(_time(playback.position)),
                              Text(_time(track.seconds)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: <Widget>[
                            IconButton(
                              tooltip: 'Previous track',
                              iconSize: 40,
                              onPressed: playback.previous,
                              icon: const Icon(Icons.skip_previous_rounded),
                            ),
                            IconButton.filled(
                              tooltip: playback.isPlaying ? 'Pause' : 'Play',
                              iconSize: 48,
                              onPressed: playback.toggle,
                              icon: Icon(playback.isPlaying
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded),
                            ),
                            IconButton(
                              tooltip: 'Next track',
                              iconSize: 40,
                              onPressed: playback.next,
                              icon: const Icon(Icons.skip_next_rounded),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
