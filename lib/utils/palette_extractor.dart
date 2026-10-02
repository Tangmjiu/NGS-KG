import 'dart:async';
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

  static const _maxCacheEntries = 128;
  final Map<String, ExtractedPalette> _cache = <String, ExtractedPalette>{};
  final Map<String, Future<ExtractedPalette>> _inFlight = {};
  int _cacheGeneration = 0;

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
  /// Limits resolution to 256px for fast extraction.
  /// Never throws — returns the [fallbackPalette] on any error.
  Future<ExtractedPalette> extract(String imageUrl) =>
      extractFromProvider(NetworkImage(imageUrl), imageUrl);

  /// Extracts a color palette using a custom [ImageProvider] (e.g. [FileImage]
  /// for local files) and caches the result under [cacheKey].
  ///
  /// Concurrent requests for the same cover share both decoding and extraction.
  /// Never throws — returns the [fallbackPalette] on any error.
  Future<ExtractedPalette> extractFromProvider(
      ImageProvider provider, String cacheKey) {
    final cached = _cache[cacheKey];
    if (cached != null) return Future.value(cached);
    final pending = _inFlight[cacheKey];
    if (pending != null) return pending;

    final completer = Completer<ExtractedPalette>();
    final future = completer.future;
    final generation = _cacheGeneration;
    _inFlight[cacheKey] = future;
    unawaited(() async {
      var palette = _fallbackPalette;
      try {
        final generator = await PaletteGenerator.fromImageProvider(
          // size 只是 ImageConfiguration 提示，降采样由 ResizeImage 执行。
          ResizeImage(provider, width: 256, height: 256,
              policy: ResizeImagePolicy.fit),
          size: const Size(256, 256),
          maximumColorCount: 16,
        );
        palette = _toExtractedPalette(generator);
      } catch (_) {
      } finally {
        if (generation == _cacheGeneration) {
          _cache[cacheKey] = palette;
          if (_cache.length > _maxCacheEntries) _cache.remove(_cache.keys.first);
        }        if (identical(_inFlight[cacheKey], future)) _inFlight.remove(cacheKey);
        completer.complete(palette);
      }
    }());
    return future;
  }

  /// The default palette used when extraction fails.
  static ExtractedPalette get fallbackPalette => _fallbackPalette;

  /// Clears all cached palette results.
  void clearCache() {
    _cacheGeneration++;
    _cache.clear();
    _inFlight.clear();
  }
}
