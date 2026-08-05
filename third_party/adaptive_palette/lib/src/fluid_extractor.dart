/// Advanced color extraction for fluid immersive backgrounds.
library;

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'cache.dart';
import 'extraction.dart';
import 'fluid_palette.dart';

/// Extracts dominant colors from images using weighted k-means clustering.
///
/// ## Primary API
///
/// Use [extractColors] to extract a ranked list of dominant colors from any
/// [ImageProvider]:
///
/// ```dart
/// final colors = await FluidPaletteExtractor.extractColors(
///   NetworkImage('https://example.com/album.jpg'),
///   count: 5,
/// );
/// ```
///
/// Results are automatically cached in [FluidPaletteCache] by image content
/// hash (SHA-1). Subsequent calls with the same image return instantly.
///
/// ## Pre-warming the cache
///
/// For music players or galleries where you know upcoming images, pre-warm
/// to eliminate latency on first display:
///
/// ```dart
/// await FluidPaletteExtractor.warmup([
///   NetworkImage(nextTrack.albumArtUrl),
///   NetworkImage(upNextTrack.albumArtUrl),
/// ]);
/// ```
///
/// ## Internal palette extraction
///
/// [FluidBackground] uses palette extraction internally — you do not need to
/// call [extract] directly. If you need a [FluidPalette] for custom rendering,
/// prefer composing from [extractColors] instead.
///
/// ## Algorithm
///
/// 1. **Smart sampling** — pixels sampled at stride-10 intervals with bias
///    toward image center and high-vibrancy regions.
/// 2. **Filtering** — near-white, near-black, and near-gray pixels discarded.
/// 3. **Weighted k-means** — 6 clusters, 10 iterations, weights by vibrancy
///    and center proximity.
/// 4. **Perceptual scoring** — clusters ranked by saturation and mid-tone
///    preference.
/// 5. **Matte treatment** — over-bright whites clamped to vibrant matte tones.
/// 6. **LRU cache** — results cached by image content hash; default 30 entries.
class FluidPaletteExtractor {
  FluidPaletteExtractor._(); // Private constructor — static API only.

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Extract the top [count] dominant colors from an [ImageProvider].
  ///
  /// Returns colors ranked by vibrancy — most dominant first. Colors are
  /// matte-treated to prevent harsh whites and washed-out highlights.
  ///
  /// Results are cached in [FluidPaletteCache] by image content hash.
  /// Subsequent calls with the same image content return instantly.
  ///
  /// [count] must be between 1 and 10 (inclusive). When fewer distinct colors
  /// are found than requested, the returned list may be shorter than [count].
  ///
  /// Throws if the image cannot be loaded. Callers should handle errors:
  ///
  /// ```dart
  /// try {
  ///   final colors = await FluidPaletteExtractor.extractColors(
  ///     NetworkImage('https://example.com/image.jpg'),
  ///     count: 5,
  ///   );
  ///   // use colors[0] as primary, colors[1] as accent, etc.
  /// } catch (e) {
  ///   // handle load or extraction failure
  /// }
  /// ```
  static Future<List<Color>> extractColors(
    ImageProvider provider, {
    int count = 5,
  }) async {
    assert(count >= 1 && count <= 10, 'count must be between 1 and 10');
    final int clampedCount = count.clamp(1, 10);

    final ui.Image image = await loadImageFromProvider(provider);
    final FluidCacheEntry entry = await _extractOrCache(image);

    return entry.colors.take(clampedCount).toList();
  }

  /// Pre-warm the [FluidPaletteCache] for a list of upcoming images.
  ///
  /// Runs extraction in parallel for all providers. Failed extractions are
  /// silently skipped — they will be re-attempted on first use.
  ///
  /// Example — pre-warm next tracks in a playlist:
  /// ```dart
  /// await FluidPaletteExtractor.warmup([
  ///   NetworkImage(nextTrack.albumArtUrl),
  ///   NetworkImage(upNextTrack.albumArtUrl),
  /// ]);
  /// ```
  static Future<void> warmup(List<ImageProvider> providers) async {
    await Future.wait(
      providers.map((provider) async {
        try {
          final ui.Image image = await loadImageFromProvider(provider);
          await _extractOrCache(image);
        } catch (_) {
          // Silently skip — warmup failures are non-fatal.
        }
      }),
    );
  }

