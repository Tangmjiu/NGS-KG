// Copyright (c) 2025-2026 mjiutang
// SPDX-License-Identifier: MIT

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wear_plus/wear_plus.dart';
import 'package:wearable_rotary/wearable_rotary.dart';

import '../../providers/player_provider.dart';
import '../utils/format.dart';
import '../utils/watch_layout.dart';
import '../utils/watch_motion.dart';
import '../widgets/round_list_tile.dart';
import '../widgets/watch_like_button.dart';
import '../widgets/watch_player_primitives.dart';
import '../widgets/watch_scaffold.dart';
import '../widgets/watch_transport_face.dart';
import 'lyrics_screen.dart';
import 'queue_screen.dart';

class WatchPlayerScreen extends StatefulWidget {
  const WatchPlayerScreen({super.key});

  @override
  State<WatchPlayerScreen> createState() => _WatchPlayerScreenState();
}

class _WatchPlayerScreenState extends State<WatchPlayerScreen> {
  late final StreamSubscription<RotaryEvent> _rotary;
  bool _ambient = false;
  double? _volumeFeedback;
  Timer? _hideVolume;

  @override
  void initState() {
    super.initState();
    _rotary = rotaryEvents.listen((event) {
      if (!mounted || _ambient || ModalRoute.of(context)?.isCurrent != true) {
        return;
      }
      final steps = ((event.magnitude ?? 25) / 25).clamp(1, 4).round();
      final delta = event.direction == RotaryDirection.clockwise ? .04 : -.04;
      _adjustVolume(steps * delta);
    });
  }

  void _adjustVolume(double delta) {
    final player = context.read<PlayerProvider>();
    final volume = ((_volumeFeedback ?? player.volume) + delta).clamp(0.0, 1.0);
    player.setVolume(volume);
    setState(() => _volumeFeedback = volume);
    _hideVolume?.cancel();
    _hideVolume = Timer(const Duration(milliseconds: 1300), () {
      if (mounted) setState(() => _volumeFeedback = null);
    });
  }

  @override
  void dispose() {
    _rotary.cancel();
    _hideVolume?.cancel();
    super.dispose();
  }

