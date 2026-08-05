/// Theme generation with Material Design 3 and WCAG validation.
library;

import 'dart:math' as math;
import 'dart:ui';

import 'package:material_color_utilities/material_color_utilities.dart' as mcu;

import 'models.dart';

/// Build a complete theme from a seed color.
///
/// Generates primary, secondary, background, surface colors and ensures
/// all text colors meet the minimum WCAG contrast ratio.
ThemeColors buildTheme(
  Color seed, {
  Brightness targetBrightness = Brightness.light,
  double minContrast = 4.5,
}) {
  // Build tonal palettes using HCT around the seed
  final hct = mcu.Hct.fromInt(seed.value);
  final hue = hct.hue;
  final baseChroma = math.max(24.0, mcu.Cam16.fromInt(seed.value).chroma);

  Color tone(double t) {
    final h = mcu.Hct.from(hue, baseChroma, t);
    return Color(h.toInt());
  }

  // Primary / Secondary / Neutral scales
  final primary = tone(targetBrightness == Brightness.light ? 55 : 65);
  final secondary = Color(
    mcu.Hct.from(
      (hue + 30) % 360,
      baseChroma * 0.6,
      targetBrightness == Brightness.light ? 45 : 70,
    ).toInt(),
  );
  final neutralBg = mcu.Hct.from(
    hue,
    8,
    targetBrightness == Brightness.light ? 98 : 6,
  );
  final surfaceT = targetBrightness == Brightness.light ? 100.0 : 8.0;
  final surface = Color(mcu.Hct.from(hue, 10, surfaceT).toInt());
  final background = Color(neutralBg.toInt());

  // Ensure interactive elements keep contrast on background FIRST
  final safePrimary = ensureContrast(primary, background, minContrast);
  final safeSecondary = ensureContrast(secondary, background, minContrast);

  // THEN calculate on-colors using the adjusted colors
  final onPrimary = findContrastingColor(
    safePrimary,
    minContrast: minContrast,
    preferTone: targetBrightness == Brightness.light ? 10 : 95,
  );
  final onSecondary = findContrastingColor(
    safeSecondary,
    minContrast: minContrast,
    preferTone: targetBrightness == Brightness.light ? 10 : 95,
  );
  final onBackground = findContrastingColor(
    background,
    minContrast: minContrast,
    preferTone: targetBrightness == Brightness.light ? 10 : 95,
  );
  final onSurface = findContrastingColor(
    surface,
    minContrast: minContrast,
    preferTone: targetBrightness == Brightness.light ? 10 : 95,
  );

  return ThemeColors(
    primary: safePrimary,
    onPrimary: onPrimary,
    secondary: safeSecondary,
    onSecondary: onSecondary,
    background: background,
    onBackground: onBackground,
    surface: surface,
    onSurface: onSurface,
  );
}

/// Find a text color that contrasts with the given background.
///
/// Tries [preferTone] first, then falls back to standard tones.
Color findContrastingColor(
  Color bg, {
  required double minContrast,
  double preferTone = 20,
}) {
  final bgHct = mcu.Hct.fromInt(bg.value);
  final bgLuminance = relativeLuminance(bg);

  // First, try pure white or black if they meet the requirement
  // This is the most reliable way to ensure contrast
  final whiteContrast = computeContrastRatio(const Color(0xFFFFFFFF), bg);
  final blackContrast = computeContrastRatio(const Color(0xFF000000), bg);

  if (whiteContrast >= minContrast && blackContrast >= minContrast) {
    // Both work - choose based on background luminance for better aesthetics
    return bgLuminance > 0.5
        ? const Color(0xFF000000)
        : const Color(0xFFFFFFFF);
  } else if (whiteContrast >= minContrast) {
    return const Color(0xFFFFFFFF);
  } else if (blackContrast >= minContrast) {
    return const Color(0xFF000000);
  }

  // Try tones with the background's hue and chroma for harmony
  for (final t in <double>[preferTone, 10, 5, 0, 95, 99, 100]) {
    final candidate = Color(mcu.Hct.from(bgHct.hue, bgHct.chroma, t).toInt());
    if (computeContrastRatio(candidate, bg) >= minContrast) {
      return candidate;
    }
  }

  // Try with reduced chroma (more neutral)
  for (final chromaReduction in [0.5, 0.0]) {
    for (final t in <double>[0, 5, 10, 90, 95, 100]) {
      final candidate = Color(
        mcu.Hct.from(bgHct.hue, bgHct.chroma * chromaReduction, t).toInt(),
      );
      if (computeContrastRatio(candidate, bg) >= minContrast) {
        return candidate;
      }
    }
  }

  // Ultimate fallback: return whichever has better contrast (even if insufficient)
  return whiteContrast >= blackContrast
      ? const Color(0xFFFFFFFF)
      : const Color(0xFF000000);
}

