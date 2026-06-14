import 'dart:math' show sin, cos, pi;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';

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
  late final AnimationController _flowController;

  @override
  void initState() {
    super.initState();
    // 动态流光循环（5 秒一个完整周期）
    _flowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat();
  }

  @override
  void dispose() {
    _flowController.dispose();
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

        // Layer 3: Dynamic flowing light (Apple Music-style)
        if (flowEnabled && hasColors)
          Positioned.fill(
            child: IgnorePointer(
              child: RepaintBoundary(
                child: AnimatedBuilder(
                  animation: _flowController,
                  builder: (_, __) => Opacity(
                    opacity: 1.0 - widget.scrollOffset * 0.5,
                    child: CustomPaint(
                      painter: FlowLightPainter(
                        colors: widget.paletteColors,
                        progress: _flowController.value,
                      ),
                      size: Size.infinite,
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
  final double progress; // 0.0 → 1.0

  const FlowLightPainter({
    required this.colors,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final count = colors.length;
    // Each blob uses a distinct set of frequencies to avoid repetition.
    // Pre-computed constants so every frame is deterministic.
    const freqsX = [2.1, 1.3, 0.9, 1.8, 0.6, 2.7, 0.3, 3.5];
    const freqsY = [1.7, 2.3, 1.1, 0.8, 1.9, 0.5, 2.8, 0.2];
    const freqsR = [0.9, 0.7, 1.3, 1.1, 0.6, 1.5, 1.2, 0.4];
    const phases = [0.0, 2.1, 4.3, 1.6, 3.8, 5.0, 1.2, 3.3];

    for (int i = 0; i < count; i++) {
      final t = progress * 2 * pi;

      // Position — each blob wanders within a 70% × 70% central area
      final x = sin(t * freqsX[i] + phases[i]) * size.width * 0.35 +
          size.width * 0.5;
      final y = cos(t * freqsY[i] + phases[i]) * size.height * 0.35 +
          size.height * 0.5;

      // Radius — gentle pulsing between 20%–35% of screen width
      final r = size.width *
          (0.20 + 0.15 * (sin(t * freqsR[i] + phases[i]) * 0.5 + 0.5));

      // Heavily blurred translucent blob
      final paint = Paint()
        ..color = colors[i % colors.length].withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 150);

      canvas.drawCircle(Offset(x, y), r.clamp(40, size.width * 0.5), paint);
    }
  }

  @override
  bool shouldRepaint(FlowLightPainter old) => old.progress != progress;
}
