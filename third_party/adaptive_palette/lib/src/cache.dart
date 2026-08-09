/// LRU cache for extracted color palettes.
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter/material.dart';

import 'config.dart';
import 'fluid_palette.dart';
import 'models.dart';

/// Singleton cache for color palettes keyed by image content hash.
class PaletteCache {
  static final PaletteCache instance = PaletteCache._();

  late _LruMap<String, ThemeColors> _map;

  PaletteCache._() {
    _map = _LruMap(capacity: CacheConfig.maxSize);
  }

  /// Get cached palette by key.
  ThemeColors? get(String key) {
    if (!CacheConfig.enabled) return null;
    return _map.get(key);
  }

  /// Store palette in cache.
  void put(String key, ThemeColors value) {
    if (!CacheConfig.enabled) return;
    _map.put(key, value);
  }

  /// Clear all cached palettes.
  void clear() {
    _map = _LruMap(capacity: CacheConfig.maxSize);
  }

  /// Get current cache size.
  int get size => _map.size;

  /// Get cache capacity.
  int get capacity => _map.capacity;

  /// Preload palettes for a list of images.
  ///
  /// Returns a map of image provider to extracted colors.
  /// Failed extractions are omitted from the result.
  ///
  /// Example:
  /// ```dart
  /// final preloaded = await PaletteCache.instance.warmup([
  ///   NetworkImage('https://example.com/hero1.jpg'),
  ///   NetworkImage('https://example.com/hero2.jpg'),
  /// ]);
  /// ```
  Future<Map<ImageProvider, ThemeColors>> warmup(
    List<ImageProvider> providers, {
    ExtractionConfig config = const ExtractionConfig(),
  }) async {
    // Import here to avoid circular dependency
    // This will be handled by the main extraction logic
    throw UnimplementedError(
      'Warmup is implemented in adaptive_palette.dart to avoid circular dependencies',
    );
  }
}

/// Simple LRU cache implementation.
class _LruMap<K, V> {
  final int capacity;
  final Map<K, V> _map = {};
  final List<K> _order = [];

  _LruMap({required this.capacity});

  V? get(K key) {
    final value = _map[key];
    if (value != null) {
      _order.remove(key);
      _order.add(key);
    }
    return value;
  }

  void put(K key, V value) {
    if (_map.length >= capacity && !_map.containsKey(key)) {
      final oldest = _order.isNotEmpty ? _order.removeAt(0) : null;
      if (oldest != null) _map.remove(oldest);
    }
    _map[key] = value;
    _order.remove(key);
    _order.add(key);
  }

  int get size => _map.length;
}

/// Compute SHA-1 hash of image bytes for content-based caching.
String computeImageHash(Uint8List data) {
  return crypto.sha1.convert(data).toString();
}

// =============================================================================
// Fluid palette cache
// =============================================================================

/// Cached result of a fluid palette extraction run.
///
/// Stores both representations so a single k-means run serves both
/// [FluidPaletteExtractor.extractColors] and
/// [FluidPaletteExtractor.buildPaletteFromImage] without re-processing.
///
/// [colors] contains up to 10 dominant colors (max allowed by [extractColors]).
/// Callers requesting fewer than 10 take the leading slice.
class FluidCacheEntry {
  const FluidCacheEntry({required this.colors, required this.palette});

  /// Dominant colors ranked by vibrancy, matte-treated. Max 10 entries.
  final List<Color> colors;

  /// Structured palette for immersive background rendering.
  final FluidPalette palette;
}

/// LRU cache for fluid palette extraction results, keyed by image content hash.
///
/// Results are cached after the first extraction so subsequent calls with the
/// same image content return instantly without re-running k-means.
///
/// The cache is a singleton. Access it via [FluidPaletteCache.instance]:
///
/// ```dart
/// // Pre-warm for upcoming images (e.g. next tracks in a playlist)
/// await FluidPaletteExtractor.warmup([
///   NetworkImage(track1.albumArtUrl),
///   NetworkImage(track2.albumArtUrl),
/// ]);
///
/// // Inspect cache stats
/// print('${FluidPaletteCache.instance.size} / ${FluidPaletteCache.instance.capacity}');
///
/// // Clear when memory pressure detected
/// FluidPaletteCache.instance.clear();
/// ```
class FluidPaletteCache {
  FluidPaletteCache._() : _map = _LruMap(capacity: defaultCapacity);

  /// Singleton instance.
  static final FluidPaletteCache instance = FluidPaletteCache._();

  /// Default LRU capacity — covers a typical "now playing + recent history"
  /// scenario for music players and image galleries.
  static const int defaultCapacity = 30;

  _LruMap<String, FluidCacheEntry> _map;

  /// Retrieve a cached entry by content hash key. Returns null on miss.
  FluidCacheEntry? get(String key) => _map.get(key);

  /// Store an extraction result under its content hash key.
  void put(String key, FluidCacheEntry entry) => _map.put(key, entry);

  /// Remove all cached entries.
  void clear() => _map = _LruMap(capacity: defaultCapacity);

  /// Number of entries currently in the cache.
  int get size => _map.size;

  /// Maximum number of entries before LRU eviction occurs.
  int get capacity => _map.capacity;
}
