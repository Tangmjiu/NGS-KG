/// Hero/card widget with adaptive gradient overlay.
library;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../config.dart';
import '../models.dart';
import 'widget_helpers.dart';

/// Ready-made hero/card widget that paints an adaptive gradient overlay
/// across an image.
///
/// **DEPRECATED**: Use [FluidBackground] instead for immersive animated backgrounds.
///
/// This widget is maintained for backward compatibility but will be removed in v4.0.0.
/// Migrate to FluidBackground for better performance and visual quality.
///
/// Example:
/// ```dart
/// AdaptiveImageOverlay.network(
///   'https://example.com/cover.jpg',
///   overlayStyle: AdaptiveOverlayStyle(
///     begin: Alignment.centerLeft,
///     end: Alignment.centerRight,
///     stops: [0.0, 0.4, 0.7, 1.0],
///     opacities: [0.95, 0.65, 0.25, 0.0],
///   ),
///   child: Text('Your content here'),
/// )
/// ```
@Deprecated('Use FluidBackground instead. Will be removed in v4.0.0')
class AdaptiveImageOverlay extends StatefulWidget {
  final ImageProvider imageProvider;
  final AdaptiveOverlayStyle overlayStyle;
  final double aspectRatio;
  final BorderRadius borderRadius;
  final Widget? child;
  final EdgeInsetsGeometry padding;
  final Alignment alignment;
  final BoxFit fit;
  final Widget? backgroundImage;
  final ExtractionConfig config;
  final ThemeColors fallbackColors;
  final ValueChanged<ThemeColors>? onColorsReady;
  final bool showLoadingIndicator;
  final Widget? loadingBuilder;

  const AdaptiveImageOverlay({
    super.key,
    required this.imageProvider,
    this.overlayStyle = const AdaptiveOverlayStyle(),
    this.aspectRatio = 16 / 9,
    this.borderRadius = const BorderRadius.all(Radius.circular(24)),
    this.child,
    this.padding = const EdgeInsets.all(24),
    this.alignment = Alignment.centerLeft,
    this.fit = BoxFit.cover,
    this.backgroundImage,
    this.config = const ExtractionConfig(),
    this.fallbackColors = const ThemeColors.fallback(),
    this.onColorsReady,
    this.showLoadingIndicator = true,
    this.loadingBuilder,
  });

  /// Create overlay with network image.
  factory AdaptiveImageOverlay.network(
    String imageUrl, {
    Key? key,
    AdaptiveOverlayStyle overlayStyle = const AdaptiveOverlayStyle(),
    double aspectRatio = 16 / 9,
    BorderRadius borderRadius = const BorderRadius.all(Radius.circular(24)),
    Widget? child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(24),
    Alignment alignment = Alignment.centerLeft,
    BoxFit fit = BoxFit.cover,
    ExtractionConfig config = const ExtractionConfig(),
    ThemeColors fallbackColors = const ThemeColors.fallback(),
    ValueChanged<ThemeColors>? onColorsReady,
    bool showLoadingIndicator = true,
    Widget? loadingBuilder,
  }) {
    return AdaptiveImageOverlay(
      key: key,
      imageProvider: CachedNetworkImageProvider(imageUrl),
      overlayStyle: overlayStyle,
      aspectRatio: aspectRatio,
      borderRadius: borderRadius,
      padding: padding,
      alignment: alignment,
      fit: fit,
      backgroundImage: CachedNetworkImage(
        imageUrl: imageUrl,
        fit: fit,
        placeholder: (_, __) => const ColoredBox(color: Colors.black12),
        errorWidget: (_, __, ___) => const ColoredBox(
          color: Colors.black12,
        ),
      ),
      config: config,
      fallbackColors: fallbackColors,
      onColorsReady: onColorsReady,
      showLoadingIndicator: showLoadingIndicator,
      loadingBuilder: loadingBuilder,
      child: child,
    );
  }

  @override
  State<AdaptiveImageOverlay> createState() => _AdaptiveImageOverlayState();
}

class _AdaptiveImageOverlayState extends State<AdaptiveImageOverlay> {
  ThemeColors? _colors;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _extractColors();
  }

  @override
  void didUpdateWidget(covariant AdaptiveImageOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageProvider != widget.imageProvider ||
        oldWidget.config.targetBrightness != widget.config.targetBrightness) {
      _extractColors();
    }
  }

  Future<void> _extractColors() async {
    setState(() => _loading = true);
    final colors = await extractColorsFromProvider(
      widget.imageProvider,
      widget.config,
      widget.fallbackColors,
    );
    if (!mounted) return;
    setState(() {
      _colors = colors;
      _loading = false;
    });
    widget.onColorsReady?.call(colors);
  }

  @override
  Widget build(BuildContext context) {
    final palette = _colors ?? const ThemeColors.fallback();
    final gradient = palette.overlayGradient(style: widget.overlayStyle);
    final textColor = palette.onPrimary;

    return AspectRatio(
      aspectRatio: widget.aspectRatio,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: widget.borderRadius,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.25),
              blurRadius: 32,
              offset: const Offset(0, 18),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: widget.borderRadius,
          child: Stack(
            fit: StackFit.expand,
            children: [
              widget.backgroundImage ??
                  Image(
                    image: widget.imageProvider,
                    fit: widget.fit,
                    filterQuality: FilterQuality.high,
                    errorBuilder: (_, __, ___) => const ColoredBox(
                      color: Colors.black12,
                      child: Icon(Icons.broken_image, color: Colors.white54),
                    ),
                  ),
              Container(decoration: BoxDecoration(gradient: gradient)),
              if (widget.child != null)
                Align(
                  alignment: widget.alignment,
                  child: Padding(
                    padding: widget.padding,
                    child: DefaultTextStyle(
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.w600,
                      ),
                      child: IconTheme(
                        data: IconThemeData(color: textColor),
                        child: widget.child!,
                      ),
                    ),
                  ),
                ),
              if (_loading && widget.showLoadingIndicator)
                Positioned(
                  right: 16,
                  top: 16,
                  child: widget.loadingBuilder ??
                      const SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
