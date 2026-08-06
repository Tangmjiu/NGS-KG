// Copyright (c) 2025-2026 mjiutang
// SPDX-License-Identifier: MIT

import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

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

/// 单个漂浮形状的参数（借鉴 Rhythm SplashBackdropShape）
class FloatingShapeSpec {
  /// 形状类型
  final ExpressiveShapeKind kind;

  /// 中心位置（-1..1 相对屏幕，如 Alignment.topLeft）
  final Alignment alignment;

  /// 形状尺寸（逻辑像素）
  final double size;

  /// 填充颜色
  final Color color;

  /// 基础不透明度
  final double baseAlpha;

  /// 呼吸缩放范围（0..1，1 为原始大小）
  final double pulseMin;
  final double pulseMax;

  /// 漂移幅度（逻辑像素）
  final double driftX;
  final double driftY;

  /// 摆动角度（度）
  final double rotationDeg;

  /// 动画速度倍率（相对总周期），用于错开节奏
  final double speed;

  /// 相位偏移（0..2π），用于错开位置
  final double phase;

  const FloatingShapeSpec({
    required this.kind,
    required this.alignment,
    required this.size,
    required this.color,
    this.baseAlpha = 0.18,
    this.pulseMin = 0.92,
    this.pulseMax = 1.06,
    this.driftX = 12,
    this.driftY = 16,
    this.rotationDeg = 8,
    this.speed = 1.0,
    this.phase = 0.0,
  });
}

/// 生成单位路径（半径 1、中心在原点）的 Expressive 形状
///
/// 极坐标半径函数：
/// - circle:    r = 1
/// - squircle:  超椭圆 |x|^n + |y|^n = 1 (n=3)，分母最小约 0.707，不会除零
/// - cookie:    r = 1 - amp·(1-cos(kθ))/2  （柔和内凹）
/// - flower:    r = 1 - amp·(1-cos(kθ))/2  （内凹更深）
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

/// 可复用的漂浮形状背景（借鉴 Rhythm SplashScreen 的背景形状层）
///
/// 单个 AnimationController 驱动全部形状，每个形状通过
/// [FloatingShapeSpec.speed]/[FloatingShapeSpec.phase] 错开节奏，
/// 组合出「呼吸缩放 + 漂移 + 摆动」三重复合动画，性能开销极低。
class FloatingShapes extends StatefulWidget {
  final List<FloatingShapeSpec> shapes;

  /// 往返动画总周期
  final Duration period;

  /// 整体不透明度（供外部入场/退出淡入淡出用）
  final Animation<double>? opacity;

  const FloatingShapes({
    super.key,
    required this.shapes,
    this.period = const Duration(seconds: 9),
    this.opacity,
  });

  @override
  State<FloatingShapes> createState() => _FloatingShapesState();
}

class _FloatingShapesState extends State<FloatingShapes>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _progress;

  // 按形状类型缓存路径，避免每帧重建
  final Map<ExpressiveShapeKind, Path> _pathCache = {};

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.period)
      ..repeat(reverse: true);
    _progress = CurvedAnimation(parent: _controller, curve: Curves.linear);
  }

  @override
  void didUpdateWidget(FloatingShapes oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.period != widget.period) {
      _controller.duration = widget.period;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Path _pathFor(ExpressiveShapeKind kind) {
    return _pathCache.putIfAbsent(kind, () => buildExpressiveShapePath(kind));
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return CustomPaint(
            size: Size.infinite,
            painter: _FloatingShapesPainter(
              shapes: widget.shapes,
              t: _progress.value,
              pathFor: _pathFor,
              opacity: widget.opacity?.value ?? 1.0,
            ),
          );
        },
      ),
    );
  }
}

class _FloatingShapesPainter extends CustomPainter {
  final List<FloatingShapeSpec> shapes;
  final double t;
  final double opacity;
  final Path Function(ExpressiveShapeKind) pathFor;

