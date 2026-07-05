// Copyright (c) 2025-2026 mjiutang
// SPDX-License-Identifier: MIT
//
// Wear OS 圆屏安全区域 — 确保内容不被圆屏边缘裁切
// 同时处理系统状态栏/导航栏 inset，替代 SafeArea

import 'package:flutter/material.dart';
import 'package:wear_plus/wear_plus.dart';

/// 圆屏安全区域 — 自动处理圆屏裁切 + 系统状态栏
///
/// 在圆形屏幕上添加足够的 padding 使内容保持在可见圆内，
/// 同时包含系统状态栏/导航栏的 insets（替代 SafeArea）。
/// 圆屏 padding 基于内接正方形计算：边距 = (D - D/√2)/2
class RoundSafeArea extends StatelessWidget {
  final Widget child;

  const RoundSafeArea({super.key, required this.child});

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

    // 圆屏：取系统 inset 和圆屏 inset 的较大值
    final roundInset = size.shortestSide * 0.145;
    final padding = EdgeInsets.fromLTRB(
      roundInset > systemPadding.left ? roundInset : systemPadding.left,
      roundInset > systemPadding.top ? roundInset : systemPadding.top,
      roundInset > systemPadding.right ? roundInset : systemPadding.right,
      roundInset > systemPadding.bottom ? roundInset : systemPadding.bottom,
    );

    return Padding(
      padding: padding,
      child: child,
    );
  }
}
