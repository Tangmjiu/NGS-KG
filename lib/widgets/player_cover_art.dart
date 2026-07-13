import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/song.dart';
import '../theme/theme_assets.dart';
import '../utils/theme.dart';
import 'hi_res_badge.dart';

/// Enhanced album cover art widget with glassmorphism shadow and
/// scroll-driven crossfade for the Apple Music-style player.
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = (constraints.maxWidth * 0.78).clamp(200.0, 400.0);

        return Center(
          child: AnimatedOpacity(
            duration: AppMotion.dShort4,
            curve: AppMotion.emphasized,
            opacity: (1.0 - scrollOffset * 2.0).clamp(0.0, 1.0),
            child: Transform.scale(
              scale: 1.0 - scrollOffset * 0.2,
              child: Hero(
                tag: 'album_art_${song.hash ?? song.id}',
                child: Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    borderRadius: AppShape.md,
                    border: Border.all(
                      color: cs.onSurface.withValues(alpha: 0.15),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: cs.scrim.withValues(alpha: 0.5),
                        blurRadius: 30,
                        offset: const Offset(0, 15),
                        spreadRadius: 5,
                      ),
                      BoxShadow(
                        color: cs.scrim.withValues(alpha: 0.3),
                        blurRadius: 60,
                        offset: const Offset(0, 30),
                        spreadRadius: 10,
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
                                  width: size,
                                  height: size,
                                  fit: BoxFit.cover,
                                  placeholder: (_, __) => _fallback(size),
                                  errorWidget: (_, __, ___) => _fallback(size),
                                )
                              : _fallback(size),
                        ),
                      ),
                      if (showHiRes)
                        Positioned(
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
        );
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
