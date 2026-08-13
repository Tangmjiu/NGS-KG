// Copyright (c) 2025-2026 mjiutang
// SPDX-License-Identifier: MIT
//
// 手表 MiniPlayer — 底部胶囊，封面 + 歌名 + 播放态呼吸条 + 顶部进度线

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/player_provider.dart';
import '../theme/watch_theme.dart';
import 'watch_cover_art.dart';

/// 手表 MiniPlayer（M3E 风格）。
///
/// 胶囊形容器：顶部 2px 进度线，内部封面缩略图 + 歌名/歌手 +
/// 播放中呼吸条指示。点击跳全屏播放器（由父级处理 onTap）。
class WatchMiniPlayer extends StatelessWidget {
  const WatchMiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<PlayerProvider>(
      builder: (context, player, _) {
        final song = player.currentSong;
        if (song == null) return const SizedBox.shrink();

        final colorScheme = Theme.of(context).colorScheme;
        final progress = player.progress.clamp(0.0, 1.0);

        return Container(
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(WatchShapeTokens.full),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── 顶部进度线 ──
              SizedBox(
                height: 2,
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 2,
                  backgroundColor: Colors.transparent,
                ),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                child: Row(
                  children: [
                    WatchCoverArt(imageUrl: song.albumCoverUrl, size: 28),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            song.name,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            song.artistDisplay,
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: colorScheme.onSurface
                                          .withValues(alpha: 0.6),
                                    ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    _PlayingIndicator(
                        isPlaying: player.isPlaying,
                        color: colorScheme.primary),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// 播放态指示：播放中为三根起伏的呼吸条，暂停时为暂停图标。
class _PlayingIndicator extends StatefulWidget {
  final bool isPlaying;
  final Color color;

  const _PlayingIndicator({required this.isPlaying, required this.color});

  @override
  State<_PlayingIndicator> createState() => _PlayingIndicatorState();
}

class _PlayingIndicatorState extends State<_PlayingIndicator>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;

  @override
  void initState() {
    super.initState();
    if (widget.isPlaying) {
      _controller = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 900),
      )..repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant _PlayingIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    final ctrl = _controller;
    if (ctrl == null) return;
    if (widget.isPlaying && !ctrl.isAnimating) {
      ctrl.repeat(reverse: true);
    } else if (!widget.isPlaying && ctrl.isAnimating) {
      ctrl.stop();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isPlaying) {
      return Icon(Icons.pause_rounded, size: 16, color: widget.color);
    }
    final ctrl = _controller;
    if (ctrl == null) {
      return Icon(Icons.play_arrow_rounded, size: 16, color: widget.color);
    }
    return AnimatedBuilder(
      animation: ctrl,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: List.generate(3, (i) {
            final phase = (ctrl.value + i * 0.33) % 1.0;
            final height = 5 + 9 * (phase < 0.5 ? phase * 2 : (1 - phase) * 2);
            return Container(
              width: 3,
              height: height,
              margin: const EdgeInsets.symmetric(horizontal: 1),
              decoration: BoxDecoration(
                color: widget.color,
                borderRadius: BorderRadius.circular(1.5),
              ),
            );
          }),
        );
      },
    );
  }
}
