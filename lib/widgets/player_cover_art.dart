import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../providers/player_provider.dart';
import '../providers/theme_provider.dart';
import '../models/song.dart';
import '../theme/theme_assets.dart';
import '../utils/theme.dart';
import 'hi_res_badge.dart';

/// Apple Music 风格大卡片封面
///
/// 特性规范：
/// 1. **流光彩色模糊阴影 (Backdrop Color Glow)**：在封面后方利用高斯模糊 (`ImageFilter.blur`) 渲染大一号的专辑图片，并随播放/暂停进行强弱无缝变幻。
/// 2. **封面对接手势切歌**：封面大图直接支持左右滑动手势切歌，并在拖拽时具有位移与倾斜阻尼。
/// 3. **播放状态无重排弹性变焦**：使用 `AnimatedScale` 驱动播放时放大为 `1.0` 暂停时缩小为 `0.88`，消除布局抖动。
class PlayerCoverArt extends StatefulWidget {
  final Song song;

  /// 0.0 = fully visible, 1.0 = lyrics page。
  /// 用 ValueListenable 驱动，PageView 滚动时只重建本组件的视差变换层，
  /// 不触发整页（含 LyricView）重建。
  final ValueListenable<double> scrollOffset;

  const PlayerCoverArt({
    super.key,
    required this.song,
    required this.scrollOffset,
  });

  @override
  State<PlayerCoverArt> createState() => _PlayerCoverArtState();
}

