// Copyright (c) 2025-2026 mjiutang
// SPDX-License-Identifier: MIT
//
// Wear OS 圆屏安全区域 — 确保内容不被圆屏边缘裁切
// 同时处理系统状态栏/导航栏 inset，替代 SafeArea

import 'package:flutter/material.dart';
import 'package:wear_plus/wear_plus.dart';

/// 圆屏安全区域 — 自动处理圆屏裁切 + 系统状态栏
///
/// 在圆形屏幕上添加 padding 使内容保持在可见圆内，
/// 同时包含系统状态栏/导航栏的 insets（替代 SafeArea）。
///
/// 圆屏 padding 策略（非均匀）：
/// - 水平：基于内接正方形计算，边距 = D × 0.146（480px 屏 ≈ 70px），
///   因为圆边在左右两侧裁切最严重。
/// - 垂直：仅取系统 chin inset 与 12px 较大值，因为圆屏顶部/底部
///   弧度较缓和，纵向可视高度接近完整直径，均匀 70px 会浪费约 140px
///   纵向空间导致内容拥挤。
class RoundSafeArea extends StatelessWidget {
  final Widget child;

  /// 可选的额外垂直 padding（用于需要更多上下留白的场景）
  final double extraVerticalPadding;

  const RoundSafeArea({
    super.key,
    required this.child,
    this.extraVerticalPadding = 0,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final systemPadding = MediaQuery.of(context).padding;
    bool isRound = false;
    try {
      isRound = WatchShape.of(context) == WearShape.round;
    } catch (_) {}

    if (!isRound) {
      return Padding(
        padding: systemPadding,
        child: child,
      );
    }

    // 圆屏：水平用内接正方形边距，垂直仅避让系统 chin
    final horizontalInset = size.shortestSide * 0.146;
    final verticalInset =
        (systemPadding.top > systemPadding.bottom ? systemPadding.top : systemPadding.bottom)
            .clamp(12.0, double.infinity) + extraVerticalPadding;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        horizontalInset > systemPadding.left ? horizontalInset : systemPadding.left,
        verticalInset > systemPadding.top ? verticalInset : systemPadding.top,
        horizontalInset > systemPadding.right ? horizontalInset : systemPadding.right,
        verticalInset > systemPadding.bottom ? verticalInset : systemPadding.bottom,
      ),
      child: child,
    );
  }
}
