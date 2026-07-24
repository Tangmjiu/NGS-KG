import 'package:flutter/material.dart';
import 'package:flutter/painting.dart';
import 'package:palette_generator/palette_generator.dart';

/// Holds the colors extracted from an album art image.
///
/// The [dominant] color is always available (either extracted or fallback).
/// All other palette colors are nullable and may be absent depending on
/// the source image content.
///
/// [topColors] contains the top N quantized colours sorted by population,
/// giving a richer set of distinct colours than the hand-picked targets alone.
class ExtractedPalette {
  /// The overall dominant color of the image.
  /// Guaranteed non-null; falls back to [PaletteExtractor._defaultDominant].
  final Color dominant;

  /// A vibrant color pulled from the image, if available.
  final Color? vibrant;

  /// A muted (desaturated) color from the image, if available.
  final Color? muted;

  /// A dark muted color, suitable for background surfaces.
  final Color? darkMuted;

  /// A light vibrant color, suitable for accents on dark backgrounds.
  final Color? lightVibrant;

  /// Top N quantized colours sorted by pixel population.
  /// Guaranteed non-empty when [dominant] is meaningful.
  final List<Color> topColors;

  const ExtractedPalette({
    required this.dominant,
    this.vibrant,
    this.muted,
    this.darkMuted,
    this.lightVibrant,
    this.topColors = const [],
  });

  @override
  String toString() =>
      'ExtractedPalette(dominant: $dominant, vibrant: $vibrant, muted: $muted, '
      'darkMuted: $darkMuted, lightVibrant: $lightVibrant, '
      'topColors: ${topColors.length})';
}

/// A singleton utility that extracts color palettes from album art images
/// and caches results to avoid repeated network and processing work.
///
/// Usage:
/// ```dart
/// final palette = await PaletteExtractor.instance.extract(imageUrl);
/// // use palette.dominant, palette.vibrant, etc.
/// ```
///
/// If extraction fails or the image cannot be loaded, a default dark palette
/// is returned — this utility **never throws**.
class PaletteExtractor {
  // ───── Singleton ─────

  PaletteExtractor._();

  /// The shared singleton instance.
  static final PaletteExtractor instance = PaletteExtractor._();

  // ───── Default fallback palette (dark theme) ─────

  static const Color _defaultDominant = Color(0xFF121212);
  static const Color _defaultVibrant = Color(0xFF1DB954);
  static const Color _defaultMuted = Color(0xFF2A2D28);

  static const ExtractedPalette _fallbackPalette = ExtractedPalette(
    dominant: _defaultDominant,
    vibrant: _defaultVibrant,
    muted: _defaultMuted,
  );

  // ───── Internal cache ─────

  final Map<String, ExtractedPalette> _cache = <String, ExtractedPalette>{};

  /// Converts a [PaletteGenerator] result into an [ExtractedPalette].
  static ExtractedPalette _toExtractedPalette(PaletteGenerator generator) {
    final crop = generator.colors
        .where((c) => c != generator.dominantColor?.color)
        .toList();
    crop.sort((a, b) => HSLColor.fromColor(a).lightness
        .compareTo(HSLColor.fromColor(b).lightness));
    final topColors = <Color>[];
    if (crop.isNotEmpty) {
      if (crop.length <= 7) {
        topColors.addAll(crop);
      } else {
        final step = (crop.length - 1) / 6;
        for (int i = 0; i < 7; i++) {
          topColors.add(crop[(i * step).round()]);
        }
      }
    }
    return ExtractedPalette(
      dominant: generator.dominantColor?.color ?? _defaultDominant,
      vibrant: generator.vibrantColor?.color,
      muted: generator.mutedColor?.color,
      darkMuted: generator.darkMutedColor?.color,
      lightVibrant: generator.lightVibrantColor?.color,
      topColors: topColors,
    );
  }

  /// Extracts a color palette from the image at [imageUrl].
  ///
  /// Uses [NetworkImage] to load the image and [PaletteGenerator] to extract
  /// the swatches. Results are cached by URL so subsequent calls with the same
  /// URL return instantly.
  ///
  /// Never throws — returns the [fallbackPalette] on any error.
  Future<ExtractedPalette> extract(String imageUrl) async {
    final cached = _cache[imageUrl];
    if (cached != null) return cached;

    try {
      final generator = await PaletteGenerator.fromImageProvider(
        NetworkImage(imageUrl),
      );
      final palette = _toExtractedPalette(generator);
      _cache[imageUrl] = palette;
      return palette;
    } catch (_) {
      _cache[imageUrl] = _fallbackPalette;
      return _fallbackPalette;
    }
  }

  /// Extracts a color palette using a custom [ImageProvider] (e.g. [FileImage]
  /// for local files) and caches the result under [cacheKey].
  ///
  /// Never throws — returns the [fallbackPalette] on any error.
  Future<ExtractedPalette> extractFromProvider(
      ImageProvider provider, String cacheKey) async {
    final cached = _cache[cacheKey];
    if (cached != null) return cached;

    try {
      final generator = await PaletteGenerator.fromImageProvider(provider);
      final palette = _toExtractedPalette(generator);
      _cache[cacheKey] = palette;
      return palette;
    } catch (_) {
      _cache[cacheKey] = _fallbackPalette;
      return _fallbackPalette;
    }
  }

  /// The default palette used when extraction fails.
  static ExtractedPalette get fallbackPalette => _fallbackPalette;

  /// Clears all cached palette results.
  void clearCache() {
    _cache.clear();
  }
}
