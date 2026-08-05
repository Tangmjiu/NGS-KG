# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [3.1.0] - 2026-03-03

### Added
- `FluidFallbackMode` enum (`dark` / `light` / `auto`) on `FluidBackground` — defaults to `auto` (matches theme brightness)
- `FluidPalette.fallbackLight()` — pastel light-mode fallback palette
- `FluidPaletteExtractor.extractColors(ImageProvider, {int count})` — new primary extraction API; returns ranked `List<Color>`
- `FluidPaletteExtractor.warmup(List<ImageProvider>)` — parallel cache pre-warm
- `FluidPaletteCache` — LRU singleton (30 entries, SHA-1 keyed); auto-populated on every extraction

### Changed
- `FluidBackground.animate` default → `false` (battery-friendly; opt-in with `animate: true`)
- Animation toggle is now smooth — resumes from frozen phase instead of jumping

### Fixed
- Stale async race in `FluidBackground`: rapid image provider changes no longer corrupt the displayed palette

### Deprecated
- `FluidPaletteExtractor.extract(ui.Image)` — use `extractColors(ImageProvider)` instead; will be removed in v4.0.0

---

## [3.0.0] - 2025-12-24

### Major Release - Complete Redesign

This release completely redesigns the package around a single, powerful concept: **FluidBackground**. The focus is now exclusively on creating immersive, fluid animated backgrounds inspired by modern music apps.

**All v2.x APIs are deprecated and will be removed in v4.0.0.**

### New Philosophy

The package now provides two simple APIs:

1. **FluidBackground Widget** - Drop-in animated background (recommended)
2. **FluidPaletteExtractor** - Manual color extraction for custom implementations

Old Material Design theming APIs (AdaptivePalette, PaletteScope, ThemeColors, etc.) are deprecated in favor of this simpler, more focused approach.

### Added

- **FluidBackground Widget**: One-line immersive animated backgrounds
  - Optional image (null = matte fallback only)
  - Instant matte gradient display (0ms startup)
  - Smooth cross-fade transitions (1400ms)
  - 4 layered ImageShaders with orbital motion
  - Heavy 80σ Gaussian blur for atmosphere
  - Corner radial glows (4 accents)
  - Configurable parameters (blur, overlay, animation)

- **FluidPaletteExtractor API**: Advanced color extraction
  - Weighted k-means clustering (k=6, 10 iterations)
  - Smart sampling (every 10th pixel, filters extremes)
  - Vibrancy weighting: (sat × 0.75 + light × 0.25)
  - Center proximity boost: 1.0 + 0.8 × decay
  - Perceptual scoring: (vivid × 1.2 + mid × 0.8)
  - Matte treatment (14% gray blend for whites)
  - Dark base enforcement (≤ 0.22 lightness)

- **FluidPalette Model**: Simple 5-color palette
  - `baseDark` (guaranteed dark)
  - `accent1-4` (corner glows)
  - `lerp()` for animations
  - `copyWith()` for immutability

### Deprecated

**All of these will be removed in v4.0.0:**

- ❌ `AdaptivePalette.fromImage()` → Use `FluidPaletteExtractor.extract()`
- ❌ `PaletteScope` → Use `FluidBackground` widget
- ❌ `ThemeColors` → Use `FluidPalette`
- ❌ `AdaptiveImageOverlay` → Use `FluidBackground`
- ❌ `AdaptiveGlowImageFrame` → Use `FluidBackground`
- ❌ `AdaptiveGradientScaffold` → Use `FluidBackground`
- ❌ `ExtractionConfig` → No longer needed
- ❌ `ExtractionQuality` → No longer needed

### Migration Guide

**Before (v2.x):**
```dart
final colors = await AdaptivePalette.fromImage(NetworkImage(url));
MaterialApp(theme: colors.toThemeData());
```

**After (v3.0):**
```dart
FluidBackground(
  imageProvider: NetworkImage(url),
  child: YourContent(),
)
```

Or for manual extraction:
```dart
final image = await loadImageFromProvider(NetworkImage(url));
final palette = await FluidPaletteExtractor.extract(image);
```

### Changed

- **README** - Completely rewritten to focus on FluidBackground
- **Library docs** - Simplified to showcase two main APIs
- **Package description** - Now emphasizes fluid backgrounds
- **Export order** - Primary APIs first, deprecated APIs last

### Why the Change?

The v2.x APIs were complex and trying to solve too many problems:
- Material Design theming
- WCAG accessibility
- Multiple widget variants
- Theme animation systems

v3.0 simplifies everything:
- **One goal**: Beautiful fluid backgrounds
- **Two APIs**: Widget (easy) or Extractor (custom)
- **Zero complexity**: No configs, no quality presets, no theme systems

### Backward Compatibility

All v2.x code continues to work with deprecation warnings. You have until v4.0 to migrate.

### Breaking Changes

None - all v2.x APIs still work (deprecated but functional).

---

## [2.0.3] - 2025-12-21

### Fixed

- README image now uses GitHub raw URL for proper display on pub.dev

## [2.0.2] - 2025-12-21

### Added

- Package preview image (`adaptive_palette.png`) showing the library in action

