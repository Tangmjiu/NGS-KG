// Copyright (c) 2025-2026 mjiutang
// SPDX-License-Identifier: MIT
//
// 径向菜单 — 圆屏专属：3–5 个固定入口沿圆周贴边排布，中心放标题/内容

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../utils/watch_layout.dart';
import '../utils/watch_motion.dart';

/// 径向菜单项。
class WatchRadialItem {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const WatchRadialItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });
}

/// 圆屏径向菜单。
///
/// 将 3–5 个固定功能入口按极坐标均匀排布在屏幕下半圆周
/// （±120° 扇区），中心区域放置 [center] 内容（页面标题/插图）。
/// 所有按钮均为 ≥48dp 圆形触控目标，文字标签保持水平。
///
/// 方屏退化为居中的换行网格（保持相同信息架构）。
class WatchRadialMenu extends StatelessWidget {
  final List<WatchRadialItem> items;
  final Widget center;

  const WatchRadialMenu({
    super.key,
    required this.items,
    required this.center,
  });

  @override
  Widget build(BuildContext context) {
    final layout = WatchLayout.of(context);
    if (!layout.isRound) return _buildGrid(context, layout);
    return _buildRadial(context, layout);
  }

  Widget _buildGrid(BuildContext context, WatchLayout layout) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        center,
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          alignment: WrapAlignment.center,
          children: [
            for (final item in items)
              _RadialButton(item: item, size: layout.touchTarget),
          ],
        ),
      ],
    );
  }

  Widget _buildRadial(BuildContext context, WatchLayout layout) {
    final d = layout.diameter;
    final btnSize = layout.touchTarget + 6 * layout.scale;
    // 按钮中心所在圆半径：贴边但不超界（按钮半径 + 标签高度 + 边距）
    final r = d / 2 - btnSize / 2 - 16 * layout.scale - layout.edgeGap;

    // 均匀分布在下方 240° 扇区：从 150° 到 390°（以右侧为 0°，顺时针）
    const start = math.pi * (150 / 180);
    const sweep = math.pi * (240 / 180);
    final n = items.length;

    return SizedBox.expand(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final cx = constraints.maxWidth / 2;
          final cy = constraints.maxHeight / 2;
          return Stack(
            children: [
              Center(child: center),
              for (var i = 0; i < n; i++)
                () {
                  final angle =
                      n == 1 ? math.pi / 2 : start + sweep * (i / (n - 1));
                  final x = cx + r * math.cos(angle) - btnSize / 2;
                  final y = cy +
                      r * math.sin(angle) -
                      btnSize / 2 -
                      10 * layout.scale;
                  return Positioned(
                    left: x,
                    top: y,
                    child: _RadialButton(item: items[i], size: btnSize),
                  );
                }(),
            ],
          );
        },
      ),
    );
  }
}

/// 径向菜单按钮：圆形图标 + 下方水平标签，M3E 按下回弹。
class _RadialButton extends StatefulWidget {
  final WatchRadialItem item;
  final double size;

  const _RadialButton({required this.item, required this.size});

  @override
  State<_RadialButton> createState() => _RadialButtonState();
}

class _RadialButtonState extends State<_RadialButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Semantics(
      button: true,
      label: widget.item.label,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedScale(
            scale: _pressed ? 0.85 : 1.0,
            duration: WatchMotion.durShort2,
            curve: WatchMotion.curveEmphasized,
            child: Material(
              color: cs.surfaceContainerHigh,
              shape: const CircleBorder(),
              child: InkWell(
                onTap: () {
                  WatchMotion.tap();
                  widget.item.onTap();
                },
                onTapDown: (_) => setState(() => _pressed = true),
                onTapUp: (_) => setState(() => _pressed = false),
                onTapCancel: () => setState(() => _pressed = false),
                customBorder: const CircleBorder(),
                child: SizedBox(
                  width: widget.size,
                  height: widget.size,
                  child: Icon(
                    widget.item.icon,
                    size: widget.size * 0.42,
                    color: cs.primary,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            widget.item.label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: cs.onSurface.withValues(alpha: 0.85),
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
