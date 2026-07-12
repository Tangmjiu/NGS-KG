// Copyright (c) 2025-2026 mjiutang
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import '../utils/theme.dart';

/// 入场渐入滑出动画包装器
///
/// 使用 [TweenAnimationBuilder] 实现 fade + slide up 入场效果，
/// 支持通过 [index] 实现 stagger（逐项延迟）。
/// 参考 [desktop_song_table.dart] 中 _SongTableRow 的入场模式。
///
/// - [index]: 在列表中的位置（0-based），用于计算 stagger 延迟
/// - [duration]: 基础动画时长，stagger 延迟会叠加
/// - [slideOffset]: 滑动距离（像素），默认 10px
/// - [staggerMs]: 每项之间的延迟（毫秒），默认 25ms
/// - [curve]: 动画曲线，默认 [AppMotion.decelerate]（easeOut）
class StaggeredFadeSlide extends StatelessWidget {
  final int index;
  final Duration duration;
  final double slideOffset;
  final int staggerMs;
  final Curve curve;
  final Widget child;

  const StaggeredFadeSlide({
    super.key,
    required this.index,
    this.duration = AppMotion.ds250,
    this.slideOffset = 10,
    this.staggerMs = 25,
    this.curve = AppMotion.decelerate,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(
        milliseconds: duration.inMilliseconds + index * staggerMs,
      ),
      curve: curve,
      builder: (_, double value, Widget? child) {
        final clamped = value.clamp(0.0, 1.0);
        return Opacity(
          opacity: clamped,
          child: Transform.translate(
            offset: Offset(0, slideOffset * (1.0 - clamped)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

/// 按压缩放反馈包装器
///
/// 使用 [AnimatedScale] 实现触控按压缩放效果。
/// 参考 [theme_settings_screen.dart] 中 _PackCard 的模式。
///
/// - [scale]: 按压时的缩放比例，默认 0.95
/// - [duration]: 动画时长，默认 [AppMotion.ds80]
class PressFeedback extends StatefulWidget {
  final VoidCallback? onPressed;
  final VoidCallback? onLongPress;
  final double scale;
  final Duration duration;
  final Widget child;

  const PressFeedback({
    super.key,
    this.onPressed,
    this.onLongPress,
    this.scale = 0.95,
    this.duration = AppMotion.ds80,
    required this.child,
  });

  @override
  State<PressFeedback> createState() => _PressFeedbackState();
}

class _PressFeedbackState extends State<PressFeedback> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onPressed,
      onLongPress: widget.onLongPress,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? widget.scale : 1.0,
        duration: widget.duration,
        curve: AppMotion.decelerate,
        child: widget.child,
      ),
    );
  }
}
