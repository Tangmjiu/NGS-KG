// Copyright (c) 2025-2026 mjiutang
// SPDX-License-Identifier: MIT

import 'dart:math' as math;
import 'package:flutter/material.dart';

/// 波浪加载条（对标 Rhythm RhythmWavyProgressLoader / M3 LinearWavyProgressIndicator）
///
/// 多条正弦波叠加横向流动；[value] 为 null 时无限波动（indeterminate），
/// 否则只填充 [value] 范围内的进度。可复用于加载态、缓冲进度等。
class WavyProgressIndicator extends StatefulWidget {
  /// 进度 0..1；null 表示不确定（无限流动）
  final double? value;

  final double height;

  /// 叠加波数（越多越厚重）
  final int waves;

  final Color? color;
  final Color? backgroundColor;

  /// 波长（逻辑像素）
  final double wavelength;

  /// 波动速度（相位/秒）
  final double speed;

  const WavyProgressIndicator({
    super.key,
    this.value,
    this.height = 6,
    this.waves = 2,
    this.color,
    this.backgroundColor,
    this.wavelength = 56,
    this.speed = 2.4,
  });

  @override
  State<WavyProgressIndicator> createState() => _WavyProgressIndicatorState();
}

class _WavyProgressIndicatorState extends State<WavyProgressIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return CustomPaint(
          size: Size.infinite,
          painter: _WavyPainter(
            value: widget.value,
            waves: widget.waves,
            color: widget.color ?? cs.primary,
            backgroundColor:
                widget.backgroundColor ?? cs.surfaceContainerHighest,
            wavelength: widget.wavelength,
            phase: _controller.value * widget.speed * 2 * math.pi,
          ),
        );
      },
    );
  }
}

class _WavyPainter extends CustomPainter {
  final double? value;
  final int waves;
  final Color color;
  final Color backgroundColor;
  final double wavelength;
  final double phase;

  const _WavyPainter({
    required this.value,
    required this.waves,
    required this.color,
    required this.backgroundColor,
    required this.wavelength,
    required this.phase,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final h = size.height;
    final w = size.width;
    final midY = h / 2;
    final amp = h / 2; // 波峰可到顶

    // 背景圆角条
    final bgRRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, w, h),
      Radius.circular(h / 2),
    );
    canvas.drawRRect(bgRRect, Paint()..color = backgroundColor);

    // 进度裁剪区（indeterminate 全宽；determinate 只画 value 部分）
    final progressW = value == null ? w : w * value!.clamp(0.0, 1.0);
    if (progressW <= 0) return;

    canvas.save();
    canvas.clipRRect(RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, progressW, h),
      Radius.circular(h / 2),
    ));

    // 叠加多条波，从下往上振幅递减、透明度递增，形成"涌动"
    for (var i = 0; i < waves; i++) {
      final waveAmp = amp * (0.35 + 0.28 * i / math.max(1, waves));
      final alpha = 0.25 + 0.35 * (i + 1) / waves;
      final shift = phase + i * 1.7;

      final path = Path();
      final k = 2 * math.pi / wavelength;
      const steps = 64;
      for (var s = 0; s <= steps; s++) {
        final x = w * s / steps;
        final y = midY -
            waveAmp * math.sin(k * x + shift) * 0.5 +
            (h - waveAmp) * 0.4;
        if (s == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      // 闭合到边界，形成填充面
      path.lineTo(w, h);
      path.lineTo(0, h);
      path.close();

      canvas.drawPath(
        path,
        Paint()
          ..color = color.withValues(alpha: alpha)
          ..style = PaintingStyle.fill,
      );
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(_WavyPainter old) {
    return old.value != value ||
        old.waves != waves ||
        old.color != color ||
        old.backgroundColor != backgroundColor ||
        old.wavelength != wavelength ||
        old.phase != phase;
  }
}

/// 便捷变体：圆形波浪加载（用于按钮/图标位置，替代转圈）
class WavyCircleLoader extends StatelessWidget {
  final double size;
  final Color? color;
  final double strokeWidth;

  const WavyCircleLoader({
    super.key,
    this.size = 28,
    this.color,
    this.strokeWidth = 3,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: WavyProgressIndicator(
        value: 0.5,
        height: size,
        color: color,
        backgroundColor: Colors.transparent,
        wavelength: size * 0.9,
        speed: 3.2,
      ),
    );
  }
}
