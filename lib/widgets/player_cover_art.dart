import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../providers/player_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/liked_songs_provider.dart';
import '../providers/theme_provider.dart';
import '../models/song.dart';
import '../theme/theme_assets.dart';
import '../utils/haptics.dart';
import '../utils/theme.dart';
import '../widgets/login_required_dialog.dart';
import 'hi_res_badge.dart';

/// Enhanced album cover art widget with glassmorphism shadow,
/// expressive MD3E scaling (shrinks when paused), and M3PressScale.
class PlayerCoverArt extends StatelessWidget {
  final Song song;
  final double scrollOffset; // 0.0 = fully visible, 1.0 = lyrics page
  final bool showHiRes; // 音质层面是否达到 Hi-Res（resolvedQuality == 'high'）

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
                child: GestureDetector(
                  // ── 双击封面：喜欢/取消喜欢（Rhythm 式快捷手势）──
                  onDoubleTap: () => _onDoubleTapLike(context),
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
                                  child: Builder(
                                    builder: (_) {
                                      final url = song.albumCoverUrl;
                                      if (url == null || url.isEmpty) {
                                        return _fallback(baseSize);
                                      }
                                      // 本地文件：file:// URI 或裸路径
                                      if (url.startsWith('file:') ||
                                          url.startsWith('/')) {
                                        final path = url.startsWith('file:')
                                            ? Uri.parse(url).toFilePath()
                                            : url;
                                        final file = File(path);
                                        if (file.existsSync()) {
                                          return Image.file(
                                            file,
                                            width: baseSize,
                                            height: baseSize,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) =>
                                                _fallback(baseSize),
                                          );
                                        }
                                        return _fallback(baseSize);
                                      }
                                      // 网络 URL → 使用缓存加载
                                      return CachedNetworkImage(
                                        imageUrl: url,
                                        width: baseSize,
                                        height: baseSize,
                                        fit: BoxFit.cover,
                                        placeholder: (_, __) =>
                                            _fallback(baseSize),
                                        errorWidget: (_, __, ___) =>
                                            _fallback(baseSize),
                                      );
                                    },
                                  ),
                                ),
                              ),
                              // ✅ context.select 在 build 方法内调用（合法位置）：
                              // 仅订阅 showHiResBadge 开关，避免在辅助方法中调用导致 Provider 断言崩溃；
                              // song/scrollOffset 等变化随父级重建正常更新，不受 Selector 缓存冻结
                              if (showHiRes &&
                                  context.select<ThemeProvider, bool>(
                                      (tp) => tp.showHiResBadge))
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
          ),
        );
      },
    );
  }

  /// 双击封面：喜欢/取消喜欢（未登录时引导登录）
  void _onDoubleTapLike(BuildContext context) {
    unawaited(haptic(HapticKind.medium));
    final auth = context.read<AuthProvider>();
    if (!auth.isLoggedIn) {
      showLoginRequiredDialog(context).then((goLogin) {
        if (goLogin && context.mounted) {
          Navigator.pushNamed(context, '/login');
        }
      });
      return;
    }
    final lp = context.read<LikedSongsProvider>();
    lp.toggle(SongInfo(
      id: song.id,
      name: song.name,
      hash: song.hash ?? '',
      albumId: song.albumId,
      audioId: song.id,
    ));
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