/// Ensure a foreground color has sufficient contrast on a background.
///
/// If contrast is insufficient, adjusts the tone to meet requirements.
Color ensureContrast(Color fg, Color bg, double minContrast) {
  if (computeContrastRatio(fg, bg) >= minContrast) return fg;

  // Shift tone using HCT towards contrast
  final fgHct = mcu.Hct.fromInt(fg.value);
  final bgLuminance = relativeLuminance(bg);
  final fgLuminance = relativeLuminance(fg);
  final shouldBeLighter = fgLuminance > bgLuminance;

  if (shouldBeLighter) {
    // Make lighter - increase tone
    for (final step in [4, 6, 8, 10, 15, 20, 30, 40, 50]) {
      final newTone = (fgHct.tone + step).clamp(0, 100).toDouble();
      final c = Color(mcu.Hct.from(fgHct.hue, fgHct.chroma, newTone).toInt());
      if (computeContrastRatio(c, bg) >= minContrast) return c;
    }

    // Try with less chroma for more contrast
    for (final chromaReduction in [0.5, 0.0]) {
      for (final tone in [90.0, 95.0, 98.0, 100.0]) {
        final c = Color(
          mcu.Hct.from(fgHct.hue, fgHct.chroma * chromaReduction, tone).toInt(),
        );
        if (computeContrastRatio(c, bg) >= minContrast) return c;
      }
    }

    // Last resort: pure white (we want lighter)
    return const Color(0xFFFFFFFF);
  } else {
    // Make darker - decrease tone
    for (final step in [4, 6, 8, 10, 15, 20, 30, 40, 50]) {
      final newTone = (fgHct.tone - step).clamp(0, 100).toDouble();
      final c = Color(mcu.Hct.from(fgHct.hue, fgHct.chroma, newTone).toInt());
      if (computeContrastRatio(c, bg) >= minContrast) return c;
    }

    // Try with less chroma for more contrast
    for (final chromaReduction in [0.5, 0.0]) {
      for (final tone in [10.0, 5.0, 2.0, 0.0]) {
        final c = Color(
          mcu.Hct.from(fgHct.hue, fgHct.chroma * chromaReduction, tone).toInt(),
        );
        if (computeContrastRatio(c, bg) >= minContrast) return c;
      }
    }

    // Last resort: pure black (we want darker)
    return const Color(0xFF000000);
  }
}

/// Calculate relative luminance per WCAG formula.
double relativeLuminance(Color c) {
  double f(int ch) {
    final v = ch / 255.0;
    return v <= 0.03928
        ? v / 12.92
        : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  }

  // Use bit operations for compatibility
  final r = f((0x00ff0000 & c.value) >> 16);
  final g = f((0x0000ff00 & c.value) >> 8);
  final b = f((0x000000ff & c.value) >> 0);
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

/// Calculate WCAG contrast ratio between two colors.
double computeContrastRatio(Color a, Color b) {
  final la = relativeLuminance(a);
  final lb = relativeLuminance(b);
  final l1 = math.max(la, lb);
  final l2 = math.min(la, lb);
  return (l1 + 0.05) / (l2 + 0.05);
}

/// Interpolate between two ThemeColors.
ThemeColors lerpThemeColors(ThemeColors a, ThemeColors b, double t) {
  Color l(Color x, Color y) => Color.lerp(x, y, t)!;
  return ThemeColors(
    primary: l(a.primary, b.primary),
    onPrimary: l(a.onPrimary, b.onPrimary),
    secondary: l(a.secondary, b.secondary),
    onSecondary: l(a.onSecondary, b.onSecondary),
    background: l(a.background, b.background),
    onBackground: l(a.onBackground, b.onBackground),
    surface: l(a.surface, b.surface),
    onSurface: l(a.onSurface, b.onSurface),
  );
}
