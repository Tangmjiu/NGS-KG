// Copyright (c) 2025-2026 mjiutang
// SPDX-License-Identifier: MIT
//
// 手表主题 — Material 3 Expressive 风格，始终深色（AMOLED 省电）

import 'package:flutter/material.dart';

/// M3E 形状令牌（手表端）
abstract final class WatchShapeTokens {
  /// 小组件圆角
  static const double small = 10;

  /// 卡片/列表项圆角
  static const double medium = 16;

  /// 大卡片圆角
  static const double large = 24;

  /// 胶囊（stadium）全圆角
  static const double full = 999;
}

ThemeData buildWatchTheme(Color seedColor) {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: seedColor,
    brightness: Brightness.dark,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: Colors.black,
    textTheme: _watchTextTheme(ThemeData.dark().textTheme),
    visualDensity: VisualDensity.compact,
    materialTapTargetSize: MaterialTapTargetSize.padded,
    splashFactory: InkSparkle.splashFactory,
    // M3E：进度指示器统一圆头
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: colorScheme.primary,
      linearTrackColor: colorScheme.surfaceContainerHighest,
      circularTrackColor: colorScheme.surfaceContainerHighest,
    ),
    listTileTheme: ListTileThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(WatchShapeTokens.medium),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      dense: true,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(WatchShapeTokens.large),
      ),
      color: colorScheme.surfaceContainerHigh,
    ),
    dialogTheme: DialogThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(WatchShapeTokens.large),
      ),
      backgroundColor: colorScheme.surfaceContainerHigh,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(WatchShapeTokens.small),
      ),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: OpenUpwardsPageTransitionsBuilder(),
      },
    ),
    // M3E：按钮一律胶囊形、最小 48 触控目标
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(48, 48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(WatchShapeTokens.full),
        ),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(WatchShapeTokens.full),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 44),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(WatchShapeTokens.full),
        ),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        minimumSize: const Size(48, 48),
      ),
    ),
    sliderTheme: const SliderThemeData(
      trackHeight: 4,
      thumbShape: RoundSliderThumbShape(enabledThumbRadius: 10),
      overlayShape: RoundSliderOverlayShape(overlayRadius: 20),
      trackShape: RoundedRectSliderTrackShape(),
    ),
  );
}

/// 手表小屏字号体系
TextTheme _watchTextTheme(TextTheme base) {
  return base.copyWith(
    displayLarge: base.displayLarge?.copyWith(fontSize: 28),
    displayMedium: base.displayMedium?.copyWith(fontSize: 24),
    displaySmall: base.displaySmall?.copyWith(fontSize: 20),
    headlineLarge: base.headlineLarge?.copyWith(fontSize: 18),
    headlineMedium: base.headlineMedium?.copyWith(fontSize: 16),
    headlineSmall: base.headlineSmall?.copyWith(fontSize: 15),
    titleLarge: base.titleLarge?.copyWith(fontSize: 14),
    titleMedium: base.titleMedium?.copyWith(fontSize: 13),
    bodyLarge: base.bodyLarge?.copyWith(fontSize: 13),
    bodyMedium: base.bodyMedium?.copyWith(fontSize: 12),
    bodySmall: base.bodySmall?.copyWith(fontSize: 10),
    labelLarge: base.labelLarge?.copyWith(fontSize: 12),
    labelSmall: base.labelSmall?.copyWith(fontSize: 9),
  );
}
