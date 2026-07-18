import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../providers/player_provider.dart';
import '../models/song.dart';
import '../theme/theme_assets.dart';
import '../utils/theme.dart';
import 'hi_res_badge.dart';

/// Enhanced album cover art widget with glassmorphism shadow,
/// expressive MD3E scaling (shrinks when paused), and M3PressScale.
class PlayerCoverArt extends StatelessWidget {
  final Song song;
  final double scrollOffset; // 0.0 = fully visible, 1.0 = lyrics page
  final bool showHiRes; // 是否显示 Hi-Res 金标

  const PlayerCoverArt({
    super.key,
    required this.song,
    required this.scrollOffset,
    this.showHiRes = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isPlaying = context.watch<PlayerProvider>().isPlaying;
    
    return LayoutBuilder(
      builder: (context, constraints) {
        final baseSize = (constraints.maxWidth * 0.78).clamp(200.0, 400.0);
        // 核心交互：播放时展开至 1.0，暂停时收缩至 0.85
        final playScale = isPlaying ? 1.0 : 0.85;

        return Center(
          child: AnimatedOpacity(
            duration: AppMotion.dShort4,
            curve: AppMotion.emphasized,
            opacity: (1.0 - scrollOffset * 2.0).clamp(0.0, 1.0),
            child: Transform.scale(
              scale: 1.0 - scrollOffset * 0.2, // 歌词滚动时的额外缩小
              child: M3PressScale(
                scaleDown: 0.95, // 用户手动按压封面的阻尼
                child: Hero(
                  tag: 'album_art_${song.hash ?? song.id}',
                  child: AnimatedContainer(
                    duration: AppMotion.dMedium1, // 使用中等时长使展开收缩有物理弹性
                    curve: AppMotion.emphasized,
                    width: baseSize * playScale,
                    height: baseSize * playScale,
                    decoration: BoxDecoration(
                      borderRadius: AppShape.md,
                      border: Border.all(
                        color: cs.onSurface.withValues(alpha: 0.15),
                        width: 1,
                      ),
                      boxShadow: [
                        // 播放时阴影向外扩张且加深，暂停时内敛柔和
                        BoxShadow(
                          color: cs.scrim.withValues(alpha: isPlaying ? 0.5 : 0.2),
                          blurRadius: isPlaying ? 30 : 15,
                          offset: Offset(0, isPlaying ? 15 : 8),
                          spreadRadius: isPlaying ? 5 : 0,
                        ),
                        BoxShadow(
                          color: cs.scrim.withValues(alpha: isPlaying ? 0.3 : 0.1),
                          blurRadius: isPlaying ? 60 : 30,
                          offset: Offset(0, isPlaying ? 30 : 15),
                          spreadRadius: isPlaying ? 10 : 2,
                        ),
                      ],
                    ),
                    child: Stack(
                    clipBehavior: Clip.hardEdge,
                    children: [
                      ClipRRect(
                        borderRadius: AppShape.md,
                        child: Semantics(
                          image: true,
                          label: '${song.name} 专辑封面',
                          child: song.albumCoverUrl != null &&
                                  song.albumCoverUrl!.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: song.albumCoverUrl!,
                                  width: baseSize * playScale,
                                  height: baseSize * playScale,
                                  fit: BoxFit.cover,
                                  placeholder: (_, __) => _fallback(baseSize * playScale),
                                  errorWidget: (_, __, ___) => _fallback(baseSize * playScale),
                                )
                              : _fallback(baseSize * playScale),
                        ),
                      ),
                      if (showHiRes)
                        const Positioned(
                          left: 4,
                          bottom: 8,
                          child: HiResBadge(height: 28),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ));
      },
    );
  }

  Widget _fallback(double size) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2A2D28), Color(0xFF121212)],
        ),
        borderRadius: AppShape.md,
      ),
      child: Center(
        child: albumPlaceholderWidget(size: size * 0.25, color: Colors.white24),
      ),
    );
  }
}
