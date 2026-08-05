/// Immersive fluid animated backgrounds from images with intelligent color extraction.
///
/// # Features
///
/// - **Fluid animated backgrounds** - Layered image shaders with orbital motion and heavy blur
/// - **Intelligent color extraction** - Weighted k-means clustering for accurate palette generation
/// - **Smooth transitions** - Cross-fade between images with palette color tweening
/// - **Corner accent glows** - Radial gradients using extracted colors
/// - **Matte treatment** - Prevents harsh whites, ensures rich vibrant colors
/// - **Performance optimized** - Instant fallback, background extraction, efficient rendering
///
/// # Quick Start - FluidBackground Widget
///
/// The easiest way - widget handles everything automatically:
///
/// ```dart
/// import 'package:adaptive_palette/adaptive_palette.dart';
///
/// FluidBackground(
///   imageProvider: NetworkImage('https://example.com/album.jpg'),
///   child: Scaffold(
///     backgroundColor: Colors.transparent,
///     body: YourContent(),
///   ),
/// )
/// ```
///
/// # Quick Start - Manual Color Extraction
///
/// For custom implementations:
///
/// ```dart
/// import 'package:adaptive_palette/adaptive_palette.dart';
///
/// // Extract palette from image
/// final image = await loadImageFromProvider(NetworkImage(url));
/// final palette = await FluidPaletteExtractor.extract(image);
///
/// // Use colors
/// Container(color: palette.baseDark);       // Dark base
/// Container(color: palette.accent1);        // Top-left glow
/// Container(color: palette.accent2);        // Top-right glow
/// Container(color: palette.accent3);        // Bottom-left glow
/// Container(color: palette.accent4);        // Bottom-right glow
/// ```
///
/// # Full Configuration
///
/// ```dart
/// FluidBackground(
///   imageProvider: imageUrl == null ? null : NetworkImage(imageUrl),
///   blurSigma: 80,              // Blur intensity (60-120)
///   overlayDarken: 0.10,         // Dark overlay for legibility (0.05-0.20)
///   animate: true,               // Enable orbital motion
///   transitionDuration: Duration(milliseconds: 1400),
///   child: YourContent(),
/// )
/// ```
///
/// # How It Works
///
/// 1. Shows matte gradient fallback instantly
/// 2. Loads image and extracts FluidPalette in background
/// 3. Cross-fades from fallback to extracted colors (1400ms)
/// 4. Renders 4 layered ImageShaders with different scales/rotations
/// 5. Applies heavy 80σ Gaussian blur for atmospheric effect
/// 6. Adds corner radial glows using accent colors
/// 7. Overlays subtle dark layer for white text legibility
library;

import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

// Core modules
import 'src/cache.dart';
import 'src/config.dart';
import 'src/extraction.dart';
import 'src/models.dart';
import 'src/palette_scope.dart';
import 'src/scoring.dart';
import 'src/theme.dart';

// ==================== PRIMARY API ====================
// These are the main APIs you should use:

/// Load ui.Image from ImageProvider for color extraction
export 'src/extraction.dart' show loadImageFromProvider;

/// FluidPaletteExtractor - Extract colors from images; FluidPaletteCache - LRU cache
export 'src/fluid_extractor.dart';
export 'src/cache.dart' show FluidPaletteCache, FluidCacheEntry;

/// FluidPalette - Color palette model (baseDark + 4 accents)
export 'src/fluid_palette.dart';

/// FluidBackground - Immersive animated background widget
export 'src/widgets/fluid_background.dart';

// ==================== DEPRECATED (will be removed in v4.0.0) ====================
// These APIs are maintained for backward compatibility only.
// Migrate to FluidBackground and FluidPaletteExtractor instead.

/// @deprecated Use FluidPaletteExtractor instead
export 'src/config.dart';

/// @deprecated Use FluidPalette instead
export 'src/models.dart';

/// @deprecated No replacement - use FluidBackground directly
export 'src/palette_scope.dart';

/// @deprecated Use FluidBackground instead
export 'src/widgets/adaptive_glow_frame.dart';

/// @deprecated Use FluidBackground instead
export 'src/widgets/adaptive_gradient_scaffold.dart';

/// @deprecated Use FluidBackground instead
export 'src/widgets/adaptive_image_overlay.dart';

