import 'dart:async' show Timer;
import 'dart:io';
import 'dart:math' show sin, cos, pi, min;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show Ticker, SchedulerBinding;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../theme/theme_assets.dart';

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

  // ── Frame timing monitoring & auto-throttling ──────────────────────
  static const int _kFrameWindowSize = 30;
  static const double _kSlowThresholdMs = 16.0;
  static const double _kSlowRatio = 0.10;
  static const int _kBlobLimitNormal = 8;
  static const int _kBlobLimitThrottled = 4;

  final List<FrameTiming> _frameTimings = [];
  bool _isThrottled = false;
  void Function(List<FrameTiming>)? _frameCallback;
  Timer? _reEvalTimer;

  /// Callback invoked by [SchedulerBinding] on each frame completion.
  void _onFrameTiming(List<FrameTiming> timings) {
    if (_frameCallback == null) return; // disposed
    for (final timing in timings) {
      _frameTimings.add(timing);
      if (_frameTimings.length > _kFrameWindowSize) {
        _frameTimings.removeAt(0);
      }
    }

    if (_frameTimings.length < _kFrameWindowSize) {
      // Not enough samples yet.
      return;
    }

    // Count frames that exceed the 60 fps budget (≈ 16 ms).
    int slowFrames = 0;
    final int thresholdUs = (_kSlowThresholdMs * 1000).toInt();
    for (final timing in _frameTimings) {
      final totalUs =
          timing.buildDuration.inMicroseconds +
          timing.rasterDuration.inMicroseconds;
      if (totalUs > thresholdUs) {
        slowFrames++;
      }
    }

    final bool shouldThrottle =
        slowFrames / _kFrameWindowSize > _kSlowRatio;
    if (shouldThrottle != _isThrottled) {
      setState(() => _isThrottled = shouldThrottle);
    }
  }

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) {
      if (!mounted) return;
      _elapsed.value = elapsed.inMicroseconds / 1000000.0;
    })..start();

    // Register frame timing callback for performance monitoring.
    _frameCallback = _onFrameTiming;
    SchedulerBinding.instance.addTimingsCallback(_frameCallback!);

    // Every 30 seconds, reset the frame window so we re-evaluate
    // performance (handles thermal recovery or plugging in power).
    _reEvalTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _frameTimings.clear(),
    );
  }

  @override
  void dispose() {
    _reEvalTimer?.cancel();
    _frameCallback = null; // allow the callback to be collected
    _ticker.stop();
    _ticker.dispose();
    _elapsed.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final flowEnabled = context.watch<ThemeProvider>().flowLightEnabled;
    final hasColors = widget.paletteColors.length >= 3;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Layer 1: Base color with animated transitions
        AnimatedContainer(
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeInOut,
          color: widget.paletteColor ?? Colors.black,
        ),

        // Layer 2: Blurred album art, dims as lyrics appear
        // Hidden when flowing light is active so the colour blobs are visible.
        if (!flowEnabled && widget.albumCoverUrl != null)
          Opacity(
            opacity: 1.0 - widget.scrollOffset * 0.6,
            child: CachedNetworkImage(
              imageUrl: widget.albumCoverUrl!,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              imageBuilder: (context, imageProvider) {
                return ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
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
        if (!flowEnabled && widget.albumCoverUrl == null && ThemeAssets.playerBg.isNotEmpty)
          Positioned.fill(
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
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
        if (flowEnabled && hasColors)
          Positioned.fill(
            child: IgnorePointer(
              child: RepaintBoundary(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 600),
                  switchInCurve: Curves.easeIn,
                  switchOutCurve: Curves.easeOut,
                  transitionBuilder: (child, animation) =>
                      FadeTransition(opacity: animation, child: child),
                  child: AnimatedBuilder(
                    key: ValueKey('flow_${widget.paletteColors.hashCode}'),
                    animation: _elapsed,
                    builder: (_, __) => Opacity(
                      opacity: 1.0 - widget.scrollOffset * 0.5,
                      child: CustomPaint(
                        painter: FlowLightPainter(
                          colors: widget.paletteColors,
                          elapsed: _elapsed.value,
                          blobLimit: _isThrottled
                              ? _kBlobLimitThrottled
                              : _kBlobLimitNormal,
                        ),
                        size: Size.infinite,
                      ),
                    ),
                  ),
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
//  FlowLightPainter — draws soft coloured blobs that drift organically
// ─────────────────────────────────────────────────────────────────────────────

class FlowLightPainter extends CustomPainter {
  final List<Color> colors;
  final double elapsed; // seconds since widget creation, never resets
  final int blobLimit; // max blobs to draw (auto-throttling)

  const FlowLightPainter({
    required this.colors,
    required this.elapsed,
    this.blobLimit = 8,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final count = min(colors.length, blobLimit);
    // Each blob has an anchor position so they naturally sit in different
    // screen regions.  They wander around their anchor via sin/cos.
    const anchorX = [0.20, 0.80, 0.50, 0.30, 0.70, 0.50, 0.25, 0.75];
    const anchorY = [0.30, 0.25, 0.70, 0.50, 0.50, 0.30, 0.75, 0.70];
    const wander  = [0.15, 0.15, 0.25, 0.20, 0.20, 0.25, 0.15, 0.15];

    const freqsX = [2.1, 1.3, 0.9, 1.8, 0.6, 2.7, 0.3, 3.5];
    const freqsY = [1.7, 2.3, 1.1, 0.8, 1.9, 0.5, 2.8, 0.2];
    const freqsR = [0.9, 0.7, 1.3, 1.1, 0.6, 1.5, 1.2, 0.4];
    const phases = [0.0, 2.1, 4.3, 1.6, 3.8, 5.0, 1.2, 3.3];

    // Higher opacity and tighter blur so each colour stands out clearly.
    const alphas = [0.45, 0.30, 0.35, 0.40, 0.32, 0.38, 0.42, 0.30];

    // Normalize elapsed to reduce floating-point precision loss in sin/cos
    // for long playback sessions.  Period is 2π, so values above 2π are
    // redundant for trigonometric functions.
    final double Function(double) _wrap =
        (v) => v % (2 * pi);

    for (int i = 0; i < count; i++) {
      // t = elapsed seconds × frequency — wrap to [0, 2π) for precision
      final t = _wrap(elapsed * freqsX[i] + phases[i]);

      // Each blob sits at its anchor and swims around it
      final x = (sin(t) * wander[i] + anchorX[i]) * size.width;
      final y = (cos(t * freqsY[i] / freqsX[i]) * wander[i] + anchorY[i]) *
          size.height;

      // Radius — larger static core + gentle pulse
      final r = size.width *
          (0.18 + 0.12 * (sin(_wrap(elapsed * freqsR[i] + phases[i])) * 0.5 + 0.5));

      // Soft but not mushy — blur is moderate so each blob keeps a core
      final paint = Paint()
        ..color =
            colors[i % colors.length].withValues(alpha: alphas[i % alphas.length])
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 50);

      canvas.drawCircle(Offset(x, y), r.clamp(40, size.width * 0.45), paint);
    }
  }

  @override
  bool shouldRepaint(FlowLightPainter old) => old.elapsed != elapsed;
}
