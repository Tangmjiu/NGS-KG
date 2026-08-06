// Copyright (c) 2025-2026 mjiutang
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../theme/expressive_shape_config.dart';
import '../utils/theme.dart';
import 'expressive_shapes.dart';

/// Expressive 封面：按主题形状预设裁剪封面，可选呼吸微动画
///
/// - 形状预设关闭时退化为 [AppShape.md] 圆角（与现有 UI 一致）
/// - 启用时按预设（squircle/cookie/flower）裁剪，仅作用于**固定比例封面**
/// - [animate] 开启时封面缓慢呼吸（4s 周期 ±1.5%），适合轮播大卡等
///   焦点元素；列表小封面建议关闭以省性能
///
/// 用法：
/// ```dart
/// ExpressiveCover(
///   width: 68, height: 68, animate: false,
///   child: CachedNetworkImage(imageUrl: cover),
/// )
/// ```
class ExpressiveCover extends StatefulWidget {
  final Widget child;
  final double? width;
  final double? height;

  /// 是否启用呼吸微动画（列表封面建议 false）
  final bool animate;

  const ExpressiveCover({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.animate = false,
  });

  @override
  State<ExpressiveCover> createState() => _ExpressiveCoverState();
}

class _ExpressiveCoverState extends State<ExpressiveCover>
    with SingleTickerProviderStateMixin {
  AnimationController? _breath;

  @override
  void initState() {
    super.initState();
    if (widget.animate) {
      _breath = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 4000),
      )..repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(ExpressiveCover oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animate && _breath == null) {
      _breath = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 4000),
      )..repeat(reverse: true);
    } else if (!widget.animate && _breath != null) {
      _breath?.dispose();
      _breath = null;
    }
  }

  @override
  void dispose() {
    _breath?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 精确订阅：只读形状开关与预设，避免跟随主题其它状态重建
    final enabled = context.select<ThemeProvider, bool>(
      (tp) => tp.expressiveShapesEnabled,
    );
    final presetId = context.select<ThemeProvider, String>(
      (tp) => tp.shapePresetId,
    );

    final breath = _breath;

    // 未启用：退化为圆角矩形
    if (!enabled) {
      return ClipRRect(
        borderRadius: AppShape.md,
        child: SizedBox(
            width: widget.width, height: widget.height, child: widget.child),
      );
    }

    final shapes = resolveExpressiveShapes(true, presetId);
    final border = shapes[ShapeTarget.cover] ??
        const ExpressiveShapeBorder(ExpressiveShapeKind.squircle);

    final base = ClipPath(
      clipper: _ExpressiveClipper(border),
      child: SizedBox(
          width: widget.width, height: widget.height, child: widget.child),
    );

    if (breath == null) return base;

    // 呼吸：±1.5% 缓慢缩放
    return AnimatedBuilder(
      animation: breath,
      builder: (context, _) {
        final t = (breath.value - 0.5) * 0.03; // -0.015 .. 0.015
        return Transform.scale(scale: 1 + t, child: base);
      },
    );
  }
}

class _ExpressiveClipper extends CustomClipper<Path> {
  final ExpressiveShapeBorder border;
  const _ExpressiveClipper(this.border);

  @override
  Path getClip(Size size) {
    return border.getOuterPath(Offset.zero & size);
  }

  @override
  bool shouldReclip(_ExpressiveClipper oldClipper) =>
      oldClipper.border != border;
}