/// Main API for extracting adaptive color palettes from images.
///
/// **DEPRECATED**: Use [FluidPaletteExtractor] instead for color extraction.
///
/// This class is maintained for backward compatibility but will be removed in v4.0.0.
/// Migrate to FluidPaletteExtractor for better color accuracy and performance.
///
/// Old usage:
/// ```dart
/// final colors = await AdaptivePalette.fromImage(NetworkImage(url));
/// ```
///
/// New usage:
/// ```dart
/// final image = await loadImageFromProvider(NetworkImage(url));
/// final palette = await FluidPaletteExtractor.extract(image);
/// ```
@Deprecated(
    'Use FluidPaletteExtractor.extract() instead. Will be removed in v4.0.0')
class AdaptivePalette {
  AdaptivePalette._(); // Private constructor - all methods are static

  /// Extract a contrast-safe color palette from an ImageProvider.
  ///
  /// This is the main entry point for color extraction. It automatically:
  /// 1. Analyzes image characteristics (colorful/monochromatic/normal)
  /// 2. Extracts dominant colors using median-cut quantization
  /// 3. Scores colors based on perceptual qualities
  /// 4. Generates Material Design 3 theme with WCAG contrast validation
  /// 5. Caches results for instant future access
  ///
  /// Example with default settings:
  /// ```dart
  /// final colors = await AdaptivePalette.fromImage(
  ///   NetworkImage('https://example.com/image.jpg'),
  ///   targetBrightness: Brightness.dark,
  /// );
  /// ```
  ///
  /// Example with quality preset:
  /// ```dart
  /// final colors = await AdaptivePalette.fromImage(
  ///   image,
  ///   config: ExtractionConfig.fromQuality(ExtractionQuality.high),
  /// );
  /// ```
  ///
  /// Example with full configuration:
  /// ```dart
  /// final colors = await AdaptivePalette.fromImage(
  ///   image,
  ///   config: ExtractionConfig(
  ///     targetBrightness: Brightness.dark,
  ///     quantizeColors: 32,
  ///     resize: 128,
  ///     minContrast: 4.5,
  ///     diversityWeight: 1.2,
  ///     onDebug: (stats) => print(stats),
  ///   ),
  /// );
  /// ```
  ///
  /// For backwards compatibility, individual parameters are supported:
  /// ```dart
  /// final colors = await AdaptivePalette.fromImage(
  ///   image,
  ///   targetBrightness: Brightness.dark,
  ///   quantizeColors: 32,
  ///   resize: 128,
  ///   minContrast: 4.5,
  /// );
  /// ```
  static Future<ThemeColors> fromImage(
    ImageProvider provider, {
    // New: Accept full config object
    ExtractionConfig? config,
    // Legacy: Individual parameters for backwards compatibility
    Brightness? targetBrightness,
    int? quantizeColors,
    int? resize,
    double? minContrast,
  }) async {
    final startTime = DateTime.now();

    // Merge config with individual parameters (individual params take priority)
    final effectiveConfig = (config ?? const ExtractionConfig()).copyWith(
      targetBrightness: targetBrightness,
      quantizeColors: quantizeColors,
      resize: resize,
      minContrast: minContrast,
    );

    // Load image
    final img = await loadImageFromProvider(provider);
    final bytes = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (bytes == null) return const ThemeColors.fallback();

    // Check cache
    final key = computeImageHash(bytes.buffer.asUint8List());
    final cached = PaletteCache.instance.get(key);
    if (cached != null) {
      final duration = DateTime.now().difference(startTime);
      effectiveConfig.onDebug?.call(ExtractionStats(
        duration: duration,
        colorsExtracted: 0,
        pixelsProcessed: 0,
        originalSize: (img.width, img.height),
        processedSize: (img.width, img.height),
        fromCache: true,
        imageType: 'cached',
        avgSaturation: 0,
        avgChroma: 0,
        cacheKey: key,
      ));
      return cached;
    }

    final pixels = bytes.buffer.asUint8List();
    final w = img.width;
    final h = img.height;

    // Downsample for performance
    final sampled = downsampleImage(
      pixels,
      w,
      h,
      effectiveConfig.resize,
    );
    final sampledSize = _calculateSampledSize(
      w,
      h,
      effectiveConfig.resize,
    );

    // Extract colors using median-cut
    final swatches = extractColors(sampled, effectiveConfig.quantizeColors);

    // Score colors using adaptive algorithm
    final scored = scoreSwatches(swatches, effectiveConfig);

    if (scored.isEmpty) {
      return const ThemeColors.fallback();
    }

    // Get characteristics for stats
    final characteristics = analyzeImageCharacteristics(swatches);

    // Build theme from best seed color
    final seed = scored.first.color;
    final colors = buildTheme(
      seed,
      targetBrightness: effectiveConfig.targetBrightness,
      minContrast: effectiveConfig.minContrast,
    );

    // Cache result
    PaletteCache.instance.put(key, colors);

    // Report stats
    final duration = DateTime.now().difference(startTime);
    effectiveConfig.onDebug?.call(ExtractionStats(
      duration: duration,
      colorsExtracted: swatches.length,
      pixelsProcessed: sampled.length ~/ 4,
      originalSize: (w, h),
      processedSize: sampledSize,
      fromCache: false,
      imageType: characteristics.type,
      avgSaturation: characteristics.avgSaturation,
      avgChroma: characteristics.avgChroma,
      cacheKey: key,
    ));

    return colors;
  }

