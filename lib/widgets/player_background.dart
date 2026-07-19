import 'dart:io';
import 'dart:math' show sin, cos, pi;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show Ticker;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../providers/player_provider.dart';
import '../theme/theme_assets.dart';
import '../utils/theme.dart';

/// Apple Music-style dynamic player background.
///
/// Layers:
///   1. Animated base color from album art palette
///   2. Gaussian-blurred album cover (50px, dims on lyrics scroll)
///   3. [Optional] Dynamic flowing light blobs via [FlowLightPainter]
///   4. Gradient overlay (darkens bottom for text legibility)
class PlayerBackground extends StatefulWidget {
  final String? albumCoverUrl;
  final Color? paletteColor;
  final List<Color> paletteColors;
  final double scrollOffset;

  const PlayerBackground({
    super.key,
    required this.albumCoverUrl,
    required this.paletteColor,
    this.paletteColors = const [],
    required this.scrollOffset,
  });

  @override
  State<PlayerBackground> createState() => _PlayerBackgroundState();
}

class _PlayerBackgroundState extends State<PlayerBackground>
    with SingleTickerProviderStateMixin {
  /// Continuously running ticker — elapsed seconds grow forever,
  /// so the flowing blobs never reset to their starting positions.
  /// Bridged through a ValueNotifier so AnimatedBuilder can listen.
  late final Ticker _ticker;
  final ValueNotifier<double> _elapsed = ValueNotifier<double>(0.0);

  double _accumulatedTime = 0.0;
  Duration _lastElapsed = Duration.zero;
  double _currentSpeed = 1.0; // 平滑插值速度

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) {
      if (!mounted) return;

      final delta = (elapsed - _lastElapsed).inMicroseconds / 1000000.0;
      _lastElapsed = elapsed;

      // 容错读取播放状态
      bool isPlaying = true;
      try {
        isPlaying = context.read<PlayerProvider>().isPlaying;
      } catch (_) {}

      // 平滑插值计算当前速度（实现 Apple Music 播放时加速、暂停时缓停的效果）
      final targetSpeed = isPlaying ? 1.0 : 0.0;
      _currentSpeed += (targetSpeed - _currentSpeed) * (delta * 3.0);

      // 当速度极小且目标为0时，直接清零以省计算
      if (!isPlaying && _currentSpeed < 0.001) {
        _currentSpeed = 0.0;
      }

      _accumulatedTime += delta * _currentSpeed;
      _elapsed.value = _accumulatedTime;
    });
  }

  void _updateTickerState(bool isPlaying) {
    // 播放时启动 ticker；暂停时让速度缓降到 0 后再停止，避免动画突兀中断。
    if (isPlaying && !_ticker.isActive) {
      _ticker.start();
    } else if (!isPlaying && _ticker.isActive && _currentSpeed < 0.001) {
      _ticker.stop();
    }
  }

  @override
  void dispose() {
    _ticker.stop();
    _ticker.dispose();
    _elapsed.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final flowEnabled = context.watch<ThemeProvider>().flowLightEnabled;
    final isPlaying = context.select<PlayerProvider, bool>((p) => p.isPlaying);
    _updateTickerState(isPlaying);
    final hasColors = widget.paletteColors.length >= 3;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Layer 1: Base color with animated transitions
        AnimatedContainer(
          duration: AppMotion.dLong2,
          curve: AppMotion.emphasized,
          color: widget.paletteColor ?? Colors.black,
        ),

        // Layer 2: Blurred album art, dims as lyrics appear
        // Hidden when flowing light is active so the colour blobs are visible.
        // Fallback to album art when flow is enabled but palette isn't ready.
        if ((!flowEnabled || !hasColors) && widget.albumCoverUrl != null)
          Opacity(
            opacity: 1.0 - widget.scrollOffset * 0.6,
            child: CachedNetworkImage(
              imageUrl: widget.albumCoverUrl!,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              imageBuilder: (context, imageProvider) {
                return ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                  child: Image(
                    image: imageProvider,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                  ),
                );
              },
              placeholder: (_, __) => const SizedBox.shrink(),
              errorWidget: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),

        // Layer 2b: Fallback to theme pack player background when no album art
        if ((!flowEnabled || !hasColors) && widget.albumCoverUrl == null && ThemeAssets.playerBg.isNotEmpty)
          Positioned.fill(
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
              child: Image.file(
                File(ThemeAssets.playerBg),
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          ),

        // Layer 3: Dynamic flowing light (Apple Music-style)
        // 依据 CSDN 原理，对封面图片进行超大模糊并辅以慢速旋转和平移。
        // 通过双层不同速度/旋转方向的封面交错平铺，让色彩在交叉运动中自然交融。
        if (flowEnabled && widget.albumCoverUrl != null)
          Positioned.fill(
            child: IgnorePointer(
              child: RepaintBoundary(
                child: AnimatedSwitcher(
                  duration: AppMotion.dMedium3,
                  switchInCurve: AppMotion.emphasizedDecelerate,
                  switchOutCurve: AppMotion.emphasizedAccelerate,
                  transitionBuilder: (child, animation) =>
                      FadeTransition(opacity: animation, child: child),
                  child: CachedNetworkImage(
                    key: ValueKey('flow_image_${widget.albumCoverUrl}'),
                    imageUrl: widget.albumCoverUrl!,
                    placeholder: (_, __) => const SizedBox.shrink(),
                    errorWidget: (_, __, ___) => const SizedBox.shrink(),
                    imageBuilder: (context, imageProvider) {
                      return AnimatedBuilder(
                        animation: _elapsed,
                        builder: (context, _) {
                          final elapsedVal = _elapsed.value;
                          final opacity = 1.0 - widget.scrollOffset * 0.5;

                          return Opacity(
                            opacity: opacity,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                // Layer A: 底层流光封面，旋转慢，缩放比偏小，高饱和度
                                FlowingImageLayer(
                                  imageProvider: imageProvider,
                                  elapsed: elapsedVal,
                                  scaleBase: 1.8,
                                  scalePulse: 0.15,
                                  speedScale: 0.05,
                                  rotationSpeed: 0.012,
                                  panSpeedX: 0.04,
                                  panSpeedY: 0.03,
                                  panRadius: 50.0,
                                  opacity: 0.85,
                                  blurSigma: 45.0,
                                ),
                                // Layer B: 顶层流光封面，反向旋转，速度不同，缩放比大，起混色作用
                                FlowingImageLayer(
                                  imageProvider: imageProvider,
                                  elapsed: elapsedVal,
                                  scaleBase: 2.2,
                                  scalePulse: 0.20,
                                  speedScale: 0.08,
                                  rotationSpeed: -0.016,
                                  panSpeedX: 0.06,
                                  panSpeedY: 0.08,
                                  panRadius: 70.0,
                                  opacity: 0.45,
                                  blurSigma: 55.0,
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
            ),
          ),

        // Layer 3b: Fallback theme pack background with flowing effect
        if (flowEnabled && widget.albumCoverUrl == null && ThemeAssets.playerBg.isNotEmpty)
          Positioned.fill(
            child: IgnorePointer(
              child: RepaintBoundary(
                child: AnimatedBuilder(
                  animation: _elapsed,
                  builder: (context, _) {
                    final elapsedVal = _elapsed.value;
                    final opacity = 1.0 - widget.scrollOffset * 0.5;
                    final imageProvider = FileImage(File(ThemeAssets.playerBg));

                    return Opacity(
                      opacity: opacity,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          FlowingImageLayer(
                            imageProvider: imageProvider,
                            elapsed: elapsedVal,
                            scaleBase: 1.7,
                            scalePulse: 0.15,
                            speedScale: 0.05,
                            rotationSpeed: 0.012,
                            panSpeedX: 0.04,
                            panSpeedY: 0.03,
                            panRadius: 40.0,
                            opacity: 0.85,
                            blurSigma: 45.0,
                          ),
                          FlowingImageLayer(
                            imageProvider: imageProvider,
                            elapsed: elapsedVal,
                            scaleBase: 2.1,
                            scalePulse: 0.20,
                            speedScale: 0.08,
                            rotationSpeed: -0.016,
                            panSpeedX: 0.06,
                            panSpeedY: 0.08,
                            panRadius: 60.0,
                            opacity: 0.45,
                            blurSigma: 55.0,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),

        // Layer 4: Gradient overlay — darkens the bottom portion
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                Colors.black.withValues(alpha: 0.7),
              ],
            ),
          ),
          child: const SizedBox.expand(),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  FlowingImageLayer — 仿 Apple Music 与 Ken Burns 动效的流光图片层
//
//  原理：
//    接收一张图片源（封面图或主题背景），对其执行超大 Radius 的高斯模糊。
//    在 GPU 上以极慢的速度对该模糊图片执行平移（pan）、缩放（zoom）和旋转（rotate）变换。
//    由于图片被高度模糊，当其进行复杂的矩阵变换时，边缘色彩在屏幕上的运动会被人眼感知为
//    平滑的、无边界的“液态极光流动”，彻底避免了多个分离色块强行相加（BlendMode.plus）导致的忽明忽暗和闪烁。
// ─────────────────────────────────────────────────────────────────────────────
class FlowingImageLayer extends StatelessWidget {
  final ImageProvider imageProvider;
  final double elapsed;
  final double scaleBase;
  final double scalePulse;
  final double speedScale;
  final double rotationSpeed;
  final double panSpeedX;
  final double panSpeedY;
  final double panRadius;
  final double opacity;
  final double blurSigma;

  const FlowingImageLayer({
    super.key,
    required this.imageProvider,
    required this.elapsed,
    required this.scaleBase,
    required this.scalePulse,
    required this.speedScale,
    required this.rotationSpeed,
    required this.panSpeedX,
    required this.panSpeedY,
    required this.panRadius,
    required this.opacity,
    required this.blurSigma,
  });

  @override
  Widget build(BuildContext context) {
    // ── 模拟歌曲节奏 (120 BPM 鼓点 + 弱拍同步) ──
    // pi * 4.0 对应每秒 2 个主拍 (即 120 BPM)
    final beat = (sin(elapsed * pi * 4.0).abs() * 0.75) + 
                 (sin(elapsed * pi * 8.0).abs() * 0.25);
    
    // 节奏对缩放的影响：在鼓点处缩放轻微呼吸 (额外 8% 的缩放，避免剧烈跳动)
    final pulseScale = scalePulse * (1.0 + 0.08 * beat);
    final scale = scaleBase + pulseScale * sin(elapsed * speedScale);
    
    // 节奏对平移的影响：在鼓点瞬间产生轻微的速度加快
    // 振幅 0.05 保证了该项的导数 > 0，因此流光只会加速减速，而不会倒退（时光倒流）
    final panTime = elapsed + 0.05 * sin(elapsed * pi * 4.0);
    final dx = sin(panTime * panSpeedX) * panRadius;
    final dy = cos(panTime * panSpeedY) * panRadius;

    // 节奏对旋转的影响：自转会在重音处轻微加速推进
    final rotationTime = elapsed + 0.05 * sin(elapsed * pi * 4.0);
    final angle = rotationTime * rotationSpeed;

    final transform = Matrix4.translationValues(dx, dy, 0.0)
      ..multiply(Matrix4.diagonal3Values(scale, scale, 1.0))
      ..multiply(Matrix4.rotationZ(angle));

    return Opacity(
      opacity: opacity,
      child: Transform(
        alignment: Alignment.center,
        transform: transform,
        child: ImageFiltered(
          imageFilter: ImageFilter.blur(
            sigmaX: blurSigma,
            sigmaY: blurSigma,
            tileMode: TileMode.clamp,
          ),
          child: Image(
            image: imageProvider,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
          ),
        ),
      ),
    );
  }
}

