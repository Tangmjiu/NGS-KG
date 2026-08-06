// Copyright (c) 2025-2026 mjiutang
// SPDX-License-Identifier: MIT

import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Expressive 形状类型（借鉴 Material 3 Expressive 的 RoundedPolygon 思路）
///
/// 全部基于极坐标半径函数生成，保证闭合、平滑、可缩放。
enum ExpressiveShapeKind {
  /// 完美圆形
  circle,

  /// 超椭圆（n=3 近似 M3 Squircle）
  squircle,

  /// 六瓣 cookie（柔和内凹）
  cookie6,

  /// 八瓣 cookie
  cookie8,

  /// 六瓣花朵（内凹更深，更有机）
  flower6,

  /// 八瓣花朵
  flower8,

  /// 圆角菱形（超椭圆 n=1.3，介于圆与菱形之间）
  gem,
}

/// 生成单位路径（半径 1、中心在原点）的 Expressive 形状
///
/// 极坐标半径函数：
/// - circle:    r = 1
/// - squircle:  超椭圆 |x|^n + |y|^n = 1 (n=3)，分母最小约 0.707，不会除零
/// - cookie:    r = 1 - amp·(1-cos(kθ))/2  （柔和内凹）
/// - flower:    r = 1 - amp·(1-cos(kθ))/2  （内凹更深）
/// - gem:       超椭圆 n=1.3（圆角菱形）
Path buildExpressiveShapePath(ExpressiveShapeKind kind, {int samples = 120}) {
  final path = Path();
  for (var i = 0; i <= samples; i++) {
    final theta = 2 * math.pi * i / samples;
    final r = _radiusAt(kind, theta);
    final x = r * math.cos(theta);
    final y = r * math.sin(theta);
    if (i == 0) {
      path.moveTo(x, y);
    } else {
      path.lineTo(x, y);
    }
  }
  path.close();
  return path;
}

double _radiusAt(ExpressiveShapeKind kind, double theta) {
  switch (kind) {
    case ExpressiveShapeKind.circle:
      return 1.0;
    case ExpressiveShapeKind.squircle:
      final ct = math.cos(theta).abs();
      final st = math.sin(theta).abs();
      const n = 3.0;
      // |c|^n + |s|^n 最小值为 (1/2)^(n/2)·2 ≈ 0.707，安全
      return 1 / math.pow(ct * ct * ct + st * st * st, 1 / n).toDouble();
    case ExpressiveShapeKind.cookie6:
      return 1 - 0.15 * (1 - math.cos(6 * theta)) / 2;
    case ExpressiveShapeKind.cookie8:
      return 1 - 0.12 * (1 - math.cos(8 * theta)) / 2;
    case ExpressiveShapeKind.flower6:
      return 1 - 0.30 * (1 - math.cos(6 * theta)) / 2;
    case ExpressiveShapeKind.flower8:
      return 1 - 0.24 * (1 - math.cos(8 * theta)) / 2;
    case ExpressiveShapeKind.gem:
      final ct = math.cos(theta).abs();
      final st = math.sin(theta).abs();
      const n = 1.3;
      // 超椭圆 n=1.3：45° 方向内收约 0.84，形成圆角菱形
      return 1 / math.pow(math.pow(ct, n) + math.pow(st, n), 1 / n).toDouble();
  }
}
