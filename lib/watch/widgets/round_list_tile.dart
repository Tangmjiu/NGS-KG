// Copyright (c) 2025-2026 mjiutang
// SPDX-License-Identifier: MIT
//
// 手表列表项 — M3E 胶囊条目，大触控区域，适配圆屏/方屏

import 'package:flutter/material.dart';

import '../theme/watch_theme.dart';
import '../utils/watch_motion.dart';

/// 手表列表项（Wear M3 Chip 风格）。
///
/// - 胶囊形（全圆角）容器，surfaceContainerHigh 底色
/// - 最小 48 高度触控目标
/// - 按下缩小微交互（M3E）
/// - [selected] 时用 primaryContainer 高亮
class RoundListTile extends StatefulWidget {
  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool selected;

  const RoundListTile({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.selected = false,
  });

  @override
  State<RoundListTile> createState() => _RoundListTileState();
}

class _RoundListTileState extends State<RoundListTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final bgColor = widget.selected
        ? colorScheme.primaryContainer
        : colorScheme.surfaceContainerHigh;
    final fgColor = widget.selected
        ? colorScheme.onPrimaryContainer
        : colorScheme.onSurface;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: WatchMotion.durShort2,
        curve: WatchMotion.curveEmphasized,
        child: Material(
          color: bgColor,
          borderRadius: BorderRadius.circular(WatchShapeTokens.full),
          child: InkWell(
            onTap: widget.onTap == null
                ? null
                : () {
                    WatchMotion.tap();
                    widget.onTap!();
                  },
            onTapDown: (_) => setState(() => _pressed = true),
            onTapUp: (_) => setState(() => _pressed = false),
            onTapCancel: () => setState(() => _pressed = false),
            borderRadius: BorderRadius.circular(WatchShapeTokens.full),
            child: Container(
              constraints: const BoxConstraints(minHeight: 46),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
              child: Row(
                children: [
                  if (widget.leading != null) ...[
                    IconTheme(
                      data: IconThemeData(color: fgColor, size: 20),
                      child: widget.leading!,
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.title,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: fgColor,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (widget.subtitle != null &&
                            widget.subtitle!.isNotEmpty)
                          Text(
                            widget.subtitle!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: fgColor.withValues(alpha: 0.6),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  if (widget.trailing != null) ...[
                    const SizedBox(width: 8),
                    widget.trailing!,
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
