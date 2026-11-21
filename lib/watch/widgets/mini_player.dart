// Copyright (c) 2025-2026 mjiutang
// SPDX-License-Identifier: MIT

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/player_provider.dart';
import '../utils/watch_motion.dart';
import 'watch_album_backdrop.dart';

/// The shell opens the player when the title is tapped. The trailing action
/// toggles playback without leaving the current page.
class WatchMiniPlayer extends StatelessWidget {
  const WatchMiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();
    final song = player.currentSong;
    if (song == null) return const SizedBox.shrink();

    final tone = player.palette?.dominant ?? const Color(0xff549a9e);
    final pastel = Color.lerp(tone, Colors.white, .54)!;
    return ClipRRect(
      borderRadius: BorderRadius.circular(100),
      child: CustomPaint(
        foregroundPainter: _CapsuleProgress(player.progress, pastel),
        child: Stack(
          children: [
            Positioned.fill(
              child: WatchAlbumBackdrop(art: song.albumCoverUrl, tone: tone),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color.lerp(
                        Colors.black,
                        tone,
                        .35,
                      )!.withValues(alpha: .84),
                      Color.lerp(
                        Colors.black,
                        tone,
                        .20,
                      )!.withValues(alpha: .84),
                    ],
                  ),
                ),
              ),
            ),
            Row(
              children: [
                const SizedBox(width: 14),
                Expanded(
                  child: Semantics(
                    button: true,
                    hint: '打开播放器',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          song.artistDisplay,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10,
                            height: 1.15,
                            color: pastel,
                          ),
                        ),
                        Text(
                          song.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            height: 1.2,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox.square(
                  dimension: 48,
                  child: IconButton(
                    tooltip: player.isPlaying ? '暂停' : '播放',
                    padding: EdgeInsets.zero,
                    icon: Icon(
                      player.isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                    onPressed: () {
                      WatchMotion.confirm();
                      player.togglePlayPause();
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CapsuleProgress extends CustomPainter {
  const _CapsuleProgress(this.progress, this.tone);
  final double progress;
  final Color tone;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(1.5);
    if (rect.isEmpty) return;
    final radius = math.min(rect.height, rect.width) / 2;
    final edge = Path()
      ..moveTo(rect.center.dx, rect.top)
      ..lineTo(rect.right - radius, rect.top)
      ..arcTo(
        Rect.fromCircle(
          center: Offset(rect.right - radius, rect.center.dy),
          radius: radius,
        ),
        -math.pi / 2,
        math.pi,
        false,
      )
      ..lineTo(rect.left + radius, rect.bottom)
      ..arcTo(
        Rect.fromCircle(
          center: Offset(rect.left + radius, rect.center.dy),
          radius: radius,
        ),
        math.pi / 2,
        math.pi,
        false,
      )
      ..close();
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2
      ..color = tone.withValues(alpha: .27);
    canvas.drawPath(edge, paint);
    final metric = edge.computeMetrics().first;
    paint.color = tone;
    canvas.drawPath(
      metric.extractPath(0, metric.length * progress.clamp(0.0, 1.0)),
      paint,
    );
  }

  @override
  bool shouldRepaint(_CapsuleProgress old) =>
      old.progress != progress || old.tone != tone;
}
