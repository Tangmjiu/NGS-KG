// SPDX-License-Identifier: MIT
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../foundation/app_motion_theme.dart';

/// 通用等待状态：圆润图形连续变形，并仅重绘自身。
class AppLoadingIndicator extends StatefulWidget {
  final Color? color;
  final String semanticLabel;

  const AppLoadingIndicator({
    super.key,
    this.color,
    this.semanticLabel = '正在加载',
  });

  @override
  State<AppLoadingIndicator> createState() => _AppLoadingIndicatorState();
}

class _AppLoadingIndicatorState extends State<AppLoadingIndicator>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  static const _cycle = Duration(milliseconds: 4550);
  late final AnimationController _controller;
  bool _tickerEnabled = false;
  bool _reduceMotion = false;
  late bool _foreground;

  @override
  void initState() {
    super.initState();
    final binding = WidgetsBinding.instance;
    _foreground = binding.lifecycleState == null ||
        binding.lifecycleState == AppLifecycleState.resumed;
    binding.addObserver(this);
    _controller = AnimationController(
      vsync: this,
      duration: _cycle,
      animationBehavior: AnimationBehavior.preserve,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _tickerEnabled = TickerMode.valuesOf(context).enabled;
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    final duration = AppMotionTheme.of(context).scale(_cycle);
    if (_controller.duration != duration) {
      _controller.stop(canceled: false);
      _controller.duration = duration;
    }
    _syncAnimation();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _syncAnimation();
  }

  void _syncAnimation() {
    if (_foreground && _tickerEnabled && !_reduceMotion) {
      if (!_controller.isAnimating) _controller.repeat();
    } else {
      // 保留相位，恢复时从原画面继续，不补跑后台经过的时间。
      _controller.stop(canceled: false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
        label: widget.semanticLabel,
        liveRegion: true,
        child: SizedBox.square(
          dimension: 48,
          child: Center(
            child: RepaintBoundary(
              child: CustomPaint(
                size: const Size.square(38),
                painter: _LoadingPainter(
                  animation: _controller,
                  color: widget.color ?? Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          ),
        ),
      );
}

class _LoadingPainter extends CustomPainter {
  static const _shapeCount = 7;
  static const _samples = 72;
  static final _paths = List.generate(_shapeCount, _buildShape);

  final Animation<double> animation;
  final Color color;

  _LoadingPainter({required this.animation, required this.color})
      : super(repaint: animation);

  // 预计算闭合曲线的控制点；各图形具有相同拓扑，帧间只插值坐标。
  static Float64List _buildShape(int shape) {
    final points = List.generate(_samples, (index) {
      final angle = index * math.pi * 2 / _samples;
      final cos = math.cos(angle);
      final sin = math.sin(angle);
      final radius = switch (shape) {
        0 => 0.8 + 0.2 * math.cos(angle * 6),
        1 => 0.86 + 0.14 * math.cos(angle * 9),
        2 => 0.9 + 0.1 * math.cos(angle * 5),
        3 => 1 / math.sqrt(cos * cos + sin * sin / (0.62 * 0.62)),
        4 => 0.8 + 0.2 * math.cos(angle * 8),
        5 => 0.8 + 0.2 * math.cos(angle * 4),
        _ => 1 / math.sqrt(cos * cos / (0.78 * 0.78) + sin * sin),
      };
      return Offset(cos * radius, sin * radius);
    });
    final commands = Float64List(2 + _samples * 6);
    commands[0] = points[0].dx;
    commands[1] = points[0].dy;
    for (var index = 0; index < _samples; index++) {
      final previous = points[(index + _samples - 1) % _samples];
      final current = points[index];
      final next = points[(index + 1) % _samples];
      final following = points[(index + 2) % _samples];
      final firstControl = current + (next - previous) / 6;
      final secondControl = next - (following - current) / 6;
      final start = 2 + index * 6;
      commands[start] = firstControl.dx;
      commands[start + 1] = firstControl.dy;
      commands[start + 2] = secondControl.dx;
      commands[start + 3] = secondControl.dy;
      commands[start + 4] = next.dx;
      commands[start + 5] = next.dy;
    }
    return commands;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final progress = animation.value * _shapeCount;
    final index = progress.floor() % _shapeCount;
    final fraction = progress - progress.floor();
    final eased = fraction * fraction * (3 - 2 * fraction);
    final from = _paths[index];
    final to = _paths[(index + 1) % _shapeCount];
    double coordinate(int index) =>
        from[index] + (to[index] - from[index]) * eased;
    final path = Path()..moveTo(coordinate(0), coordinate(1));
    for (var index = 2; index < from.length; index += 6) {
      path.cubicTo(
        coordinate(index),
        coordinate(index + 1),
        coordinate(index + 2),
        coordinate(index + 3),
        coordinate(index + 4),
        coordinate(index + 5),
      );
    }
    path.close();
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(animation.value * math.pi * 4);
    canvas.scale(math.min(size.width, size.height) / 2);
    canvas.drawPath(path, Paint()..color = color);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _LoadingPainter oldDelegate) =>
      oldDelegate.animation != animation || oldDelegate.color != color;
}
