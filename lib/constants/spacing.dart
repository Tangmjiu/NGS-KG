import 'package:flutter/material.dart';

/// 全局间距与内边距常量
///
/// 基于 4dp 基准网格：xs(4) / sm(8) / md(12) / lg(16) /
/// xl(24) / xxl(32) / xxxl(48) / huge(64)
abstract final class AppSpacing {
  AppSpacing._();

  // ──────────────────────────────────────────────
  // 间距原子 token（4dp 基准网格）
  // ──────────────────────────────────────────────

  /// 4dp — 最小间距
  static const double xs = 4;

  /// 8dp — 紧凑间距
  static const double sm = 8;

  /// 12dp — 标准控件间距
  static const double md = 12;

  /// 16dp — 卡片内边距 / 列表项间距
  static const double lg = 16;

  /// 24dp — 章节间距 / 大卡片边距
  static const double xl = 24;

  /// 32dp — 屏幕级间距
  static const double xxl = 32;

  /// 48dp — 大区块间距
  static const double xxxl = 48;

  /// 64dp — 最大间距
  static const double huge = 64;

  // ──────────────────────────────────────────────
  // 常用 Inset 组合
  // ──────────────────────────────────────────────

  /// 屏幕左右安全边距（lg=16）
  static const EdgeInsets screenHorizontal = EdgeInsets.symmetric(
    horizontal: lg,
  );

  /// 屏幕四周安全边距（lg=16）
  static const EdgeInsets screen = EdgeInsets.all(lg);

  /// 卡片内边距（sm=8 左右，md=12 上下）
  static const EdgeInsets card = EdgeInsets.symmetric(
    horizontal: sm,
    vertical: md,
  );

  /// 列表项内边距（水平 lg=16，垂直 sm=8）
  static const EdgeInsets listItem = EdgeInsets.symmetric(
    horizontal: lg,
    vertical: sm,
  );

  /// 紧凑内边距（xs=4）
  static const EdgeInsets compact = EdgeInsets.all(xs);

  /// 大内边距（xl=24）
  static const EdgeInsets spacious = EdgeInsets.all(xl);
}