  void _open(Widget page) {
    WatchMotion.tap();
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    return AmbientMode(
      builder: (context, mode, _) {
        _ambient = mode == WearMode.ambient;
        if (_ambient) return const WatchChronoFace();
        final volume = _volumeFeedback;
        if (volume != null) {
          return _VolumeHalo(value: volume, onAdjust: _adjustVolume);
        }
        return Consumer<PlayerProvider>(
          builder: (context, player, _) {
            final song = player.currentSong;
            if (song == null) {
              return const WatchScaffold(
                showTime: false,
                body: WatchPlayerInsets(child: Center(child: Text('暂无播放'))),
              );
            }
            final tone = player.palette?.dominant ?? const Color(0xff81a6a6);
            final layout = WatchLayout.of(context);
            final lyricController = player.lyricController;
            final lines = lyricController.lyricNotifier.value?.lines;
            final index = lyricController.activeIndexNotifiter.value;
            final lyric = lines != null && index >= 0 && index < lines.length
                ? lines[index].text
                : null;
            return WatchScaffold(
              showTime: false,
              body: Stack(
                fit: StackFit.expand,
                children: [
                  WatchPlaybackBackdrop(art: song.albumCoverUrl, tone: tone),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onDoubleTap: player.togglePlayPause,
                  ),
                  if (layout.isRound)
                    Positioned(
                      top: math.max(4, layout.systemPadding.top),
                      left: 0,
                      right: 0,
                      child: const IgnorePointer(child: WatchTimeText()),
                    ),
                  WatchPlayerInsets(
                    child: WatchSpringReveal(
                      key: ValueKey((song.id, song.hash, song.filePath)),
                      child: WatchTransportFace(
                        title: song.name,
                        subtitle: player.isFmMode
                            ? '私人 FM · ${song.artistDisplay}'
                            : song.artistDisplay,
                        playing: player.isPlaying,
                        fm: player.isFmMode,
                        progress: player.progress,
                        position: player.position,
                        duration: player.duration,
                        lyric: lyric,
                        tone: tone,
                        onPrevious: player.playPrevious,
                        onNext: player.playNext,
                        onToggle: () {
                          WatchMotion.confirm();
                          player.togglePlayPause();
                        },
                        onLyrics: () => _open(const WatchLyricsScreen()),
                        onOptions: () => _open(const _PlayerOptions()),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _PlayerOptions extends StatefulWidget {
  const _PlayerOptions();

  @override
  State<_PlayerOptions> createState() => _PlayerOptionsState();
}

class _PlayerOptionsState extends State<_PlayerOptions> {
  double? _drag;
  static const speeds = [.5, .75, 1.0, 1.25, 1.5, 2.0];
  final ScrollController _scroll = RotaryScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();
    final song = player.currentSong;
    final duration = player.duration;
    final fraction = _drag ?? player.progress.clamp(0.0, 1.0);
    final elapsed = _drag == null ? player.position : duration * fraction;
    final modeLabel = switch (player.playMode) {
      PlayMode.shuffle => '随机播放',
      PlayMode.repeatOne => '单曲循环',
      PlayMode.radio => '电台播放',
      _ => '顺序播放',
    };
    return WatchScaffold(
      showTime: false,
      scrollController: _scroll,
      body: Stack(
        fit: StackFit.expand,
        children: [
          WatchPlaybackBackdrop(
            art: song?.albumCoverUrl,
            tone: player.palette?.dominant ?? const Color(0xff9789ae),
          ),
          WatchPlayerInsets(
            child: ListView(
              controller: _scroll,
              padding: EdgeInsets.zero,
              children: [
                Text(
                  '播放选项',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 6),
                Text(
                  '${formatWatchDuration(elapsed)} / ${formatWatchDuration(duration)}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                Slider(
                  value: fraction,
                  semanticFormatterCallback: (v) =>
                      formatWatchDuration(duration * v),
                  onChanged: duration > Duration.zero
                      ? (v) => setState(() => _drag = v)
                      : null,
                  onChangeEnd: (v) {
                    player.seek(duration * v);
                    setState(() => _drag = null);
                  },
                ),
                RoundListTile(
                  title: '播放队列',
                  subtitle: '${player.playlist.length} 首',
                  leading: const Icon(Icons.queue_music_rounded),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => const WatchQueueScreen(),
                    ),
                  ),
                ),
                if (song != null)
                  RoundListTile(
                    title: '收藏',
                    trailing: SizedBox.square(
                      dimension: 48,
                      child: WatchLikeButton(song: song),
                    ),
                  ),
                if (!player.isFmMode)
                  RoundListTile(
                    title: '播放模式',
                    subtitle: modeLabel,
                    leading: const Icon(Icons.repeat_rounded),
                    onTap: () => player.setPlayMode(switch (player.playMode) {
                      PlayMode.sequential => PlayMode.shuffle,
                      PlayMode.shuffle => PlayMode.repeatOne,
                      _ => PlayMode.sequential,
                    }),
                  ),
                RoundListTile(
                  title: '播放速度',
                  subtitle: '${player.currentSpeed}×',
                  leading: const Icon(Icons.speed_rounded),
                  onTap: () => player.setSpeed(
                    speeds[(speeds.indexOf(player.currentSpeed) + 1) %
                        speeds.length],
                  ),
                ),
                RoundListTile(
                  title: '音质',
                  subtitle: player.resolvedQualityLabel,
                  leading: const Icon(Icons.audiotrack_rounded),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VolumeHalo extends StatelessWidget {
  const _VolumeHalo({required this.value, required this.onAdjust});
  final double value;
  final ValueChanged<double> onAdjust;

  @override
  Widget build(BuildContext context) {
    final percent = '${(value * 100).round()}%';
    return WatchScaffold(
      showTime: false,
      body: CustomPaint(
        painter: _HaloArc(value),
        child: WatchPlayerInsets(
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox.square(
                  dimension: 48,
                  child: IconButton(
                    tooltip: '调低音量',
                    icon: const Icon(Icons.volume_down_rounded),
                    onPressed: () => onAdjust(-.04),
                  ),
                ),
                Flexible(
                  child: Semantics(
                    liveRegion: true,
                    label: '音量 $percent',
                    excludeSemantics: true,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 4,
                      ),
                      decoration: ShapeDecoration(
                        shape: StadiumBorder(
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: .4),
                          ),
                        ),
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          percent,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox.square(
                  dimension: 48,
                  child: IconButton(
                    tooltip: '调高音量',
                    icon: const Icon(Icons.volume_up_rounded),
                    onPressed: () => onAdjust(.04),
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

class _HaloArc extends CustomPainter {
  const _HaloArc(this.value);
  final double value;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromCircle(
      center: size.center(Offset.zero),
      radius: size.shortestSide * .477,
    );
    final pen = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3
      ..color = const Color(0xff332b30);
    const start = math.pi * .7;
    const sweep = -math.pi * .4;
    canvas.drawArc(rect, start, sweep, false, pen);
    pen.color = const Color(0xffdfb6c2);
    canvas.drawArc(rect, start, sweep * value, false, pen);
  }

  @override
  bool shouldRepaint(_HaloArc old) => old.value != value;
}

/// Ambient rendering has one timer aligned to the next minute and no audio ticker.
class WatchChronoFace extends StatefulWidget {
  const WatchChronoFace({super.key});

  @override
  State<WatchChronoFace> createState() => _WatchChronoFaceState();
}

class _WatchChronoFaceState extends State<WatchChronoFace> {
  Timer? _minute;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _scheduleMinute();
  }

  void _scheduleMinute() {
    final now = DateTime.now();
    _minute = Timer(
      Duration(seconds: 60 - now.second, milliseconds: -now.millisecond),
      () {
        if (!mounted) return;
        setState(() => _now = DateTime.now());
        _scheduleMinute();
      },
    );
  }

  @override
  void dispose() {
    _minute?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                radius: .54,
                colors: [Color(0xff221f16), Color(0xff100f0a), Colors.black],
              ),
            ),
          ),
          CustomPaint(painter: _MinuteMarks(_now.minute)),
          WatchPlayerInsets(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${_now.hour}:${_now.minute.toString().padLeft(2, '0')}',
                    style: const TextStyle(
                      fontFeatures: [FontFeature.tabularFigures()],
                      fontSize: 24,
                      height: 1.15,
                      fontWeight: FontWeight.w600,
                      color: Color(0xffbcb8ac),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: 42,
                    height: 1,
                    color: const Color(0xff706c5c),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MinuteMarks extends CustomPainter {
  const _MinuteMarks(this.minute);
  final int minute;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide * .478;
    final pen = Paint()..strokeCap = StrokeCap.round;
    for (var i = 0; i < 60; i++) {
      final unit = Offset.fromDirection(i * math.pi / 30 - math.pi / 2);
      final selected = i == minute;
      pen.color = selected ? const Color(0xff8d846b) : const Color(0xff2a2822);
      pen.strokeWidth = selected ? 2 : 1;
      canvas.drawLine(
        center + unit * (radius - (i % 5 == 0 || selected ? 3 : 1)),
        center + unit * radius,
        pen,
      );
    }
  }

  @override
  bool shouldRepaint(_MinuteMarks old) => old.minute != minute;
}
