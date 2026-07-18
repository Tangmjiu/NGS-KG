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
    final isPlaying = context.watch<PlayerProvider>().isPlaying;
    // 核心交互：播放时展开至 1.0，暂停时收缩至 0.85
    final double playScale = isPlaying ? 1.0 : 0.85;

    return LayoutBuilder(
      builder: (context, constraints) {
        final baseSize = (constraints.maxWidth * 0.78).clamp(200.0, 400.0);

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
                  // ── 用 AnimatedScale 做变换层缩放，不触发布局重排 ──
                  child: AnimatedScale(
                    scale: playScale,
                    duration: AppMotion.dMedium4, // 400ms 让缩放更有物理感
                    curve: AppMotion.emphasizedDecelerate,
                    child: _ShadowWrapper(
                      isPlaying: isPlaying,
                      child: SizedBox(
                        width: baseSize,
                        height: baseSize,
                        child: Stack(
                          clipBehavior: Clip.hardEdge,
                          fit: StackFit.expand,
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
                                        width: baseSize,
                                        height: baseSize,
                                        fit: BoxFit.cover,
                                        placeholder: (_, __) =>
                                            _fallback(baseSize),
                                        errorWidget: (_, __, ___) =>
                                            _fallback(baseSize),
                                      )
                                    : _fallback(baseSize),
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
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _fallback(double size) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
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

/// 用 TweenAnimationBuilder 平滑过渡阴影参数，
/// 避免 isPlaying 瞬间切换导致阴影跳变。
class _ShadowWrapper extends StatelessWidget {
  final bool isPlaying;
  final Widget child;

  const _ShadowWrapper({required this.isPlaying, required this.child});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // 0.0 = paused, 1.0 = playing
    final double target = isPlaying ? 1.0 : 0.0;

    return TweenAnimationBuilder<double>(
      tween: Tween(end: target),
      duration: AppMotion.dMedium4,
      curve: AppMotion.emphasizedDecelerate,
      builder: (context, t, child) {
        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: AppShape.md,
            border: Border.all(
              color: cs.onSurface.withValues(alpha: 0.15),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: cs.scrim.withValues(alpha: lerpDouble(0.2, 0.5, t)),
                blurRadius: lerpDouble(15, 30, t),
                offset: Offset(0, lerpDouble(8, 15, t)),
                spreadRadius: lerpDouble(0, 5, t),
              ),
              BoxShadow(
                color: cs.scrim.withValues(alpha: lerpDouble(0.1, 0.3, t)),
                blurRadius: lerpDouble(30, 60, t),
                offset: Offset(0, lerpDouble(15, 30, t)),
                spreadRadius: lerpDouble(2, 10, t),
              ),
            ],
          ),
          child: child!,
        );
      },
      child: child,
    );
  }

  static double lerpDouble(double a, double b, double t) => a + (b - a) * t;
}
