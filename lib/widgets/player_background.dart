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

      // 速度缓降到 0 后在回调内停止：暂停后父组件不再重建，
      // 若只在 build 里判断，ticker 会一直以 60fps 空转。
      if (!isPlaying && _currentSpeed == 0.0) {
        _ticker.stop();
      }
    });
  }

  void _updateTickerState(bool isPlaying, bool flowEnabled) {
    if (!flowEnabled) {
      if (_ticker.isActive) _ticker.stop();
      return;
    }
    if (isPlaying && !_ticker.isActive) {
      // 重新启动后 elapsed 从 0 开始计，重置基准避免 delta 为负。
      _lastElapsed = Duration.zero;
      _ticker.start();
    }
  }

  /// 流光源图解码尺寸。小图拉伸到全屏本身就很柔和，
  /// 只需一次轻度模糊即可，显存占用与解码开销都极低。
  static const int _flowDecodeSize = 96;

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
    _updateTickerState(isPlaying, flowEnabled);
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
                    memCacheWidth: _flowDecodeSize,
                    memCacheHeight: _flowDecodeSize,
                    placeholder: (_, __) => const SizedBox.shrink(),
                    errorWidget: (_, __, ___) => const SizedBox.shrink(),
                    imageBuilder: (context, imageProvider) {
                      return AnimatedBuilder(
                        animation: _elapsed,
                        builder: (context, _) {
                          final elapsedVal = _elapsed.value;
                          final opacity =
                              (1.0 - widget.scrollOffset * 0.5).clamp(0.0, 1.0);

                          return _FlowBlur(
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
                                  opacity: 0.85 * opacity,
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
                                  opacity: 0.45 * opacity,
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
                    final opacity =
                        (1.0 - widget.scrollOffset * 0.5).clamp(0.0, 1.0);
                    final imageProvider = ResizeImage(
                      FileImage(File(ThemeAssets.playerBg)),
                      width: _flowDecodeSize,
                      height: _flowDecodeSize,
                      policy: ResizeImagePolicy.fit,
                    );

                    return _FlowBlur(
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
                            opacity: 0.85 * opacity,
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
                            opacity: 0.45 * opacity,
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
//    接收一张低分辨率（~96px）的图片源，拉伸到全屏后本身就是柔和的色块，
//    在 GPU 上以极慢的速度执行平移（pan）、缩放（zoom）和旋转（rotate）变换，
//    人眼感知为平滑、无边界的“液态极光流动”。
//
//  性能要点：
//    - 不在每层内部做模糊：放大变换下的 ImageFiltered 会生成数倍屏幕尺寸的
//      离屏纹理，两层 × 60fps 足以耗尽共享显存，导致 SystemUI 重启。
//    - 透明度通过 Image.opacity 直接作用于绘制，避免 Opacity 的 saveLayer。
//    - 统一由 [_FlowBlur] 在屏幕尺寸内做一次轻度模糊。
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

    return Transform(
      alignment: Alignment.center,
      transform: transform,
      child: Image(
        image: imageProvider,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        filterQuality: FilterQuality.medium,
        opacity: AlwaysStoppedAnimation(opacity),
        gaplessPlayback: true,
      ),
    );
  }
}

/// 在屏幕尺寸内对流光层做一次模糊，抹平低分辨率拉伸带来的条纹。
/// ClipRect 位于滤镜内部，保证离屏纹理不超过屏幕大小。
class _FlowBlur extends StatelessWidget {
  final Widget child;

  const _FlowBlur({required this.child});

  @override
  Widget build(BuildContext context) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(
        sigmaX: 24,
        sigmaY: 24,
        tileMode: TileMode.clamp,
      ),
      child: ClipRect(child: child),
    );
  }
}

