// Copyright (c) 2025-2026 mjiutang
// SPDX-License-Identifier: MIT

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';

import '../utils/format.dart';
import 'watch_album_backdrop.dart';

/// The artwork fills the glass. Only the interactive face is inset.
class WatchPlaybackBackdrop extends StatelessWidget {
  const WatchPlaybackBackdrop({super.key, this.art, required this.tone});

  final String? art;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Stack(
        fit: StackFit.expand,
        children: [
          WatchAlbumBackdrop(art: art, tone: tone),
          IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -.04),
                  radius: .57,
                  colors: [
                    Color.lerp(Colors.black, tone, .32)!.withValues(alpha: .82),
                    Color.lerp(Colors.black, tone, .17)!.withValues(alpha: .84),
                    const Color(0xfa000000),
                  ],
                  stops: const [0, .55, 1],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class WatchTransportFace extends StatelessWidget {
  const WatchTransportFace({
    super.key,
    required this.title,
    required this.subtitle,
    required this.playing,
    required this.progress,
    required this.onPrevious,
    required this.onToggle,
    required this.onNext,
    required this.onLyrics,
    required this.onOptions,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.tone = const Color(0xffa7cbcc),
    this.fm = false,
    this.lyric,
  });

  final String title, subtitle;
  final String? lyric;
  final bool playing, fm;
  final double progress;
  final Duration position, duration;
  final Color tone;
  final VoidCallback onPrevious, onToggle, onNext, onLyrics, onOptions;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, bounds) {
        final width = math.min(bounds.maxWidth, 288.0);
        final compact = width < 164;
        final dial = math.min(width - 96, width * .36).clamp(48.0, 84.0);
        final pastel = Color.lerp(tone, Colors.white, .58)!;
        final actions = [
          _action(
            fm ? Icons.thumb_down_outlined : Icons.skip_previous_rounded,
            fm ? '不喜欢，跳过' : '上一首',
            onPrevious,
          ),
          SizedBox.square(
            dimension: dial,
            child: Stack(
              fit: StackFit.expand,
              children: [
                _action(
                  playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  playing ? '暂停' : '播放',
                  onToggle,
                  diameter: dial,
                  disc: true,
                ),
                IgnorePointer(
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: CircularProgressIndicator(
                      value: progress.clamp(0.0, 1.0),
                      strokeWidth: compact ? 3 : 4,
                      strokeCap: StrokeCap.round,
                      color: pastel,
                      backgroundColor: const Color(0x36ffffff),
                      semanticsLabel: '播放进度',
                    ),
                  ),
                ),
              ],
            ),
          ),
          _action(Icons.skip_next_rounded, '下一首', onNext),
        ];
        return Center(
          child: SizedBox(
            width: width,
            child: SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: bounds.maxHeight),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: compact ? 15 : 18,
                        height: 1.15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    if (subtitle.isNotEmpty)
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 12,
                          height: 1.15,
                          color: Color(0xffc1cccb),
                        ),
                      ),
                    SizedBox(height: compact ? 4 : 6),
                    if (width >= 144)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: actions,
                      )
                    else
                      Wrap(alignment: WrapAlignment.center, children: actions),
                    SizedBox(
                      height: 48,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Align(
                            alignment: Alignment.topCenter,
                            child: Text(
                              '${formatWatchDuration(position)} / ${formatWatchDuration(duration)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 10,
                                height: 1.4,
                                fontFeatures: [FontFeature.tabularFigures()],
                                color: Colors.white70,
                              ),
                            ),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _action(Icons.lyrics_outlined, '歌词', onLyrics),
                              _action(
                                Icons.more_vert_rounded,
                                '更多操作',
                                onOptions,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (bounds.maxHeight >= 220 && lyric?.isNotEmpty == true)
                      Text(
                        lyric!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: pastel),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _action(
    IconData icon,
    String label,
    VoidCallback action, {
    double diameter = 48,
    bool disc = false,
  }) {
    return SizedBox.square(
      dimension: diameter,
      child: IconButton(
        tooltip: label,
        onPressed: action,
        style: IconButton.styleFrom(
          padding: EdgeInsets.zero,
          shape: const CircleBorder(),
          foregroundColor: Colors.white,
          backgroundColor: disc ? const Color(0x24ffffff) : Colors.transparent,
        ),
        icon: Icon(icon, size: disc ? diameter * .48 : 22),
      ),
    );
  }
}

@Preview(
  name: '紧凑圆屏 · 192dp',
  size: Size(192, 192),
  brightness: Brightness.dark,
)
@Preview(name: '大圆屏 · 225dp', size: Size(225, 225), brightness: Brightness.dark)
Widget transportPreview() => LayoutBuilder(
  builder: (context, bounds) {
    return ClipOval(
      child: Material(
        color: Colors.black,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const WatchPlaybackBackdrop(tone: Color(0xff729b9d)),
            Padding(
              padding: EdgeInsets.all(bounds.biggest.shortestSide * .12),
              child: WatchTransportFace(
                title: '夜空中最亮的星',
                subtitle: '逃跑计划',
                playing: true,
                progress: .42,
                position: const Duration(seconds: 59),
                duration: const Duration(minutes: 2, seconds: 20),
                onPrevious: () {},
                onToggle: () {},
                onNext: () {},
                onLyrics: () {},
                onOptions: () {},
              ),
            ),
          ],
        ),
      ),
    );
  },
);
