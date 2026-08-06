// Copyright (c) 2025-2026 mjiutang
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import '../utils/theme.dart';

/// 流光骨架屏（Shimmer）— 通用动效组件库第一块
///
/// 对标 Rhythm 的 ShimmerBox：单一 [AnimationController] 驱动
/// 高光渐变从左到右扫过，替代静态灰块。低端机友好（渐变区域小、
/// 无模糊/遮罩层级叠加）。
///
/// 用法：加载态时用它替代静态 `Container(color: ...)` 即可，
/// 圆角/尺寸与原占位一致：
///
/// ```dart
/// ShimmerBox(width: 130, height: 130, borderRadius: AppShape.sm)
/// ```
class ShimmerBox extends StatefulWidget {
  /// 尺寸（null 表示由父级约束决定）
  final double? width;
  final double? height;

  /// 圆角（默认 [AppShape.sm]）
  final BorderRadius? borderRadius;

  /// 基色（默认 `surfaceContainerHighest`）
  final Color? baseColor;

  /// 流光高光色（默认 `surface` 提亮一档）
  final Color? highlightColor;

  /// 单个扫光周期
  final Duration duration;

  /// 扫光起始角度（-1.5 ~ 1.5，越小越斜）
  final double sweepAngle;

  const ShimmerBox({
    super.key,
    this.width,
    this.height,
    this.borderRadius,
    this.baseColor,
    this.highlightColor,
    this.duration = const Duration(milliseconds: 1400),
    this.sweepAngle = -1.2,
  });

  @override
  State<ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<ShimmerBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..repeat();
  }

  @override
  void didUpdateWidget(ShimmerBox oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.duration != widget.duration) {
      _controller.duration = widget.duration;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final base = widget.baseColor ?? cs.surfaceContainerHighest;
    final highlight =
        widget.highlightColor ?? cs.surface.withValues(alpha: 0.9);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        // 渐变随进度平移：begin/end 同步右移，形成扫光
        final t = _controller.value;
        final beginX = widget.sweepAngle + t * 3.0;
        final endX = beginX + 1.0;

        return Container(
          width: widget.width,
          height: widget.height,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: base,
            borderRadius: widget.borderRadius ?? AppShape.sm,
          ),
          child: ShaderMask(
            blendMode: BlendMode.srcATop,
            shaderCallback: (bounds) {
              return LinearGradient(
                begin: Alignment(beginX, -1),
                end: Alignment(endX, 1),
                colors: [
                  highlight.withValues(alpha: 0.0),
                  highlight.withValues(alpha: 0.7),
                  highlight.withValues(alpha: 0.0),
                ],
                stops: const [0.2, 0.5, 0.8],
              ).createShader(bounds);
            },
            child: Container(
              color: Colors.white,
              width: widget.width,
              height: widget.height,
            ),
          ),
        );
      },
    );
  }
}

/// 便捷变体：圆角矩形占位行（标题/文本条）
class ShimmerBar extends StatelessWidget {
  final double? width;
  final double height;
  final BorderRadius? borderRadius;

  const ShimmerBar({
    super.key,
    this.width,
    this.height = 16,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return ShimmerBox(
      width: width,
      height: height,
      borderRadius: borderRadius ?? AppShape.xs,
    );
  }
}
