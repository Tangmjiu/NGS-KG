// Copyright (c) 2025-2026 mjiutang
// SPDX-License-Identifier: MIT
//
// Watch 轻量主题提供者 — 仅读取颜色种子，无 ZIP 主题包/主题市场依赖

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 手表端轻量主题提供者。
///
/// 与手机版 [ThemeProvider] 共享 SharedPreferences 键，但只读取颜色种子值，
/// 不加载任何 ZIP 主题包、ThemeAssets 或 ThemeLoader。
/// 始终强制 [Brightness.dark]。
class WatchThemeProvider extends ChangeNotifier {
  static const Color _defaultSeed = Color(0xFF2CA1F4);

  Color _colorSeed = _defaultSeed;

  /// 当前颜色种子（用于 Material You 取色）。
  Color get colorSeed => _colorSeed;

  /// 手表始终使用深色模式。
  Brightness get brightness => Brightness.dark;

  /// 从 SharedPreferences 初始化颜色种子。
  ///
  /// 与手机版共用键名：
  /// - `theme_accent` — 预设主题键（如 `"blue"`, `"purple"`, `"custom"`）
  /// - `theme_custom_color` — 自定义颜色 ARGB int
  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final accentKey = prefs.getString('theme_accent') ?? '';
      if (accentKey == 'custom') {
        final customColor = prefs.getInt('theme_custom_color');
        if (customColor != null) {
          _colorSeed = Color(customColor);
        }
      } else if (accentKey.isNotEmpty) {
        _colorSeed = _presetColors[accentKey] ?? _defaultSeed;
      }
    } catch (_) {
      // 默认使用酷狗蓝
      _colorSeed = _defaultSeed;
    }
    notifyListeners();
  }

  /// 预设颜色映射（与手机版 ThemeProvider 保持一致）。
  static const Map<String, Color> _presetColors = {
    'blue': Color(0xFF2CA1F4),
    'purple': Color(0xFF9C27B0),
    'pink': Color(0xFFE91E63),
    'red': Color(0xFFF44336),
    'orange': Color(0xFFFF9800),
    'yellow': Color(0xFFFFEB3B),
    'green': Color(0xFF4CAF50),
    'teal': Color(0xFF009688),
  };
}
