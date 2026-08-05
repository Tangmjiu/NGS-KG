/// Fluid dynamic palette with base and accent colors for immersive backgrounds.
library;

import 'package:flutter/material.dart';

/// Fluid dynamic color palette extracted from an image.
///
/// Contains a dark base color and four accent colors for corner glows
/// and fluid gradient backgrounds. Uses advanced weighted k-means clustering
/// to extract accurate, vibrant colors optimized for animated, immersive UIs.
///
/// Example:
/// ```dart
/// final palette = await FluidPaletteExtractor.extract(image);
/// print('Base: ${palette.baseDark}');
/// print('Accents: ${palette.accent1}, ${palette.accent2}...');
/// ```
class FluidPalette {
  /// Dark base color for backgrounds (guaranteed lightness ≤ 0.22).
  final Color baseDark;

  /// First accent color (top-left glow).
  final Color accent1;

  /// Second accent color (top-right glow).
  final Color accent2;

  /// Third accent color (bottom-left glow).
  final Color accent3;

  /// Fourth accent color (bottom-right glow).
  final Color accent4;

  const FluidPalette({
    required this.baseDark,
    required this.accent1,
    required this.accent2,
    required this.accent3,
    required this.accent4,
  });

  /// Default matte fallback palette (dark mode).
  const FluidPalette.fallback()
      : baseDark = const Color(0xFF0F1419),
        accent1 = const Color(0xFF2C1F4A),
        accent2 = const Color(0xFF2E3B5F),
        accent3 = const Color(0xFF3A2858),
        accent4 = const Color(0xFF1F2D4E);

  /// Matte fallback palette optimized for light mode surfaces.
  const FluidPalette.fallbackLight()
      : baseDark = const Color(0xFFF4F6FA),
        accent1 = const Color(0xFFE3D8FF),
        accent2 = const Color(0xFFD9E7FF),
        accent3 = const Color(0xFFF3DCF1),
        accent4 = const Color(0xFFDCE7F8);

  /// Linearly interpolate between two palettes.
  ///
  /// Used for smooth color transitions in animations.
  ///
  /// Example:
  /// ```dart
  /// final interpolated = FluidPalette.lerp(paletteA, paletteB, 0.5);
  /// ```
  static FluidPalette lerp(
    FluidPalette a,
    FluidPalette b,
    double t,
  ) {
    return FluidPalette(
      baseDark: Color.lerp(a.baseDark, b.baseDark, t) ?? b.baseDark,
      accent1: Color.lerp(a.accent1, b.accent1, t) ?? b.accent1,
      accent2: Color.lerp(a.accent2, b.accent2, t) ?? b.accent2,
      accent3: Color.lerp(a.accent3, b.accent3, t) ?? b.accent3,
      accent4: Color.lerp(a.accent4, b.accent4, t) ?? b.accent4,
    );
  }

  /// Create a copy with modified values.
  FluidPalette copyWith({
    Color? baseDark,
    Color? accent1,
    Color? accent2,
    Color? accent3,
    Color? accent4,
  }) {
    return FluidPalette(
      baseDark: baseDark ?? this.baseDark,
      accent1: accent1 ?? this.accent1,
      accent2: accent2 ?? this.accent2,
      accent3: accent3 ?? this.accent3,
      accent4: accent4 ?? this.accent4,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FluidPalette &&
          runtimeType == other.runtimeType &&
          baseDark == other.baseDark &&
          accent1 == other.accent1 &&
          accent2 == other.accent2 &&
          accent3 == other.accent3 &&
          accent4 == other.accent4;

  @override
  int get hashCode =>
      baseDark.hashCode ^
      accent1.hashCode ^
      accent2.hashCode ^
      accent3.hashCode ^
      accent4.hashCode;

  @override
  String toString() {
    return 'FluidPalette('
        'baseDark: $baseDark, '
        'accent1: $accent1, '
        'accent2: $accent2, '
        'accent3: $accent3, '
        'accent4: $accent4)';
  }
}