  // ---------------------------------------------------------------------------
  // Deprecated API
  // ---------------------------------------------------------------------------

  /// Extract a [FluidPalette] from a [ui.Image].
  ///
  /// **Deprecated.** Use [extractColors] instead, which accepts an
  /// [ImageProvider] directly and returns a plain [List<Color>] you can adapt
  /// to any use-case without being locked into the [FluidPalette] structure.
  ///
  /// This method will be removed in v4.0.0.
  ///
  /// Migration:
  /// ```dart
  /// // Before:
  /// final image = await loadImageFromProvider(provider);
  /// final palette = await FluidPaletteExtractor.extract(image);
  ///
  /// // After:
  /// final colors = await FluidPaletteExtractor.extractColors(provider);
  /// ```
  @Deprecated(
    'Use FluidPaletteExtractor.extractColors(ImageProvider) instead. '
    'extract() will be removed in v4.0.0.',
  )
  static Future<FluidPalette> extract(ui.Image image) =>
      buildPaletteFromImage(image);

  // ---------------------------------------------------------------------------
  // Advanced API
  // ---------------------------------------------------------------------------

  /// Builds a [FluidPalette] from a pre-decoded [ui.Image].
  ///
  /// Use this when you already hold a [ui.Image] (e.g. from a custom decode
  /// pipeline). For the common case, prefer [extractColors] which accepts an
  /// [ImageProvider] directly.
  ///
  /// Results are cached by image content hash — repeated calls with the same
  /// image bytes return instantly without re-running k-means.
  static Future<FluidPalette> buildPaletteFromImage(ui.Image image) async {
    final FluidCacheEntry entry = await _extractOrCache(image);
    return entry.palette;
  }

  // ---------------------------------------------------------------------------
  // Private implementation
  // ---------------------------------------------------------------------------

  /// Core extraction + cache logic.
  ///
  /// Decodes [image] to raw bytes once, computes a content hash, returns the
  /// cached [FluidCacheEntry] on hit, or runs the full pipeline on miss and
  /// stores both [FluidPalette] and [List<Color>] representations together.
  static Future<FluidCacheEntry> _extractOrCache(ui.Image image) async {
    final ByteData? bd =
        await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (bd == null) {
      return FluidCacheEntry(
        colors: const [],
        palette: const FluidPalette.fallback(),
      );
    }

    final Uint8List px = bd.buffer.asUint8List();
    final String key = computeImageHash(px);

    final FluidCacheEntry? cached = FluidPaletteCache.instance.get(key);
    if (cached != null) return cached;

    final List<_Vec3> centers = _runPipeline(px, image.width, image.height);

    final List<Color> colors = centers
        .take(10)
        .map(
          (v) => _matteizeIfTooBright(
            _matteizeWhite(
              _amplify(_toColor(v), satBoost: 1.18, lightBoost: 1.04),
            ),
          ),
        )
        .toList();

    final FluidPalette palette = _buildPalette(centers);
    final FluidCacheEntry entry =
        FluidCacheEntry(colors: colors, palette: palette);

    FluidPaletteCache.instance.put(key, entry);
    return entry;
  }

  static FluidPalette _buildPalette(List<_Vec3> centers) {
    if (centers.isEmpty) return const FluidPalette.fallback();

    Color pick(int idx, {required double satB, required double lightB}) {
      if (idx >= centers.length) return const FluidPalette.fallback().accent1;
      final Color raw = _amplify(
        _toColor(centers[idx]),
        satBoost: satB,
        lightBoost: lightB,
      );
      return _matteizeIfTooBright(_matteizeWhite(raw));
    }

    return FluidPalette(
      baseDark: _ensureBaseDark(pick(0, satB: 1.15, lightB: 1.05)),
      accent1: pick(1, satB: 1.20, lightB: 1.05),
      accent2: pick(2, satB: 1.18, lightB: 1.03),
      accent3: pick(3, satB: 1.16, lightB: 1.02),
      accent4: pick(4, satB: 1.14, lightB: 1.02),
    );
  }

