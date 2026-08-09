/// Configuration options for adaptive palette extraction.
library;

import 'package:flutter/material.dart';

/// Quality presets for color extraction.
///
/// These presets balance speed vs accuracy for different use cases:
/// - [ExtractionQuality.fast]: For scrolling lists, real-time updates
/// - [ExtractionQuality.balanced]: General purpose (default)
/// - [ExtractionQuality.high]: For hero images, detail views
enum ExtractionQuality {
  /// Fast extraction optimized for scrolling lists.
  ///
  /// - Resize: 64px
  /// - Colors: 16
  /// - Best for: List items, thumbnails, rapid updates
  fast,

  /// Balanced quality for general use.
  ///
  /// - Resize: 96px
  /// - Colors: 24
  /// - Best for: Most use cases
  balanced,

  /// High quality extraction for important images.
  ///
  /// - Resize: 128px
  /// - Colors: 32
  /// - Best for: Hero images, detail views, album covers
  high,
}

/// Configuration for adaptive palette extraction.
class ExtractionConfig {
  /// Target brightness for theme generation.
  final Brightness targetBrightness;

  /// Number of colors to extract (8-64).
  ///
  /// Higher values provide better color selection but slower processing.
  /// - Fast: 16 colors
  /// - Balanced: 24 colors
  /// - High: 32 colors
  final int quantizeColors;

  /// Target size for image downsampling (64-256).
  ///
  /// Larger values are slower but more accurate.
  /// - Fast: 64px
  /// - Balanced: 96px
  /// - High: 128px
  final int resize;

  /// Minimum WCAG contrast ratio for text colors.
  ///
  /// - 4.5:1 = WCAG AA (default)
  /// - 7.0:1 = WCAG AAA
  final double minContrast;

  /// Weight for color diversity in scoring (0.0-2.0).
  ///
  /// Higher values favor colors different from already selected colors.
  /// - 1.0 = Default behavior
  /// - 1.5 = Strongly favor diverse colors
  /// - 0.0 = No diversity preference
  final double diversityWeight;

  /// Callback for extraction statistics and debugging.
  ///
  /// Receives [ExtractionStats] after color extraction completes.
  final void Function(ExtractionStats stats)? onDebug;

  /// Callback for error logging.
  ///
  /// If not provided, errors are printed to debug console only.
  final void Function(Object error, StackTrace stack)? onError;

  const ExtractionConfig({
    this.targetBrightness = Brightness.light,
    this.quantizeColors = 24,
    this.resize = 96,
    this.minContrast = 4.5,
    this.diversityWeight = 1.1,
    this.onDebug,
    this.onError,
  })  : assert(quantizeColors >= 8 && quantizeColors <= 64,
            'quantizeColors must be between 8 and 64'),
        assert(
            resize >= 64 && resize <= 256, 'resize must be between 64 and 256'),
        assert(minContrast >= 3.0 && minContrast <= 21.0,
            'minContrast must be between 3.0 and 21.0'),
        assert(diversityWeight >= 0.0 && diversityWeight <= 2.0,
            'diversityWeight must be between 0.0 and 2.0');

  /// Create configuration from quality preset.
  factory ExtractionConfig.fromQuality(
    ExtractionQuality quality, {
    Brightness targetBrightness = Brightness.light,
    double? minContrast,
    double? diversityWeight,
    void Function(ExtractionStats stats)? onDebug,
    void Function(Object error, StackTrace stack)? onError,
  }) {
    final (colors, size) = switch (quality) {
      ExtractionQuality.fast => (16, 64),
      ExtractionQuality.balanced => (24, 96),
      ExtractionQuality.high => (32, 128),
    };

    return ExtractionConfig(
      targetBrightness: targetBrightness,
      quantizeColors: colors,
      resize: size,
      minContrast: minContrast ?? 4.5,
      diversityWeight: diversityWeight ?? 1.1,
      onDebug: onDebug,
      onError: onError,
    );
  }

  /// Create a copy with modified values.
  ExtractionConfig copyWith({
    Brightness? targetBrightness,
    int? quantizeColors,
    int? resize,
    double? minContrast,
    double? diversityWeight,
    void Function(ExtractionStats stats)? onDebug,
    void Function(Object error, StackTrace stack)? onError,
  }) {
    return ExtractionConfig(
      targetBrightness: targetBrightness ?? this.targetBrightness,
      quantizeColors: quantizeColors ?? this.quantizeColors,
      resize: resize ?? this.resize,
      minContrast: minContrast ?? this.minContrast,
      diversityWeight: diversityWeight ?? this.diversityWeight,
      onDebug: onDebug ?? this.onDebug,
      onError: onError ?? this.onError,
    );
  }
}

/// Statistics from color extraction for debugging and optimization.
class ExtractionStats {
  /// Total time taken for extraction.
  final Duration duration;

  /// Number of colors extracted.
  final int colorsExtracted;

  /// Number of pixels processed.
  final int pixelsProcessed;

  /// Original image dimensions.
  final (int width, int height) originalSize;

  /// Downsampled image dimensions.
  final (int width, int height) processedSize;

  /// Whether result was loaded from cache.
  final bool fromCache;

  /// Image type detected by scoring algorithm.
  final String imageType;

  /// Average saturation of extracted colors.
  final double avgSaturation;

  /// Average chroma of extracted colors.
  final double avgChroma;

  /// Cache key (SHA-1 hash).
  final String cacheKey;

  const ExtractionStats({
    required this.duration,
    required this.colorsExtracted,
    required this.pixelsProcessed,
    required this.originalSize,
    required this.processedSize,
    required this.fromCache,
    required this.imageType,
    required this.avgSaturation,
    required this.avgChroma,
    required this.cacheKey,
  });

  @override
  String toString() {
    return 'ExtractionStats('
        'duration: ${duration.inMilliseconds}ms, '
        'colors: $colorsExtracted, '
        'pixels: $pixelsProcessed, '
        'size: ${originalSize.$1}x${originalSize.$2} -> ${processedSize.$1}x${processedSize.$2}, '
        'cached: $fromCache, '
        'type: $imageType, '
        'avgSat: ${avgSaturation.toStringAsFixed(2)}, '
        'avgChroma: ${avgChroma.toStringAsFixed(1)}'
        ')';
  }
}

/// Global cache configuration.
class CacheConfig {
  /// Maximum number of palettes to cache in memory.
  static int maxSize = 32; // Increased from 16

  /// Clear the entire cache.
  static void clear() {
    // Implementation in cache.dart
  }

  /// Enable/disable caching.
  static bool enabled = true;
}
