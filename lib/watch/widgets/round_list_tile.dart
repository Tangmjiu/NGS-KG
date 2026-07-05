// Copyright (c) 2025-2026 mjiutang
// SPDX-License-Identifier: MIT
//
// Wear OS 圆屏列表项 — 大触控区域、圆角卡片样式，适配圆形屏幕

import 'package:flutter/material.dart';

/// Wear OS 圆屏列表项。
///
/// 提供了一个适合在圆屏上触摸操作的列表条目：
/// - 最小 48px 高度，便于手指触控
/// - 12px 圆角
/// - 支持标题、副标题、前置图标、后置组件
/// - `selected` 高亮状态
///
/// 通常与 [WatchScrollList] 配合使用：
/// ```dart
/// WatchScrollList(
///   itemCount: items.length,
///   itemBuilder: (context, index) {
///     final item = items[index];
///     return RoundListTile(
///       title: item.name,
///       subtitle: item.subtitle,
///       onTap: () => handleTap(index),
///     );
///   },
/// )
/// ```
class RoundListTile extends StatelessWidget {
  /// 标题（必填）
  final String title;

  /// 副标题（可选）
  final String? subtitle;

  /// 前置组件（可选），通常为图标
  final Widget? leading;

  /// 后置组件（可选）
  final Widget? trailing;

  /// 点击回调
  final VoidCallback? onTap;

  /// 是否处于选中状态（高亮背景）
  ///
  /// 默认 false。
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // 选中状态下的背景色
    final bgColor = selected
        ? colorScheme.primaryContainer.withValues(alpha: 0.3)
        : Colors.transparent;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Material(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                // ── 前置组件 ──
                if (leading != null) ...[
                  leading!,
                  const SizedBox(width: 12),
                ],

                // ── 文字区域 ──
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight:
                              selected ? FontWeight.bold : FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (subtitle != null && subtitle!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            subtitle!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurface
                                  .withValues(alpha: 0.6),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
                ),

                // ── 后置组件 ──
                if (trailing != null) ...[
                  const SizedBox(width: 8),
                  trailing!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
