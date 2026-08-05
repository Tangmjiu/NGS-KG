/// Core data models for adaptive palette.
library;

import 'package:flutter/material.dart';

/// Theme colors extracted from an image with accessibility guarantees.
///
/// All "on-colors" (onPrimary, onSecondary, etc.) are guaranteed to meet
/// the minimum WCAG contrast ratio specified during extraction.
class ThemeColors {
  /// Main brand color from the image.
  final Color primary;

  /// Text color for primary backgrounds (contrast-safe).
  final Color onPrimary;

  /// Accent color from the image.
  final Color secondary;

  /// Text color for secondary backgrounds (contrast-safe).
  final Color onSecondary;

  /// Page background color.
  final Color background;

  /// Text color for backgrounds (contrast-safe).
  final Color onBackground;

  /// Card/surface color.
  final Color surface;

  /// Text color for surfaces (contrast-safe).
  final Color onSurface;

  const ThemeColors({
    required this.primary,
    required this.onPrimary,
    required this.secondary,
    required this.onSecondary,
    required this.background,
    required this.onBackground,
    required this.surface,
    required this.onSurface,
  });

  /// Default fallback theme (teal/dark).
  const ThemeColors.fallback()
      : primary = const Color(0xFF0EA5A3),
        onPrimary = Colors.white,
        secondary = const Color(0xFF1E293B),
        onSecondary = Colors.white,
        background = const Color(0xFF0A0A0A),
        onBackground = const Color(0xFFE0E0E0),
        surface = const Color(0xFF121212),
        onSurface = const Color(0xFFE0E0E0);

  /// Create a copy with modified values.
  ThemeColors copyWith({
    Color? primary,
    Color? onPrimary,
    Color? secondary,
    Color? onSecondary,
    Color? background,
    Color? onBackground,
    Color? surface,
    Color? onSurface,
  }) =>
      ThemeColors(
        primary: primary ?? this.primary,
        onPrimary: onPrimary ?? this.onPrimary,
        secondary: secondary ?? this.secondary,
        onSecondary: onSecondary ?? this.onSecondary,
        background: background ?? this.background,
        onBackground: onBackground ?? this.onBackground,
        surface: surface ?? this.surface,
        onSurface: onSurface ?? this.onSurface,
      );

  /// Convert to Material ThemeData.
  ThemeData toThemeData({
    Brightness brightness = Brightness.light,
  }) {
    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: primary,
      onPrimary: onPrimary,
      secondary: secondary,
      onSecondary: onSecondary,
      error: const Color(0xFFB00020),
      onError: Colors.white,
      surface: surface,
      onSurface: onSurface,
    );
    return ThemeData(
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        foregroundColor: onSurface,
        elevation: 0,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: onPrimary,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: onPrimary,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: primary),
      ),
    );
  }

  /// Creates a gradient overlay from this palette.
  LinearGradient overlayGradient({
    AdaptiveOverlayStyle style = const AdaptiveOverlayStyle(),
    Color? baseColor,
  }) {
    return style.build(this, baseColor: baseColor);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ThemeColors &&
          runtimeType == other.runtimeType &&
          primary == other.primary &&
          onPrimary == other.onPrimary &&
          secondary == other.secondary &&
          onSecondary == other.onSecondary &&
          background == other.background &&
          onBackground == other.onBackground &&
          surface == other.surface &&
          onSurface == other.onSurface;

  @override
  int get hashCode =>
      primary.hashCode ^
      onPrimary.hashCode ^
      secondary.hashCode ^
      onSecondary.hashCode ^
      background.hashCode ^
      onBackground.hashCode ^
      surface.hashCode ^
      onSurface.hashCode;
}

/// The core color tone a gradient should be derived from.
enum AdaptiveOverlayTone {
  /// Use primary color as gradient base.
  primary,

  /// Use secondary color as gradient base.
  secondary,

  /// Use surface color as gradient base.
  surface,

  /// Use background color as gradient base.
  background,
}

