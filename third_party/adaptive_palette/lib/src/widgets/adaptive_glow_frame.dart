/// YouTube-style glow border widget.
library;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../config.dart';
import '../models.dart';
import 'widget_helpers.dart';

/// Builds a YouTube-style glow/border shadow derived from image colors.
///
/// **DEPRECATED**: Use [FluidBackground] instead for immersive animated backgrounds.
///
/// This widget is maintained for backward compatibility but will be removed in v4.0.0.
/// Migrate to FluidBackground for better performance and visual quality.
///
/// Example:
/// ```dart
/// AdaptiveGlowImageFrame.network(
///   'https://example.com/image.jpg',
///   blurRadius: 48,
///   spreadRadius: 10,
///   layers: 2,
///   tone: AdaptiveOverlayTone.secondary,
/// )
/// ```
@Deprecated('Use FluidBackground instead. Will be removed in v4.0.0')
class AdaptiveGlowImageFrame extends StatefulWidget {
  final ImageProvider imageProvider;
  final double aspectRatio;
  final BorderRadius borderRadius;
  final double blurRadius;
  final double spreadRadius;
  final int layers;
  final AdaptiveOverlayTone tone;
  final BoxFit fit;
  final Widget? backgroundImage;
  final ExtractionConfig config;
  final ThemeColors fallbackColors;
  final ValueChanged<ThemeColors>? onColorsReady;

  const AdaptiveGlowImageFrame({
    super.key,
    required this.imageProvider,
    this.aspectRatio = 16 / 9,
    this.borderRadius = const BorderRadius.all(Radius.circular(24)),
    this.blurRadius = 36,
    this.spreadRadius = 6,
    this.layers = 2,
    this.tone = AdaptiveOverlayTone.primary,
    this.fit = BoxFit.cover,
    this.backgroundImage,
    this.config = const ExtractionConfig(),
    this.fallbackColors = const ThemeColors.fallback(),
    this.onColorsReady,
  }) : assert(layers >= 1 && layers <= 3, 'layers must be between 1-3');

  /// Create glow frame with network image.
  factory AdaptiveGlowImageFrame.network(
    String imageUrl, {
    Key? key,
    double aspectRatio = 16 / 9,
    BorderRadius borderRadius = const BorderRadius.all(Radius.circular(24)),
    double blurRadius = 36,
    double spreadRadius = 6,
    int layers = 2,
    AdaptiveOverlayTone tone = AdaptiveOverlayTone.primary,
    BoxFit fit = BoxFit.cover,
    ExtractionConfig config = const ExtractionConfig(),
    ThemeColors fallbackColors = const ThemeColors.fallback(),
    ValueChanged<ThemeColors>? onColorsReady,
  }) {
    return AdaptiveGlowImageFrame(
      key: key,
      imageProvider: CachedNetworkImageProvider(imageUrl),
      aspectRatio: aspectRatio,
      borderRadius: borderRadius,
      blurRadius: blurRadius,
      spreadRadius: spreadRadius,
      layers: layers,
      tone: tone,
      fit: fit,
      backgroundImage: CachedNetworkImage(
        imageUrl: imageUrl,
        fit: fit,
        placeholder: (_, __) => const ColoredBox(color: Colors.black12),
        errorWidget: (_, __, ___) => const ColoredBox(
          color: Colors.black12,
          child: Icon(Icons.broken_image, color: Colors.white54),
        ),
      ),
      config: config,
      fallbackColors: fallbackColors,
      onColorsReady: onColorsReady,
    );
  }

  @override
  State<AdaptiveGlowImageFrame> createState() => _AdaptiveGlowImageFrameState();
}

class _AdaptiveGlowImageFrameState extends State<AdaptiveGlowImageFrame> {
  ThemeColors? _colors;

  @override
  void initState() {
    super.initState();
    _extractColors();
  }

  @override
  void didUpdateWidget(covariant AdaptiveGlowImageFrame oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageProvider != widget.imageProvider ||
        oldWidget.config.targetBrightness != widget.config.targetBrightness) {
      _extractColors();
    }
  }

  Future<void> _extractColors() async {
    final colors = await extractColorsFromProvider(
      widget.imageProvider,
      widget.config,
      widget.fallbackColors,
    );
    if (!mounted) return;
    setState(() => _colors = colors);
    widget.onColorsReady?.call(colors);
  }

  List<BoxShadow> _buildShadows(ThemeColors palette) {
    final base = _resolveTone(palette, widget.tone);
    final secondary = palette.secondary;
    final layers = <BoxShadow>[];
    for (int i = 0; i < widget.layers; i++) {
      final t = (i + 1) / widget.layers;
      layers.add(
        BoxShadow(
          color: Color.lerp(base, secondary, t)!.withOpacity(0.35 - (0.1 * i)),
          blurRadius: widget.blurRadius * (1 + 0.6 * i),
          spreadRadius: widget.spreadRadius * (1 + 0.3 * i),
        ),
      );
    }
    return layers;
  }

  Color _resolveTone(ThemeColors colors, AdaptiveOverlayTone tone) {
    return switch (tone) {
      AdaptiveOverlayTone.primary => colors.primary,
      AdaptiveOverlayTone.secondary => colors.secondary,
      AdaptiveOverlayTone.surface => colors.surface,
      AdaptiveOverlayTone.background => colors.background,
    };
  }

  @override
  Widget build(BuildContext context) {
    final palette = _colors;
    return AspectRatio(
      aspectRatio: widget.aspectRatio,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: widget.borderRadius,
          boxShadow: palette == null ? [] : _buildShadows(palette),
        ),
        child: ClipRRect(
          borderRadius: widget.borderRadius,
          child: widget.backgroundImage ??
              Image(
                image: widget.imageProvider,
                fit: widget.fit,
                filterQuality: FilterQuality.high,
                errorBuilder: (_, __, ___) => const ColoredBox(
                  color: Colors.black12,
                  child: Icon(Icons.broken_image, color: Colors.white54),
                ),
              ),
        ),
      ),
    );
  }
}