  const _FloatingShapesPainter({
    required this.shapes,
    required this.t,
    required this.pathFor,
    required this.opacity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (opacity <= 0.01 || size.isEmpty) return;
    for (final spec in shapes) {
      final phase = spec.phase + t * spec.speed * 2 * math.pi;

      // 呼吸缩放：sin 往返 → 0..1 → lerp(pulseMin, pulseMax)
      final pulseWave = (math.sin(phase) + 1) / 2;
      final scale = lerpDouble(spec.pulseMin, spec.pulseMax, pulseWave) ?? 1.0;

      // 漂移：低频双正弦，两个方向频率不同产生 Lissajous 轨迹
      final dx = spec.driftX * math.sin(phase * 0.5 + spec.phase);
      final dy = spec.driftY * math.sin(phase * 0.35 + spec.phase * 1.7);

      // 摆动旋转（来回，非整圈旋转，更柔和）
      final rotation = spec.rotationDeg * math.sin(phase * 0.8) * math.pi / 180;

      final cx = (spec.alignment.x + 1) / 2 * size.width;
      final cy = (spec.alignment.y + 1) / 2 * size.height;
      final r = spec.size / 2 * scale;

      final paint = Paint()
        ..color = spec.color.withValues(alpha: spec.baseAlpha * opacity)
        ..style = PaintingStyle.fill
        ..isAntiAlias = true;

      canvas.save();
      canvas.translate(cx + dx, cy + dy);
      canvas.rotate(rotation);
      canvas.scale(r, r);
      canvas.drawPath(pathFor(spec.kind), paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_FloatingShapesPainter oldDelegate) {
    return oldDelegate.t != t ||
        oldDelegate.opacity != opacity ||
        oldDelegate.shapes != shapes;
  }
}

/// 按主题色生成一组默认漂浮形状（供启动页等场景直接使用）
///
/// [seed] 改变锚点随机分布；[count] 控制形状数量（低端机建议 6-8）。
List<FloatingShapeSpec> buildDefaultFloatingShapes(
  ColorScheme scheme, {
  int seed = 0,
  int count = 8,
}) {
  final random = math.Random(seed);
  final palette = [
    scheme.primary,
    scheme.secondary,
    scheme.tertiary,
    scheme.surfaceContainerHighest,
  ];
  const anchors = <Alignment>[
    Alignment(-0.76, -0.72),
    Alignment(0.76, -0.70),
    Alignment(-0.72, 0.72),
    Alignment(0.74, 0.74),
    Alignment(-0.88, 0.0),
    Alignment(0.88, 0.06),
    Alignment(-0.10, -0.88),
    Alignment(0.12, 0.88),
    Alignment(0.30, -0.34),
    Alignment(-0.34, 0.36),
  ];
  const kinds = <ExpressiveShapeKind>[
    ExpressiveShapeKind.squircle,
    ExpressiveShapeKind.cookie6,
    ExpressiveShapeKind.flower8,
    ExpressiveShapeKind.cookie8,
    ExpressiveShapeKind.circle,
    ExpressiveShapeKind.flower6,
  ];
  final results = List<FloatingShapeSpec>.empty(growable: true);
  for (var i = 0; i < count && i < anchors.length; i++) {
    final anchor = anchors[random.nextInt(anchors.length)];
    final jitterX = (random.nextDouble() - 0.5) * 0.14;
    final jitterY = (random.nextDouble() - 0.5) * 0.14;
    results.add(FloatingShapeSpec(
      kind: kinds[random.nextInt(kinds.length)],
      alignment: Alignment(
        (anchor.x + jitterX).clamp(-1.0, 1.0),
        (anchor.y + jitterY).clamp(-1.0, 1.0),
      ),
      size: 64 + random.nextDouble() * 96,
      color: palette[random.nextInt(palette.length)],
      baseAlpha: 0.08 + random.nextDouble() * 0.14,
      pulseMin: 0.90 + random.nextDouble() * 0.04,
      pulseMax: 1.02 + random.nextDouble() * 0.06,
      driftX: 10 + random.nextDouble() * 20,
      driftY: 12 + random.nextDouble() * 24,
      rotationDeg: 6 + random.nextDouble() * 12,
      speed: 0.7 + random.nextDouble() * 0.6,
      phase: random.nextDouble() * 2 * math.pi,
    ));
  }
  return results;
}

/// 主题感知的漂浮形状背景（自动取主题色 + 适配暗色）
///
/// 可直接嵌入任意页面的 Stack 最底层，作为 Expressive 背景层。
class ThemedFloatingShapes extends StatelessWidget {
  final int seed;
  final int count;
  final Animation<double>? opacity;

  const ThemedFloatingShapes({
    super.key,
    this.seed = 0,
    this.count = 8,
    this.opacity,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final shapes = buildDefaultFloatingShapes(scheme, seed: seed, count: count);
    return FloatingShapes(shapes: shapes, opacity: opacity);
  }
}