  /// Preload palettes for multiple images.
  ///
  /// Useful for warming the cache before showing a list of images.
  /// Failed extractions are omitted from the result.
  ///
  /// Example:
  /// ```dart
  /// final preloaded = await AdaptivePalette.warmup([
  ///   NetworkImage('https://example.com/image1.jpg'),
  ///   NetworkImage('https://example.com/image2.jpg'),
  ///   NetworkImage('https://example.com/image3.jpg'),
  /// ]);
  /// print('Preloaded ${preloaded.length} palettes');
  /// ```
  static Future<Map<ImageProvider, ThemeColors>> warmup(
    List<ImageProvider> providers, {
    ExtractionConfig config = const ExtractionConfig(),
  }) async {
    final results = <ImageProvider, ThemeColors>{};
    await Future.wait(
      providers.map((provider) async {
        try {
          final colors = await fromImage(provider, config: config);
          results[provider] = colors;
        } catch (e, stack) {
          debugPrint('AdaptivePalette.warmup: Failed to extract $provider: $e');
          config.onError?.call(e, stack);
        }
      }),
    );
    return results;
  }

  /// Animate the app theme to new colors inside a [PaletteScope].
  ///
  /// Convenience method equivalent to:
  /// ```dart
  /// PaletteScope.of(context).animateTo(colors);
  /// ```
  ///
  /// Example:
  /// ```dart
  /// final colors = await AdaptivePalette.fromImage(image);
  /// await AdaptivePalette.animateTo(context, colors);
  /// ```
  static Future<void> animateTo(
    BuildContext context,
    ThemeColors colors, {
    Duration duration = const Duration(milliseconds: 800),
    Curve curve = Curves.easeInOutCubicEmphasized,
  }) async {
    PaletteScope.of(context).animateTo(
      colors,
      duration: duration,
      curve: curve,
    );
  }

  /// Clear the palette cache.
  ///
  /// Useful for memory management or when you want to force re-extraction.
  ///
  /// Example:
  /// ```dart
  /// AdaptivePalette.clearCache();
  /// ```
  static void clearCache() {
    PaletteCache.instance.clear();
  }

  /// Get current cache statistics.
  ///
  /// Returns (current size, capacity).
  ///
  /// Example:
  /// ```dart
  /// final (size, capacity) = AdaptivePalette.cacheStats();
  /// print('Cache: $size/$capacity');
  /// ```
  static (int size, int capacity) cacheStats() {
    return (PaletteCache.instance.size, PaletteCache.instance.capacity);
  }
}

// Helper to calculate sampled image size
(int, int) _calculateSampledSize(int w, int h, int target) {
  if (w <= target && h <= target) return (w, h);
  final aspect = w / h;
  if (aspect >= 1.0) {
    return (target, (target / aspect).round());
  } else {
    return ((target * aspect).round(), target);
  }
}

// Update widget_helpers.dart implementation
// This needs to be accessible from widgets
Future<ThemeColors> extractColorsFromProviderImpl(
  ImageProvider provider,
  ExtractionConfig config,
  ThemeColors fallback,
) async {
  try {
    return await AdaptivePalette.fromImage(provider, config: config);
  } catch (error, stack) {
    debugPrint('AdaptivePalette: failed to extract colors: $error');
    if (kDebugMode) debugPrint('$stack');
    config.onError?.call(error, stack);
    return fallback;
  }
}