class _PlayerCoverArtState extends State<PlayerCoverArt>
    with SingleTickerProviderStateMixin {
  double _dragOffset = 0.0;
  bool _hasVibrated = false;
  late AnimationController _resetController;
  Animation<double>? _resetAnimation;

  @override
  void initState() {
    super.initState();
    _resetController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _resetController.addListener(() {
      setState(() {
        _dragOffset = _resetAnimation!.value;
      });
    });
  }

  @override
  void dispose() {
    _resetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 只订阅播放状态（播放/暂停时弹性变焦），进度通知不重建封面；
    // read 用于手势回调，不建立订阅。
    final player = context.read<PlayerProvider>();
    final isPlaying = context.select<PlayerProvider, bool>((p) => p.isPlaying);
    // Hi-Res 金标：仅在真实源解析完成且为 Hi-Res、且设置开启时显示
    final showHiRes =
        context.select<PlayerProvider, String?>((p) => p.resolvedQuality) ==
                'high' &&
            context.select<ThemeProvider, bool>((tp) => tp.showHiResBadge);
    // 核心交互：播放时展开至 1.0，暂停时收缩至 0.88
    final double playScale = isPlaying ? 1.0 : 0.88;

    return LayoutBuilder(
      builder: (context, constraints) {
        final baseSize = (constraints.maxWidth * 0.82).clamp(220.0, 360.0);
        const swipeThreshold = 80.0;
        final dragPercent =
            (_dragOffset.abs() / swipeThreshold).clamp(0.0, 1.0);

        // 滚动偏移只影响视差变换层（透明度/缩放）：ValueListenableBuilder
        // 只包裹 AnimatedOpacity/Transform.scale，滚动时封面主体（手势、
        // Hero、模糊层）完全不重建。
        return Center(
          child: ValueListenableBuilder<double>(
            valueListenable: widget.scrollOffset,
            builder: (context, offset, _) {
              return AnimatedOpacity(
                duration: AppMotion.dShort4,
                curve: AppMotion.emphasized,
                opacity: (1.0 - offset * 2.0).clamp(0.0, 1.0),
                child: Transform.scale(
                  scale: 1.0 - offset * 0.15, // 歌词滚动时的额外缩小
                  child: GestureDetector(
                    onHorizontalDragUpdate: (details) {
                      if (_resetController.isAnimating) {
                        _resetController.stop();
                      }
                      setState(() {
                        // 带有阻尼的拖拽
                        _dragOffset += details.delta.dx * 0.7;
                        if (_dragOffset.abs() >= swipeThreshold) {
                          if (!_hasVibrated) {
                            HapticFeedback.lightImpact();
                            _hasVibrated = true;
                          }
                        } else {
                          _hasVibrated = false;
                        }
                      });
                    },
                    onHorizontalDragEnd: (details) {
                      if (_dragOffset > swipeThreshold) {
                        player.playPrevious();
                      } else if (_dragOffset < -swipeThreshold) {
                        player.playNext();
                      }

                      // 回弹复位
                      _resetAnimation = Tween<double>(
                        begin: _dragOffset,
                        end: 0.0,
                      ).animate(CurvedAnimation(
                        parent: _resetController,
                        curve: Curves.easeOutBack,
                      ));
                      _resetController.forward(from: 0.0);
                      _hasVibrated = false;
                    },
                    child: Transform.translate(
                      offset: Offset(_dragOffset, 0),
                      child: Transform.rotate(
                        // 滑动时倾斜阻尼
                        angle: (_dragOffset / 1600.0).clamp(-0.04, 0.04),
                        child: M3PressScale(
                          scaleDown: 0.96,
                          child: Hero(
                            tag:
                                'album_art_${widget.song.hash ?? widget.song.id}',
                            child: AnimatedScale(
                              scale: playScale,
                              duration: AppMotion.dMedium4,
                              curve: AppMotion.emphasizedDecelerate,
                              child: Stack(
                                alignment: Alignment.center,
                                clipBehavior: Clip.none,
                                children: [
                                  // ── 后方流光彩色投影 (高斯模糊与播放呼吸感) ──
                                  Positioned(
                                    child: TweenAnimationBuilder<double>(
                                      tween: Tween(end: isPlaying ? 1.0 : 0.0),
                                      duration: AppMotion.dMedium4,
                                      curve: AppMotion.emphasizedDecelerate,
                                      builder: (context, t, _) {
                                        final blurScale = 1.02 + (t * 0.06);
                                        final blurOpacity = 0.40 + (t * 0.28);
                                        return Opacity(
                                          opacity: (blurOpacity *
                                                  (1.0 - dragPercent * 0.45))
                                              .clamp(0.0, 1.0),
                                          child: Transform.scale(
                                            scale: blurScale,
                                            // RepaintBoundary 缓存高斯模糊结果：
                                            // 呼吸动画期间只做合成变换，不重复模糊
                                            child: RepaintBoundary(
                                              child: ImageFiltered(
                                                imageFilter:
                                                    ui.ImageFilter.blur(
                                                  sigmaX: 42,
                                                  sigmaY: 42,
                                                ),
                                                child: SizedBox(
                                                  width: baseSize * 0.93,
                                                  height: baseSize * 0.93,
                                                  child: _buildCoverImage(
                                                      baseSize),
                                                ),
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),

                                  // ── 前方清晰卡片层 ──
                                  SizedBox(
                                    width: baseSize,
                                    height: baseSize,
                                    child: Stack(
                                      clipBehavior: Clip.hardEdge,
                                      fit: StackFit.expand,
                                      children: [
                                        Container(
                                          decoration: BoxDecoration(
                                            borderRadius: AppShape.md,
                                            border: Border.all(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurface
                                                  .withValues(alpha: 0.12),
                                              width: 1,
                                            ),
                                          ),
                                          child: ClipRRect(
                                            borderRadius: AppShape.md,
                                            child: Semantics(
                                              image: true,
                                              label: '${widget.song.name} 专辑封面',
                                              child: _buildCoverImage(baseSize),
                                            ),
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
          ),
        );
      },
    );
  }

  Widget _buildCoverImage(double baseSize) {
    final url = widget.song.albumCoverUrl;
    if (url == null || url.isEmpty) {
      return _fallback(baseSize);
    }
    if (url.startsWith('file:') || url.startsWith('/')) {
      final path = url.startsWith('file:') ? Uri.parse(url).toFilePath() : url;
      final file = File(path);
      if (file.existsSync()) {
        return Image.file(
          file,
          width: baseSize,
          height: baseSize,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _fallback(baseSize),
        );
      }
      return _fallback(baseSize);
    }
    return CachedNetworkImage(
      imageUrl: url,
      width: baseSize,
      height: baseSize,
      fit: BoxFit.cover,
      placeholder: (_, __) => _fallback(baseSize),
      errorWidget: (_, __, ___) => _fallback(baseSize),
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