  /// Shared pixel sampling and weighted k-means clustering pipeline.
  ///
  /// Accepts pre-decoded [px] bytes to avoid double-decoding.
  /// Returns cluster centers sorted by perceptual vibrancy score.
  static List<_Vec3> _runPipeline(Uint8List px, int w, int h) {
    final List<_Vec3> samples = [];
    const int stride = 10;

    for (int y = 0; y < h; y += stride) {
      for (int x = 0; x < w; x += stride) {
        final int i = (y * w + x) * 4;
        if (i + 3 >= px.length) continue;

        final int r = px[i];
        final int g = px[i + 1];
        final int b = px[i + 2];
        final int a = px[i + 3];
        if (a < 200) continue;

        final _ColorStats s = _ColorStats.fromRgb(r, g, b);

        // Discard near-white, near-black, near-gray.
        if (s.lightness > 0.96) continue;
        if (s.lightness < 0.03) continue;
        if (s.sat < 0.05 && s.lightness > 0.85) continue;

        // Weight by vibrancy and center proximity.
        final double cx = (x / (w - 1)) - 0.5;
        final double cy = (y / (h - 1)) - 0.5;
        final double centerWeight =
            1.0 + (0.8 * (1.0 - (cx * cx + cy * cy).clamp(0.0, 1.0)));
        final double vib = s.sat * 0.75 + s.lightness * 0.25;

        samples.add(
          _Vec3(
            r.toDouble(),
            g.toDouble(),
            b.toDouble(),
            weight: (0.5 + vib) * centerWeight,
          ),
        );
      }
    }

    if (samples.isEmpty) return const [];

    final List<_Vec3> centers = _kmeansWeighted(samples, k: 6, iters: 10);
    centers.sort((a, b) => _clusterScore(b).compareTo(_clusterScore(a)));
    return centers;
  }

  /// Perceptual vibrancy score for a cluster center.
  static double _clusterScore(_Vec3 v) {
    final _ColorStats s = _ColorStats.fromRgb(
      v.x.round(),
      v.y.round(),
      v.z.round(),
    );
    final double mid = 1.0 - (s.lightness - 0.55).abs();
    final double penaltyGray = s.sat < 0.10 ? 0.25 : 1.0;
    return (s.sat * 1.2 + mid * 0.8) * penaltyGray;
  }
}

// -----------------------------------------------------------------------------
// Internal helper types
// -----------------------------------------------------------------------------

/// 3D vector representing an RGB color sample with optional weight.
class _Vec3 {
  const _Vec3(this.x, this.y, this.z, {this.weight = 1.0});

  final double x;
  final double y;
  final double z;
  final double weight;

  /// Squared Euclidean distance to [other].
  double dist2(_Vec3 other) {
    final double dx = x - other.x;
    final double dy = y - other.y;
    final double dz = z - other.z;
    return dx * dx + dy * dy + dz * dz;
  }
}

/// HSL-derived saturation and lightness for a sampled pixel.
class _ColorStats {
  const _ColorStats({required this.sat, required this.lightness});

  final double sat;
  final double lightness;

  static _ColorStats fromRgb(int r, int g, int b) {
    final HSLColor hsl = HSLColor.fromColor(Color.fromARGB(255, r, g, b));
    return _ColorStats(sat: hsl.saturation, lightness: hsl.lightness);
  }
}

// -----------------------------------------------------------------------------
// K-means clustering
// -----------------------------------------------------------------------------

