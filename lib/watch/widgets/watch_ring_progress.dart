// Copyright (c) 2025-2026 mjiutang
// SPDX-License-Identifier: MIT
//
// 环形进度条 — 圆屏播放器/息屏共用，自绘圆弧，无三方依赖

import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 圆屏环形进度。
///
/// 以 [child] 为中心内容，围绕其绘制进度圆弧。
/// - 进度从顶部（12 点方向）开始顺时针增长
/// - 圆头笔帽，轨道色随主题
/// - [onTap] 非空时整个组件可点击（用于切换表冠模式等）
/// - 语义信息供无障碍读出进度百分比
class WatchRingProgress extends StatelessWidget {
  /// 进度 0.0–1.0
  final double progress;

  /// 整体边长（圆环外接正方形）
  final double size;

  /// 弧线宽度
  final double strokeWidth;

  /// 中心内容
  final Widget? child;

  /// 点击回调（可选）
  final VoidCallback? onTap;

  /// 进度弧颜色；默认 primary
  final Color? color;

  /// 轨道颜色；默认 surfaceContainerHighest
  final Color? trackColor;

  /// 无障碍标签（如「播放进度」）
  final String semanticsLabel;

  const WatchRingProgress({
    super.key,
    required this.progress,
    required this.size,
    this.strokeWidth = 4,
    this.child,
    this.onTap,
    this.color,
    this.trackColor,
    this.semanticsLabel = '进度',
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final clamped = progress.clamp(0.0, 1.0);

    Widget result = SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RingPainter(
          progress: clamped,
          strokeWidth: strokeWidth,
          color: color ?? cs.primary,
          trackColor: trackColor ?? cs.surfaceContainerHighest,
        ),
        child: child == null ? null : Center(child: child),
      ),
    );

    if (onTap != null) {
      result = Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: result,
        ),
      );
    }

    return Semantics(
      label: semanticsLabel,
      value: '${(clamped * 100).round()}%',
      child: result,
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final double strokeWidth;
  final Color color;
  final Color trackColor;

  const _RingPainter({
    required this.progress,
    required this.strokeWidth,
    required this.color,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, 0, math.pi * 2, false, trackPaint);

    if (progress <= 0) return;
    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    // 从顶部（-90°）开始顺时针
    canvas.drawArc(
        rect, -math.pi / 2, math.pi * 2 * progress, false, progressPaint);
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress ||
      old.color != color ||
      old.trackColor != trackColor ||
      old.strokeWidth != strokeWidth;
}
