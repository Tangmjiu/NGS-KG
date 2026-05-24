import 'package:flutter/material.dart';
import 'package:palette_generator/palette_generator.dart';

/// Holds the colors extracted from an album art image.
///
/// The [dominant] color is always available (either extracted or fallback).
/// All other palette colors are nullable and may be absent depending on
/// the source image content.
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

  const ExtractedPalette({
    required this.dominant,
    this.vibrant,
    this.muted,
    this.darkMuted,
    this.lightVibrant,
  });

  @override
  String toString() =>
      'ExtractedPalette(dominant: $dominant, vibrant: $vibrant, muted: $muted, '
      'darkMuted: $darkMuted, lightVibrant: $lightVibrant)';
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

  /// Extracts a color palette from the image at [imageUrl].
  ///
  /// Uses [NetworkImage] to load the image and [PaletteGenerator] to extract
  /// the swatches. Results are cached by URL so subsequent calls with the same
  /// URL return instantly.
  ///
  /// Never throws — returns the [fallbackPalette] on any error.
  Future<ExtractedPalette> extract(String imageUrl) async {
    // Check cache first.
    final cached = _cache[imageUrl];
    if (cached != null) {
      return cached;
    }

    try {
      final generator = await PaletteGenerator.fromImageProvider(
        NetworkImage(imageUrl),
      );

      final palette = ExtractedPalette(
        dominant: generator.dominantColor?.color ?? _defaultDominant,
        vibrant: generator.vibrantColor?.color,
        muted: generator.mutedColor?.color,
        darkMuted: generator.darkMutedColor?.color,
        lightVibrant: generator.lightVibrantColor?.color,
      );

      _cache[imageUrl] = palette;
      return palette;
    } catch (_) {
      // Graceful fallback — return the default dark palette.
      _cache[imageUrl] = _fallbackPalette;
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
