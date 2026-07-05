import 'package:flutter/material.dart';

import '../utils/theme.dart' show AppBreakpoint;

/// 响应式工具类
class Responsive {
  Responsive._();

  static double width(BuildContext context) =>
      MediaQuery.of(context).size.width;

  static double height(BuildContext context) =>
      MediaQuery.of(context).size.height;
}

/// BuildContext 上对 [AppBreakpoint] 的便捷扩展
extension ResponsiveExtension on BuildContext {
  /// 当前屏幕宽度
  double get screenWidth => MediaQuery.of(this).size.width;

  /// 当前屏幕高度
  double get screenHeight => MediaQuery.of(this).size.height;

  /// 是否为窄屏（手机竖屏） — width < 600
  bool get isCompact => screenWidth < AppBreakpoint.compact;

  /// 是否为中等屏（手机横屏 / 小平板竖屏） — 600 ≤ width < 840
  bool get isMedium =>
      screenWidth >= AppBreakpoint.compact && screenWidth < AppBreakpoint.medium;

  /// 是否为宽屏（平板横屏 / 桌面） — width ≥ 840
  bool get isExpanded => screenWidth >= AppBreakpoint.medium;

  /// 兼容旧模式的「宽屏」检测 — width ≥ 880
  /// 用于逐步迁移至 [isExpanded]
  bool get isWide => screenWidth >= 880;

  /// MD3 列数：宽屏 3 列，中屏 2 列，窄屏 1 列
  int get columnCount => AppBreakpoint.columnCount(screenWidth);
}