/// Weighted k-means in RGB space.
///
/// Initialises centers using weighted random selection, then alternates between
/// assignment and update steps for [iters] iterations. Near-duplicate cluster
/// centers (distance < 28) are collapsed before returning.
List<_Vec3> _kmeansWeighted(
  List<_Vec3> pts, {
  required int k,
  required int iters,
}) {
  final math.Random rnd = math.Random(42);

  // Weighted random initialisation.
  final List<_Vec3> centers = [];
  double sumW = pts.fold(0.0, (acc, p) => acc + p.weight);

  for (int i = 0; i < k; i++) {
    double r = rnd.nextDouble() * sumW;
    for (final _Vec3 p in pts) {
      r -= p.weight;
      if (r <= 0) {
        centers.add(_Vec3(p.x, p.y, p.z));
        break;
      }
    }
  }

  final List<int> assign = List.filled(pts.length, 0);

  for (int it = 0; it < iters; it++) {
    // Assignment step.
    for (int i = 0; i < pts.length; i++) {
      double best = double.infinity;
      int bi = 0;
      for (int c = 0; c < centers.length; c++) {
        final double d = pts[i].dist2(centers[c]);
        if (d < best) {
          best = d;
          bi = c;
        }
      }
      assign[i] = bi;
    }

    // Weighted update step.
    final List<double> sx = List.filled(k, 0.0);
    final List<double> sy = List.filled(k, 0.0);
    final List<double> sz = List.filled(k, 0.0);
    final List<double> sw = List.filled(k, 0.0);

    for (int i = 0; i < pts.length; i++) {
      final int c = assign[i];
      final _Vec3 p = pts[i];
      sx[c] += p.x * p.weight;
      sy[c] += p.y * p.weight;
      sz[c] += p.z * p.weight;
      sw[c] += p.weight;
    }

    for (int c = 0; c < k; c++) {
      if (sw[c] < 1e-6) continue;
      centers[c] = _Vec3(sx[c] / sw[c], sy[c] / sw[c], sz[c] / sw[c]);
    }
  }

  // Collapse near-duplicate centers.
  final List<_Vec3> out = [];
  for (final _Vec3 c in centers) {
    if (out.every((o) => c.dist2(o) > 28 * 28)) {
      out.add(c);
    }
  }
  return out.length >= 5 ? out : centers;
}

// -----------------------------------------------------------------------------
// Color enhancement
// -----------------------------------------------------------------------------

/// Convert an RGB [_Vec3] to a Flutter [Color].
Color _toColor(_Vec3 v) {
  return Color.fromARGB(
    255,
    v.x.round().clamp(0, 255),
    v.y.round().clamp(0, 255),
    v.z.round().clamp(0, 255),
  );
}

/// Boost saturation and lightness for more vibrant output.
Color _amplify(Color c,
    {required double satBoost, required double lightBoost}) {
  final HSLColor hsl = HSLColor.fromColor(c);
  return hsl
      .withSaturation((hsl.saturation * satBoost).clamp(0.0, 0.95))
      .withLightness((hsl.lightness * lightBoost).clamp(0.0, 0.90))
      .toColor();
}

/// Clamp the base color to a dark range suitable for white text (L ≤ 0.22).
Color _ensureBaseDark(Color c) {
  final HSLColor hsl = HSLColor.fromColor(c);
  if (hsl.lightness <= 0.22) return c;
  return hsl.withLightness((hsl.lightness * 0.55).clamp(0.08, 0.22)).toColor();
}

/// Replace near-white colors with a matte tinted gray.
///
/// Prevents harsh pure whites — colors with lightness > 0.90 are nudged toward
/// a subtle tinted gray to maintain color character without blowing out.
Color _matteizeWhite(Color c, {double grayMix = 0.14, double satFloor = 0.10}) {
  final HSLColor hsl = HSLColor.fromColor(c);
  if (hsl.lightness < 0.90) return c;

  const Color matteGray = Color(0xFF989CA1);
  final Color mixed = Color.lerp(c, matteGray, grayMix) ?? c;
  final HSLColor m = HSLColor.fromColor(mixed);

  return m
      .withLightness((m.lightness * 0.72).clamp(0.50, 0.72))
      .withSaturation(math.max(m.saturation * 0.6, satFloor))
      .toColor();
}

/// Clamp overly bright colors into the matte highlight range.
///
/// Colors with lightness > 0.82 are pulled back to preserve color character
/// without appearing washed out on dark backgrounds.
Color _matteizeIfTooBright(Color c) {
  final HSLColor hsl = HSLColor.fromColor(c);
  if (hsl.lightness <= 0.82) return c;

  return hsl
      .withLightness((hsl.lightness * 0.78).clamp(0.55, 0.78))
      .withSaturation((hsl.saturation * 0.75).clamp(0.06, 0.55))
      .toColor();
}
