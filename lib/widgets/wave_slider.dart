// Copyright (c) 2025-2026 mjiutang
// SPDX-License-Identifier: MIT

import 'dart:math' as math;
import 'package:flutter/material.dart';

/// 波形滑块（对标 Rhythm WaveSlider）
///
/// 用一组伪随机高度的柱条模拟波形，左侧（已到达）高亮、右侧灰显，
/// 可选呼吸动画营造"跳动"感。可复用于音量、均衡器、播放进度等场景
/// （组件本身不绑定任何播放器状态，仅暴露 [value]/[onChanged]）。
class WaveSlider extends StatefulWidget {
  /// 当前值 0..1
  final double value;

  final ValueChanged<double>? onChanged;
  final ValueChanged<double>? onChangeEnd;

  /// 柱条数量
  final int bars;

  final Color? activeColor;
  final Color? inactiveColor;

  /// 是否让柱条持续呼吸（跳动感）
  final bool animate;

  final double height;

  /// 滑块 thumb 半径（0 则不显示 thumb）
  final double thumbRadius;

  const WaveSlider({
    super.key,
    required this.value,
    this.onChanged,
    this.onChangeEnd,
    this.bars = 28,
    this.activeColor,
    this.inactiveColor,
    this.animate = false,
    this.height = 36,
    this.thumbRadius = 8,
  });

  @override
  State<WaveSlider> createState() => _WaveSliderState();
}

class _WaveSliderState extends State<WaveSlider>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breath;

  @override
  void initState() {
    super.initState();
    _breath =
        AnimationController(vsync: this, duration: const Duration(seconds: 2))
          ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _breath.dispose();
    super.dispose();
  }

  double _fromPosition(double dx, double width) {
    if (width <= 0) return 0;
    return (dx / width).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final active = widget.activeColor ?? cs.primary;
    final inactive = widget.inactiveColor ?? cs.surfaceContainerHighest;

    return SizedBox(
      height: widget.height,
      child: AnimatedBuilder(
        animation: _breath,
        builder: (context, _) {
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) {
              final box = context.findRenderObject() as RenderBox?;
              if (box == null) return;
              final v = _fromPosition(d.localPosition.dx, box.size.width);
              widget.onChanged?.call(v);
            },
            onHorizontalDragStart: (d) {
              final box = context.findRenderObject() as RenderBox?;
              if (box == null) return;
              widget.onChanged
                  ?.call(_fromPosition(d.localPosition.dx, box.size.width));
            },
            onHorizontalDragUpdate: (d) {
              final box = context.findRenderObject() as RenderBox?;
              if (box == null) return;
              widget.onChanged
                  ?.call(_fromPosition(d.localPosition.dx, box.size.width));
            },
            onHorizontalDragEnd: (_) => widget.onChangeEnd?.call(widget.value),
            onHorizontalDragCancel: () =>
                widget.onChangeEnd?.call(widget.value),
            child: CustomPaint(
              size: Size.infinite,
              painter: _WaveSliderPainter(
                value: widget.value.clamp(0.0, 1.0),
                bars: widget.bars,
                activeColor: active,
                inactiveColor: inactive,
                phase: widget.animate ? _breath.value : null,
                thumbRadius: widget.thumbRadius,
                height: widget.height,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _WaveSliderPainter extends CustomPainter {
  final double value;
  final int bars;
  final Color activeColor;
  final Color inactiveColor;
  final double? phase;
  final double thumbRadius;
  final double height;

  const _WaveSliderPainter({
    required this.value,
    required this.bars,
    required this.activeColor,
    required this.inactiveColor,
    required this.phase,
    required this.thumbRadius,
    required this.height,
  });

  /// 确定性伪随机柱高（0.3..1.0），同一索引恒定
  static double _barHeight(int i) {
    final x = (i * 2654435761) & 0x7fffffff;
    return 0.3 + ((x % 1000) / 1000) * 0.7;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final w = size.width;
    final h = size.height;

    final slot = w / bars;
    final barW = slot * 0.6;
    final midY = h / 2;
    final maxHalf = h / 2 - 2;

    for (var i = 0; i < bars; i++) {
      var f = _barHeight(i);
      if (phase != null) {
        // 呼吸：相位 + 错峰，让柱条像均衡器一样跳动
        f = (f + 0.16 * math.sin(phase! * 2 * math.pi + i * 0.9))
            .clamp(0.12, 1.0);
      }
      final half = maxHalf * f;
      final cx = slot * i + slot / 2;
      final isActive = cx / w <= value;

      final paint = Paint()
        ..color = isActive ? activeColor : inactiveColor
        ..style = PaintingStyle.fill;

      final rRect = RRect.fromRectAndRadius(
        Rect.fromLTRB(
          cx - barW / 2,
          midY - half,
          cx + barW / 2,
          midY + half,
        ),
        Radius.circular(barW / 2),
      );
      canvas.drawRRect(rRect, paint);
    }

    // thumb
    if (thumbRadius > 0) {
      final tx = (value * w).clamp(thumbRadius, w - thumbRadius);
      canvas.drawCircle(
          Offset(tx, midY), thumbRadius + 2, Paint()..color = activeColor);
      canvas.drawCircle(
        Offset(tx, midY),
        thumbRadius - 1,
        Paint()..color = Colors.white,
      );
    }
  }

  @override
  bool shouldRepaint(_WaveSliderPainter old) {
    return old.value != value ||
        old.bars != bars ||
        old.activeColor != activeColor ||
        old.inactiveColor != inactiveColor ||
        old.phase != phase ||
        old.thumbRadius != thumbRadius;
  }
}

/// 便捷变体：只读波形进度（无交互、无 thumb）
class WaveformProgress extends StatelessWidget {
  final double value;
  final int bars;
  final double height;

  const WaveformProgress({
    super.key,
    required this.value,
    this.bars = 28,
    this.height = 30,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: WaveSlider(
        value: value,
        bars: bars,
        height: height,
        thumbRadius: 0,
      ),
    );
  }
}
