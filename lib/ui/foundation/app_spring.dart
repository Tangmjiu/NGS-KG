// SPDX-License-Identifier: MIT
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import 'app_motion_theme.dart';

/// 目标改变时延续当前位置与速度，快速操作不会把动画重置回起点。
class AppSpring extends StatefulWidget {
  final double value;
  final Widget? child;
  final Widget Function(BuildContext, double, Widget?) builder;

  const AppSpring(
      {super.key, required this.value, required this.builder, this.child});

  @override
  State<AppSpring> createState() => _AppSpringState();
}

class _AppSpringState extends State<AppSpring>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController.unbounded(vsync: this, value: widget.value);
  bool _animate = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _animate = !MediaQuery.disableAnimationsOf(context) &&
        TickerMode.valuesOf(context).enabled;
    if (!_animate) _controller.value = widget.value;
  }

  @override
  void didUpdateWidget(AppSpring oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value == oldWidget.value) return;
    if (!_animate) {
      _controller.value = widget.value;
      return;
    }
    _controller.animateWith(SpringSimulation(
      AppMotionTheme.of(context).spatialSpring,
      _controller.value,
      widget.value,
      _controller.velocity,
      snapToEnd: true,
      tolerance: const Tolerance(distance: 0.0005, velocity: 0.001),
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _controller,
        child: widget.child,
        builder: (context, child) =>
            widget.builder(context, _controller.value, child),
      );
}
