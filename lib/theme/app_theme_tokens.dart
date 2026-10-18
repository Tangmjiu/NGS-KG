// SPDX-License-Identifier: MIT
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

@immutable
class AppThemeTokens extends ThemeExtension<AppThemeTokens> {
  final double pagePadding;
  final double sectionSpacing;
  final double cardRadius;
  final double controlRadius;
  final double contentMaxWidth;

  const AppThemeTokens({
    this.pagePadding = 20,
    this.sectionSpacing = 28,
    this.cardRadius = 24,
    this.controlRadius = 16,
    this.contentMaxWidth = 1120,
  });

  static const defaults = AppThemeTokens();

  static AppThemeTokens of(BuildContext context) =>
      Theme.of(context).extension<AppThemeTokens>() ?? defaults;

  factory AppThemeTokens.fromJson(Map<String, dynamic> json) {
    double value(String key, double fallback, double min, double max) {
      final raw = json[key];
      if (raw is! num || !raw.isFinite) return fallback;
      return raw.toDouble().clamp(min, max);
    }

    return AppThemeTokens(
      pagePadding: value('pagePadding', 20, 8, 48),
      sectionSpacing: value('sectionSpacing', 28, 8, 64),
      cardRadius: value('cardRadius', 24, 0, 48),
      controlRadius: value('controlRadius', 16, 0, 32),
      contentMaxWidth: value('contentMaxWidth', 1120, 600, 1920),
    );
  }

  Map<String, dynamic> toJson() => {
        'pagePadding': pagePadding,
        'sectionSpacing': sectionSpacing,
        'cardRadius': cardRadius,
        'controlRadius': controlRadius,
        'contentMaxWidth': contentMaxWidth,
      };

  @override
  AppThemeTokens copyWith({
    double? pagePadding,
    double? sectionSpacing,
    double? cardRadius,
    double? controlRadius,
    double? contentMaxWidth,
  }) =>
      AppThemeTokens.fromJson({
        'pagePadding': pagePadding ?? this.pagePadding,
        'sectionSpacing': sectionSpacing ?? this.sectionSpacing,
        'cardRadius': cardRadius ?? this.cardRadius,
        'controlRadius': controlRadius ?? this.controlRadius,
        'contentMaxWidth': contentMaxWidth ?? this.contentMaxWidth,
      });

  @override
  AppThemeTokens lerp(covariant AppThemeTokens? other, double t) {
    if (other == null) return this;
    return copyWith(
      pagePadding: lerpDouble(pagePadding, other.pagePadding, t),
      sectionSpacing: lerpDouble(sectionSpacing, other.sectionSpacing, t),
      cardRadius: lerpDouble(cardRadius, other.cardRadius, t),
      controlRadius: lerpDouble(controlRadius, other.controlRadius, t),
      contentMaxWidth: lerpDouble(contentMaxWidth, other.contentMaxWidth, t),
    );
  }
}