/// Configuration for gradient overlays.
///
/// Used to generate Spotify/Luma-style gradient overlays on images.
///
/// Example:
/// ```dart
/// const style = AdaptiveOverlayStyle(
///   begin: Alignment.centerLeft,
///   end: Alignment.centerRight,
///   stops: [0.0, 0.4, 0.7, 1.0],
///   opacities: [0.95, 0.65, 0.25, 0.0],
///   tone: AdaptiveOverlayTone.primary,
/// );
/// ```
class AdaptiveOverlayStyle {
  /// Gradient start alignment.
  final Alignment begin;

  /// Gradient end alignment.
  final Alignment end;

  /// Color stop positions (0.0-1.0).
  final List<double> stops;

  /// Opacity at each stop (0.0-1.0).
  final List<double> opacities;

  /// Explicit colors (overrides tone if provided).
  final List<Color>? colors;

  /// Which palette color to use as base.
  final AdaptiveOverlayTone tone;

  /// Override the base color entirely.
  final Color? colorOverride;

  const AdaptiveOverlayStyle({
    this.begin = Alignment.centerLeft,
    this.end = Alignment.center,
    this.stops = const [0.0, 0.35, 0.7, 1.0],
    this.opacities = const [0.95, 0.7, 0.3, 0.0],
    this.colors,
    this.tone = AdaptiveOverlayTone.primary,
    this.colorOverride,
  });

  /// Create a copy with modified values.
  AdaptiveOverlayStyle copyWith({
    Alignment? begin,
    Alignment? end,
    List<double>? stops,
    List<double>? opacities,
    List<Color>? colors,
    AdaptiveOverlayTone? tone,
    Color? colorOverride,
  }) {
    return AdaptiveOverlayStyle(
      begin: begin ?? this.begin,
      end: end ?? this.end,
      stops: stops ?? this.stops,
      opacities: opacities ?? this.opacities,
      colors: colors ?? this.colors,
      tone: tone ?? this.tone,
      colorOverride: colorOverride ?? this.colorOverride,
    );
  }

  /// Build a [LinearGradient] from a [ThemeColors] palette.
  LinearGradient build(
    ThemeColors colors, {
    Color? baseColor,
  }) {
    assert(stops.isNotEmpty, 'stops cannot be empty');
    assert(stops.length == opacities.length,
        'stops and opacities must have the same length');
    assert(this.colors == null || this.colors!.length == stops.length,
        'custom colors must match stops length');

    final resolved = baseColor ?? colorOverride ?? _resolveColor(colors);
    final resolvedColors = this.colors ??
        opacities
            .map((opacity) => resolved.withOpacity(opacity.clamp(0.0, 1.0)))
            .toList(growable: false);

    assert(
      resolvedColors.length == stops.length,
      'colors and stops must be the same length',
    );

    return LinearGradient(
      begin: begin,
      end: end,
      colors: resolvedColors,
      stops: stops,
    );
  }

  Color _resolveColor(ThemeColors theme) {
    return switch (tone) {
      AdaptiveOverlayTone.primary => theme.primary,
      AdaptiveOverlayTone.secondary => theme.secondary,
      AdaptiveOverlayTone.surface => theme.surface,
      AdaptiveOverlayTone.background => theme.background,
    };
  }
}

/// Internal: Color swatch with population count.
class Swatch {
  final Color color;
  final int population;
  const Swatch(this.color, this.population);
}

/// Internal: Scored color candidate.
class ScoredSwatch {
  final Swatch swatch;
  final double score;
  Color get color => swatch.color;
  const ScoredSwatch(this.swatch, this.score);
}

/// Characteristics of an image's color distribution.
class ImageCharacteristics {
  final double avgSaturation;
  final double avgChroma;
  final bool isColorful;
  final bool isMonochromatic;
  final bool hasFewColors;

  const ImageCharacteristics({
    required this.avgSaturation,
    required this.avgChroma,
    required this.isColorful,
    required this.isMonochromatic,
    required this.hasFewColors,
  });

  String get type {
    if (isMonochromatic) return 'monochromatic';
    if (isColorful) return 'colorful';
    return 'normal';
  }
}
