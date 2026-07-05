// Copyright (c) 2025-2026 mjiutang
// SPDX-License-Identifier: MIT
//
// Wear OS 圆屏视觉主题 — 适配小屏圆形的 Material You 主题

import 'package:flutter/material.dart';

/// 构建手表版浅色主题
ThemeData buildWatchTheme(Color seedColor) {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorSchemeSeed: seedColor,
    // Wear OS 圆屏大字号/大触控区域
    textTheme: _watchTextTheme(ThemeData.light().textTheme),
    visualDensity: VisualDensity.compact,
    materialTapTargetSize: MaterialTapTargetSize.padded,
  );
}

/// 构建手表版深色主题（Wear OS 默认深色背景）
ThemeData buildWatchDarkTheme(Color seedColor) {
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
    // 圆屏列表样式
    listTileTheme: ListTileThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      dense: true,
    ),
    // 按钮放大 — 适应手指触控
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(48, 48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        minimumSize: const Size(48, 48),
      ),
    ),
    sliderTheme: SliderThemeData(
      trackHeight: 4,
      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
      overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
    ),
  );
}

/// 圆屏大字号适配
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
