// Copyright (c) 2025-2026 mjiutang
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import '../utils/theme.dart';

/// 数字滚动动画（对标 Rhythm DigitTickerText）
///
/// 数值变化时旧数字下滑淡出、新数字下滑滚入，配合宽度固定避免跳动。
/// 支持任意整数值与自定义格式（补零、千分位、时长等由 [formatter] 处理）。
///
/// 用法：
/// ```dart
/// DigitTicker(value: plays, style: textTheme.headlineMedium)
/// ```
class DigitTicker extends StatefulWidget {
  final int value;

  /// 文本样式
  final TextStyle? style;

  /// 翻滚动画时长
  final Duration duration;

  /// 数字格式器（默认原样输出）
  final String Function(int value)? formatter;

  /// 是否在数字下方叠加一条滑入的强调线（表达"变化"）
  final bool showUnderline;

  const DigitTicker({
    super.key,
    required this.value,
    this.style,
    this.duration = const Duration(milliseconds: 400),
    this.formatter,
    this.showUnderline = true,
  });

  @override
  State<DigitTicker> createState() => _DigitTickerState();
}

class _DigitTickerState extends State<DigitTicker> {
  String get _text => widget.formatter?.call(widget.value) ?? '${widget.value}';

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: widget.duration,
      switchInCurve: AppMotion.emphasizedDecelerate,
      switchOutCurve: AppMotion.emphasizedAccelerate,
      transitionBuilder: (child, animation) {
        // 新数字：从下方 0.6 高度滚入 + 淡入；旧数字：淡出上移
        final offset = Tween<Offset>(
          begin: const Offset(0, 0.55),
          end: Offset.zero,
        ).animate(animation);
        final reverseOffset = Tween<Offset>(
          begin: Offset.zero,
          end: const Offset(0, -0.35),
        ).animate(ReverseAnimation(animation));
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: offset,
            child: SlideTransition(position: reverseOffset, child: child),
          ),
        );
      },
      child: Column(
        key: ValueKey<int>(widget.value),
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_text, style: widget.style),
          if (widget.showUnderline)
            FractionallySizedBox(
              widthFactor: 0.5,
              child: Container(
                height: 2,
                margin: const EdgeInsets.only(top: 3),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 时长格式化的数字滚动（mm:ss / h:mm:ss），适合播放时间等场景
class DurationTicker extends StatelessWidget {
  final Duration value;
  final TextStyle? style;

  const DurationTicker({
    super.key,
    required this.value,
    this.style,
  });

  static String format(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    String two(int n) => n.toString().padLeft(2, '0');
    return h > 0 ? '$h:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
  }

  @override
  Widget build(BuildContext context) {
    return DigitTicker(
      value: value.inSeconds,
      style: style,
      formatter: (seconds) => format(Duration(seconds: seconds)),
      showUnderline: false,
    );
  }
}
