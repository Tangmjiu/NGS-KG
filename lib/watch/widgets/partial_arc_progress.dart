// Copyright (c) 2025-2026 mjiutang
// SPDX-License-Identifier: MIT
//
// 部分圆弧进度指示器 — 支持拖动 seek + MD3 拖动反馈动画

import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 部分圆弧进度条。
///
/// 在指定角度范围内绘制进度弧线，轨道为半透明、进度段为全色。
/// 圆头笔帽，无填充。用于播放器的进度弧（左下）和音量弧（右下）。
///
/// [onSeek] 非空时支持沿弧线拖动调整进度：
/// - 拖动中弧线加粗提亮（MD3 强调动画，约 150ms）
/// - [onDragStart]/[onDragEnd] 供调用方暂停/恢复进度流，避免拖动抖动
class PartialArcProgress extends StatefulWidget {
  /// 进度 0.0–1.0
  final double progress;

  /// 整体边长
  final double size;

  /// 弧线宽度
  final double strokeWidth;

  /// 起始角度（度数，0=右，90=下，顺时针）
  final double startAngle;

  /// 扫掠范围（度数）
  final double sweep;

  /// 进度颜色
  final Color color;

  /// 无障碍标签
  final String semanticsLabel;

  /// 拖动进度回调（0.0–1.0），为 null 时不可拖动。
  final ValueChanged<double>? onSeek;

  /// 拖动开始/结束回调
  final VoidCallback? onDragStart;
  final VoidCallback? onDragEnd;

  const PartialArcProgress({
    super.key,
    required this.progress,
    required this.size,
    this.strokeWidth = 6,
    this.startAngle = 210,
    this.sweep = 120,
    this.color = Colors.white,
    this.semanticsLabel = '进度',
    this.onSeek,
    this.onDragStart,
    this.onDragEnd,
  });

  @override
  State<PartialArcProgress> createState() => _PartialArcProgressState();
}

class _PartialArcProgressState extends State<PartialArcProgress> {
  bool _dragging = false;

  void _handleDrag(Offset localPosition) {
    final center = Offset(widget.size / 2, widget.size / 2);
    final dx = localPosition.dx - center.dx;
    final dy = localPosition.dy - center.dy;
    // 计算角度（0=右，顺时针，弧度）
    var angle = math.atan2(dy, dx);
    if (angle < 0) angle += math.pi * 2;
    final angleDeg = angle * 180 / math.pi;
    // 在弧段内的相对进度
    var relative = (angleDeg - widget.startAngle) / widget.sweep;
    if (relative < 0) relative += 360 / widget.sweep;
    widget.onSeek!(relative.clamp(0.0, 1.0));
  }

  @override
  Widget build(BuildContext context) {
    final clamped = widget.progress.clamp(0.0, 1.0);

    // MD3 拖动反馈：拖动中加粗提亮，松手回落（短时长强调动画）
    final stroke = _dragging ? widget.strokeWidth * 1.8 : widget.strokeWidth;
    final alpha = _dragging ? 1.0 : 0.0;

    Widget result = SizedBox(
      width: widget.size,
      height: widget.size,
      child: CustomPaint(
        painter: _ArcPainter(
          progress: clamped,
          startAngle: widget.startAngle,
          sweep: widget.sweep,
          strokeWidth: stroke,
          color: Color.lerp(
            widget.color,
            Colors.white,
            alpha * 0.35,
          )!,
        ),
      ),
    );

    if (widget.onSeek != null) {
      result = GestureDetector(
        onPanStart: (d) {
          setState(() => _dragging = true);
          widget.onDragStart?.call();
          _handleDrag(d.localPosition);
        },
        onPanUpdate: (d) => _handleDrag(d.localPosition),
        onPanEnd: (_) {
          setState(() => _dragging = false);
          widget.onDragEnd?.call();
        },
        onPanCancel: () {
          setState(() => _dragging = false);
          widget.onDragEnd?.call();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOutCubic,
          width: widget.size,
          height: widget.size,
          child: result,
        ),
      );
    }

    return Semantics(
      label: widget.semanticsLabel,
      value: '${(clamped * 100).round()}%',
      child: result,
    );
  }
}

class _ArcPainter extends CustomPainter {
  final double progress;
  final double startAngle;
  final double sweep;
  final double strokeWidth;
  final Color color;

  const _ArcPainter({
    required this.progress,
    required this.startAngle,
    required this.sweep,
    required this.strokeWidth,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // 轨道（半透明）
    final trackPaint = Paint()
      ..color = color.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      rect,
      startAngle * math.pi / 180,
      sweep * math.pi / 180,
      false,
      trackPaint,
    );

    // 进度段
    if (progress <= 0) return;
    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      rect,
      startAngle * math.pi / 180,
      sweep * progress * math.pi / 180,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(_ArcPainter old) =>
      old.progress != progress ||
      old.color != color ||
      old.startAngle != startAngle ||
      old.sweep != sweep ||
      old.strokeWidth != strokeWidth;
}