### Changed

- Updated README installation instructions to reference correct version

## [2.0.1] - 2025-12-01

### Fixed

- **Critical Fix**: Added missing `dart:ui` import in `theme.dart` for `Brightness` enum
- Package now compiles correctly when used as a dependency

## [2.0.0] - 2025-12-01

### Major Release - Architectural Rewrite

This release restructures the package with improved modularity, performance, and developer experience. The core API remains backward compatible - most v1.x code continues to work without changes.

### Added

- **Quality Presets**: `ExtractionQuality.fast`, `balanced`, and `high` for different use cases
- **ExtractionConfig**: Unified configuration object with quality presets and callbacks
- **Performance Monitoring**: `ExtractionStats` with duration, cache hits, and image type detection
- **Cache Management**: Configurable size (default: 32), warmup API, and statistics
- **Debug Callbacks**: `onDebug` and `onError` for real-time insights
- **Diversity Control**: Configurable weight (0.0-2.0) to prevent selecting similar colors
- **Comprehensive Tests**: 59 unit tests covering all core algorithms
- **Extensive Documentation**: 15+ usage examples and migration guide

### Changed

- **Modular Architecture**: Refactored from 1636-line monolithic file into 12 clean modules
- **Improved WCAG Compliance**: More reliable contrast ratio calculations
- **Better Default Parameters**: Optimized for real-world performance
- **Enhanced Theme Generation**: Fixed color contrast bugs, improved fallback behavior
- **Larger Cache**: Increased from 16 to 32 entries by default

### Breaking Changes

1. **Widget Parameters**: Now use `ExtractionConfig` instead of individual parameters
   ```dart
   // Before
   AdaptiveImageOverlay.network(url, resize: 96, quantizeColors: 24)

   // After
   AdaptiveImageOverlay.network(url, config: ExtractionConfig.fromQuality(ExtractionQuality.high))
   ```

2. **ThemeColors.toThemeData()**: Changed from static to instance method
   ```dart
   // Before
   ThemeColors.toThemeData(colors, brightness: Brightness.dark)

   // After
   colors.toThemeData(brightness: Brightness.dark)
   ```

3. **Internal Imports**: Don't import from `lib/src/` - use public API only

### Backward Compatible

The following v1.x code works without changes:
- `AdaptivePalette.fromImage()` with named parameters
- `PaletteScope` widget and controller
- All `ThemeColors` properties and `copyWith()`

See [MIGRATING.md](MIGRATING.md) for detailed upgrade instructions.

### Fixed

- WCAG contrast calculation bugs in theme generation
- Type safety issues (34 analyzer warnings → 0)
- Memory leaks in cache management
- Documentation accuracy

### Performance

Typical extraction times (MacBook Pro M1, Release mode):

| Quality | Time | Use Case |
|---------|------|----------|
| Fast | 30-50ms | Lists, thumbnails |
| Balanced | 60-90ms | General use (default) |
| High | 90-140ms | Hero images |
| Cache Hit | <1ms | All cached images |

---

## [1.0.7] - 2025-11-18

### Changed
- Major algorithm improvement with adaptive scoring for different image types
- Increased default `quantizeColors` to 32 and `resize` to 128
- Now uses CAM16 perceptual color space for better accuracy

### Improved
- Adaptive thresholds for colorful, monochromatic, and normal images
- Better color diversity through hue distance calculations
- Smart filtering prevents selecting multiple shades of same color

---

## [1.0.6] - 2025-11-18

### Fixed
- Critical compatibility fix: replaced `toARGB32()` with `.value` for Flutter 3.0+

---

## [1.0.5] - 2025-11-18

### Fixed
- Universal compatibility using bit operations for color component extraction

---

## [1.0.4] - 2025-11-16

### Changed
- Lowered minimum SDK to `>=3.0.0 <4.0.0` (Flutter 3.0+ support)

---

## [1.0.0] - 2025-11-11

### Added
- Initial release with CAM16/HCT color extraction
- WCAG AA/AAA contrast compliance
- PaletteScope for animated theme transitions
- Three pre-built widgets
- Material Design 3 integration

---

[3.0.0]: https://github.com/HardikSJain/adaptive_palette/releases/tag/v3.0.0
[2.0.3]: https://github.com/HardikSJain/adaptive_palette/releases/tag/v2.0.3
[2.0.2]: https://github.com/HardikSJain/adaptive_palette/releases/tag/v2.0.2
[2.0.1]: https://github.com/HardikSJain/adaptive_palette/releases/tag/v2.0.1
[2.0.0]: https://github.com/HardikSJain/adaptive_palette/releases/tag/v2.0.0
[1.0.7]: https://github.com/HardikSJain/adaptive_palette/releases/tag/v1.0.7
[1.0.6]: https://github.com/HardikSJain/adaptive_palette/releases/tag/v1.0.6
[1.0.5]: https://github.com/HardikSJain/adaptive_palette/releases/tag/v1.0.5
[1.0.4]: https://github.com/HardikSJain/adaptive_palette/releases/tag/v1.0.4
[1.0.0]: https://github.com/HardikSJain/adaptive_palette/releases/tag/v1.0.0
